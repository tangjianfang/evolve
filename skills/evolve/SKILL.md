---
name: evolve
description: Self-iterating evolution for any project — N rounds, each = visual review (haiku subagent, UI targets only) + code review (main model) → fix bugs / optimize / extend → verify with project commands → commit → record. State lives in docs/evolve-log.md + docs/lessons.md; first run auto-profiles the project. Use when the user says "iterate N times", "/evolve N", "迭代 N 次" or "evolve N 次".
---

# Evolution Protocol (Generic)

Treat the current project as a continuously self-improving system. Each round is one small, complete loop: **find a problem → solve it → verify → commit → record**. Two roles collaborate:

- **Visual Reviewer (haiku)**: screenshot analysis — broken layout, overflow, contrast, scaling anomalies. Delegated via the `Agent` tool with `model: haiku` and Read/Bash permissions (R2); returns an issue list only. Runs only when the target is UI and the project has a screenshot mechanism; otherwise skip this step and weight code review heavier.
- **Logic Engineer (main model)**: code review, bug fixes, new features, verification, commits — executed by the current session, never delegated to subagents.

## Input

- Round count N (user says "iterate 50 times" → N=50). Default 5 when unspecified.

## Step 0 (mandatory): read project data

1. Read the project's `CLAUDE.md`/`AGENTS.md` (if present) — project boundaries, conventions, and verification methods are part of this protocol.
2. Read `docs/lessons.md` (missing = empty lesson library; the retrospective round will create it).
3. Read `docs/evolve-log.md`. **If missing → run project profiling first** (below), then continue.

## Project profiling (first run only)

Generate the initial `docs/evolve-log.md`:

1. **Verification commands** (round step 5 runs these):
   - `CMakeLists.txt` / `*.sln` / `build.bat` → build command + test runner (ctest / standalone test exe); record the baseline test count (run it once first);
   - `package.json` → syntax check (`node --check`) + test script; for web projects also record the deploy cadence (deploy every 5 rounds; the final round must deploy);
   - `pyproject.toml` / `setup.py` / `requirements.txt` / `*.py` → `python -m pytest` (fall back to `python -m unittest`);
   - `Cargo.toml` → `cargo test`;
   - `go.mod` → `go test ./...`;
   - `pom.xml` / `build.gradle(.kts)` → the project's test task (`mvn test` / `gradle test`);
   - none of the above → ask the user "what command verifies a change?" and record it verbatim.
2. **Target pool** (four priority tiers):
   - Tier 1, known defects: read the project's KNOWN_ISSUES/issues/TODO docs; grep the code for each entry to confirm it is actually unfixed (D7: docs lag behind code);
   - Tier 2, test coverage gaps;
   - Tier 3, module rotation review: list modules from the `src/` directory structure;
   - Tier 4, backlog of small extensions (big items go through their own spec→plan flow, not into rounds).
3. Header block: `- verify: <command>`, `- pointer: #1 (next round)`, `- rounds done: 0`, `- status: initialized`, plus running counters `- metrics: findings 0 | fixes 0 | regressions 0`.

## Pool refresh (every 10 rounds, or after one full sweep of the pool)

A stale pool wastes rounds on an outdated map. When either trigger fires, do it as part of that round's work (no separate commit):

1. Re-verify Tier 1 entries against the code — drop the ones already fixed (D7).
2. Re-list Tier 3 from the current `src/` structure — drop deleted modules, add new ones.
3. Mention the refresh in that round's log line (action `pool-refresh`).

## Per-round loop (strict order)

1. **Pick a target**: next item from the pool by tier priority 1→4 (pointer lives in the `docs/evolve-log.md` header).
2. **Visual review** (UI targets with screenshot capability only): delegate the haiku subagent, prompt template: "This is a screenshot of <area> of <project>. List visual/interaction problems: broken layout, overflow, occlusion, insufficient contrast, scaling anomalies, abnormal spacing, missing copy — ordered by severity. If there are none, answer 'clean'." Every finding must be re-verified before acting (R1: ~15% hallucinated findings — cross-check the source, re-screenshot, or re-run tests).
3. **Code review** — scope by module size (cost guard): small module (≤ ~2000 lines) → read the target sources and tests in full; large module → read the files named by the target and their tests first, expand outward only when findings demand it. Focus = the project CLAUDE.md convention checklist + generic checks (error handling, concurrency/lock boundaries, resource leaks, dead code, hardcoding, performance).
4. **Act** (1–3 items this round, by priority): fix bugs (confirmed review findings first) → optimize existing features → pick a backlog extension that fits in one round.
5. **Verify**: run the commands declared in the evolve-log header; all green or the round doesn't count; re-screenshot UI changes.
6. **Commit**: follow the project's commit conventions (conventional commits etc.); subject `evolve #<round>: <one sentence>`; body lists findings and fixes. **Do not push** (unless the user explicitly asks).
7. **Record**: append one structured line to `docs/evolve-log.md`, advance the header pointer to the next round, and update the header metric counters (findings / fixes / regressions):
   `#<round> | <target> | findings(<n>) | actions(<n>) | result(green|red, <test count>) | diff(<lines>) | <notes>`
   If an issue or KNOWN_ISSUES entry was fixed, update the corresponding doc in the same commit.

## Long-run context management

Long runs (N ≥ 10) degrade as context fills. Rules:

1. Keep only structured outcomes in the conversation — the log line and the commit summary. Never re-paste long diffs or full file contents into chat.
2. Every 10 rounds (or as soon as compaction feels imminent): write a checkpoint into the evolve-log header — current pointer, pool snapshot, in-flight work — then suggest the user start a fresh session; the next session resumes from the pointer via Step 0.
3. Visual-review subagents return issue lists only (already the rule) — never raw screenshots or long prose.
4. If a round is interrupted mid-way: finish the current step or discard uncommitted work, log the round as `result(interrupted)`, and resume from the pointer next time.

## Convergence & termination

- A target that is clean for 2 consecutive rounds leaves the pool for 10 rounds.
- 3 consecutive all-clean pool rounds with an empty backlog → terminate early and report "project converged". "Clean" must be backed by data — 0 findings and 0 regressions in those rounds — not by impression.
- Every round is an independent commit; stop anytime; a resuming run continues from the log header pointer.
- New user instructions take priority; finish them, then return to the loop.

## Retrospective round (mandatory, final round of every run)

After N rounds, the last round **must** be the retrospective, producing three things:

1. **New lessons** → append to `docs/lessons.md` under the right category, template: `| id | one-sentence lesson | how to apply (an executable action, not a slogan) | source |`; update existing entries on the same topic instead of duplicating; if nothing new, re-check that existing entries still apply.
2. **Process improvements** → if this run hit a pit already covered by the lesson library, revise the corresponding step in this SKILL.md (source repo: github.com/tangjianfang/evolve — commit the revision there).
3. **Summary report** → big runs (≥ 20 rounds) update/create `docs/evolve-report.md` including the metrics trend (findings / fixes / regressions over time); small runs append a summary block to evolve-log (outcome numbers, fix list, lesson index).

The retrospective itself counts as a round with its own commit — experience capture is not a bonus, it is part of the iteration.

## Red lines (self-check every round)

- Respect the product boundaries and "don't do" lists declared in the project's CLAUDE.md/AGENTS.md (if absent, confirm boundaries with the user first).
- No auto-push; no touching vendored dependency directories; no new third-party dependencies.
- Tests must be all green before commit (baseline count only grows).
- Keep each round's diff within ~300 lines (or the cap declared in project lessons) — every round stays revertible.
- Fixing an issue entry must update the corresponding doc in the same commit.
- Never delete or modify user data; destructive commands always require confirmation.
