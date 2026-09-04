# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-04

### Added

- Generic self-iteration protocol skill (`evolve`), generalized from a 181-round real-world iteration run on the GumuHub portal project.
- Per-round loop: target selection from a 4-tier priority pool → visual review (haiku subagent, UI targets only) → code review → fix / optimize / extend → project-defined verification → commit → record.
- First-run project profiling: auto-detect build/test commands and build the target pool from known issues, test gaps, module rotation, and backlog.
- Convergence rules (retire clean targets, early termination), mandatory retrospective round, and per-round red lines (no auto-push, no new deps, tests must stay green, ~300-line diff cap).
- Claude Code plugin packaging (`.claude-plugin/`) with self-referencing marketplace, bilingual README (English / 简体中文), MIT license.
