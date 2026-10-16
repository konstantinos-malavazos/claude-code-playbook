#!/usr/bin/env bash
# PreToolUse hook (matcher: Write / Edit). Agent-scoped: wired in agent frontmatter only, never in settings.
# Lets the agent that carries it Write/Edit handoff files and chart review files, and
# nothing else. Exit 2 = block.
#
# It closes the Write/Edit route only. The same agent keeps Bash for tests and git, and
# Bash can still write a file.

set -euo pipefail

block() { echo "Blocked: $1" >&2; exit 2; }

_lib="${BASH_SOURCE[0]//\\//}"
case "$_lib" in */*) _lib="${_lib%/*}/_lib/common.sh" ;; *) _lib="_lib/common.sh" ;; esac
HOOK_LIB_LOADED=
# shellcheck source-path=SCRIPTDIR source=_lib/common.sh
if ! . "$_lib" 2>/dev/null || [ "$HOOK_LIB_LOADED" != 1 ]; then
    block "the shared hook library is missing or broken at $_lib — re-run the installer."
fi

[ "${#PY_LIST[@]}" -gt 0 ] || block "no python3 or python on PATH — this hook cannot read which file is being written."

hook_read_payload
fields="$(py_run "$HOOK_PAYLOAD" '
import json, sys
d = json.loads(sys.stdin.buffer.read())
if not isinstance(d, dict):
    sys.exit(3)
ti = d.get("tool_input")
ti = ti if isinstance(ti, dict) else {}
tool, path = d.get("tool_name"), ti.get("file_path")
tool = tool if isinstance(tool, str) else ""
path = path if isinstance(path, str) else ""
sys.stdout.buffer.write((tool + "\x1e" + path).encode("utf-8"))
')" || block "the payload did not parse as JSON — refusing to guess which file this writes. $(py_tried)"

tool="${fields%%$'\x1e'*}"
path="${fields#*$'\x1e'}"

[ -n "$tool" ] || block "the payload carried no tool_name — a call with no name is not a call this hook can clear."

case "$tool" in
    Write|Edit) : ;;
    *) exit 0 ;;
esac

refuse() { block "this agent may only write handoff files, not ${path:-(no file_path)}"; }

p="/${path//\\//}"
case "$p/" in */../*) refuse ;; esac

case "$p" in
    */.claude/handoffs/?*) exit 0 ;;
esac

# A chart's reviews/ folder: <anything>/.claude/charts/<KEY>/reviews/<file>.
case "$p" in
    */.claude/charts/*)
        rest="${p#*/.claude/charts/}"
        key="${rest%%/*}"
        case "$rest" in
            "$key"/reviews/?*) if [ -n "$key" ]; then exit 0; fi ;;
        esac
        ;;
esac

refuse
