[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$PrepareOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $RepoRoot 'sync.config.local.json'
$StatePath = Join-Path $RepoRoot 'sync.state.local.json'
$SensitiveNamePattern = '(?i)(^|[._-])(\.env|credentials?|secrets?|tokens?|id_rsa)([._-]|$)|\.(pem|key|pfx|p12)$'
$SensitiveContentPatterns = @(
    '-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----',
    'github_pat_[A-Za-z0-9_]{20,}',
    'gh[pousr]_[A-Za-z0-9_]{20,}',
    'sk-(?:proj-)?[A-Za-z0-9_-]{20,}',
    'AKIA[0-9A-Z]{16}',
    'AIza[0-9A-Za-z_-]{20,}',
    'xox[baprs]-[0-9A-Za-z-]{10,}'
)
$TextExtensions = @('.md', '.txt', '.json', '.yaml', '.yml', '.toml', '.ini', '.config', '.ps1', '.psm1', '.py', '.js', '.ts', '.tsx', '.jsx', '.cs', '.sh', '.bat', '.cmd', '.xml', '.html', '.css', '.scss')

function Get-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-RedactionRules {
    param([Parameter(Mandatory)]$Config)

    $rules = @()
    foreach ($rule in @($Config.redactions)) {
        if ([string]::IsNullOrWhiteSpace($rule.value) -or [string]::IsNullOrWhiteSpace($rule.placeholder)) {
            throw '每条脱敏规则必须同时包含 value 和 placeholder。'
        }
        $rules += [pscustomobject]@{
            Value = [string]$rule.value
            Placeholder = [string]$rule.placeholder
        }
    }
    return @($rules | Sort-Object { $_.Value.Length } -Descending)
}

function Redact-PublicPaths {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][array]$Rules
    )

    foreach ($file in Get-ChildItem -LiteralPath $Directory -Recurse -File -Force) {
        if ($TextExtensions -notcontains $file.Extension.ToLowerInvariant()) {
            continue
        }

        try {
            $original = [System.IO.File]::ReadAllText($file.FullName)
        }
        catch {
            throw "无法读取脱敏文件：$($file.FullName)"
        }

        $redacted = $original
        foreach ($rule in $Rules) {
            $pathPattern = [regex]::Escape($rule.Value) -replace '\\\\', '[\\\\/]'
            $redacted = [regex]::Replace($redacted, $pathPattern, $rule.Placeholder, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
        $redacted = [regex]::Replace($redacted, '(?<![A-Za-z0-9])(?:[A-Za-z]:[\\/](?![\\/]))[^\s"''`<>|*?]+', '<LOCAL_PATH>')
        $redacted = [regex]::Replace($redacted, '(?i)%(?:USERPROFILE|APPDATA|LOCALAPPDATA|HOMEDRIVE|HOMEPATH)%', '<USER_HOME>')

        if ($redacted -ne $original) {
            [System.IO.File]::WriteAllText($file.FullName, $redacted, [System.Text.UTF8Encoding]::new($false))
        }
    }
}

function Test-SensitiveFile {
    param([Parameter(Mandatory)][System.IO.FileInfo]$File)

    if ($File.Name -match $SensitiveNamePattern) {
        return "敏感文件名：$($File.Name)"
    }

    if ($TextExtensions -notcontains $File.Extension.ToLowerInvariant()) {
        return $null
    }

    try {
        $content = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8
    }
    catch {
        return "无法读取并扫描：$($File.Name)"
    }

    foreach ($pattern in $SensitiveContentPatterns) {
        if ($content -match $pattern) {
            return "疑似密钥内容：$($File.Name)"
        }
    }

    return $null
}

function Get-SafeSkillPlans {
    param([Parameter(Mandatory)]$Source)

    $plans = @()
    $seenNames = @{}
    $allowedNames = @()
    $skillNamesProperty = $Source.PSObject.Properties['skillNames']
    if ($null -ne $skillNamesProperty) {
        $allowedNames = @($Source.skillNames | ForEach-Object { [string]$_ })
        if ($allowedNames.Count -eq 0) {
            throw "来源 $($Source.name) 配置了 skillNames，但列表为空。"
        }

        foreach ($allowedName in $allowedNames) {
            if ([string]::IsNullOrWhiteSpace($allowedName) -or $allowedName -notmatch '^[A-Za-z0-9_-]+$') {
                throw "来源 $($Source.name) 的 skillNames 必须使用仅含英文、数字、下划线或连字符的名称。"
            }
        }
    }

    foreach ($rootPath in @($Source.skillRoots)) {
        if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
            Write-Warning "Skill 根目录不存在，已跳过：$rootPath"
            continue
        }

        $candidates = Get-ChildItem -LiteralPath $rootPath -Directory -Force
        foreach ($candidate in $candidates) {
            if ($candidate.Name -eq '.system') {
                continue
            }

            if ($allowedNames.Count -gt 0 -and $allowedNames -notcontains $candidate.Name) {
                continue
            }

            $skillDefinitions = @(Get-ChildItem -LiteralPath $candidate.FullName -Recurse -File -Filter 'SKILL.md' -Force)
            if ($skillDefinitions.Count -eq 0) {
                continue
            }

            if ($seenNames.ContainsKey($candidate.Name)) {
                throw "来源 $($Source.name) 中存在同名 Skill：$($candidate.Name)"
            }
            $seenNames[$candidate.Name] = $true

            $reason = $null
            foreach ($file in Get-ChildItem -LiteralPath $candidate.FullName -Recurse -File -Force) {
                $reason = Test-SensitiveFile -File $file
                if ($null -ne $reason) {
                    break
                }
            }

            if ($null -ne $reason) {
                Write-Warning "跳过 Skill $($Source.name)/$($candidate.Name)：$reason"
                continue
            }

            $plans += [pscustomobject]@{
                Name = $candidate.Name
                Path = $candidate.FullName
            }
        }
    }

    return $plans
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "找不到本地配置文件：$ConfigPath"
}

$state = $null
if (Test-Path -LiteralPath $StatePath -PathType Leaf) {
    $state = Get-JsonFile -Path $StatePath
}

if (-not $Force -and $null -ne $state -and $null -ne $state.lastSuccessfulCheckAt) {
    $lastSuccessfulCheckAt = [DateTimeOffset]::Parse([string]$state.lastSuccessfulCheckAt)
    if ((([DateTimeOffset]::Now - $lastSuccessfulCheckAt).TotalDays) -lt 7) {
        Write-Host "距离上次成功检查不足 7 天，跳过。"
        exit 0
    }
}

$config = Get-JsonFile -Path $ConfigPath
$redactionRules = Get-RedactionRules -Config $config
$sourcePlans = @()
foreach ($source in @($config.sources)) {
    if ([string]::IsNullOrWhiteSpace($source.name) -or $source.name -notmatch '^[A-Za-z0-9_-]+$') {
        throw '每个来源必须使用仅含英文、数字、下划线或连字符的 name。'
    }

    $agentPlan = $null
    if (Test-Path -LiteralPath $source.agentsPath -PathType Leaf) {
        $agentFile = Get-Item -LiteralPath $source.agentsPath
        $agentReason = Test-SensitiveFile -File $agentFile
        if ($null -eq $agentReason) {
            $agentPlan = $agentFile.FullName
        }
        else {
            Write-Warning "跳过 AGENTS.md ($($source.name))：$agentReason"
        }
    }
    else {
        Write-Warning "AGENTS.md 不存在，已跳过：$($source.agentsPath)"
    }

    $sourcePlans += [pscustomobject]@{
        Name = $source.name
        AgentPath = $agentPlan
        Skills = @(Get-SafeSkillPlans -Source $source)
    }
}

foreach ($sourcePlan in $sourcePlans) {
    $destination = Join-Path $RepoRoot $sourcePlan.Name
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null

    if ($null -ne $sourcePlan.AgentPath) {
        Copy-Item -LiteralPath $sourcePlan.AgentPath -Destination (Join-Path $destination 'AGENTS.md') -Force
    }

    if ($sourcePlan.Skills.Count -gt 0) {
        $skillsDestination = Join-Path $destination 'skills'
        New-Item -ItemType Directory -Path $skillsDestination -Force | Out-Null
        foreach ($skill in $sourcePlan.Skills) {
            Copy-Item -LiteralPath $skill.Path -Destination (Join-Path $skillsDestination $skill.Name) -Recurse -Force
        }
    }

    Redact-PublicPaths -Directory $destination -Rules $redactionRules
}

if ($PrepareOnly) {
    Write-Host '准备完成：未提交、未推送，也未更新同步状态。'
    exit 0
}

& git -C $RepoRoot rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    throw '当前目录尚未初始化为 Git 仓库。'
}

$pathsToStage = @($sourcePlans.Name)
& git -C $RepoRoot add --all -- $pathsToStage
if ($LASTEXITCODE -ne 0) {
    throw 'git add 失败。'
}

& git -C $RepoRoot diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    $changed = $false
}
elseif ($LASTEXITCODE -eq 1) {
    $changed = $true
}
else {
    throw '无法判断暂存区状态。'
}

if ($changed) {
    $message = 'sync: ' + (Get-Date -Format 'yyyy-MM-dd')
    & git -C $RepoRoot commit -m $message
    if ($LASTEXITCODE -ne 0) {
        throw 'git commit 失败。'
    }

    & git -C $RepoRoot push
    if ($LASTEXITCODE -ne 0) {
        throw 'git push 失败。'
    }
    Write-Host '已完成同步、提交和推送。'
}
else {
    Write-Host '内容无变化，已完成检查。'
}

$newState = [pscustomobject]@{
    lastSuccessfulCheckAt = [DateTimeOffset]::Now.ToString('o')
}
$newState | ConvertTo-Json | Set-Content -LiteralPath $StatePath -Encoding UTF8
