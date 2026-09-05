# Epics — <project name>

Escalated innovation/refactor proposals. Rounds NEVER execute epics — entries exist so the user can review before anything runs. Retrospectives re-check open entries: stale or contradicted proposals are rewritten or dropped, like lessons.

Entry template (one block per proposal):

```markdown
## EP-<n> | type: refactor|innovate | status: proposed|approved|rejected|done
- trigger: (a)–(f) with evidence (round #s / log lines)
- hypothesis: the structural cause the symptoms suggest
- implementation sketch: scope boundary, impacted modules, verification
  strategy, rollback plan, estimated round count once decomposed
- proposed in round: #<n> · decided: <date, by whom>
```

Rules (mirrors SKILL.md "Epic escalation"):

1. `status` flips `proposed → approved | rejected` only by user review — never by a round.
2. At most one new proposal per round, one open proposal per target.
3. Approved epics run their own spec→plan flow; decomposed, independently-verifiable slices may re-enter the Tier 4 backlog as a coordinated sequence.
