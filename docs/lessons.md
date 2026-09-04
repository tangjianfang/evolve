# Lessons — evolve

Entry template: `| id | one-sentence lesson | how to apply (an executable action, not a slogan) | source |`

Update an existing entry on the same topic instead of adding a duplicate.

## distribution

| id | lesson | how to apply | source |
|---|---|---|---|
| E1 | A skill name colliding with a big plugin collection breaks bare `/name` invocation, and you won't see it until you install side by side | Before publishing, grep popular plugin marketplaces for the chosen name; ship a README disambiguation note; steer users to natural-language triggers that description-match correctly | live repro 2026-09-05 (`everything-claude-code:evolve` won the bare name) |

## verification

| id | lesson | how to apply | source |
|---|---|---|---|
| E2 | A repo with no build system still needs a verification command — define one in round 1, don't hand-wave | On profiling a docs/prompt repo, create a structural check suite (JSON parse, frontmatter fields, version consistency, link resolution), wire it into CI, and use the check count as the baseline | evolve #1 |

## protocol

| id | lesson | how to apply | source |
|---|---|---|---|
| E3 | Asking the user for verification commands is ceremony when the whole run was delegated | When the run is autonomous, define the verify command yourself, record it as self-defined in the evolve-log header, and flag it for user review in the retrospective | evolve #0 (amended into SKILL.md in #5) |

## recording

| id | lesson | how to apply | source |
|---|---|---|---|
| E4 | Round counters drift when findings are counted casually mid-round | Count findings/actions from the round's review notes before writing the log line; header counters must always equal the sum of round lines (amended into SKILL.md step 7) | evolve #4 counter fix |
