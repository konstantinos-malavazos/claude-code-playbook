#!/usr/bin/env bash
# PreToolUse hook (matcher: your tracker + git-host MCP tool namespaces).
# Read-only veto at the MCP layer: default-DENY, allow only read-shaped tool names.
# Better than a shell guard because it sees the MCP call itself. Exit 2 = block.

set -euo pipefail

block() { echo "BLOCKED by block-mcp-writes: $1" >&2; exit 2; }

# python parses the payload and a payload it cannot read is a BLOCK, never a pass.
# Duplicated from block-dangerous-git.sh, deliberately — the reasoning is in the note
# there.
PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || block "no python3 or python on PATH — this hook cannot read the tool name it exists to check."

payload="$(cat)"
tool="$(printf '%s' "$payload" | "$PY" -c '
import json, sys
sys.stdout.write(json.load(sys.stdin).get("tool_name") or "")
' 2>/dev/null)" || block "the payload did not parse as JSON — refusing to guess which tool this is."

# An EMPTY tool name is the second way this hook used to fail open: a parse that
# succeeded and returned nothing fell through the `case` below to `exit 0`, so the call
# was allowed on the strength of a name nobody had read. Same rule as an unreadable
# payload — if the name is not there, the call does not go.
[ -n "$tool" ] || block "the payload carried no tool_name — a call with no name is not a call this hook can clear."

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

block "'$tool' is a write-class MCP call. The tracker/git-host are read-only by policy — do writes manually with explicit approval."
