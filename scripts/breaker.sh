#!/usr/bin/env bash
# breaker — the auto-evolve driver's stop rules, extracted from
# auto-evolve.sh so scripts/verify.py can exercise them against fixture
# logs behaviorally instead of probing the driver's source text (T4f).
#
# Sourced by auto-evolve.sh; also runnable standalone as a probe:
#   scripts/breaker.sh <evolve-log.md>
#     exit 0, reason ("no-progress" / "converged") on stdout → stop the run
#     exit 1 (silent)                                 → continue the run

breaker_reason=""

should_stop() {
  local log="$1"
  breaker_reason=""

  # Circuit breaker: 3 consecutive no-progress ROUNDS. Round lines look like
  # '#N | target | ... | result(green+no-progress, ...) | ...' — the log's
  # file tail can be a run-summary block, so select the round lines, take the
  # last 3, and stop only when all 3 are no-progress (T1e). The count reads
  # the FIRST ' | '-delimited field with a full 'result(<vocab>, ' shape,
  # scanning from field 3 — round notes routinely QUOTE the vocabulary
  # (E3/F3, #12), the free-form target may contain ' | ' (G2, #12) or mimic
  # the result syntax to shadow the real column, even deliberately as an
  # anti-gaming evasion (H2/H3, #12); the vocabulary+comma shape plus
  # skipping free-form field 2 closes every shadow vector (fields 3-4 are
  # format-locked counters, and the real result field always follows them).
  # Reading the log (not a counter) also survives driver restarts mid-run.
  local recent count
  recent=$(grep -E '^#[0-9]+ \|' "$log" | tail -n 3 || true)
  count=$(awk -F' [|] ' '
    { for (i = 3; i <= NF; i++)
        if ($i ~ /^result\((green\+progress|green\+no-progress|red|blocked|interrupted), /) {
          if ($i ~ /^result\(green\+no-progress/) n++
          break
        } }
    END { print n + 0 }' <<<"$recent")
  if [ -n "$recent" ] && [ "$count" -eq 3 ]; then
    breaker_reason="no-progress"
    return 0
  fi
  # Status channels read the HEADER region only — lines before the first
  # `## ` heading. A col-0 terminating-status line quoted inside an old
  # run-summary block must not false-stop a resumed run (#21; both channels
  # inherited the whole-file grep from #10's converged channel). A log with
  # no `## ` heading at all — or one whose first line IS a `## ` heading
  # (POSIX 1,/re/ never tests addr2 on addr1's line, so the range never
  # closes) — degenerates to the whole file (fail-safe).
  local header_region
  header_region=$(sed -n '1,/^## /p' "$log" 2>/dev/null || true)
  if grep -q "^- status: converged" <<<"$header_region"; then
    breaker_reason="converged"
    return 0
  fi
  # T1h (#18): the all-parked termination is session-side only unless the
  # breaker can see it — the session sets `- status: pending-epics` when it
  # ends a run because every remaining target is parked awaiting an epic
  # decision; without this channel the driver burns empty sessions up to N.
  if grep -q "^- status: pending-epics" <<<"$header_region"; then
    breaker_reason="pending-epics"
    return 0
  fi
  return 1
}

# Standalone probe mode only when executed directly, not when sourced.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    echo "usage: $0 <evolve-log.md>" >&2
    exit 2
  fi
  if should_stop "$1"; then
    echo "$breaker_reason"
    exit 0
  fi
  exit 1
fi
