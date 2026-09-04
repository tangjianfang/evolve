# evolve log — evolve (self-hosting experiment)

- verify: `python scripts/verify.py` (created round #1; pre-creation baseline = both `.claude-plugin/*.json` parse)
- pointer: #3 (next round)
- rounds done: 2
- status: in progress
- metrics: findings 2 | fixes 2 | regressions 0

## Target pool

- Tier 1 (known defects):
  - T1a skill name collision: bare `evolve` resolves to `everything-claude-code:evolve` when that plugin is installed — reproduced live 2026-09-05
  - T1b zero automated verification (JSON / frontmatter / version consistency) — the "no eval" score deduction
  - T1c install path never exercised: `/plugin marketplace add tangjianfang/evolve` untested in a clean environment
- Tier 2 (coverage gaps): zero checks — merged into T1b
- Tier 3 (module rotation):
  - T3a SKILL.md internal consistency after the English rewrite
  - T3b bilingual README ↔ SKILL.md mechanism sync (+ metrics example line)
  - T3c CHANGELOG ↔ actual content alignment
- Tier 4 (backlog):
  - T4a docs/templates/ starters (evolve-log / lessons / evolve-report)
  - T4b GitHub Actions CI running the verification suite
  - T4c (merged into T3b)

## Rounds

#1 | T1b zero verification | findings(1) | actions(1) | result(green, 28 checks) | diff(~150) | scripts/verify.py — 28 structural checks (JSON, frontmatter, bilingual trigger, version consistency, links); profiling done in same commit; T1b closed
#2 | T4a no data-file templates | findings(1) | actions(1) | result(green, 31 checks) | diff(~60) | docs/templates/ (evolve-log / lessons / evolve-report) wired into SKILL.md profiling + READMEs; verify baseline 28→31; T4a closed
