# evolve

**Self-iterating evolution protocol for Claude Code — treat any project as a system that continuously improves itself.**

[简体中文](README.zh-CN.md) | English

evolve runs N rounds of small, complete feedback loops on any project:

> **find a problem → fix it → verify → commit → record**

It was generalized from a real-world run of **181 consecutive iteration rounds** on a production project, then distilled into a generic protocol that works on any codebase.

## How it works

Each round is a strict seven-step loop, driven by two collaborating roles:

| Role | Who | Does what |
|---|---|---|
| Visual Reviewer | haiku subagent (UI targets only) | Screenshot analysis: broken layout, overflow, contrast, scaling issues |
| Logic Engineer | the main model (your session) | Code review, bug fixes, new features, verification, commits |

1. **Pick a target** from a 4-tier priority pool (known issues → test gaps → module rotation → backlog)
2. **Visual review** — delegated to a haiku subagent; findings are cross-checked before acting (≈15% hallucinated findings in practice)
3. **Code review** — project conventions + common checks (error handling, concurrency, leaks, dead code, hardcoding, performance)
4. **Act** — 1–3 items per round, by priority: fix → optimize → small extension
5. **Verify** — run the project's own build/test commands; all green or the round doesn't count
6. **Commit** — one commit per round (`evolve #<round>: <summary>`); never auto-pushes
7. **Record** — append the round to `docs/evolve-log.md` and advance the pointer

The loop **converges**: targets that stay clean for 2 rounds are retired; 3 clean full-pool rounds trigger early termination. The final round is always a **retrospective** that feeds lessons back into `docs/lessons.md` — and, when the process itself was the problem, back into this skill.

## Project data files

evolve keeps its state inside your project:

- `docs/evolve-log.md` — verification commands, round pointer, one line per round
- `docs/lessons.md` — accumulated lessons, each with an actionable "how to apply"

First run on a new project? evolve profiles it automatically: detects build/test commands, greps known-issue docs against the code, and builds the target pool.

## Safety rails (checked every round)

- Respects the project's `CLAUDE.md` / `AGENTS.md` boundaries and "don't do" lists
- Never pushes; never touches vendored deps; never introduces new dependencies
- Tests must stay green (baseline can only grow)
- ~300-line diff cap per round, keeping every round revertible
- Issue fixes must update the corresponding docs in the same commit
- Destructive commands always require confirmation

## Install

**As a Claude Code plugin (recommended):**

```
/plugin marketplace add tangjianfang/evolve
/plugin install evolve@evolve-marketplace
```

**Manual:** copy [`skills/evolve/SKILL.md`](skills/evolve/SKILL.md) to `~/.claude/skills/evolve/SKILL.md` (user-level) or `.claude/skills/evolve/SKILL.md` (project-level).

## Usage

Just say it naturally:

```
迭代 50 次          (iterate 50 rounds)
evolve 30 次
/evolve 20
```

Unspecified, it defaults to 5 rounds. You can stop at any point — state lives in `docs/evolve-log.md`, so a later run resumes from the pointer.

## License

[MIT](LICENSE)
