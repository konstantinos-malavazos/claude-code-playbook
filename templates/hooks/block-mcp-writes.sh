#!/usr/bin/env bash
# PreToolUse hook (matcher: your tracker + git-host MCP tool namespaces).
# Read-only veto at the MCP layer: default-DENY, allow only read-shaped tool names.
# Better than a shell guard because it sees the MCP call itself. Exit 2 = block.

set -euo pipefail

block() { echo "BLOCKED by block-mcp-writes: $1" >&2; exit 2; }

# python parses the payload and a payload it cannot read is a BLOCK, never a pass.
# Duplicated from block-dangerous-git.sh, deliberately — the reasoning for all of it (why
# python and not jq or sed, why 127 is the same class as success, why a WindowsApps
# python3 goes to the END of the list and is never dropped, and why nothing is probed
# until we are refusing anyway) is in the notes there. The code below is byte-identical in
# all six hooks and in test-hooks.sh.
PY_LIST=()
PY_LAST=()
# ONE command substitution, not one per candidate. A fork costs ~30ms on Windows and this
# runs on every single hook invocation, so asking twice cost measurably more than the
# whole ordering decision it feeds. The `true` keeps the list non-fatal when neither name
# resolves; the empty-line guard is what a missing candidate looks like here.
while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    case "${_p,,}" in
        */windowsapps/*) PY_LAST+=("$_p") ;;
        *)               PY_LIST+=("$_p") ;;
    esac
done <<< "$(command -v python3 2>/dev/null; command -v python 2>/dev/null; true)"
PY_LIST+=(${PY_LAST[@]+"${PY_LAST[@]}"})

py_tried() { # the refusal's evidence: every candidate by resolved path, with a verdict
    local _c _out=""
    for _c in ${PY_LIST[@]+"${PY_LIST[@]}"}; do
        if "$_c" -c "pass" >/dev/null 2>&1; then
            _out="${_out}${_out:+, }${_c} (is python)"
        else
            _out="${_out}${_out:+, }${_c} (on PATH, but not a working python)"
        fi
    done
    printf 'interpreter tried: %s' "${_out:-none — no python3 or python on PATH}"
}

py_run() { # <stdin> <program> [args…] — first candidate that answers wins
    local _in="$1" _prog="$2" _c _rc=127
    shift 2
    for _c in ${PY_LIST[@]+"${PY_LIST[@]}"}; do
        _rc=0
        printf '%s' "$_in" | "$_c" -c "$_prog" "$@" 2>/dev/null || _rc=$?
        [ "$_rc" -eq 0 ] && return 0
        # 3 is the PROGRAM saying no, not the interpreter failing to be python. Handing
        # the same input to a different interpreter would get the same answer.
        [ "$_rc" -eq 3 ] && return 3
    done
    return "$_rc"
}

[ "${#PY_LIST[@]}" -gt 0 ] || block "no python3 or python on PATH — this hook cannot read the tool name it exists to check."

# `read -d ""` rather than $(cat). A command substitution forks a subshell and then execs
# cat, which measured 37ms on Windows — more than choosing the interpreter above and more
# than the parse itself on an ordinary payload, for reading one string off stdin. `-d ""`
# reads to EOF (a JSON payload carries no NUL), `-r` keeps backslashes literal, `IFS=`
# keeps leading and trailing whitespace, and the non-zero exit at EOF is the expected
# outcome, not a failure. The only difference from $(cat) is that a trailing newline
# survives, and no JSON reader cares. Measured faster at 4KB as well as at 60 bytes.
IFS= read -r -d '' payload || true
tool="$(py_run "$payload" '
import json, sys
sys.stdout.write(json.load(sys.stdin).get("tool_name") or "")
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

# Allow-list: only clearly read-shaped operations pass.
if printf '%s' "$tool" | grep -Eiq '__(get|list|search|read|download|whoami|health|.*_lint|validate)([_A-Za-z0-9]*)$'; then
    exit 0
fi

block "'$tool' is a write-class MCP call. The tracker/git-host are read-only by policy — do writes manually with explicit approval."
