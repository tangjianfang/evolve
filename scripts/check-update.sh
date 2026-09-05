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
#   check-update.sh --version-of <file>
#                                extract the version string of a manifest file
#                                (test seam: proves the parser is inert to
#                                hostile content — only [0-9.] can survive,
#                                so fetched text can never reach a shell)
#
# Safety: 5s timeout, silent on any failure (offline = no output, exit 0).
# Override the remote URL for tests via EVOLVE_VERSION_URL.
#
# Fetch cap: a successful fetch seeds a 24h cache (path overridable via
# EVOLVE_CACHE_FILE for tests); while the cache is fresh the script serves
# it without touching the network — a 50-round driver run must not pay 50
# fetches. The cache is private state of this script alone: nothing else
# reads it, staleness fails silent (E11-clean).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/../.claude-plugin/plugin.json"
REMOTE_URL="${EVOLVE_VERSION_URL:-https://raw.githubusercontent.com/tangjianfang/evolve/main/.claude-plugin/plugin.json}"
CACHE_FILE="${EVOLVE_CACHE_FILE:-${TMPDIR:-/tmp}/evolve-check-update.cache}"
CACHE_TTL_MIN=1440

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
    --version-of)
        [ $# -eq 2 ] && [ -f "$2" ] || exit 2
        version_of "$2"
        ;;
    "")
        [ -f "$MANIFEST" ] || exit 0
        local_version=$(version_of "$MANIFEST")
        [ -n "$local_version" ] || exit 0
        if [ -f "$CACHE_FILE" ] && [ -n "$(find "$CACHE_FILE" -mmin -"$CACHE_TTL_MIN" 2>/dev/null)" ]; then
            remote_version=$(head -c 64 "$CACHE_FILE" 2>/dev/null)
        else
            # remote first: a manifest we cannot read must not silence a drift notice
            remote_manifest=$(curl -fsS -m 5 "$REMOTE_URL" 2>/dev/null) || remote_manifest=""
            remote_version=$(printf '%s' "$remote_manifest" | version_of /dev/stdin) || remote_version=""
            if [ -n "$remote_version" ]; then
                printf '%s' "$remote_version" > "$CACHE_FILE" 2>/dev/null || true
            fi
        fi
        [ -n "$remote_version" ] || exit 0
        verdict=$(compare "$local_version" "$remote_version") || exit 0
        if [ "$verdict" = "newer" ]; then
            echo "evolve $local_version installed, $remote_version available — update via your plugin manager (the skill never self-updates)"
        fi
        ;;
    *)
        exit 2
        ;;
esac
