# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-09-05

First self-hosted run: the evolve protocol iterating the evolve repo itself (5 rounds, per-round commits `evolve #1..#5`).

### Added

- `scripts/verify.py` — 32-check structural verification suite (plugin/marketplace JSON, SKILL.md frontmatter, bilingual trigger words, version consistency, link resolution, template/CI presence).
- CI workflow (`.github/workflows/verify.yml`) running the suite on push/PR.
- `docs/templates/` — starter templates for `evolve-log` / `lessons` / `evolve-report`, wired into the profiling and retrospective steps.
- README name-collision note (`everything-claude-code:evolve` wins the bare name) and structured-record example line, both bilingual.
- `docs/lessons.md` seeded with 4 lessons (E1–E4); E3/E4 amended back into SKILL.md (autonomous-run verification, counter-sum discipline).

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
