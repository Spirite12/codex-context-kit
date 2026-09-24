---
name: core
description: 阅读、开发或评审本 Unity DC 工程时使用；定位业务与 DCFrame 边界，按需接入 UI、配表、本地化及现有批处理，并核对验证结果。
---

# Core Skill 入口规范

用于建立当前工程的基础认知，并按任务范围跳转到对应的 `references` 文档。

## 使用顺序

1. 先读仓库根目录 `AGENTS.md`，确认本次任务的读写边界、完成定义与项目级协作规则。
2. 检查工作区状态、子模块状态和任务范围；除非用户明确要求，不把 `Library/`、`Logs/`、`obj/`、IDE 缓存等可再生文件当作工程源码审查对象。
3. 再读当前文档，确认 `core` 的入口导航、索引与专题边界。
4. 读取 `references/project-map.md`，根据任务涉及的模块继续读取对应专题文档。

## 当前职责

- `core` 负责工程入口导航、专题文档索引、模块边界说明与 `core` 自身的自检配置。
- 仓库级通用规则与完成定义不在本 Skill 内重复维护；PR 前 Core 检查流程由根目录 `AGENTS.md` 约束，通用 GitHub 操作由系统级 `github-workflow` Skill 执行。
- `Assets/DCFrame/` 是 Git 子模块；业务任务默认不修改其源码。涉及框架事实时，应同时报告父仓库记录的提交与当前子模块提交是否一致。

## 按任务选择路径

- 工程审查：先按 `references/verification.md` 建立阅读清单，区分源码审查、资源引用扫描、插件概览和未验证项；报告缺陷的触发条件与代码依据。
- 功能开发：从 `project-map.md` 定位模块，再读取对应专题；只接入需求涉及的表、本地化、缓存、红点或音效，不为补齐清单新增功能。
- Skill 更新：以当前源码、配置和场景为事实依据，补丁式修改受影响专题；新增专题时同步本页索引及 `scripts/self-check.json`。
- 完成后按 `references/verification.md` 选择与改动风险匹配的检查。目录存在、脚本 dry-run、自检退出码均不能替代 Unity 执行或 Player 验收。

## 业务开发约束

- 文本统一从 `table` 表读取，并在对应的 `Localization` 下访问。

## 自检入口

- 通用自检脚本：`.agents/scripts/skill_self_check.py`
- 自检注册表：`.agents/registries/skill-self-check.json`
- `core` 自检配置：`.agents/skills/core/scripts/self-check.json`
- `core` 对外描述配置：`.agents/skills/core/agents/openai.yaml`
- 执行方式：在仓库根运行 `python .agents/scripts/skill_self_check.py`；需要显式指定范围时，按实际文件逐个传入 `--path <路径>`；该参数会替代自动收集，须包含完整待审范围，仅传子模块根目录不保证命中其全部专题规则。父仓库通常只显示子模块路径，不能据此认定已检查子模块内部全部改动。
- 此脚本是改动到文档的路由器，不检查事实正确性；`--strict` 仅检查命中 Skill 是否至少有一份相关文档出现在改动中，不能作为逐条核验结果，也不应为通过它而制造无意义文档修改。
- 当 PR 前检查命中 `core` 相关规则时，优先补丁式更新当前文档或对应 `references/*.md`，不整篇重写。

## scripts 索引

- Unity 自动化入口：`scripts/run_unity_task.py`
  - 用途：通过 Unity 命令行调用项目提供的 `CodexBatchVerify` 批处理适配器，执行导表、本地化资源生成或其初始化顺序。
  - 适配器位置：`Assets/DCFrame/Editor/Foundation/CodexBatchVerify.cs`；该文件位于 DCFrame 子模块，修改后需同步核对子模块提交与父仓库指针。
  - 前置条件：项目必须实现脚本映射的静态入口；脚本会先在约定路径静态检查该适配器的无参 `public static void` 声明（不等同于 C# 编译），缺失时不得启动 Unity，也不得把未执行的生成步骤报告为已完成。
  - 使用提示：适配器存在时，涉及 `TableEditor.PackageConfig()`、`LocalizeEditor.CreateLocalizeAsset()` 或首次 Localize 初始化可优先调用该脚本；适配器缺失时，由开发者在 Unity Editor 的既有工具入口执行，或在获得框架修改授权后补齐适配器。

## references 索引

- 审查范围、验证方式与交付证据：`references/verification.md`
- 工程目录与模块入口：`references/project-map.md`
- 框架层说明：`references/framework.md`
- UI / 红点 / 音效：`references/ui.md`
- 表 / 导表 / 生成代码：`references/table.md`
- 本地化：`references/localization.md`

## references 文档编写约定

- 专题文档优先围绕当前任务所需的信息组织内容，保证结构清晰、便于执行，不强制统一模板。
- 按目录、模块或入口罗列内容时，默认按文件夹或路径名字母顺序排列；若采用其他顺序，需说明依据。
- 文档优先记录入口、规则、处理顺序与执行边界，不优先写易过时的实现细节、长代码示例或零散调用片段。
- 说明用法时，优先写简短的“使用提示”或“接入提示”，不展开成完整教程。
- 文档应尽量明确 AI 与开发者的分工边界；若步骤依赖手动操作、资源摆放、预制体拼装或最终表现校验，需单独说明由开发者处理。
