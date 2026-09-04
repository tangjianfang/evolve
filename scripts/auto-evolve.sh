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
# - Stops early on: 3 consecutive no-progress rounds (circuit breaker) or
#   `status: converged` in the log header.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <project-path> <rounds> [--danger]" >&2
  exit 1
fi

PROJECT=$(realpath "$1")
N=${2:-5}
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

for ((i = 1; i <= N; i++)); do
  echo "=== auto-evolve round $i/$N ==="
  (cd "$PROJECT" && claude -p "${PERMS[@]}" \
    "Run exactly ONE round of the evolve protocol in autonomous mode. First read the protocol itself: skills/evolve/SKILL.md inside this project if it exists, otherwise ~/.claude/skills/evolve/skills/evolve/SKILL.md (do not invoke a skill named 'evolve' — a different plugin may own that name; read the file directly). Step 0 first: read docs/evolve-log.md and follow its header pointer. Anti-gaming rules and the progress whitelist apply. End by appending the round's structured log line with result one of: green+progress / green+no-progress / red / blocked. Then stop — do not start another round.")

  # Circuit breaker: 3 consecutive no-progress ROUNDS. Round lines look like
  # '#N | target | ... | result(green+no-progress, ...) | ...' — the log's
  # file tail can be a run-summary block, so select the round lines, take the
  # last 3, and stop only when all 3 are no-progress (T1e). Reading the log
  # (not a counter) also survives driver restarts mid-run.
  recent=$(grep -E '^#[0-9]+ \|' "$LOG" | tail -n 3 || true)
  if [ -n "$recent" ] \
    && [ "$(grep -c 'result(green+no-progress' <<<"$recent")" -eq 3 ]; then
    echo "!! circuit breaker: 3 consecutive no-progress rounds — stopping." >&2
    break
  fi
  if grep -q "^- status: converged" "$LOG"; then
    echo "== converged — stopping."
    break
  fi
done

echo "== done. Summary and round log: $LOG"
