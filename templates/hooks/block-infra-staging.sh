#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash / PowerShell).
# Blocks staging/committing AI-infra files into a product repo. Exit 2 = block.
# Catches: CLAUDE.md (any depth), .claude/, .serena/, .forgetful/, MEMORY.md, memory dirs.

set -euo pipefail

payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // .tool_input.script // ""')"
norm="$(printf '%s' "$cmd" | tr '\n' ' ' | tr -s ' ')"

block() { echo "BLOCKED by block-infra-staging: $1" >&2; exit 2; }

# Only inspect git add / commit / stage commands.
if printf '%s' "$norm" | grep -Eiq 'git +(add|commit|stage)'; then
    for pat in 'CLAUDE\.md' '\.claude/' '\.claude\\' '\.serena' '\.forgetful' 'MEMORY\.md'; do
        if printf '%s' "$norm" | grep -Eiq "$pat"; then
            block "attempt to stage AI-infra path matching /$pat/ — these must never enter a product repo."
        fi
    done
    # Bare `git add -A`/`.` can sweep infra files in — nudge to explicit paths.
    if printf '%s' "$norm" | grep -Eiq 'git +add +(-A\b|--all\b|\. *($|[;&|]))'; then
        block "git add -A / git add . can sweep in .claude/ or CLAUDE.md — stage explicit paths."
    fi
fi

exit 0
