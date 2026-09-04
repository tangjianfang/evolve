# evolve log — evolve (self-hosting experiment)

- verify: `python scripts/verify.py` (created round #1; pre-creation baseline = both `.claude-plugin/*.json` parse)
- push: auto-authorized (2026-09-05, for the first autonomous-run experiment)
- pointer: #11 (next run resumes here)
- rounds done: 10
- status: active — Tier 1 drained except T1c (manual clean-env install test, not autonomous); next: T3d rotation (verify.py counter-sum check landed in #10; remaining: auto-evolve.sh header/docs + templates/lessons)
- metrics: findings 16 | fixes 21 | regressions 0

## Target pool

- Tier 1 (known defects):
  - T1a skill name collision: bare `evolve` resolves to `everything-claude-code:evolve` when that plugin is installed — reproduced live 2026-09-05
  - T1b zero automated verification (JSON / frontmatter / version consistency) — the "no eval" score deduction
  - T1c install path never exercised: `/plugin marketplace add tangjianfang/evolve` untested in a clean environment
  - T1d (refresh #8) SKILL.md retrospective output list has a duplicated item — numbering runs 1,2,3,4,3 with "**Summary report**" twice (lines ~114-115); introduced by #6's crystallization edit. Fix: drop the duplicate; add a verify.py ordered-list-numbering check (write it, watch it FAIL, fix, watch it pass — red-then-green) — closed #9
  - T1e (refresh #8) auto-evolve.sh circuit breaker reads `tail -n 5` of the whole log file, but round lines are not the file tail (the Run-summary block follows the Rounds block in this repo's log), and any single no-progress match inside the window increments the streak — so "3 consecutive no-progress rounds" is not what it measures. Fix: select round lines (`^#[0-9]+ \|`) and require the last 3 to all be no-progress — closed #10
  - T1f (refresh #8) autonomous sessions cannot execute the verify command when the project allow-list uses `Bash(...)` prefixes but the session's shell tool is PowerShell — `.claude/settings.local.json` allows `Bash(python:*)` yet `python` is denied, and spawned subagents have no Bash tool either. Fix: add `PowerShell(...)` rules to the allow-list (needs one manual approval — settings writes are protected) and document the requirement in auto-evolve.sh's header + README autonomous section — closed #9 (rules live in local untracked settings; requirement documented in all three)
- Tier 2 (coverage gaps): zero checks — merged into T1b
- Tier 3 (module rotation):
  - T3a SKILL.md internal consistency after the English rewrite
  - T3b bilingual README ↔ SKILL.md mechanism sync (+ metrics example line)
  - T3c CHANGELOG ↔ actual content alignment
  - T3d (refresh #8) rotation extended to scripts/auto-evolve.sh, scripts/verify.py, docs/lessons.md, docs/templates/* — auto-evolve.sh got its first review in #8 (finding → T1e); verify.py next (candidate: crystallize E4 into a counter-sum check)
- Tier 4 (backlog):
  - T4a docs/templates/ starters (evolve-log / lessons / evolve-report)
  - T4b GitHub Actions CI running the verification suite
  - T4c (merged into T3b)

## Rounds

#1 | T1b zero verification | findings(1) | actions(1) | result(green, 28 checks) | diff(~150) | scripts/verify.py — 28 structural checks (JSON, frontmatter, bilingual trigger, version consistency, links); profiling done in same commit; T1b closed
#2 | T4a no data-file templates | findings(1) | actions(1) | result(green, 31 checks) | diff(~60) | docs/templates/ (evolve-log / lessons / evolve-report) wired into SKILL.md profiling + READMEs; verify baseline 28→31; T4a closed
#3 | T4b no CI | findings(1) | actions(1) | result(green, 32 checks) | diff(~25) | .github/workflows/verify.yml runs the suite on push/PR; scope note: v1.0 spec excluded CI, superseded by the earn-back-10-points directive; baseline 31→32; T4b closed
#4 | T3a/b/c rotation + T1a | findings(4) | actions(2) | result(green, 32 checks) | diff(~20) | findings: README metrics example missing, T1a collision undocumented, CHANGELOG lags rounds 1–3, protocol gap (autonomous profiling) — first two fixed in both READMEs; latter two deferred to #5; T1a mitigated (registry precedence is environmental, documented not closed)
#5 | retrospective + T3c | findings(1) | actions(4) | result(green, 32 checks) | diff(~90) | lessons.md seeded E1–E4; SKILL.md amended (E3 autonomous verify, E4 counter-sum); release v1.2.0 (CHANGELOG + plugin/marketplace bump); summary block below
#6 | T4d ECC-benchmark borrow | findings(1) | actions(2) | result(green, 32 checks) | diff(~80) | comparative eval of everything-claude-code:evolve (different species: crystallizer vs engine); adopted its verified-counters + crystallization into retrospective (now 4 outputs); lessons template + own library gained verified column; E5 added; folded into unreleased 1.2.0
#7 | T4e autonomy + anti-gaming | findings(1) | actions(4) | result(green, 33 checks) | diff(~170) | user directive: full automation, no fake progress — added Autonomous mode (one round per headless session, circuit breaker, conditional auto-push) + Anti-gaming rules (progress whitelist, adversarial inspector, novelty/difficulty guards, verification lock, replay audit) + scripts/auto-evolve.sh driver; release v1.3.0; NOTE: autonomous mode itself not yet validated by a real headless run
#8 | pool-refresh + T3 rotation (SKILL.md, auto-evolve.sh, verify.py) | findings(3) | actions(1) | result(blocked, 33 checks NOT executable — permission denial) | diff(~45) | first real autonomous/headless round (validates #7's mechanism end-to-end incl. resume-from-pointer); pool refresh triggered (full sweep done): T1d SKILL.md retrospective duplicate list item, T1e auto-evolve.sh circuit-breaker tail-window bug, T1f allow-list tool-prefix gap (`Bash(python:*)` ≠ PowerShell session → verify unrunnable); NO code fixes committed — red line "tests green before commit" cannot be satisfied without executing verify, and hand-simulating checks would be narrative progress; all three fixes pre-staged as Tier 1 entries for #9
#9 | T1f gate fix + T1d dedup | findings(1) | actions(2) | result(green+progress, 34 checks) | diff(~40) | T1f: `PowerShell(...)` rules live in settings.local.json (local, untracked) + tool-prefix requirement documented in auto-evolve.sh header + both READMEs; verify denial reproduced RED (twice: #8 and #9-open), then executable GREEN 33/33; #8's log record reconciliation-committed first (67a8eab) once green was provable; T1d: ordered-list-sequentiality check added to verify.py — watched FAIL ("line 115: item 3, expected 5"), SKILL.md duplicate item removed, 34/34; whitelist: red-then-green ×2, baseline 33→34, inspector CONFIRMED both; new finding: chained commands (`a && b`) rejected by static validation even when both halves allow-listed (documented alongside T1f); inspector noted check blind spots (indented sub-lists, renumbered duplicates) — accepted scope, revisit under T3d; verify command itself unchanged (lock respected)
#10 | T1e circuit-breaker window | findings(2) | actions(3) | result(green+progress, 37 checks) | diff(~50) | breaker now selects round lines (`^#[0-9]+ \|`) → last 3 → all `result(green+no-progress` (old code tail -n 5'd the whole file — summary tail, not rounds — and any single match bumped an in-memory streak; log-derived state now also survives driver restarts); verify.py +3 checks, both new breaker checks watched FAIL on old code then 37/37 green, plus round-lines↔rounds-done reconciliation (T3d's E4 counter-sum candidate, landed early); whitelist: red-then-green ×2, baseline 34→37 (k=3), inspector CONFIRMED with mutation probing → finding 1: `tail -n 2` mutation passed both checks (check 2 tightened on the spot: `tail -n 3` asserted); finding 2 (pre-existing, unfixed): `claude -p` non-zero exit kills the driver under set -e before the breaker runs; residual: legacy `result(green, …)` rows never count as no-progress (fail-safe direction); verify command unchanged (lock respected)

## Run summary (2026-09-05, 5 rounds)

- Outcome: baseline 0 → 32 automated checks; CI live; templates shipped; v1.2.0 released; 4 lessons seeded, 2 amended back into SKILL.md
- Closed: T1b, T2, T3b, T3c, T4a, T4b · Clean: T3a · Mitigated: T1a (documented, environmental)
- Open: T1c install path untested in a clean environment (needs a manual `/plugin marketplace add` test) · Backlog: trigger-match eval set, ≥20-round long-run validation of the v1.1/v1.2 mechanisms
- Lesson index: E1 name collision, E2 docs-repo verification, E3 autonomous verify command, E4 counter discipline

