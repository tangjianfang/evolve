#!/usr/bin/env bash
# auto-evolve — fully automated evolve runs: one round per headless session.
#
# Usage:
#   scripts/auto-evolve.sh [--dry-run] <project-path> (<rounds> | --until <datetime> | --for <duration>) [--danger]
#
# - Termination: count-based (<rounds>) or time-budgeted — an absolute
#   deadline (--until "2026-09-07 09:00", GNU date required) or a duration
#   (--for 5h / --for 90m). The budget gates round LAUNCHES only (industry
#   consensus: budgets are checked at the top of each iteration, never a
#   mid-session kill — a hard `timeout` wrapper would lose uncommitted round
#   work). While more than the reserve remains (AUTO_EVOLVE_MIN_RESERVE,
#   default 900s), normal rounds launch; then the driver launches ONE final
#   retrospective session itself — the mandatory retrospective must not
#   depend on a session guessing the clock (T1g). AUTO_EVOLVE_MAX_ROUNDS
#   (default 0 = unlimited) caps a long budget from below-cost surprises.
#
# - --dry-run validates the configuration and prints the plan (project,
#   rounds, permissions, log pointer, breaker state, hook) WITHOUT spawning
#   any session — pilot the wiring for free before burning sessions
#   (plan-first, borrowed from Claude Code's plan mode).
#
# - Requires one interactive round first, so docs/evolve-log.md exists with a
#   profiled verify command (the driver never profiles a project itself).
# - Permissions: by default each session runs `claude -p` with
#   --permission-mode acceptEdits. The project's verify commands still need
#   approval — pre-configure an allow-list in the project's
#   .claude/settings.local.json, or pass --danger for
#   --dangerously-skip-permissions (trusted projects only).
# - Allow-list rule prefixes must match the session's shell tool: Bash(...)
#   rules do not cover a PowerShell session (Windows default), so add
#   parallel PowerShell(...) rules for the verify command and git (proved
#   live in round #9). Chained commands (a && b) fail static validation
#   even when both halves are allow-listed — invoke verify as one command.
# - Auto-push happens only if the project's evolve-log header declares
#   `push: auto-authorized`; otherwise rounds commit without pushing.
# - Set AUTO_EVOLVE_ROUND_HOOK='<command>' to run a command after every
#   successful round (notification, deploy, metrics export). A hook failure
#   is reported but never stops the run; failed sessions fire no hook.
# - Stops early on: 3 consecutive no-progress rounds (circuit breaker),
#   3 consecutive failed `claude -p` sessions, `status: converged`, or
#   `status: pending-epics` (every remaining target parked awaiting an
#   epic decision) in the log header.

set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

if [ $# -lt 1 ]; then
  echo "usage: $0 [--dry-run] <project-path> (<rounds> | --until <datetime> | --for <duration>) [--danger]" >&2
  exit 1
fi

PROJECT=$(realpath "$1")
shift

# Termination mode: count (default 5) or time budget (--until / --for).
BUDGET_MODE=""
DEADLINE=0
N=""
case "${1:-}" in
  "")
    N=5
    ;;
  --until)
    [ $# -ge 2 ] || { echo "usage: --until needs a datetime, e.g. \"2026-09-07 09:00\"" >&2; exit 1; }
    DEADLINE=$(date -d "$2" +%s 2>/dev/null) || DEADLINE=""
    if ! [[ "$DEADLINE" =~ ^[0-9]+$ ]] || [ "$DEADLINE" -le "$(date +%s)" ]; then
      echo "!! --until needs GNU date and a FUTURE datetime (got: $2)" >&2
      exit 1
    fi
    BUDGET_MODE=until
    shift 2
    ;;
  --for)
    [ $# -ge 2 ] || { echo "usage: --for needs a duration with unit, e.g. 5h or 90m" >&2; exit 1; }
    # Capture the groups immediately: a second =~ in the same condition
    # clears BASH_REMATCH (caught live — the 2h budget parsed as 0h).
    if [[ "$2" =~ ^([0-9]+h)?([0-9]+m)?$ ]] && [[ "$2" == *[0-9]* ]]; then
      h=${BASH_REMATCH[1]:-0}; h=${h%h}
      m=${BASH_REMATCH[2]:-0}; m=${m%m}
    else
      echo "!! --for needs a duration with unit, e.g. 5h or 90m (got: $2)" >&2
      exit 1
    fi
    DEADLINE=$(( $(date +%s) + h * 3600 + m * 60 ))
    BUDGET_MODE=for
    shift 2
    ;;
  *)
    # `${1}` (not `${1:-5}`): an explicitly empty <rounds> is a caller error,
    # not a request for the default — let the validation below reject it.
    N="$1"
    shift
    ;;
esac
# Validate before use: bash arithmetic evaluates a non-numeric identifier
# like '--danger' to 0, so a swapped argument list would otherwise run the
# loop zero times — silently — with danger mode on.
if [ -z "$BUDGET_MODE" ] && ! [[ "$N" =~ ^[1-9][0-9]*$ ]]; then
  echo "usage: $0 [--dry-run] <project-path> (<rounds: positive integer> | --until <datetime> | --for <duration>) [--danger]" >&2
  exit 1
fi
if [ -n "$BUDGET_MODE" ] && [ -n "${1:-}" ] && [ "${1:-}" != "--danger" ]; then
  echo "!! time budget and a round count are mutually exclusive (stray arg: $1)" >&2
  exit 1
fi
RESERVE=${AUTO_EVOLVE_MIN_RESERVE:-900}
MAXR=${AUTO_EVOLVE_MAX_ROUNDS:-0}

PERMS=(--permission-mode acceptEdits)
if [ "${1:-}" = "--danger" ]; then
  PERMS=(--dangerously-skip-permissions)
fi

LOG="$PROJECT/docs/evolve-log.md"
if [ ! -f "$LOG" ]; then
  echo "!! $LOG not found — run one interactive round first (profiling)." >&2
  exit 1
fi

# Stop rules (no-progress circuit breaker + converged header) live in
# breaker.sh — the single source of truth, shared with verify.py's
# behavioral fixture checks (T4f).
source "$(dirname "$0")/breaker.sh"

if [ "$DRY_RUN" = "1" ]; then
  if should_stop "$LOG"; then
    breaker_state="STOP ($breaker_reason)"
  else
    breaker_state="continue"
  fi
  if [ -n "$BUDGET_MODE" ]; then
    remaining=$(( DEADLINE - $(date +%s) ))
    echo "dry-run: time-budget mode=$BUDGET_MODE deadline=$(date -d "@$DEADLINE" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$DEADLINE") (~$((remaining / 60)) min remain)"
    echo "dry-run: budget gates round launches only; reserve=${RESERVE}s, max-rounds=${MAXR} (0 = unlimited); one final retrospective session launches when the reserve is reached"
  else
    echo "dry-run: rounds=$N"
  fi
  echo "dry-run: project=$PROJECT"
  echo "dry-run: perms=${PERMS[*]}"
  echo "dry-run: pointer=$(sed -n 's/^- pointer: //p' "$LOG" | head -n 1)"
  echo "dry-run: breaker would $breaker_state"
  echo "dry-run: hook=${AUTO_EVOLVE_ROUND_HOOK:-<none>}"
  echo "dry-run: no sessions spawned — pass no --dry-run to run for real."
  exit 0
fi

consecutive_failures=0
launched=0
while :; do
  if [ -n "$BUDGET_MODE" ]; then
    remaining=$(( DEADLINE - $(date +%s) ))
    if [ "$remaining" -le "$RESERVE" ]; then
      echo "=== time budget: ~$((remaining / 60)) min left, within reserve ${RESERVE}s — no more normal rounds ==="
      break
    fi
    if [ "$MAXR" -gt 0 ] && [ "$launched" -ge "$MAXR" ]; then
      echo "!! AUTO_EVOLVE_MAX_ROUNDS=$MAXR reached — stopping." >&2
      break
    fi
    launched=$((launched + 1))
    echo "=== auto-evolve round $launched (time-budgeted) ==="
    POSITION="This is driver round $launched of a TIME-BUDGETED run (deadline $(date -d "@$DEADLINE" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$DEADLINE"), ~$((remaining / 60)) minutes remain; the round count is not fixed — do not infer a final round from the count)."
  else
    launched=$((launched + 1))
    if [ "$launched" -gt "$N" ]; then
      break
    fi
    echo "=== auto-evolve round $launched/$N ==="
    # T1g: sessions cannot know their run position from the log alone — the
    # driver must say it, or the mandatory final-round retrospective silently
    # never happens (proved live: run #8–#12 closed on T4f, not a retrospective).
    POSITION="This is driver round $launched of $N."
    if [ "$launched" -eq "$N" ]; then
      POSITION="This is the FINAL round ($launched of $N) of this run. Do NOT start a normal round: run the RETROSPECTIVE exactly as the protocol defines it (replay audit first, then its outputs), record it as a round with its own commit, and set the log status accordingly."
    fi
  fi
  # Guarded, not bare: under `set -e` a non-zero claude exit (rate limit,
  # crashed session) would kill the driver before the breakers below ever
  # run. Instead report it, still let the breakers read the log (the round
  # may have appended its line before dying), and abort only on 3
  # consecutive failed sessions — mirroring the no-progress breaker.
  if (cd "$PROJECT" && claude -p "${PERMS[@]}" \
    "Run exactly ONE round of the evolve protocol in autonomous mode. First read the protocol itself: skills/evolve/SKILL.md inside this project if it exists, otherwise ~/.claude/skills/evolve/skills/evolve/SKILL.md (do not invoke a skill named 'evolve' — a different plugin may own that name; read the file directly). $POSITION Step 0 first: read docs/evolve-log.md and follow its header pointer. Anti-gaming rules and the progress whitelist apply. End by appending the round's structured log line with result one of: green+progress / green+no-progress / red / blocked / interrupted. Then stop — do not start another round."); then
    consecutive_failures=0
    # Round-complete hook (borrowed from Claude Code's lifecycle hooks): a
    # deterministic user command after every successful round. Advisory
    # only: a hook failure is reported and never stops the run, and failed
    # sessions fire no hook (E11: stateless — nothing to own or reset).
    if [ -n "${AUTO_EVOLVE_ROUND_HOOK:-}" ]; then
      echo "--- round hook: $AUTO_EVOLVE_ROUND_HOOK"
      sh -c "$AUTO_EVOLVE_ROUND_HOOK" || echo "!! round hook failed (non-fatal)" >&2
    fi
  else
    rc=$?
    consecutive_failures=$((consecutive_failures + 1))
    echo "!! round $launched session exited $rc ($consecutive_failures/3 consecutive failures)" >&2
    if [ "$consecutive_failures" -ge 3 ]; then
      echo "!! 3 consecutive failed sessions — stopping." >&2
      break
    fi
  fi

  if should_stop "$LOG"; then
    echo "!! stopping: $breaker_reason (see breaker.sh for the rules)." >&2
    break
  fi
done

# Time-budgeted runs: the driver itself launches the ONE mandatory final
# retrospective session (T1g — sessions cannot infer the end of a run whose
# length was never a count). Guarded like a round; a failure is reported and
# leaves the log header untouched for the operator to see.
if [ -n "$BUDGET_MODE" ]; then
  echo "=== launching the FINAL retrospective session (time budget reached) ==="
  if (cd "$PROJECT" && claude -p "${PERMS[@]}" \
    "This is the FINAL session of a TIME-BUDGETED autonomous run — the deadline has been reached, so do NOT start a normal round. Run the RETROSPECTIVE exactly as the protocol defines it (replay audit first, then its outputs), record it as a round with its own commit, and set the log status accordingly. First read the protocol itself: skills/evolve/SKILL.md inside this project if it exists, otherwise ~/.claude/skills/evolve/skills/evolve/SKILL.md (do not invoke a skill named 'evolve' — read the file directly)."); then
    :
  else
    echo "!! final retrospective session exited $?" >&2
  fi
fi

echo "== done. Summary and round log: $LOG"
