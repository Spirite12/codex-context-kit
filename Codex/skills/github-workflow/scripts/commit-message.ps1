[CmdletBinding(DefaultParameterSetName = 'Generate')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Generate')]
    [ValidateNotNullOrEmpty()]
    [string]$Type,

    [Parameter(Mandatory, ParameterSetName = 'Generate')]
    [ValidateNotNullOrEmpty()]
    [string]$Subject,

    [Parameter(Mandatory, ParameterSetName = 'Validate')]
    [ValidateNotNullOrEmpty()]
    [string]$Validate,

    [string]$RepositoryRoot = (Get-Location).Path,
    [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DefaultFormat = '<{type}> {subject}'
$DefaultTypes = @('feature', 'fix', 'refactor', 'test', 'docs', 'ui', 'chore')

function Get-CommitRules {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$ExplicitConfigPath
    )

    $format = $DefaultFormat
    $types = @($DefaultTypes)

    $resolvedConfigPath = $null
    if (-not [string]::IsNullOrWhiteSpace($ExplicitConfigPath)) {
        $candidate = $ExplicitConfigPath
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-Path $Root $candidate
        }
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "GitHub Workflow 配置不存在：$candidate"
        }
        $resolvedConfigPath = (Resolve-Path -LiteralPath $candidate).Path
    }
    else {
        $candidate = Join-Path $Root 'github-cli-config.json'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $resolvedConfigPath = (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if ($null -ne $resolvedConfigPath) {
        $config = Get-Content -LiteralPath $resolvedConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $commitProperty = $config.PSObject.Properties['commit']
        if ($null -ne $commitProperty -and $null -ne $commitProperty.Value) {
            $commitConfig = $commitProperty.Value

            $formatProperty = $commitConfig.PSObject.Properties['format']
            if ($null -ne $formatProperty -and -not [string]::IsNullOrWhiteSpace([string]$formatProperty.Value)) {
                $format = [string]$formatProperty.Value
            }

            $typesProperty = $commitConfig.PSObject.Properties['types']
            if ($null -ne $typesProperty -and $null -ne $typesProperty.Value) {
                foreach ($property in $typesProperty.Value.PSObject.Properties) {
                    if ($types -notcontains $property.Name) {
                        $types += $property.Name
                    }
                }
            }
        }
    }

    if ([regex]::Matches($format, '\{type\}').Count -ne 1 -or [regex]::Matches($format, '\{subject\}').Count -ne 1) {
        throw 'commit.format 必须且只能各包含一次 {type} 与 {subject}。'
    }

    [pscustomobject]@{
        Format = $format
        Types = $types
    }
}

function Get-CommitMessagePattern {
    param([Parameter(Mandatory)][string]$Format)

    $pattern = [regex]::Escape($Format)
    $pattern = $pattern.Replace([regex]::Escape('{type}'), '(?<type>[A-Za-z0-9_-]+)')
    $pattern = $pattern.Replace([regex]::Escape('{subject}'), '(?<subject>.+)')
    '^' + $pattern + '$'
}

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$rules = Get-CommitRules -Root $root -ExplicitConfigPath $ConfigPath

if ($PSCmdlet.ParameterSetName -eq 'Generate') {
    $resolvedType = $Type.Trim()
    $resolvedSubject = $Subject.Trim()

    if ($resolvedType -notin $rules.Types) {
        throw "不支持的 Commit 类型：$resolvedType"
    }
    if ([string]::IsNullOrWhiteSpace($resolvedSubject) -or $resolvedSubject -match '[\r\n]') {
        throw 'Commit subject 必须是非空单行文本。'
    }

    $rules.Format.Replace('{type}', $resolvedType).Replace('{subject}', $resolvedSubject)
    exit 0
}

$message = $Validate
if ($message -ne $message.Trim() -or $message -match '[\r\n]') {
    throw 'Commit message 必须是无首尾空白的单行文本。'
}

$match = [regex]::Match($message, (Get-CommitMessagePattern -Format $rules.Format))
if (-not $match.Success) {
    throw "Commit message 不符合当前格式：$($rules.Format)"
}

$matchedType = $match.Groups['type'].Value
if ($matchedType -notin $rules.Types) {
    throw "Commit message 使用了不支持的类型：$matchedType"
}

$message
