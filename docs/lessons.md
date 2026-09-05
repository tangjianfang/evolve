# Lessons — evolve

Entry template: `| id | one-sentence lesson | how to apply (an executable action, not a slogan) | source | verified |`

- Update an existing entry on the same topic instead of adding a duplicate.
- Every retrospective re-checks entries: confirmed in action → `verified +1`; proved wrong or stale → rewrite or delete on the spot.
- ≥ 3 same-theme lessons with ≥ 5 total verifications → crystallize into a named SKILL.md mechanism or a standalone skill; mark the entries `crystallized → <where>`.

## distribution

| id | lesson | how to apply | source | verified |
|---|---|---|---|---|
| E1 | A skill name colliding with a big plugin collection breaks bare `/name` invocation, and you won't see it until you install side by side | Before publishing, grep popular plugin marketplaces for the chosen name; ship a README disambiguation note; steer users to natural-language triggers that description-match correctly | live repro 2026-09-05 (`everything-claude-code:evolve` won the bare name); driver prompt points at SKILL.md directly — all 5 headless sessions loaded the right protocol | 2 |

## verification

| id | lesson | how to apply | source | verified |
|---|---|---|---|---|
| E2 | A repo with no build system still needs a verification command — define one in round 1, don't hand-wave | On profiling a docs/prompt repo, create a structural check suite (JSON parse, frontmatter fields, version consistency, link resolution), wire it into CI, and use the check count as the baseline | evolve #1; autonomous run #8–#12 leaned on it for every whitelist claim (33 → 71 checks); #15's red-then-green + replay audit leaned on it again | 3 |
| E10 | Installation/usage docs rot invisibly until someone follows them verbatim — this repo's own install instruction had shipped without the templates since #2, and only a live install exposed it | Before a release, execute the README's install/usage instructions once in a clean target and diff the outcome against what the code expects; cheaper standing guard: pin the instruction's key tokens with a line-anchored wiring check, so a mention elsewhere in the doc cannot mask the omission | live install 2026-09-05 (installer had to infer docs/templates/ from SKILL.md because the README omitted it) → found & fixed in #15 | 1 |
| E8 | Substring assertions about a script's source survive behavior-flipping mutations — #11's probes passed 2/6; only executing the behavior catches them | When a check guards a script, run the script against fixture inputs and assert its decision (breaker.sh's 24 fixtures); keep substring checks for wiring that cannot be executed (e.g. a claude prompt string) and mutation-probe both kinds | #11 → #12 (final replay: 15/15 mutants killed, every one behaviorally); #15's first file-wide substring check passed vacuously and had to be line-anchored — the non-executable ceiling held (negation/wrong-destination survive) | 2 |

## protocol

| id | lesson | how to apply | source | verified |
|---|---|---|---|---|
| E3 | Asking the user for verification commands is ceremony when the whole run was delegated | When the run is autonomous, define the verify command yourself, record it as self-defined in the evolve-log header, and flag it for user review in the retrospective | evolve #0 (amended into SKILL.md in #5); every autonomous round #9–#12 ran it without prompting | 2 |

## recording

| id | lesson | how to apply | source | verified |
|---|---|---|---|---|
| E4 | Round counters drift when findings are counted casually mid-round | Count findings/actions from the round's review notes before writing the log line; header counters must always equal the sum of round lines (amended into SKILL.md step 7) | evolve #4 counter fix; #10 landed it as a verify.py reconciliation check, #11/#12 kept Σ=header green every round | 2 |

## benchmarking

| id | lesson | how to apply | source | verified |
|---|---|---|---|---|
| E5 | Steal mechanisms, not architectures: a sibling project's value lies in the gaps it patches, not its taxonomy | When evaluating a comparable tool, list its mechanisms against your own短板 first; adopt only what closes a real gap at low cost, and record where each borrow came from | ECC:evolve comparison 2026-09-05 (adopted: verified counters + crystallization) | 1 |

## autonomy

| id | lesson | how to apply | source | verified |
|---|---|---|---|---|
| E6 | Autonomy blocks in the permission layer, not the protocol layer: allow-list prefixes must match the session's shell tool, and chained commands fail static validation even when both halves are allowed | Before an autonomous run, configure BOTH `Bash(...)` and `PowerShell(...)` rules (or the platform's shell) for verify + git; invoke verify as a single command; document it in the driver header (round #9 did) | autonomous run #8 (blocked) → #9 (unblocked), 2026-09-05 | 1 |
| E7 | A driver must tell each session its run position, or the mandatory final-round retrospective silently never happens | Pass "round i of N" in every session prompt and instruct round N to run the retrospective instead of a normal round (landed as T1g fix, commit c788c52) | autonomous run #8–#12: #12 even flagged "next: retrospective" in the log but no session could act on it | 1 |
| E9 | Two agent sessions in one working tree corrupt each other's rounds silently — mid-round file rewrites, interleaved commits, double round lines | One driver per tree, no parallel manual sessions; a session that sees state change beneath it stops editing, re-reads the log header, and yields (result(blocked), citing the foreign commit) or re-scopes on top — never continues from a stale snapshot. Root cause of the live collision (operator note): never edit a driver script while it runs — bash re-reads scripts incrementally, so an in-place edit shifts offsets, corrupts execution (exit 2 on a phantom EOF), and can re-execute loop bodies, launching extra sessions; deploy driver edits only between runs | live collision 2026-09-05: two concurrent retrospective sessions; one yielded and re-scoped as round #14 | 1 |
