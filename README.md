# evolve

**Self-iterating evolution protocol for Claude Code — treat any project as a system that continuously improves itself.**

[简体中文](README.zh-CN.md) | English

evolve runs N rounds of small, complete feedback loops on any project:

> **find a problem → fix it → verify → commit → record**

It was generalized from a real-world run of **181 consecutive iteration rounds** on a production project, then distilled into a generic protocol that works on any codebase.

## How it works

Each round is a strict seven-step loop, run by a senior engineering team — the roles are senior, the execution is tiered (exactly one writable session plus read-only subagents where independence or cost pays):

| Role | Executor | Responsibility (mechanism) |
|---|---|---|
| Tech Lead | the session | target selection, pool priority & refresh, convergence calls, epic graduation calls, diff-cap scope control |
| Senior UX Quality Engineer | haiku subagent · read-only · returns an issue list only | visual review (UI targets with screenshots only): layout, overflow, contrast, scaling |
| Senior Code Reviewer | the session | code review: project conventions + generic defect classes |
| Senior Developer — sole writer | the session (never delegated) | fixes, optimizations, small extensions |
| Senior QA Engineer | the session | red-then-green tests, baseline only grows, runs the locked verify command |
| Principal Inspector (adversarial) | independent subagent · sees the bug + tests, never the fix | refutes every claimed fix |
| Release Manager | the session | one revertible commit per round, never auto-pushes |
| Knowledge Steward | the session | round records, lessons library, crystallization |
| SRE on call | scripts (`auto-evolve.sh` + `breaker.sh`), unattended | circuit breaker, metrics, checkpoints, replay audit |

1. **Pick a target** from a 4-tier priority pool (known issues → test gaps → module rotation → backlog); the pool is re-scanned every 10 rounds so it never iterates against a stale map
2. **Visual review** — delegated to a haiku subagent; findings are cross-checked before acting (≈15% hallucinated findings in practice)
3. **Code review** — project conventions + common checks (error handling, concurrency, leaks, dead code, hardcoding, performance); review scope is cost-guarded by module size
4. **Act** — 1–3 items per round, by priority: fix → optimize → small extension
5. **Verify** — run the project's own build/test commands; all green or the round doesn't count
6. **Commit** — one commit per round (`evolve #<round>: <summary>`); never auto-pushes
7. **Record** — append a structured line (`findings / actions / result / diff`) to `docs/evolve-log.md`, advance the pointer, update the metric counters

The loop **converges**: targets that stay clean for 2 rounds are retired; 3 full-pool-clean rounds with **zero findings and zero regressions** trigger early termination — backed by data, not impression. The final round is always a **retrospective** that feeds lessons back into `docs/lessons.md` — and, when the process itself was the problem, back into this skill.

**Epic escalation:** rounds are deliberately small (fix → optimize → extend). When the log shows round-sized work cannot close a target — fixes keep failing (≥2 red rounds), the target keeps re-entering the pool, three rounds can't finish it, the change can't be sliced into green-able ~300-line rounds, or the capability exceeds the current architecture — evolve stops grinding and writes a proposal to `docs/epics.md` (type refactor/innovate, trigger evidence, hypothesis, implementation sketch). **Rounds never execute epics**: proposals surface at run end for your review, and only approved epics proceed through their own spec→plan flow.

Long runs are first-class: every 10 rounds evolve writes a checkpoint into the log and hands off to a fresh session, resuming from the pointer — context pressure never degrades round quality.

### Architecture

```text
Input: "iterate N times" / "/evolve N"   (unspecified → N = 5)
  │
  ├── interactive mode ── the session runs the rounds (sole writable context)
  │
  └── autonomous mode ── scripts/auto-evolve.sh driver
        one headless session per round, prompt states "round i of N"
        (without the position, the final-round retrospective silently
        never happens — proved live); circuit breaker scripts/breaker.sh:
        3 consecutive no-progress rounds / 3 failed sessions → stop
  │
  ▼
Step 0 · every session reads: CLAUDE.md/AGENTS.md → docs/lessons.md → docs/evolve-log.md
  │      (log missing ⇒ first-run profiling: detect build/test commands,
  │       fix the verify command + baseline, build the target pool)
  ▼
───────── per-round loop · i = 1..N · strict order ─────────

  1. pick target    next pool item by tier priority 1→4 (pointer in the log header)
      ↓
  2. visual review  haiku subagent, UI targets with screenshots only;
      │             findings must be re-verified (~15% hallucinated)
      ↓
  3. code review    Senior Code Reviewer (the session): project conventions +
      │             error handling / concurrency / leaks / dead code /
      │             hardcoding / performance; modules ≤ ~2000 lines read
      │             in full, larger ones expand on demand
      ↓
  4. act            1–3 items per round: fix bugs → optimize → small extension
      ↓
  5. verify         run the verify command locked in the log header —
      │             all green or the round doesn't count (red / blocked);
      │             3 consecutive reds on one action → end the round, no grinding
      ↓
  6. commit         "evolve #i: …" standalone commit; never auto-pushed
      │             (unless explicitly authorized)
      ↓
  7. record         one structured line appended to the log; pointer and
      │             counters updated (header counters ≡ sum of round lines)
      │
      ├─→ i < N: back to 1  (every 10 rounds: checkpoint + pool refresh,
      │                 hand off to a fresh session resuming from the pointer)
      │
      └─→ target hits the epic-escalation standard (a–f)?
                         ──► proposal written to docs/epics.md (consumes a
                              round action; proposing alone ≠ progress — the
                              breaker caps streaks); surfaces at run end →
                              user review → approved runs its own spec→plan,
                              never a round; decomposed slices may re-enter
                              the Tier 4 backlog
──────────────────────────────────────────────────────────
  │
  ▼
Termination: N rounds done / early convergence / breaker / user stop
  → the final round is always the retrospective:
  replay audit (git snapshot replay, strike gamed rounds)
  → lessons update (verified+1 / rewrite / delete — the library must not rot)
  → epics register re-check (rewrite / drop stale proposals)
  → process improvement (a pit already covered by a lesson → revise SKILL.md)
  → crystallization (≥3 same-theme lessons + ≥5 verifications → named mechanism)
  → summary report (≥20 rounds → docs/evolve-report.md; small runs → log block)

═══ cross-cutting layers ═══

[target pool — feeds step 1]
  Tier 1 known defects (issue-doc entries grepped against code — docs lag)
  Tier 2 test-coverage gaps
  Tier 3 module rotation (re-listed from the current src/ layout)
  Tier 4 small-extension backlog (big items go through spec→plan, not rounds)
  refresh: every 10 rounds or one full sweep (drop fixed, re-list modules)
  convergence: a target clean 2 consecutive rounds → out for 10 rounds;
               3 consecutive all-clean rounds + empty backlog → early stop

[anti-gaming — every round; progress = evidence, never narrative]
  progress whitelist (one of): new tests green / red-then-green fix /
    measured improvement / inspector-confirmed fix
  adversarial inspector: gets the bug + the tests, never the fix; told to refute
  novelty guard (vs last 10 rounds) · difficulty guard (2 trivial rounds →
    next must be Tier 1) · verify command locked · retrospective replay audit

[state lives in the project — the resume-from-pointer foundation]
  docs/evolve-log.md   verify command · pointer · rounds done · metrics · round lines
  docs/lessons.md      lesson library (maintained by retrospectives)
```

Design rationale at a glance:

- **Small rounds, big runs** — the ~300-line diff cap keeps every round independently revertible and attributable (a regression is one `git revert`; a progress claim is one replayable commit). Large features aren't blocked — they're decomposed into rounds through their own spec→plan flow.
- **State lives in your repo** — pointer, pool, metrics, lessons: any session can die and the next resumes from the pointer.
- **Progress = evidence** — the whitelist (new tests / red-then-green / measured improvement / inspector-confirmed) makes "improvement" auditable instead of narrative.
- **The process improves itself** — retrospectives feed lessons back into `docs/lessons.md`, and lessons that keep proving out get crystallized into the protocol itself.

## Project data files

evolve keeps its state inside your project:

- `docs/evolve-log.md` — verification commands, round pointer, one structured line per round (findings / actions / result / diff), running metric counters. Example line:
  ```
  #7 | src/ui/Toolbar | findings(2) | actions(2) | result(green, 148 tests) | diff(210) | fixed focus loss + dead shortcut
  ```
- `docs/lessons.md` — accumulated lessons, each with an actionable "how to apply"

First run on a new project? evolve profiles it automatically: detects build/test commands (CMake, package.json, pytest, cargo, go, maven, gradle — or asks you), greps known-issue docs against the code, and builds the target pool. Starter templates ship with the skill under `docs/templates/` (evolve-log, lessons, evolve-report, epics — the last created on first proposal).

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

**Manual:** copy [`skills/evolve/SKILL.md`](skills/evolve/SKILL.md) to `~/.claude/skills/evolve/SKILL.md` (user-level) or `.claude/skills/evolve/SKILL.md` (project-level), plus [`docs/templates/`](docs/templates) alongside it (as `docs/templates/`) — first-run profiling copies these starters when present.

> **Name-collision note:** if the `everything-claude-code` plugin is installed, its own `evolve` skill may win the bare `/evolve` invocation. Prefer the natural-language trigger ("iterate 20 rounds" / "迭代 20 次" — description matching picks this skill) or disable the conflicting plugin.

## Usage

Just say it naturally:

```
迭代 50 次          (iterate 50 rounds)
evolve 30 次
/evolve 20
```

Unspecified, it defaults to 5 rounds. You can stop at any point — state lives in `docs/evolve-log.md`, so a later run resumes from the pointer.

**Fully automated:** run N rounds with zero interaction — one round per headless session, circuit-breaked, anti-gaming guarded:

```
scripts/auto-evolve.sh /path/to/project 50
```

Prerequisites: one interactive round first (profiling), and either a permissions allow-list in the project's `.claude/settings.local.json` or `--danger` on a trusted project. Cost scales linearly with N — pilot with a small N (e.g. 5) to validate profiling and permissions before launching long runs. Allow-list rule prefixes must match the session's shell tool — `Bash(...)` rules do not cover a PowerShell session (Windows default), so add parallel `PowerShell(...)` rules for the verify command and git, and invoke verify as a single command (chained `a && b` fails static validation). Every round must earn `green+progress` through the whitelist — new tests, red-then-green fixes, measured improvements, or inspector-confirmed fixes; 3 consecutive no-progress rounds — or 3 consecutive failed sessions — stop the run. Auto-push only when the project's log header declares `push: auto-authorized`.

## License

[MIT](LICENSE)
