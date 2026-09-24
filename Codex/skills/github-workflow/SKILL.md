---
name: github-workflow
description: 统一执行项目级 Git 与 GitHub 工作流。用户要求检查改动、按功能提交、推送分支、创建或合并 PR、管理远端分支、生成版本 Tag、创建 Release、完成版本收口，或审核这些流程时使用。按用户明确要求推进到对应阶段，不自动扩大到后续远端或发布操作。
---

# GitHub Workflow

统一管理项目的 Git 检查、提交、推送、PR、合并、Tag 和 Release。本文只保留控制流程；配置细节、远端操作和版本发布规则按需读取 references。

## 核心原则

1. 用户当前请求决定本次允许执行到哪个阶段，以及具体写操作授权。
2. 项目 AGENTS.md 补充项目专属检查、暂停条件和安全边界。
3. github-cli-config.json 只记录项目相对本 Skill 默认值的覆盖项；未配置项继承默认值。
4. 配置不得降低本 Skill 或项目 AGENTS.md 的固定安全规则。
5. 不因为前一阶段已经完成，就自动进入用户未要求的后一阶段。

## 阶段模型

根据用户目标从当前状态补齐到对应阶段，已经完成且可核验的步骤不重复执行：

- inspect：只读检查状态、Diff、分支、远端或历史。
- commit：完成本地检查和 Commit 后停止。
- push：完成 Commit 与 Push 后停止。
- pr：完成 Push 与创建或更新 PR 后停止。
- merge：检查 PR 条件并完成合并后停止。
- version-release：处理版本记录、Tag、Release 和本地收尾。
- destructive-remote：删除远端分支、Tag 等破坏性操作，独立按用户明确授权执行。

只要求本地操作时，不要求 GitHub 认证；只要求检查时，不产生 Git 写操作。

## 开始任务

1. 使用 git rev-parse --show-toplevel 确认仓库根目录。
2. 读取当前项目适用的 AGENTS.md。
3. 明确目标阶段、允许写入的仓库和排除项。
4. 只读取当前阶段需要的配置；缺失但存在默认值的参数直接使用默认值。
5. 执行 git status --short --branch、git diff --stat，并读取必要 Diff。
6. 发现无法确认归属的已有改动、错误仓库、错误分支或权限冲突时，停止相关写操作并报告。

## 按需读取 references

- 配置发现、默认值、多仓库、分支和 Commit 参数：读取 references/configuration.md。
- Push、PR、merge / squash / rebase、网络异常和远端分支管理：读取 references/github-operations.md。
- 版本号、版本文件、Tag、Release 和发布后同步：读取 references/version-release.md。

不要为一次本地 Commit 提前加载或询问 Release 参数。

## 本地 Git 与 Commit

只处理能够直接追溯到用户当前请求的改动，不顺手暂存、格式化、回退或删除无关文件。

按功能组织 Commit：

- 同一功能的关联文件放在一个 Commit；
- 独立功能、修复、文档或配置可分别提交；
- 强依赖且无法安全拆分时保持一个完整 Commit；
- 不为增加 Commit 数量机械拆分。

每次只暂存当前 Commit 对应的文件，提交后重新检查工作区状态。

默认 Commit 格式为 `<{type}> {subject}`。默认类型：

- feature：新增或扩展功能；
- fix：修复功能、逻辑或兼容性问题；
- refactor：重构且不改变用户可见行为；
- test：自动测试或 QA；
- docs：项目文档；
- ui：视觉、布局或交互；
- chore：配置、依赖、构建或工程维护。

项目可通过配置覆盖格式或扩展类型。自动化脚本不得各自硬编码 Commit 格式；需要自动生成 Commit message 时，应使用项目已有的统一 helper，或按同一套默认值 + 项目 override 规则生成并验证。

## 最小检查

默认至少执行：

- `git diff --check`；
- 暂存区文件范围检查；
- Commit message 格式检查。

同时执行项目 AGENTS.md 对当前改动明确要求的检查，以及 `checks.commands` 中配置的额外命令。

未执行、失败或无法确认的检查必须如实记录，不得写成已通过。

## GitHub 远端阶段

进入 Push、PR、合并或远端删除操作时，读取 references/github-operations.md。

优先使用当前环境已经认证且适合任务的 GitHub 工具；只有实际使用本地 `gh` CLI 时，才要求 `gh --version` 和 `gh auth status`。

远端写操作失败或返回网络错误时，先读取远端状态确认是否已经生效，再决定是否重试，不盲目重复创建、合并、删除、打 Tag 或发布。

## 版本与发布阶段

只有用户目标包含版本收口、Tag、Release 或完整发布流程时，才读取 references/version-release.md 和版本配置。

普通 inspect、commit、push、pr 或 merge 不自动修改版本文件，也不因为 `github.tag.afterMerge` 或 `github.release.afterTag` 为 true 而扩大用户授权范围。

## 完成核验

根据本次实际终止阶段核对对应结果，并报告：

- 已完成的阶段；
- 实际 Commit、分支、PR、Tag 或 Release 状态；
- 已执行及未执行的检查；
- 尚未确认或被明确排除的事项。

任何关键结果无法核对时，不声明流程完整成功。

## 固定安全规则

除非用户针对具体破坏性操作明确授权：

- 不强推；
- 不覆盖 Git 历史；
- 不删除 Tag；
- 不删除远端分支；
- 不使用 `git reset --hard` 清理现场；
- 不丢弃无法确认归属的已有改动；
- 不绕过仓库保护规则。

删除远端分支等操作的风险确认方式见 references/github-operations.md。

任何情况下不得把 Token、密码、私钥或其他认证秘密写入仓库、Commit、PR、Tag、Release 或回复。
