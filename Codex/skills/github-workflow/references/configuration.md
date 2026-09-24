# 配置规则

项目配置是默认规则的 override，不是完整配置副本。与全局默认一致的字段应省略，只有项目确实不同的行为才写入 `github-cli-config.json`。

## 配置发现

先用 `git rev-parse --show-toplevel` 得到项目根目录，再按顺序查找：

1. 项目根目录 `github-cli-config.json`；
2. `<USER_HOME>/.codex/state/github-workflow/projects.json` 中当前项目登记的 `configPath`；
3. 都没有时使用 Skill 默认值。

外部登记表只保存项目路径、配置路径和 `skipPrompt`，不保存认证信息。配置路径不存在或 JSON 无法解析时报告错误，不静默使用损坏配置。

只有当前阶段确实需要一个没有默认值的参数时才询问用户；不要为本地 Commit 提前询问 Tag、Release 或版本文件。

## 默认值

未配置时使用：

- `repositories`：只处理项目根目录仓库；
- `repository.remote`：`origin`；
- `repository.primary`：项目根目录仓库；
- `github.baseBranch`：GitHub 仓库默认分支；
- `branch.format`：`{type}/{stage}_{version}_{function}@{developer}`；
- `branch.types`：`feature`、`hotfix`；
- `branch.stages`：`dev / develop`、`rel / release`；
- `commit.format`：`<{type}> {subject}`；
- `commit.types`：`feature`、`fix`、`refactor`、`test`、`docs`、`ui`、`chore`；
- `checks.commands`：空；
- `github.pr.bodySections`：`branches`、`summary`、`verification`；
- `github.mergeMethod`：`merge`；
- `github.tag.afterMerge`：`false`；
- `github.tag.format`：`{version}`；
- `github.tag.annotated`：`true`；
- `github.release.afterTag`：`false`；
- `github.release.notesFile`：继承 `version.file`。

`github.tag.afterMerge` 和 `github.release.afterTag` 只表示在用户已经授权 version-release 阶段时是否继续，不会把普通 merge 自动扩大成发布。

## 可配置项

- `repositories`：每项支持 `name`、`path`、`baseBranch`、`remote`、`primary`。
- `version.file`、`version.upgradeRules`。
- `branch.format`、`branch.types`、`branch.stages`。
- `commit.format`、`commit.types`；旧版 `commit.resourceTypes` 可继续作为分类提示，但不参与 Commit message。
- `checks.commands`。
- `github.baseBranch`。
- `github.pr.bodySections`。
- `github.mergeMethod`：`merge`、`squash`、`rebase`。
- `github.tag.afterMerge`、`github.tag.format`、`github.tag.annotated`。
- `github.release.afterTag`、`github.release.notesFile`。

只写需要覆盖的字段。例如一个使用简化分支名的项目只需要：

~~~json
{
  "branch": {
    "format": "{type}/{function}@{developer}"
  }
}
~~~

## 覆盖规则

- `repositories` 未配置时只处理根仓库；配置后每个仓库分别解析 `path`、`remote`、`baseBranch` 和状态。
- 最多一个仓库设置 `primary: true`；版本、Tag 和 Release 默认只作用于主仓库。
- `repository.baseBranch` 优先于 `github.baseBranch`；两者都没有时使用 GitHub 默认分支。
- `branch.types`、`branch.stages` 和 `commit.types` 按名称与默认集合合并；同名覆盖说明，新增名称扩展集合。
- `branch.format` 和 `commit.format` 是整体覆盖。
- `commit.format` 必须且只能各包含一次 `{type}` 与 `{subject}`。
- `github.mergeMethod` 只允许 `merge`、`squash`、`rebase`；其他值视为配置错误。
- `github.pr.bodySections` 支持 `branches`、`summary`、`verification`；未知栏目视为配置错误。

## 多仓库

对每个配置仓库分别检查工作区、当前分支、远端、改动范围、Commit、Push 和 PR。一个仓库的 Commit 不得包含另一个仓库的文件。

没有有效路径、发现未授权改动或某个仓库状态无法确认时，只暂停受影响仓库，并报告其他仓库的已完成与未完成状态。

## 分支与开发者标识

已有分支不自动重命名；格式不匹配时报告。新建分支时 `function` 使用简短英文任务名，推荐 kebab-case。

需要 `{developer}` 时依次尝试：

1. 本地 `git config user.name`；
2. 已认证 GitHub 用户显示名；
3. GitHub `login`；
4. 用户提供的非中文标识。

为空或包含中文时跳过当前候选。不得使用邮箱、Token 或其他敏感字段。

## 版本升级配置

`version.upgradeRules` 声明 X、Y、Z 的 `increment` 和 `reset`。没有本次所需规则时，只给出版本建议并询问，不自行猜测清零行为。

~~~json
{
  "X": { "increment": 1, "reset": ["Y", "Z"] },
  "Y": { "increment": 1, "reset": ["Z"] },
  "Z": { "increment": 1, "reset": [] }
}
~~~

`increment` 缺省为 1。X 版本升级仍需用户明确确认，不根据累计次数自动升级。
