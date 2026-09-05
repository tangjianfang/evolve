#!/usr/bin/env bash
# auto-evolve — fully automated evolve runs: one round per headless session.
#
# Usage:
#   scripts/auto-evolve.sh <project-path> <rounds> [--danger]
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
# - Stops early on: 3 consecutive no-progress rounds (circuit breaker),
#   3 consecutive failed `claude -p` sessions, or `status: converged` in
#   the log header.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <project-path> <rounds> [--danger]" >&2
  exit 1
fi

PROJECT=$(realpath "$1")
# `${2-5}` (not `${2:-5}`): an explicitly empty <rounds> is a caller error,
# not a request for the default — let the validation below reject it.
N=${2-5}
# Validate before use: bash arithmetic evaluates a non-numeric identifier
# like '--danger' to 0, so a swapped argument list would otherwise run the
# loop zero times — silently — with danger mode on.
if ! [[ "$N" =~ ^[1-9][0-9]*$ ]]; then
  echo "usage: $0 <project-path> <rounds: positive integer> [--danger]" >&2
  exit 1
fi
shift 2 || true

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

consecutive_failures=0
for ((i = 1; i <= N; i++)); do
  echo "=== auto-evolve round $i/$N ==="
  # T1g: sessions cannot know their run position from the log alone — the
  # driver must say it, or the mandatory final-round retrospective silently
  # never happens (proved live: run #8–#12 closed on T4f, not a retrospective).
  POSITION="This is driver round $i of $N."
  if [ "$i" -eq "$N" ]; then
    POSITION="This is the FINAL round ($i of $N) of this run. Do NOT start a normal round: run the RETROSPECTIVE exactly as the protocol defines it (replay audit first, then its outputs), record it as a round with its own commit, and set the log status accordingly."
  fi
  # Guarded, not bare: under `set -e` a non-zero claude exit (rate limit,
  # crashed session) would kill the driver before the breakers below ever
  # run. Instead report it, still let the breakers read the log (the round
  # may have appended its line before dying), and abort only on 3
  # consecutive failed sessions — mirroring the no-progress breaker.
  if (cd "$PROJECT" && claude -p "${PERMS[@]}" \
    "Run exactly ONE round of the evolve protocol in autonomous mode. First read the protocol itself: skills/evolve/SKILL.md inside this project if it exists, otherwise ~/.claude/skills/evolve/skills/evolve/SKILL.md (do not invoke a skill named 'evolve' — a different plugin may own that name; read the file directly). $POSITION Step 0 first: read docs/evolve-log.md and follow its header pointer. Anti-gaming rules and the progress whitelist apply. End by appending the round's structured log line with result one of: green+progress / green+no-progress / red / blocked / interrupted. Then stop — do not start another round."); then
    consecutive_failures=0
  else
    rc=$?
    consecutive_failures=$((consecutive_failures + 1))
    echo "!! round $i session exited $rc ($consecutive_failures/3 consecutive failures)" >&2
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

echo "== done. Summary and round log: $LOG"
