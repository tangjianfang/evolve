# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- verify.py: wiring check pinning the driver's run-position prompt (T1g — the fix shipped in 1.3.1 without a check; the new check was watched failing as the only red check on the pre-fix tree, then green), plus two structural checks on the lessons library (5-column template present, `verified` counters are integers). Suite: 71 → 74 checks.
- verify.py: manual-install completeness check — both READMEs' install instruction line must cover `docs/templates/`, anchored to the exact `**Manual:**`/`**手动安装：**` prefix so a templates mention elsewhere in the README cannot mask an omission, and a future `**Manual …:**` line above it cannot capture the match (inspector mutant, tightened on the spot). Suite: 74 → 77 checks (the two extra are link-resolution checks on the new README links).
- Lessons E8 (execute behavior against fixtures — substring probes pass behavior-flipping mutants) and E9 (single writer per tree + the yield procedure on mid-round foreign changes); SKILL.md Autonomous mode amended accordingly (driver states run position; single-writer rule).
- Lesson E10: installation/usage docs rot invisibly until someone follows them verbatim — #15's install-instruction defect had shipped with the templates since they landed in #2, and only a live install exposed it. Audit by executing the README path once in a clean target; guard standing with a line-anchored wiring check.

### Fixed

- READMEs' manual-install instruction copied only `SKILL.md`, omitting the `docs/templates/` starter templates that first-run profiling expects next to it — a verbatim manual install was silently degraded (observed live during a real install). Both install lines now cover the templates (#15).
- evolve-log hygiene: round #13's line relocated into the Rounds block, and its `result` corrected `green+progress` → `green+no-progress` — a docs-only round carries no whitelist credential (the label overstated; the work itself was real, and the missing red-then-green credential for T1g is supplied above).

## [1.3.1] - 2026-09-05

First autonomous run (driver `auto-evolve.sh`, 5 headless sessions on this repo, rounds #8–#12): one honest blocked round + four progressive rounds, verify suite 33 → 71 checks, every fix red-then-green with adversarial-inspector confirmation.

### Added

- **Behavioral verification harness** (T4f): the driver's stop rules were extracted into `scripts/breaker.sh` (single source of truth, sourced by `auto-evolve.sh`), and `scripts/verify.py` now executes them against twenty-four fixture logs — asserting the stop/continue decision itself instead of substring-probing the driver's source (mutation probes had passed the old checks 2/6; five adversarial-inspection rounds drove the harness to kill every known behavior-changing mutant, behaviorally). Both scripts are also parsed with `bash -n`. Suite: 40 → 71 checks.
- Driver tells each session its run position and instructs the final round to run the retrospective (T1g — without it the mandatory retrospective silently never happens; proved live by this run, fixed post-run with lessons E6/E7 recorded).

### Fixed

- Circuit breaker was fragile in three ways the old substring checks could not see: round notes QUOTING the vocabulary false-stopped healthy runs (E3/F3); a free-form TARGET containing `' | '` silently disabled the breaker (G2); a TARGET mimicking the result syntax could shadow the real column — including deliberately, as an anti-gaming evasion (H2/H3). The count now reads the FIRST `' | '`-delimited field with a full `result(<vocabulary>, ` shape, scanning from field 3 — inert to all three (inspector rounds, #12).
- Verify-gate unrunnable in autonomous PowerShell sessions — allow-list tool prefixes documented (T1f, #9).
- SKILL.md retrospective output list carried a duplicated item; ordered-list sequentiality now checked (#9, T1d).
- Circuit breaker read the log's file tail instead of the round lines and counted any single match as a streak (T1e, #10); driver no longer dies under `set -e` on a failed `claude -p` session and validates `<rounds>` as a positive integer (#11).

## [1.3.0] - 2026-09-05

Full autonomy + anti-gaming: N rounds with zero user interaction, where every round must earn its progress by evidence.

### Added

- **Autonomous mode**: `scripts/auto-evolve.sh <project> <N>` drives headless `claude -p` sessions, one round per session (context always fresh, pointer-based resume); circuit breaker stops after 3 consecutive no-progress rounds; auto-push only when the project's log header declares `push: auto-authorized`; destructive operations forbidden outright (no confirmation available).
- **Anti-gaming rules**: progress whitelist (baseline-grew / red-then-green / measured-number / inspector-confirmed), adversarial inspector subagent (refute-the-fix, blind to the fix), novelty guard vs the last 10 rounds, difficulty guard (2 trivial rounds → force Tier 1), verification-command lock, and a retrospective **replay audit** that time-travels via git to strike `gamed` rounds.
- `result` field extended: `green+progress` / `green+no-progress` / `red` / `blocked` / `interrupted`.

## [1.2.0] - 2026-09-05

First self-hosted run: the evolve protocol iterating the evolve repo itself (5 rounds, per-round commits `evolve #1..#5`).

### Added

- `scripts/verify.py` — 32-check structural verification suite (plugin/marketplace JSON, SKILL.md frontmatter, bilingual trigger words, version consistency, link resolution, template/CI presence).
- CI workflow (`.github/workflows/verify.yml`) running the suite on push/PR.
- `docs/templates/` — starter templates for `evolve-log` / `lessons` / `evolve-report`, wired into the profiling and retrospective steps.
- README name-collision note (`everything-claude-code:evolve` wins the bare name) and structured-record example line, both bilingual.
- `docs/lessons.md` seeded with 5 lessons (E1–E5); E3/E4 amended back into SKILL.md (autonomous-run verification, counter-sum discipline).
- **Lesson verified-counters + crystallization** (borrowed from `everything-claude-code:evolve` after comparative evaluation): every retrospective re-verifies lessons (`verified +1` / rewrite / delete), and ≥3 same-theme lessons with ≥5 total verifications promote into a named SKILL.md mechanism or standalone skill.

## [1.1.0] - 2026-09-05

### Added

- **Long-run context management**: structured outcomes only in conversation, checkpoint + fresh-session handoff every 10 rounds, interrupted-round recovery via `result(interrupted)`.

- **Pool refresh** every 10 rounds (or one full pool sweep): re-verify Tier 1 against code, re-list Tier 3 modules — no more iterating against a stale map.
- **Structured per-round record**: `#<round> | target | findings(n) | actions(n) | result(green|red, tests) | diff(lines)` plus running metric counters in the log header; "converged" now requires 0 findings and 0 regressions, not impression.
- **Cost-guarded code review scope**: small modules (≤ ~2000 lines) read in full; large modules expand outward from target files only as findings demand.
- **Broader verification detection**: pytest / cargo test / go test / maven / gradle in addition to CMake, sln, and package.json.
- SKILL.md body rewritten in English (canonical) with a bilingual description so both "iterate N times" and "迭代 N 次" trigger it.

## [1.0.0] - 2026-09-04

### Added

- Generic self-iteration protocol skill (`evolve`), generalized from a 181-round real-world iteration run on the GumuHub portal project.
- Per-round loop: target selection from a 4-tier priority pool → visual review (haiku subagent, UI targets only) → code review → fix / optimize / extend → project-defined verification → commit → record.
- First-run project profiling: auto-detect build/test commands and build the target pool from known issues, test gaps, module rotation, and backlog.
- Convergence rules (retire clean targets, early termination), mandatory retrospective round, and per-round red lines (no auto-push, no new deps, tests must stay green, ~300-line diff cap).
- Claude Code plugin packaging (`.claude-plugin/`) with self-referencing marketplace, bilingual README (English / 简体中文), MIT license.
