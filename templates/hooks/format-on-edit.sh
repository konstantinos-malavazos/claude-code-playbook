#!/usr/bin/env bash
# PostToolUse hook (matcher: Write / Edit / NotebookEdit).
# Auto-formats the file that was just edited, per its extension. Non-blocking.

set -euo pipefail

# python parses the payload, not jq — see block-dangerous-git.sh for why.
#
# THIS HOOK CANNOT FAIL CLOSED, and is not made to try. The six blocking hooks exit 2
# when they cannot read their payload, because a guard that cannot see the command must
# stop it. This one is PostToolUse: it runs AFTER the edit it would be objecting to, so
# there is nothing left to stop and exit 2 would only report a failure on work already
# done. No library, no parser, or a payload that will not parse, means it formats nothing
# and says so. The asymmetry with the blocking hooks is the harness's, not an oversight here.

_lib="${BASH_SOURCE[0]//\\//}"
case "$_lib" in */*) _lib="${_lib%/*}/_lib/common.sh" ;; *) _lib="_lib/common.sh" ;; esac
HOOK_LIB_LOADED=
# shellcheck source-path=SCRIPTDIR source=_lib/common.sh
if ! . "$_lib" 2>/dev/null || [ "$HOOK_LIB_LOADED" != 1 ]; then
    echo "format-on-edit: the shared hook library is missing or broken at $_lib — skipping the format. Re-run the installer." >&2
    exit 0
fi

if [ "${#PY_LIST[@]}" -eq 0 ]; then
    echo "format-on-edit: no python3 or python on PATH — skipping the format." >&2
    exit 0
fi

hook_read_payload
file="$(py_run "$HOOK_PAYLOAD" '
import json, sys
# Read and write both use the buffer: bytes read with a text-mode write
# fails on any character the machine code page lacks.
ti = json.loads(sys.stdin.buffer.read()).get("tool_input") or {}
sys.stdout.buffer.write((ti.get("file_path") or "").encode("utf-8"))
')" || { echo "format-on-edit: the payload did not parse as JSON — skipping the format. $(py_tried)" >&2; exit 0; }
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

# Map extensions to your formatters. Fail-soft: never block an edit on a format error.
case "$file" in
    *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md)  npx --no-install prettier --write "$file" 2>/dev/null || true ;;
    *.py)                                     black "$file" 2>/dev/null || true ;;
    *.go)                                     gofmt -w "$file" 2>/dev/null || true ;;
    *.rs)                                     rustfmt "$file" 2>/dev/null || true ;;
    *.cs)                                     dotnet format --include "$file" 2>/dev/null || true ;;
    *) : ;;
esac

exit 0
