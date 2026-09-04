# v1.1 改进设计：评分从 82 → 90

- 日期：2026-09-05
- 状态：已批准（用户确认"先到90分"，语言方案选"英文正文+双语描述"）

## 背景

对 v1.0.0 的 skill 做百分制评估得 82 分，六项扣分。本文档记录逐项修法。

## 扣分项与修法对照

| 扣分 | 问题 | v1.1 修法 |
|---|---|---|
| -5 | 长跑无上下文管理策略 | 新增 "Long-run context management" 节：会话内只留结构化结果；每 10 轮写 checkpoint 进 log 头部并建议开新会话；中断轮记 `result(interrupted)` 从指针恢复 |
| -4 | SKILL.md 仅中文 | 正文重写为英文（canonical、省 token），frontmatter description 中英双语，中文触发词保留 |
| -3 | 目标池会腐化 | 新增 "Pool refresh" 节：每 10 轮或指针绕池一周时，Tier 1 重新 grep 核对、Tier 3 按当前 src/ 重列，并入当轮工作 |
| -3 | 无量化指标 | 记录行结构化：`#<n> \| target \| findings(n) \| actions(n) \| result(green\|red, tests) \| diff(lines)`；头部加 `metrics: findings \| fixes \| regressions` 计数器；"收敛"必须 0 发现 0 回归 |
| -2 | 成本无感知 | 代码 review 按模块大小分级：≤2000 行全读，大模块从目标文件+测试出发按需扩展 |
| -1 | 验证探测覆盖窄 | 显式枚举 pytest / cargo test / go test / mvn test / gradle test |

## 翻译保真说明

英文重写逐节对照中文原版，协议语义不变：七步循环顺序、双角色分工、四层目标池、R1（幻报复核）/R2（子代理权限）/D7（文档滞后）教训引用、复盘轮三产出、全部红线均原样保留。改动仅限上表六项。

## 版本与分发

- plugin.json / marketplace.json → 1.1.0；tag `v1.1.0`
- CHANGELOG.md 记录全部六项
- 双语 README 同步新机制描述
- 本机 `~/.claude/skills/evolve/`（仓库 clone）`git pull` 同步
