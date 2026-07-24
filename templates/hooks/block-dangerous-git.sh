#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash / PowerShell).
# Blocks irreversible or policy-violating git operations. Exit 2 = block.
#
# Wire in ~/.claude/settings.json under hooks.PreToolUse (see settings-hooks.snippet.json).

set -euo pipefail

# The harness passes the tool call as JSON on stdin.
payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // .tool_input.script // ""')"

# Normalize whitespace for matching.
norm="$(printf '%s' "$cmd" | tr '\n' ' ' | tr -s ' ')"

block() { echo "BLOCKED by block-dangerous-git: $1" >&2; exit 2; }

# --- Hard blocks ---------------------------------------------------------------
# git push — the human pushes manually. (Add a narrow exception below if you have one.)
if printf '%s' "$norm" | grep -Eiq '(^|[;&|] *)git +push'; then
    # Example exception: allow pushing to a dedicated staging branch only.
    # if printf '%s' "$norm" | grep -Eiq 'git +push +origin +staging\b'; then :; else
    block "git push is not allowed — push manually."
    # fi
fi

printf '%s' "$norm" | grep -Eiq 'git +reset +--hard'      && block "git reset --hard"
printf '%s' "$norm" | grep -Eiq 'git +clean +-[a-z]*f'    && block "git clean -f"
printf '%s' "$norm" | grep -Eiq 'git +branch +-D'         && block "git branch -D (force delete)"
printf '%s' "$norm" | grep -Eiq 'git +push +.*--force|git +push +.*-f\b' && block "git push --force"
printf '%s' "$norm" | grep -Eiq -- '--no-verify'          && block "--no-verify (bypasses hooks)"
printf '%s' "$norm" | grep -Eiq -- '--no-gpg-sign'        && block "--no-gpg-sign"
printf '%s' "$norm" | grep -Eiq 'git +add +(-A\b|--all\b|\. *($|[;&|]))' && \
    block "git add -A / git add . — stage explicit paths only (avoids committing AI-infra files)."

exit 0
