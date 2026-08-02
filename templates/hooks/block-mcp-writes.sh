#!/usr/bin/env bash
# PreToolUse hook (matcher: your tracker + git-host MCP tool namespaces).
# Read-only veto at the MCP layer: default-DENY, allow only read-shaped tool names.
# Better than a shell guard because it sees the MCP call itself. Exit 2 = block.

set -euo pipefail

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"

# Only police the MCP servers that must stay read-only. Adjust the prefixes to yours.
# NEVER add Serena's prefix here: Serena's write tools (replace_symbol_body,
# insert_*_symbol, rename_symbol, safe_delete_symbol, create_text_file) are the MANDATORY
# path for editing code (docs/shared/04-serena.md). Blocking them forces agents back onto
# line-based Edit — exactly the failure mode the rule exists to prevent.
case "$tool" in
    mcp__tracker__*|mcp__gitlab__*|mcp__github__*) : ;;  # policed below
    *) exit 0 ;;                                        # everything else: not our business
esac

# Allow-list: only clearly read-shaped operations pass.
if printf '%s' "$tool" | grep -Eiq '__(get|list|search|read|download|whoami|health|.*_lint|validate)([_A-Za-z0-9]*)$'; then
    exit 0
fi

echo "BLOCKED by block-mcp-writes: '$tool' is a write-class MCP call. The tracker/git-host are read-only by policy — do writes manually with explicit approval." >&2
exit 2
