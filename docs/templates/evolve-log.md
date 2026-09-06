# evolve log — <project name>

- verify: <verification command(s), from profiling step 1>
<!-- optional — declare only to authorize auto-push in autonomous runs:
- push: auto-authorized
-->
<!-- optional — declare when the user names a visual-review model (default haiku):
- visual-model: <model name>
-->
<!-- optional — present from the first epic proposal on, kept current every round:
- epics pending: <EP-ids or none>
-->
- pointer: #1 (next round)
- rounds done: 0
- status: initialized
- metrics: findings 0 | fixes 0 | regressions 0

## Target pool

- Tier 1 (known defects): <entries from KNOWN_ISSUES / issues / TODO docs, each grep-verified against the code>
- Tier 2 (coverage gaps): <modules/paths with no or thin tests>
- Tier 3 (module rotation): <module list from the src/ directory structure>
- Tier 4 (backlog): <small extensions that fit in one round; big items go spec→plan instead>

## Rounds

<!-- one line per round (result vocabulary per the anti-gaming rules):
#<n> | <target> | findings(<n>) | actions(<n>) | result(green+progress|green+no-progress|red|blocked|interrupted, <test count>) | diff(<lines>) | <notes>
-->
