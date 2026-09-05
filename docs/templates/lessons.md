# Lessons — <project name>

Entry template: `| id | one-sentence lesson | how to apply (an executable action, not a slogan) | source | verified |`

- Update an existing entry on the same topic instead of adding a duplicate.
- Every retrospective re-checks entries: confirmed in action → `verified +1`; proved wrong or stale → rewrite or delete on the spot.
- ≥ 3 same-theme lessons with ≥ 5 total verifications → crystallize into a named SKILL.md mechanism or a standalone skill; mark the entries `crystallized → <where>`.

## <category, e.g. build / testing / ui / concurrency>

| id | lesson | how to apply | source | verified |
|---|---|---|---|---|

### Seeds (distilled from the evolve project's own runs)

S-ids deliberately avoid your E-numbering; the project's **first retrospective deletes any row it cannot apply**, exactly like a stale entry — the library must not rot.

| id | lesson | how to apply | source | verified |
|---|---|---|---|---|
| S1 | A repo with no build system still needs a verification command — define one in round 1, don't hand-wave | On profiling a docs/prompt repo, create a structural check suite (JSON parse, frontmatter fields, version consistency, link resolution), wire it into CI, and use the check count as the baseline | evolve E2 | 0 |
| S2 | Steal mechanisms, not architectures: a sibling project's value lies in the gaps it patches, not its taxonomy | When evaluating a comparable tool, list its mechanisms against your own gaps first; adopt only what closes a real gap at low cost, and record where each borrow came from | evolve E5 | 0 |
| S3 | Substring assertions about a script's source survive behavior-flipping mutations — only executing the behavior catches them | When a check guards a script, run it against fixture inputs and assert its decision; keep substring checks for wiring that cannot be executed, and mutation-probe both kinds | evolve E8 | 0 |
| S4 | Installation/usage docs rot invisibly until someone follows them verbatim | Before a release, execute the README's install/usage instructions once in a clean target and diff the outcome against what the code expects; pin the instruction's key tokens with line-anchored wiring checks | evolve E10 | 0 |
| S5 | Every state a mechanism writes needs set/terminate/reset ownership in a named step, or its readers rot silently | When adding a header field, status line, or register that a reader depends on, write the ownership into the step list before landing — who sets it, when it takes its terminating value, who resets it on resume | evolve E11 | 0 |
