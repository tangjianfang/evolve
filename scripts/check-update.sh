#!/usr/bin/env bash
# check-update.sh — protocol-drift notice for the evolve skill.
#
# Borrowed mechanism (E5): silent plugin updates strand long-lived sessions on
# a stale protocol (live case 2026-09-05: the marketplace moved 1.3.1 -> 1.4.0
# mid-day with no notice; prior art: gstack-upgrade self-updater, Claude Code
# lifecycle hooks). evolve's version stays a NOTICE, never a self-update —
# upgrading the plugin is the user's action through their plugin manager.
#
# Usage:
#   check-update.sh              compare installed vs latest release; print
#                                one line ONLY when a newer release exists
#   check-update.sh --compare A B
#                                print newer|equal|older for B vs A (offline)
#
# Safety: 5s timeout, silent on any failure (offline = no output, exit 0).
# Override the remote URL for tests via EVOLVE_VERSION_URL.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/../.claude-plugin/plugin.json"
REMOTE_URL="${EVOLVE_VERSION_URL:-https://raw.githubusercontent.com/tangjianfang/evolve/main/.claude-plugin/plugin.json}"

version_of() {
    # first "version": "X.Y.Z" occurrence of a manifest-shaped text
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' "$1" 2>/dev/null | head -n 1
}

compare() {
    # newer|equal|older for $2 vs $1; exit 2 on malformed input
    case "$1$2" in
        *[!0-9.]*|"") return 2 ;;
    esac
    newer=$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)
    if [ "$newer" = "$2" ] && [ "$2" != "$1" ]; then
        echo "newer"
    elif [ "$2" = "$1" ]; then
        echo "equal"
    else
        echo "older"
    fi
}

case "${1-}" in
    --compare)
        [ $# -eq 3 ] || exit 2
        compare "$2" "$3"
        ;;
    "")
        # remote first: a manifest we cannot read must not silence a drift notice
        remote_manifest=$(curl -fsS -m 5 "$REMOTE_URL" 2>/dev/null) || remote_manifest=""
        remote_version=$(printf '%s' "$remote_manifest" | version_of /dev/stdin) || remote_version=""
        [ -n "$remote_version" ] || exit 0
        [ -f "$MANIFEST" ] || exit 0
        local_version=$(version_of "$MANIFEST")
        [ -n "$local_version" ] || exit 0
        verdict=$(compare "$local_version" "$remote_version") || exit 0
        if [ "$verdict" = "newer" ]; then
            echo "evolve $local_version installed, $remote_version available — update via your plugin manager (the skill never self-updates)"
        fi
        ;;
    *)
        exit 2
        ;;
esac
