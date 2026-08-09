#!/usr/bin/env bash
# PostToolUse hook (matcher: Write / Edit / MultiEdit).
# Auto-formats the file that was just edited, per its extension. Non-blocking.

set -euo pipefail

# python parses the payload, not jq — see block-dangerous-git.sh for why.
#
# THIS HOOK CANNOT FAIL CLOSED, and is not made to try. The four blocking hooks exit 2
# when they cannot read their payload, because a guard that cannot see the command must
# stop it. This one is PostToolUse: it runs AFTER the edit it would be objecting to, so
# there is nothing left to stop and exit 2 would only report a failure on work already
# done. No parser, or a payload that will not parse, means it formats nothing and says
# so. The asymmetry with the blocking hooks is the harness's, not an oversight here.
PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then
    echo "format-on-edit: no python3 or python on PATH — skipping the format." >&2
    exit 0
fi

payload="$(cat)"
file="$(printf '%s' "$payload" | "$PY" -c '
import json, sys
ti = json.load(sys.stdin).get("tool_input") or {}
sys.stdout.write(ti.get("file_path") or "")
' 2>/dev/null)" || { echo "format-on-edit: the payload did not parse as JSON — skipping the format." >&2; exit 0; }
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
