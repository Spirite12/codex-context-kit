# codex-context-kit

把 Codex 全局与项目级的 `AGENTS.md`、完整 Skill 目录同步到一个公开 GitHub 仓库，方便在其他设备查看、下载和恢复。

## 仓库内容

```text
Codex/       # Codex 全局 AGENTS.md 和个人 Skills（排除 .system）
Thyroid/     # Thyroid 项目的上下文
Unity-dc/    # Unity-dc 项目的上下文
scripts/     # 同步工具
```

每个同步的 Skill 会保留其完整目录，包括 `SKILL.md`、`references/`、`scripts/`、`assets/` 等附属文件。Codex 的 `.system` 目录及其内容永不参与同步。

## 本地配置

真实路径在 `sync.config.local.json` 中，该文件已被 Git 忽略，不会上传。公开内容中的绝对路径会被替换为通用占位符；要添加项目或 Skill 根目录时，只编辑本机此文件。

每个来源包含：

- `name`：仓库中的目标目录名；
- `agentsPath`：对应的 `AGENTS.md`；
- `skillRoots`：Skill 父目录列表。父目录下的每个子目录视为一个完整 Skill；名为 `.system` 的目录始终跳过；
- `skillNames`：可选的 Skill 白名单。配置后只同步列出的名称，未列出的新增 Skill 默认不会上传；新增 Skill 需要先加入本机 `sync.config.local.json` 的对应列表。

## 安全规则

同步前会逐文件检查。命中 `.env`、私钥、凭据、token 等敏感文件名，或检测到常见密钥内容时，脚本会跳过整个对应 Skill；其他来源仍可继续同步。

由于这是公开仓库，首次及每次新增 Skill 后都应人工检查 `git diff --cached` 再推送。密钥一旦推送到 GitHub 历史中，删除当前文件并不能彻底消除泄露风险。

## 手动同步

在仓库根目录执行：

```powershell
pwsh -File .\scripts\sync.ps1 -Force
```

首次测试可使用 `-PrepareOnly`：它会复制与扫描文件，但不会提交、推送或更新同步状态。

```powershell
pwsh -File .\scripts\sync.ps1 -Force -PrepareOnly
```

## Codex 定时任务

定时任务应在此仓库的本地项目中运行以下命令：

```powershell
pwsh -File .\scripts\sync.ps1
```

设置为每周六、周日的 11:00 和 15:00。脚本在成功检查或成功推送后会记录本地状态；七天内的后续触发会自动跳过，因此四个时点只作为错过或失败时的兜底。

本地任务仅在电脑开机且 ChatGPT/Codex 桌面端运行时可处理本机文件。若四个时点都错过，可在“已安排”中手动选择“立即运行”。
