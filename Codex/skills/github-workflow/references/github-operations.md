# GitHub 远端操作

## 认证与工具

优先使用当前环境已经认证且适合任务的 GitHub 连接器或工具。只有实际使用本地 `gh` CLI 时，才执行：

- `gh --version`
- `gh auth status`

认证失败、权限不足或参数错误时停止相关写操作，不重复尝试。

读取操作遇到 EOF、TLS 握手失败或其他临时网络错误时最多重试两次，也可以切换到同一认证上下文下的 REST 查询。写操作出现网络错误时先查询远端状态，确认是否已生效后再决定是否重试。

## Push 与 PR

本地提交、工作区和配置确认后，只按用户目标推送需要的功能分支。

创建 PR 时使用解析后的 `baseBranch`。默认 PR 正文：

~~~markdown
## 分支
- 当前分支：
- 目标分支：

## 变更摘要
- 本次修改内容

## 自检
- 已执行检查
- 未执行检查及原因
~~~

`github.pr.bodySections` 只选择 Skill 已支持的栏目。

## PR 合并前检查

合并前读取：

- PR 当前状态；
- 冲突状态；
- required checks；
- review 状态；
- 仓库是否允许配置的合并方式。

没有检查项不视为失败；明确失败的 required check 才阻止合并。无法确认关键状态时暂停，不凭猜测继续。

## merge / squash / rebase

`github.mergeMethod` 正式支持：

- `merge`：使用 merge commit；
- `squash`：把 PR 改动压缩为一个提交后合入；
- `rebase`：把 PR 提交重放到基准分支后合入。

使用 `gh` CLI 时分别对应：

~~~text
gh pr merge <number> --merge
gh pr merge <number> --squash
gh pr merge <number> --rebase
~~~

仓库未开启配置的方法时停止并报告，不自动降级成其他方式。

合并前记录基准分支 HEAD；合并后重新读取 PR 与远端基准分支，并记录实际集成结果。不要把所有方式都假设成存在 merge commit：

- `merge`：核对实际 merge commit；
- `squash`：核对基准分支上的 squash commit；
- `rebase`：核对本次 PR 重放后进入基准分支的提交范围。

如果并发提交导致无法唯一确认本次 PR 的集成结果，停止后续 Tag 或 Release 并报告。

默认不使用 `--delete-branch`；功能分支删除由用户单独决定。

## 远端分支删除

默认不删除远端分支。只有用户明确指定目标分支时才执行。

删除前至少确认：

- 分支名称与用户指定一致；
- 不是仓库默认分支；
- 不受保护；
- 是否含有未被其他保留分支或 Tag 覆盖的唯一 Commit。

普通已合并功能分支不要求机械地再次确认。只有删除会让未合并唯一 Commit 失去正常引用，或实际目标与用户描述不一致时，才暂停并再次说明风险。

删除后重新读取远端分支列表确认结果。

## 完成核验

根据实际阶段确认 Push、PR 或合并状态。无法确认时明确标记未确认，不把本地成功等同于 GitHub 远端成功。
