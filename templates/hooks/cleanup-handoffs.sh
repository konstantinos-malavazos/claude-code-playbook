#!/usr/bin/env bash
# SessionEnd hook. Deletes ephemeral pipeline handoff dirs so in-flight state never
# lingers or leaks into memory. Skips when the session ended for a resume.

set -euo pipefail

# python parses the payload, not jq — see block-dangerous-git.sh for why.
#
# THIS HOOK CANNOT FAIL CLOSED, and is not made to try. The four blocking hooks exit 2
# when they cannot read their payload. This one is SessionEnd, where Claude Code ignores
# the exit code entirely — there is no verdict to return, so exit 2 would be a number
# nobody reads. The asymmetry with the blocking hooks is the harness's, not an oversight.
#
# It fails SAFE instead, and in the direction that keeps data: without the reason it
# cannot tell a resume from a real end, and deleting the handoffs the resume flow is
# about to want is the expensive mistake. Leaving them costs a stale directory.
PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then
    echo "cleanup-handoffs: no python3 or python on PATH — leaving the handoffs in place." >&2
    exit 0
fi

payload="$(cat)"
reason="$(printf '%s' "$payload" | "$PY" -c '
import json, sys
sys.stdout.write(json.load(sys.stdin).get("reason") or "")
' 2>/dev/null)" || { echo "cleanup-handoffs: the payload did not parse as JSON — leaving the handoffs in place." >&2; exit 0; }

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
