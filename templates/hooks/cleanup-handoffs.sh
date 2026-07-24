#!/usr/bin/env bash
# SessionEnd hook. Deletes ephemeral pipeline handoff dirs so in-flight state never
# lingers or leaks into memory. Skips when the session ended for a resume.

set -euo pipefail

payload="$(cat)"
reason="$(printf '%s' "$payload" | jq -r '.reason // ""')"

# Don't wipe if the session is being resumed — the resume flow needs the handoffs.
if [ "$reason" = "resume" ]; then
    exit 0
fi

# Point this at your workspace's handoffs root.
HANDOFFS_ROOT="${WORKSPACE_HANDOFFS_ROOT:-$PWD/.claude/handoffs}"

if [ -d "$HANDOFFS_ROOT" ]; then
    # Remove per-ticket handoff dirs but keep the root.
    find "$HANDOFFS_ROOT" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
fi

exit 0
