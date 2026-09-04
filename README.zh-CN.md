# evolve

**Claude Code 自我迭代进化协议 —— 把任意项目当成持续自我完善的系统。**

简体中文 | [English](README.md)

evolve 在任何项目上执行 N 轮小而完整的闭环迭代：

> **发现问题 → 解决 → 验证 → 提交 → 记录**

它从一次真实项目上**连续 181 轮迭代**的实践中提炼，泛化为适用于任意代码库的通用协议。

## 工作原理

每轮是严格的七步闭环，由两个协作角色驱动：

| 角色 | 执行者 | 职责 |
|---|---|---|
| 视觉评审员 | haiku 子代理（仅 UI 类目标） | 截图分析：布局错乱、溢出、对比度、缩放异常 |
| 逻辑工程师 | 主模型（当前会话） | 代码 review、修 bug、写新功能、验证、提交 |

1. **选目标**：从四层优先级目标池取下一个（已知缺陷 → 测试缺口 → 模块轮转 → Backlog）；目标池每 10 轮重扫一次，不会拿过时地图迭代
2. **视觉 review**：委派 haiku 子代理执行；发现必须复核再动手（实践中约 15% 是幻报）
3. **代码 review**：项目惯例 + 通用项（错误处理、并发/锁边界、资源泄漏、死代码、硬编码、性能）；review 范围按模块大小成本分级
4. **行动**：每轮 1–3 项，按优先级：修 bug → 优化 → 小扩展
5. **验证**：按项目声明的构建/测试命令执行，全绿才算完成
6. **提交**：每轮独立 commit（`evolve #<轮次>: <一句话>`）；绝不自动 push
7. **记录**：向 `docs/evolve-log.md` 追加结构化一行（发现数 / 行动数 / 结果 / diff 行数），拨动指针，更新指标计数

循环会**收敛**：某目标连续 2 轮干净即移出池子；连续 3 轮全池干净且**零发现、零回归**触发提前终止 —— 靠数据说话，不凭印象。最后一轮固定是**复盘轮**，把教训沉淀进 `docs/lessons.md` —— 若流程本身有坑，还会反哺修订本 skill。

长跑是一等公民：每 10 轮向日志写入 checkpoint 并交接给新会话、从指针续跑 —— 上下文压力不会拖垮轮次质量。

## 项目数据文件

evolve 的状态保存在你的项目里：

- `docs/evolve-log.md` —— 验证命令、轮次指针、每轮一行结构化记录（发现 / 行动 / 结果 / diff）、指标计数器。示例行：
  ```
  #7 | src/ui/Toolbar | findings(2) | actions(2) | result(green, 148 tests) | diff(210) | 修复焦点丢失 + 失效快捷键
  ```
- `docs/lessons.md` —— 累积教训库，每条带可执行的"如何应用"

首次在新项目上运行？evolve 会自动做项目画像：探测构建/测试命令（CMake、package.json、pytest、cargo、go、maven、gradle，都没有就问你）、把已知 issue 文档逐条 grep 代码核对、建立目标池。三个数据文件的起始模板随 skill 自带（`docs/templates/`）。

## 安全红线（每轮自检）

- 遵循项目 `CLAUDE.md` / `AGENTS.md` 声明的边界与"不要做"清单
- 不自动 push；不动 vendored 依赖；不引入新第三方依赖
- 测试必须全绿（基线只增不减）
- 每轮 diff 控制在 ~300 行内，保持可回滚
- 修复 issue 条目必须在同一 commit 同步更新对应文档
- 破坏性命令一律要求确认

## 安装

**作为 Claude Code plugin（推荐）：**

```
/plugin marketplace add tangjianfang/evolve
/plugin install evolve@evolve-marketplace
```

**手动安装：** 把 [`skills/evolve/SKILL.md`](skills/evolve/SKILL.md) 复制到 `~/.claude/skills/evolve/SKILL.md`（用户级）或项目的 `.claude/skills/evolve/SKILL.md`（项目级）。

> **名称冲突提示：** 若同时安装了 `everything-claude-code` 插件，裸名 `/evolve` 可能被它的同名 skill 抢占。建议用自然语言触发（“迭代 20 次”——描述匹配会选中本 skill），或禁用冲突插件。

## 使用

自然语言即可触发：

```
迭代 50 次
evolve 30 次
/evolve 20
```

未指定轮数时默认 5 轮。随时可停 —— 状态存在 `docs/evolve-log.md`，下次运行从指针处继续。

**全自动模式：**零交互跑 N 轮——每轮一个 headless 会话，带熔断与反欺骗防线：

```
scripts/auto-evolve.sh /path/to/project 50
```

前提：先手动跑一轮交互迭代（完成项目画像），并为项目配置 `.claude/settings.local.json` 权限白名单（或在可信项目上用 `--danger`）。白名单规则前缀必须匹配会话的 shell 工具——`Bash(...)` 规则不覆盖 PowerShell 会话（Windows 默认），需为 verify 命令和 git 平行添加 `PowerShell(...)` 规则，且 verify 需以单条命令调用（链式 `a && b` 无法通过静态校验）。每轮必须通过进步白名单挣得 `green+progress`——新增测试、先红后绿修复、可测量改善、或验收员确认的修复；连续 3 轮无进步或连续 3 次会话失败自动熔断。仅当项目 log 头部声明 `push: auto-authorized` 时才自动 push。

## 许可证

[MIT](LICENSE)
