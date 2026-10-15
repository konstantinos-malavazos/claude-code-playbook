#!/usr/bin/env bash
# PreToolUse hook (matcher: mcp__forgetful__execute_forgetful_tool).
# Runs the memory-lint skill's lint.py on every Forgetful create_memory / update_memory
# call and refuses the write when lint reports a FAIL. Every other Forgetful tool passes.
# Exit 2 = block.

set -euo pipefail

block() { echo "BLOCKED by memory-lint: $1" >&2; exit 2; }

_lib="${BASH_SOURCE[0]//\\//}"
case "$_lib" in */*) _hooks="${_lib%/*}" ;; *) _hooks="." ;; esac
_lib="$_hooks/_lib/common.sh"
HOOK_LIB_LOADED=
# shellcheck source-path=SCRIPTDIR source=_lib/common.sh
if ! . "$_lib" 2>/dev/null || [ "$HOOK_LIB_LOADED" != 1 ]; then
    block "the shared hook library is missing or broken at $_lib — re-run the installer."
fi

[ "${#PY_LIST[@]}" -gt 0 ] || block "no python3 or python on PATH — this hook cannot read the memory write it exists to check."

hook_read_payload
fields="$(py_run "$HOOK_PAYLOAD" '
import json, sys
d = json.loads(sys.stdin.buffer.read())
if not isinstance(d, dict) or not isinstance(d.get("tool_input"), dict):
    sys.exit(3)
ti = d["tool_input"]
inner = ti.get("tool_name")
inner = inner if isinstance(inner, str) else ""
sys.stdout.buffer.write((inner + "\x1e" + json.dumps(ti)).encode("utf-8"))
')" || block "the payload did not parse as a Forgetful call — refusing to guess whether it writes memory. $(py_tried)"

inner="${fields%%$'\x1e'*}"
tool_input="${fields#*$'\x1e'}"

[ -n "$inner" ] || block "the call carried no inner tool_name — a call with no name is not a call this hook can clear."

case "$inner" in
    create_memory|update_memory) : ;;
    *) exit 0 ;;
esac

# Relative to this file, so one layout serves both places it runs: ~/.claude/hooks next
# to ~/.claude/skills when installed, templates/hooks next to templates/skills in the repo.
LINT="$_hooks/../skills/memory-lint/lint.py"
[ -f "$LINT" ] || block "lint.py is not installed at $LINT, so this $inner call cannot be checked. Every memory write is refused until it is: re-run the installer with skill:memory-lint selected."

# A /c/... path holding an apostrophe is not translated for a native python.
if command -v cygpath >/dev/null 2>&1; then
    LINT="$(cygpath -m "$LINT")"
fi

# py_run takes a program string, not a file, so lint.py runs through runpy.
rc=0
out="$(py_run "$tool_input" 'import runpy, sys
p = sys.argv[1]
sys.argv = [p]
runpy.run_path(p, run_name="__main__")' "$LINT")" || rc=$?

# Decide on the exit code alone: a passing write may still print WARN lines.
case "$rc" in
    0) exit 0 ;;
    3) block "this $inner call fails the memory lint (the memory-lint skill explains each rule):
$out" ;;
    *) block "lint.py at $LINT did not run (exit $rc), so this $inner call cannot be checked. $(py_tried)" ;;
esac
