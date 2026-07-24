#!/usr/bin/env bash
# PostToolUse hook (matcher: Write / Edit / MultiEdit).
# Auto-formats the file that was just edited, per its extension. Non-blocking.

set -euo pipefail

payload="$(cat)"
file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""')"
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
