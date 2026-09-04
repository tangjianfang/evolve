---
name: evolve
description: Self-iterating evolution for any project — N rounds, each = visual review (haiku subagent, UI targets only) + code review (main model) → fix bugs / optimize / extend → verify with project commands → commit → record. State lives in docs/evolve-log.md + docs/lessons.md; first run auto-profiles the project. Fully automated runs supported via scripts/auto-evolve.sh (one round per headless session, anti-gaming guards). Use when the user says "iterate N times", "/evolve N", "迭代 N 次" or "evolve N 次".
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

Starter templates for the project data files ship with this skill (`docs/templates/`, next to this SKILL.md in the installation) — copy them when present; the structures described below are authoritative.

Generate the initial `docs/evolve-log.md`:

1. **Verification commands** (round step 5 runs these):
   - `CMakeLists.txt` / `*.sln` / `build.bat` → build command + test runner (ctest / standalone test exe); record the baseline test count (run it once first);
   - `package.json` → syntax check (`node --check`) + test script; for web projects also record the deploy cadence (deploy every 5 rounds; the final round must deploy);
   - `pyproject.toml` / `setup.py` / `requirements.txt` / `*.py` → `python -m pytest` (fall back to `python -m unittest`);
   - `Cargo.toml` → `cargo test`;
   - `go.mod` → `go test ./...`;
   - `pom.xml` / `build.gradle(.kts)` → the project's test task (`mvn test` / `gradle test`);
   - none of the above → ask the user "what command verifies a change?" and record it verbatim. In an autonomous run (the user delegated the whole iteration), define a structural check yourself (JSON / frontmatter / version consistency / link resolution as applicable), establish the baseline, record it as self-defined, and flag it for user review in the retrospective (E3).
2. **Target pool** (four priority tiers):
   - Tier 1, known defects: read the project's KNOWN_ISSUES/issues/TODO docs; grep the code for each entry to confirm it is actually unfixed (D7: docs lag behind code);
   - Tier 2, test coverage gaps;
   - Tier 3, module rotation review: list modules from the `src/` directory structure;
   - Tier 4, backlog of small extensions (big items go through their own spec→plan flow, not into rounds).
3. Header block: `- verify: <command>`, `- pointer: #1 (next round)`, `- rounds done: 0`, `- status: initialized`, plus running counters `- metrics: findings 0 | fixes 0 | regressions 0`. Autonomous runs may also declare `- push: auto-authorized` (see Autonomous mode) — add it only when the user has explicitly authorized auto-push.

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
7. **Record**: append one structured line to `docs/evolve-log.md`, advance the header pointer to the next round, and update the header metric counters (findings / fixes / regressions) — count from the round's review notes, and keep the header counters equal to the sum of the round lines (E4):
   `#<round> | <target> | findings(<n>) | actions(<n>) | result(green+progress|green+no-progress|red|blocked|interrupted, <test count>) | diff(<lines>) | <notes>`
   If an issue or KNOWN_ISSUES entry was fixed, update the corresponding doc in the same commit.

## Long-run context management

Long runs (N ≥ 10) degrade as context fills. Rules:

1. Keep only structured outcomes in the conversation — the log line and the commit summary. Never re-paste long diffs or full file contents into chat.
2. Every 10 rounds (or as soon as compaction feels imminent): write a checkpoint into the evolve-log header — current pointer, pool snapshot, in-flight work — then suggest the user start a fresh session; the next session resumes from the pointer via Step 0.
3. Visual-review subagents return issue lists only (already the rule) — never raw screenshots or long prose.
4. If a round is interrupted mid-way: finish the current step or discard uncommitted work, log the round as `result(interrupted)`, and resume from the pointer next time.

## Autonomous mode

Fully automated runs: the user launches `scripts/auto-evolve.sh <project> <N>` (a driver looping headless `claude -p` sessions) and walks away. Differences from interactive mode:

1. **One round per session** — each headless session runs exactly one round and exits; the driver owns rounds 1..N, and Step 0's pointer makes every session resume cleanly. Context is always fresh: the compaction problem disappears by construction. The driver's prompt states each session's position (`round i of N`) and flags round N as the retrospective — sessions cannot infer this from the log alone (T1g, proved live: a run's final round silently did a normal round instead).
2. **Auto-push** — if the evolve-log header declares `- push: auto-authorized`, step 6 commits AND pushes. Without that declaration the no-push red line stands.
3. **No user prompts** — profiling defines verification commands itself and records them as self-defined (E3); destructive operations are outright forbidden in autonomous mode (no confirmation is possible) — if a round would need one, log `result(blocked)` and pick the next target.
4. **Circuit breaker** — 3 consecutive `no-progress` rounds → stop and report "converged or needs human input". Never manufacture progress to keep the loop alive.
5. **Single writer per tree** — one driver (and no parallel manual session) per project working tree. If a session observes repo state changing beneath it mid-round — files rewritten between its own reads, commits or pushes it did not make — it must stop editing immediately, re-read the log header, and either yield (log `result(blocked)` citing the foreign commit) or re-scope its round on top of the new state; never keep editing from a stale snapshot (live collision 2026-09-05: two concurrent retrospective sessions, one yielded and re-scoped as the next round).

## Anti-gaming rules (objective anchors, every round)

Progress is defined by evidence, never by narrative. A round counts as progress only if it meets the **progress whitelist** — at least one of:

- test baseline grew (+k tests, all green);
- a fix proven red-then-green (a failing test was written and watched failing before the fix, green after);
- a measured number improved (benchmark / coverage / latency — before and after values in the log line);
- a review finding fixed and confirmed by the adversarial inspector.

Rules:

1. **Adversarial inspector**: every bug fix is verified by an independent subagent that receives only the bug description and the tests — never the fix or the fixing session — and is instructed to refute the fix.
2. **Novelty guard**: before committing, compare the round's target+action against the last 10 log lines; substantively repeating a prior round → discard and pick the next target.
3. **Difficulty guard**: 2 consecutive trivial rounds (whitelist satisfied only by k < 2 new tests) → the next round must come from Tier 1.
4. **Verification lock**: the verify command in the log header is read-only after profiling; changing it requires its own commit, flagged in the log.
5. **Replay audit** (in the retrospective): sample 2 rounds whose progress claim was red-then-green or baseline-grew; check out each round's parent commit and confirm the round's new tests are absent-or-failing there and green on the round's commit. A round that fails replay is struck from the metrics and marked `gamed`.
6. The record's `result` field takes one of: `green+progress` / `green+no-progress` / `red` / `blocked` / `interrupted`.

## Convergence & termination

- A target that is clean for 2 consecutive rounds leaves the pool for 10 rounds.
- 3 consecutive all-clean pool rounds with an empty backlog → terminate early and report "project converged". "Clean" must be backed by data — 0 findings and 0 regressions in those rounds — not by impression.
- Every round is an independent commit; stop anytime; a resuming run continues from the log header pointer.
- New user instructions take priority; finish them, then return to the loop.

## Retrospective round (mandatory, final round of every run)

After N rounds, the last round **must** be the retrospective. Run the **replay audit** first (Anti-gaming rules #5) — strike any `gamed` rounds from the metrics — then produce four things:

1. **New lessons** → append to `docs/lessons.md` under the right category, template: `| id | lesson | how to apply | source | verified |`. Each retrospective also re-checks existing entries: a lesson this run confirmed in action gets `verified +1`; one that proved wrong or stale gets rewritten or deleted on the spot — the library must not rot.
2. **Process improvements** → if this run hit a pit already covered by the lesson library, revise the corresponding step in this SKILL.md (source repo: github.com/tangjianfang/evolve — commit the revision there).
3. **Crystallization** → when ≥ 3 lessons share a theme and carry ≥ 5 total verifications, promote them into structure: a named mechanism inside SKILL.md or a standalone small skill. Mark the source entries `crystallized → <where>` so the library records what grew into what.
4. **Summary report** → big runs (≥ 20 rounds) update/create `docs/evolve-report.md` (template ships with the skill) including the metrics trend (findings / fixes / regressions over time); small runs append a summary block to evolve-log (outcome numbers, fix list, lesson index).

The retrospective itself counts as a round with its own commit — experience capture is not a bonus, it is part of the iteration.

## Red lines (self-check every round)

- Respect the product boundaries and "don't do" lists declared in the project's CLAUDE.md/AGENTS.md (if absent, confirm boundaries with the user first).
- No auto-push; no touching vendored dependency directories; no new third-party dependencies.
- Tests must be all green before commit (baseline count only grows).
- Keep each round's diff within ~300 lines (or the cap declared in project lessons) — every round stays revertible.
- Fixing an issue entry must update the corresponding doc in the same commit.
- Never delete or modify user data; destructive commands always require confirmation.
- Anti-gaming rules apply every round: progress only via the whitelist; never pad metrics, never repeat a prior round's work, never loosen the verify command. In autonomous mode destructive operations are forbidden outright.
