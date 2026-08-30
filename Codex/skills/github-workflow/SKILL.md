---
name: github-workflow
description: 统一执行项目级 Git 与 GitHub 工作流。用户要求按功能提交、推送分支、创建或合并 PR、生成 Tag、创建 Release、完结版本，或要求检查这些流程时使用；
---

# GitHub Workflow

统一本地 Git 与 GitHub 的提交、PR、合并、Tag 和 Release 流程。项目可通过 github-cli-config.json 写入自身差异，未配置项使用本文档默认规则。项目也可以通过顶层 `repositories` 声明多个相互独立的 Git 仓库；未声明时默认只处理项目根目录仓库。

Git 工作流的结构化配置来源仅为项目配置文件和本 Skill 默认规则。项目级 `AGENTS.md` 可以规定项目专属步骤、检查和暂停条件，但不作为结构化 Git 参数来源；`Standard.md` 不参与本 Skill 的 Git 配置解析。用户当前请求仍决定本次是否执行本地、远端或发布操作。只要求本地提交时停止在本地阶段；只有用户要求完整流程时才进入 GitHub 阶段。

## 多仓库规则

- `repositories` 是可选数组；每项至少包含 `name` 和 `path`。`path` 相对于项目根目录，也可使用绝对路径指向项目范围内的其他 Git 仓库。
- 每项可单独配置 `baseBranch`；未配置时继承顶层 `github.baseBranch`。`remote` 未配置时使用 `origin`。
- `primary: true` 用于标记版本、Tag 和 Release 的主仓库；未标记时默认使用 `path` 为 `.` 的仓库。最多只能有一个主仓库。
- 对数组中的每个仓库分别执行状态、分支、远端、改动范围、提交、推送和 PR 检查；一个仓库的本地提交不能包含另一个仓库的文件。
- 各仓库可以使用相同或不同的当前分支、目标分支和远端；不得因为名称相同就跳过单独核对。
- 顶层 `github.pr` 规则应用于所有仓库；顶层版本、Tag 和 Release 规则默认只应用于主仓库。没有有效仓库路径、存在未授权改动或某个仓库状态无法确认时，暂停受影响仓库，并报告已完成与未完成的仓库。

多仓库配置示例：

~~~json
{
  "repositories": [
    {
      "name": "main",
      "path": ".",
      "baseBranch": "develop",
      "primary": true
    },
    {
      "name": "framework",
      "path": "Assets/Framework",
      "baseBranch": "develop"
    }
  ],
  "github": {
    "baseBranch": "main"
  }
}
~~~

## 配置发现与缺失处理

以 git rev-parse --show-toplevel 得到项目根目录，按以下顺序查找配置：

1. 项目根目录的 github-cli-config.json；
2. 用户外部登记表 <USER_HOME>\.codex\state\github-workflow\projects.json 中的 configPath；
3. 两处都没有时检查外部 skipPrompt 标记；没有标记则逐项询问。

登记表项目键使用仓库根目录绝对路径。configPath 可以使用相对于项目根目录的路径，也可以使用外部绝对路径：相对路径用于项目子目录中的配置，绝对路径用于项目外部的个人配置。
项目配置优先于外部登记表。登记表只保存项目路径、配置路径和“不再询问”标记，不保存凭据，也不放入项目仓库或 Skill。

登记表记录示例：

~~~json
{
  "projects": {
    "<UNITY_DC_PROJECT_ROOT>": {
      "configPath": "Tools/Git/github-cli-config.json",
      "skipPrompt": false
    },
    "<THYROID_PROJECT_ROOT>": {
      "configPath": "<USER_HOME>/Configs/thyroid-github-cli-config.json",
      "skipPrompt": false
    }
  }
}
~~~

configPath 和 skipPrompt 都按项目键生效。外部配置文件不会自动影响其他项目；只有多个项目主动登记同一份配置时，才会共享规则。配置路径不存在或 JSON 无法解析时，报告错误并进入缺失配置处理，不静默使用损坏的配置。

### 缺失配置的询问顺序

首次没有找到有效项目配置且没有命中 skipPrompt 时，先询问是否建立或指定项目配置；同意后再逐项收集配置。每次只推进一个问题：

1. 配置位置：项目根目录、项目相对路径、外部绝对路径或跳过配置；
2. 基准分支；
3. 版本 Markdown 路径；
4. X/Y/Z 版本升级和清零规则；
5. 分支格式、类型和阶段别名；
6. Commit 格式、类型、资源类型及可选判断提示；
7. 额外提交前检查；
8. PR 正文栏目；
9. 合并后的 Tag 和 Release 规则。

开发者选择不配置时，记录 skipPrompt: true，后续按默认规则执行；开发者主动配置时重新读取。

### 配置示例

配置只写需要覆盖的项目差异，例如：

~~~json
{
  "repositories": [
    {
      "name": "main",
      "path": ".",
      "primary": true
    }
  ],
  "version": {
    "file": "docs/版本.md"
  },
  "branch": {
    "types": {
      "experiment": "实验分支"
    }
  },
  "commit": {
    "types": {
      "plugin": "插件或外部工具"
    }
  },
  "checks": {
    "commands": []
  },
  "github": {
    "baseBranch": "main",
    "mergeMethod": "merge",
    "release": {
      "notesFile": "docs/版本.md"
    }
  }
}
~~~

branch.types、branch.stages、commit.types 和 commit.resourceTypes 与系统默认值合并；同名配置覆盖默认说明，新增名称扩展默认列表。branch.format 和 commit.format 属于格式覆盖。`commit.format` 支持 `{type}` 和 `{subject}` 占位符，其他字符按字面保留；未配置时默认使用 `<{type}> {subject}`。commit.types 和 commit.resourceTypes 的条目可以使用旧版字符串说明，也可以使用包含 description、formats 和 commonContent 的对象。formats 与 commonContent 各自独立可选，配置了就按配置判断，未配置就使用系统默认判断。checks.commands 只执行明确配置的额外命令；github.mergeMethod 只允许使用 merge。

### 可配置项

- repositories：参与本次 GitHub 流程的仓库列表；每项支持 name、path、baseBranch、remote 和 primary；缺省时只处理项目根目录仓库；
- version.file：版本 Markdown 路径；
- version.upgradeRules：X/Y/Z 的递增和清零规则；
- branch.format、branch.types、branch.stages：分支格式、类型和阶段别名；
- commit.format、commit.types、commit.resourceTypes：Commit 格式、类型和资源分类；条目对象可选 description、formats、commonContent；
- checks.commands：提交前需要额外执行的命令；
- github.baseBranch：PR 目标分支；
- github.pr.bodySections：PR 正文栏目，默认保留分支、变更摘要和自检；
- github.mergeMethod：合并方式，仅允许 merge；
- github.tag.afterMerge、github.tag.format、github.tag.annotated：合并后是否创建 Tag、Tag 格式和是否使用 annotated Tag；
- github.release.afterTag、github.release.notesFile：Tag 后是否创建 Release，以及版本 Markdown 正文来源。Release 默认只取文件中与当前版本号匹配的版本段落，不使用整份文件。

### 提交分类配置

commit.types 和 commit.resourceTypes 的条目支持以下两种形式：

~~~json
{
  "code": {
    "description": "运行时代码",
    "formats": ["cs", "asmdef", "json"],
    "commonContent": ["运行逻辑", "业务代码"]
  }
}
~~~

description、formats 和 commonContent 都是可选字段，可以只配置其中一个或两个。配置了的字段优先于系统默认提示，未配置的字段由 Skill 根据实际改动判断。每次提交只选择一个类型，不使用额外的 selection 配置。

### 版本升级配置

version.upgradeRules 用于声明升级 X、Y、Z 后的递增和清零行为：

~~~json
{
  "X": {
    "increment": 1,
    "reset": ["Y", "Z"]
  },
  "Y": {
    "increment": 1,
    "reset": ["Z"]
  },
  "Z": {
    "increment": 1,
    "reset": []
  }
}
~~~

increment 未填写时按递增 1 处理；reset 必须明确列出需要清零的版本位。系统 Skill 只定义 X、Y、Z 的变更级别，不预设清零规则。缺少项目配置或缺少本次所需的 upgradeRules 时，先提示开发者补充；确认前只给出版本建议，不修改版本文件。不配置初始版本号，也不执行按累计次数自动升级 X；X 仍需开发者明确确认。

## 版本记录流程

当用户要求执行完整 GitHub PR 流程且配置了 `version.file` 时，在主仓库 PR 阶段：

- 读取版本文件，按现有格式和 `version.upgradeRules`，根据实际改动生成版本号与记录草稿。
- 先报告草稿并获得开发者确认，再写入版本文件；未确认不修改。
- 文件不存在、版本无法解析或有未授权的无关改动时暂停；确认后的版本改动按正常 Commit 处理，Tag 和 Release 按配置执行。

## 默认规则

- 新建分支：{type}/{stage}_{version}_{function}@{developer}；默认类型为 feature（功能）、hotfix（紧急修复），阶段别名为 dev/develop（开发）、rel/release（发布）。已有分支不自动重命名，格式不匹配时先提示。`function` 使用简短英文任务名，例如 `review`、`enhance`、`release`。
- 开发者标识：为 `{developer}` 取值时，依次读取本地 `git config user.name`、GitHub 开发者显示名和 GitHub `login` 账号；候选值为空或包含中文字符时跳过，优先使用下一个候选值。GitHub 信息通过已认证的 `gh api user` 获取；无法获取时继续执行后续候选或询问用户。所有候选都无效时，要求用户提供一个不含中文的开发者名称或账号。不得使用邮箱、Token 或其他敏感字段。
- Commit：默认格式为 `<{type}> {subject}`，例如 `<feature> 新增功能`；默认类型及说明为：
  - feature：新增或扩展用户功能；
  - fix：修复功能、逻辑或兼容性问题；
  - refactor：重构代码，不改变用户可见行为；
  - test：新增或修改自动化测试、QA 脚本；
  - docs：只修改项目文档；
  - ui：更改前端页面的视觉样式、布局或交互表现；
  - chore：依赖、配置、构建、忽略文件等维护工作。
- 常用资源类型：code（业务代码）、editor（编辑器或开发工具）、table（表格或数据）、localize（本地化）、ui（界面）、anim（动画）、scene（场景）、audio（音频）、shader（着色器）、config（配置）、doc（文档）、test（测试），仅用于补充资源归类。
- 版本：X 表示重大架构或不兼容变更，Y 表示新增功能，Z 表示修复、配置或小调整；清零行为以项目 version.upgradeRules 为准，未配置时先提示开发者，不自行推断；X 必须由用户明确确认，不因累计次数自动递增。
- 未确认版本时只给出版本建议，不自行修改版本文件。

## 本地 Git 阶段

### 1. 读取范围

- 执行 git status --short --branch；
- 执行 git diff --stat，并读取必要 diff；
- 确认当前提交、目标分支和远端跟踪关系；
- 读取版本 Markdown，确认当前版本和本次版本变化。

只根据用户当前请求、实际改动及已确认的策划/技术文档判断范围，不处理 Todo 文档。

### 2. 按功能提交

- 独立功能、修复、文档和配置可以分别提交；
- 同一功能的多个文件放在一个提交中；存在强依赖或无法安全拆分时提交一个完整节点；
- 每次只暂存本组文件，提交后核对提交摘要和工作区状态，不为增加数量而机械拆分。
- 如果改动无法可靠区分功能，不强行拆成多个提交。

### 3. 最小检查

默认执行 git diff --check、暂存区范围检查和 Commit 格式检查；项目配置明确要求的命令也必须执行。不默认执行完整回归或生产构建，未执行或失败的检查必须如实记录。

提交失败时保留现场并报告原因，不绕过项目已有的自动检查，也不擅自修改项目规范。

## GitHub 阶段

### 1. CLI 前置检查

任何远端操作前执行 gh --version 和 gh auth status。未安装时给出安装步骤，未登录时给出 gh auth login 步骤；检查失败时暂停远端阶段。不把 Token 写入项目或回复。

读取类命令遇到 `EOF`、TLS 握手失败或其他临时网络错误时，最多有限重试 2 次，并优先改用同一工具提供的 REST 查询；认证失败、权限不足和参数错误不重复重试。写操作返回网络错误时，先查询远端状态确认是否已经生效，再决定是否重试，禁止盲目重复创建、合并、打 Tag 或发布。

### 2. 推送与 PR

本地提交、工作区和配置确认后，对每个已配置仓库分别推送功能分支并创建 PR。PR 正文固定包含：当前分支和目标分支、变更摘要、已执行及未执行的检查结果。不添加“风险和发布限制”栏目，除非用户另行要求。

PR 正文可按以下结构生成：

~~~markdown
## 分支
- 当前分支：
- 目标分支：

## 变更摘要
- 本次完成的功能、修复或文档变更

## 自检
- 已执行的检查及结果
- 未执行的检查及原因
~~~

### 3. 合并

对每个仓库创建 PR 后，分别读取状态、检查项和审查状态。条件满足且用户已授权时执行：

gh pr merge <number> --merge

不得使用 --squash 或 --rebase，也不使用 `--delete-branch`；默认保留本地和远端功能分支。遇到审查、检查或冲突阻塞时停止并报告，不绕过保护规则。

`statusCheckRollup` 为空表示仓库没有配置检查项，不视为失败；明确返回失败的检查才阻止合并。检查查询遇到临时网络错误时按前置规则重试或使用 REST 查询，无法确认状态时暂停，不凭猜测继续合并。

### 4. Tag 与 Release

确认主仓库的 GitHub PR 已完成合并并取得远端合并节点后：

1. 在该节点创建并推送版本 Tag，默认格式为 0.1.0 的版本号；
2. 按配置创建 annotated Tag；
3. Tag 推送成功后，按第 5 节把本地基准分支快进到远端基准分支；
4. 使用配置的版本 Markdown 创建 Release：以 Tag 对应的版本号定位独立 Markdown 标题（例如 `# 0.1.0` 或 `## 0.1.0`，允许标题带 `v` 前缀），只截取该标题下直到下一个同级或更高层级标题之前的内容；标题前的工程说明、目录和其他版本内容不得写入 Release；
5. 复核 Tag 指向的提交、Release 名称和正文来源。

版本 Markdown 未找到唯一匹配的版本标题时，停止 Release 流程并报告，不把整份文件作为兜底正文。用户明确要求修正已存在 Release 的正文时，使用 `gh release edit` 按同样规则更新正文，不删除或覆盖 Tag。

Tag 不提前创建、不覆盖已有 Tag、不强推；Tag 或 Release 已存在时先停止。Release 创建失败时保留已完成的 Tag，并报告失败原因。

### 5. 发布后的本地基准分支同步

主仓库的 Tag 推送成功后，默认把主仓库本地基准分支快进到远端基准分支，等价于在 Git 客户端对本地 `<baseBranch>` 执行“Fast-Forward to `<remote>/<baseBranch>`”；完成后再继续创建 Release。多仓库中的 `<baseBranch>`、`<remote>` 和工作区状态均按对应仓库分别解析：

1. 记录当前分支并确认工作区干净；
2. 执行 `git fetch <remote> <baseBranch>`；
3. 确认本地 `<baseBranch>` 是 `<remote>/<baseBranch>` 的祖先；发生分叉时停止，不覆盖本地提交；
4. 当前分支不是 `<baseBranch>` 时，执行 `git fetch <remote> <baseBranch>:<baseBranch>`，直接快进本地基准分支，不切换工作分支；这等价于 Git 客户端的“Fast-Forward to `<remote>/<baseBranch>`”；
5. 当前分支就是 `<baseBranch>` 时，执行 `git merge --ff-only <remote>/<baseBranch>`；
6. 再次确认工作区状态和本地基准分支指向远端节点。

有未提交改动、无法切换分支或无法快进时，停止并报告，不使用 `reset --hard`、强制移动分支或强推替代。

### 6. 流程完成核验

完整流程结束时统一核对：

- 每个仓库的 PR 状态为已合并，合并提交存在且使用 merge commit；
- 主仓库的 Tag 存在、类型符合配置，解引用后的提交等于主仓库 PR 的 merge commit；
- 主仓库的 Release 绑定当前 Tag，正文只包含版本 Markdown 中匹配当前版本的段落；
- 每个仓库的本地基准分支与对应 `<remote>/<baseBranch>` 指向同一提交；
- 每个仓库恢复为流程开始前的当前分支；
- 每个仓库工作区干净，`git diff --check` 通过。

任一项无法核对时，报告已完成的阶段和未确认的项目，不声明流程全部完成。

## 安全与暂停条件

- 不强推、覆盖远端历史或删除远端分支，除非用户明确提出并再次确认；
- 不用 git reset --hard 代替核对，回退前确定精确目标并确认提交仍被其他分支或标签保留；
- 发现未授权的工作区改动时先隔离并告知，不擅自丢弃；
- 配置与本 Skill 的固定安全规则冲突时先报告；用户本次操作范围和授权按任务请求处理；
- 推送、PR、合并、Tag 和 Release 都必须在配置及本地提交确认后执行；不把认证信息、局域网地址、密钥或环境私密配置写入项目、PR、Tag 或 Release。
