# evolve skill GitHub 开源仓库设计

- 日期：2026-09-04
- 状态：已批准（用户确认方案 1：完整开源门面）

## 背景与目标

`evolve` skill（通用自我迭代协议 v1，从 GumuHub portal 181 轮真实迭代泛化而来）目前仅存于本地 `D:\Github\evolve` 仓库（单 commit，无远程）。目标：以 Claude Code plugin 形式发布到 GitHub 公开仓库，支持一行命令安装，同时保留手动复制使用方式。

## 决策记录

| 决策点 | 结论 |
|---|---|
| 发布形式 | Claude Code plugin（`.claude-plugin/` + `skills/evolve/SKILL.md`） |
| 仓库名 | `tangjianfang/evolve` |
| README 语言 | 英文主（`README.md`）+ 中文副（`README.zh-CN.md`），顶部互链 |
| 许可证 | MIT |
| 组织方案 | 完整开源门面：含 `CHANGELOG.md` + `docs/design/` |
| 分支 | `master` 改名 `main`（对齐 GitHub 默认） |
| 版本 | `v1.0.0` 起 tag |

## 仓库结构

```
evolve/
├── .claude-plugin/
│   ├── plugin.json          # plugin 元数据
│   └── marketplace.json     # 自引用 marketplace（source: "./"）
├── skills/
│   └── evolve/
│       └── SKILL.md         # skill 本体
├── README.md                # 英文主文档
├── README.zh-CN.md          # 中文文档
├── LICENSE                  # MIT
├── CHANGELOG.md             # skill 自身迭代历史
└── docs/
    └── design/              # 设计文档
        └── 2026-09-04-github-repo-design.md
```

## 关键文件

### plugin.json

`name: "evolve"`、`version: "1.0.0"`、`author: "tangjianfang"`、一句话 description。字段对照本地已安装 plugin（superpowers 缓存）的实际样例，确保兼容 Claude Code plugin 规范。

### marketplace.json

自引用 marketplace：`plugins[0].source = "./"`，使 `/plugin marketplace add tangjianfang/evolve` 可用。字段同样对照实际样例。

### skills/evolve/SKILL.md

内容原样保留（含中文本体），仅改第 60 行硬编码本地路径 `D:\Github\evolve` 为 `github.com/tangjianfang/evolve`，让任意机器上的安装用户知道去哪贡献。

### README.md / README.zh-CN.md

大纲（两版同构）：

1. What it is —— 源自 181 轮真实项目迭代的自我进化协议
2. How it works —— 每轮七步闭环（选目标 → 视觉 review → 代码 review → 行动 → 验证 → 提交 → 记录）+ 双角色（haiku 视觉评审员 / 主模型逻辑工程师）
3. Install —— marketplace 一行命令 + 手动复制到 `~/.claude/skills/evolve/`
4. Usage —— 自然语言"迭代 50 次"或 `/evolve 50`
5. 项目数据文件 —— `docs/evolve-log.md`（轮次指针）、`docs/lessons.md`（教训库）
6. License

### CHANGELOG.md

Keep a Changelog 风格。首条 `## [1.0.0] - 2026-09-04`：从 GumuHub portal 181 轮协议泛化为通用 skill，打包为 Claude Code plugin。

### LICENSE

标准 MIT 文本，`Copyright (c) 2026 tangjianfang`。

## 操作序列

1. `mkdir -p skills/evolve` + `git mv SKILL.md skills/evolve/SKILL.md`
2. 写入全部新文件，编辑 SKILL.md 路径行
3. 分两次 commit：`docs: add github repo design spec`、`feat: package evolve skill as claude code plugin`
4. `git branch -m master main`
5. `gh repo create tangjianfang/evolve --public --source . --push`，repo 描述：`Self-iterating evolution protocol for Claude Code — N rounds of review → fix → verify → commit`
6. `git tag v1.0.0` 并推送

## 验证

- `git ls-files` 输出与设计结构一致，无多余文件
- `gh repo view tangjianfang/evolve` 确认公开、默认分支 `main`、tag `v1.0.0` 存在
- plugin.json / marketplace.json 字段与规范样例兼容

## 范围外（YAGNI）

- 不做多 skill 集合结构（未来新增 skill 时平滑升级）
- 不提供 SKILL.md 英文版（v1 保持中文；英文 README 已是国际用户理解入口）
- 不配置 CI / GitHub Actions / Discussions
