# 版本、Tag 与 Release

## 进入条件

只有用户目标包含版本收口、Tag、Release 或完整发布流程时才进入本流程。`github.tag.afterMerge` 或 `github.release.afterTag` 为 true 只是项目行为配置，不会扩大用户当前授权范围。

## 版本记录

配置 `version.file` 后：

1. 读取当前版本文件和现有格式；
2. 根据实际改动判断 X / Y / Z 建议；
3. 使用 `version.upgradeRules` 计算候选版本；
4. 向用户展示版本号与版本记录草稿；
5. 用户确认后才修改版本文件；
6. 把版本文件修改作为正常 Commit 纳入 PR。

X 表示重大架构或不兼容变化，Y 表示新增功能，Z 表示修复、配置或小调整。X 必须明确确认，不按累计次数自动升级。

文件不存在、版本无法解析、升级规则缺失或存在无法确认的无关改动时暂停版本写入。

## 确定发布提交

PR 合并后依据实际 `mergeMethod` 核对集成结果：

- `merge`：发布提交是实际 merge commit；
- `squash`：发布提交是基准分支上的 squash commit；
- `rebase`：从本次 PR 重放后的提交范围中确定对应版本的最终提交。

如果存在并发更新或工具返回信息不足，导致无法唯一证明发布提交与本次 PR 对应，停止 Tag，不猜测目标。

## Tag

只有用户授权 version-release 阶段且 `github.tag.afterMerge` 为 true 时：

1. 确认发布提交；
2. 按 `github.tag.format` 生成 Tag 名称；
3. 根据 `github.tag.annotated` 创建 lightweight 或 annotated Tag；
4. 推送 Tag；
5. 重新读取 Tag，确认解引用后的提交等于发布提交。

Tag 不提前创建、不覆盖已有 Tag、不强推。Tag 已存在时停止并报告。

默认格式为 `{version}`。

## Release

只有 Tag 已确认且 `github.release.afterTag` 为 true 时创建 Release。

Release 正文优先使用 `github.release.notesFile`；未配置时继承 `version.file`。以当前版本号匹配独立 Markdown 标题，例如 `# 0.8.0` 或 `## 0.8.0`，也允许标题带 `v` 前缀。

只截取匹配标题下直到下一个同级或更高层级标题之前的内容。标题前的工程说明、目录和其他版本内容不得进入 Release。

找不到唯一匹配标题时停止，不使用整份文件兜底。

需要修正已存在 Release 正文时编辑 Release，不删除或覆盖 Tag。

## 本地基准分支收尾

远端 Tag 和 Release 都完成或明确不适用后，再同步本地基准分支：

1. 确认工作区干净；
2. fetch 对应 `remote/baseBranch`；
3. 确认本地 `baseBranch` 没有独立分叉；
4. 只使用 fast-forward 同步；
5. 恢复流程开始前所在分支；
6. 再次检查工作区状态。

不得使用 `reset --hard`、强制移动分支或强推代替同步。

本地同步失败不回滚已经成功的远端 Tag 或 Release；报告本地收尾未完成即可。

## 完整版本流程核验

至少确认：

- PR 已按配置方式合入；
- 实际集成结果可追溯；
- Tag 类型和名称符合配置；
- Tag 指向正确发布提交；
- Release 绑定正确 Tag；
- Release 正文来自正确版本段落；
- 本地基准分支同步状态明确；
- 工作区没有本次流程遗留的未预期改动。

任一项无法确认时，报告已完成阶段和未确认项目，不声明版本流程完整成功。
