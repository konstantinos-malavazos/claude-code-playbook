#!/usr/bin/env bash
# PreToolUse hook (matcher: your tracker + git-host MCP tool namespaces).
# Read-only veto at the MCP layer: default-DENY, allow only read-shaped tool names.
# Better than a shell guard because it sees the MCP call itself. Exit 2 = block.

set -euo pipefail

block() { echo "BLOCKED by block-mcp-writes: $1" >&2; exit 2; }

# python parses the payload and a payload it cannot read is a BLOCK, never a pass.
_lib="${BASH_SOURCE[0]//\\//}"
case "$_lib" in */*) _lib="${_lib%/*}/_lib/common.sh" ;; *) _lib="_lib/common.sh" ;; esac
HOOK_LIB_LOADED=
# shellcheck source-path=SCRIPTDIR source=_lib/common.sh
if ! . "$_lib" 2>/dev/null || [ "$HOOK_LIB_LOADED" != 1 ]; then
    block "the shared hook library is missing or broken at $_lib — re-run the installer."
fi

[ "${#PY_LIST[@]}" -gt 0 ] || block "no python3 or python on PATH — this hook cannot read the tool name it exists to check."

hook_read_payload
tool="$(py_run "$HOOK_PAYLOAD" '
import json, sys
# Read and write both use the buffer: bytes read with a text-mode write
# fails on any character the machine code page lacks.
sys.stdout.buffer.write((json.loads(sys.stdin.buffer.read()).get("tool_name") or "").encode("utf-8"))
')" || block "the payload did not parse as JSON — refusing to guess which tool this is. $(py_tried)"

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

# Classify tool segment: block on write verbs or connectives; allow safe read shapes.
seg="${tool##*__}"

_humps=()
_cur=""
_i=0
while [ "$_i" -lt "${#seg}" ]; do
    _ch="${seg:_i:1}"
    case "$_ch" in
        [A-Z])
            [ -n "$_cur" ] && _humps+=("$_cur")
            _cur="$_ch"
            ;;
        *)
            _cur="${_cur}${_ch}"
            ;;
    esac
    _i=$((_i + 1))
done
[ -n "$_cur" ] && _humps+=("$_cur")

_raw_segments=()
for _h in "${_humps[@]}"; do
    while [ -n "$_h" ]; do
        _s="${_h%%_*}"
        [ -n "$_s" ] && _raw_segments+=("$_s")
        if [ "$_s" = "$_h" ]; then
            break
        fi
        _h="${_h#*_}"
    done
done

segments=()
for _s in "${_raw_segments[@]}"; do
    segments+=("${_s,,}")
done

for _seg in "${segments[@]}"; do
    case "$_seg" in
        create|update|delete|add|remove|set|edit|write|post|put|patch|upload|push|merge|close|reopen|assign|unassign|transition|move|rename|archive|restore|link|unlink)
            block "'$tool' is a write-class MCP call. The tracker/git-host are read-only by policy — do writes manually with explicit approval."
            ;;
        # Connective check backstops words the write-verb list cannot fully enumerate.
        or|and|then|plus|also)
            block "'$tool' mixes words with and/or/then, so the name alone cannot say whether it writes. Blocked. If it is read-only, run it yourself outside the agent, or get the tool renamed."
            ;;
    esac
done

if [ "${#segments[@]}" -gt 0 ]; then
    case "${segments[0]}" in
        get|list|search|read|download|whoami|health|validate)
            exit 0
            ;;
    esac
    case "${segments[-1]}" in
        lint)
            exit 0
            ;;
    esac
fi

block "'$tool' was not recognised as a safe read shape. The tracker/git-host are read-only by policy — only names starting with a read verb or ending in '_lint' are allowed."
