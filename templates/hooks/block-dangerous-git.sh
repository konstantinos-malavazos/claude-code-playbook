#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash / PowerShell).
# Blocks irreversible or policy-violating git operations. Exit 2 = block.
#
# Wire in ~/.claude/settings.json under hooks.PreToolUse (see settings-hooks.snippet.json).

set -euo pipefail

# The harness passes the tool call as JSON on stdin.
payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // .tool_input.script // ""')"

# Normalize for matching. Newlines become ';' because a separate LINE is a separate
# command: collapsing it to a space hides `git push` on every line after the first, since
# the patterns below anchor on a start-of-string or a [;&|] separator. \r is mapped too so
# a CRLF payload behaves the same.
norm="$(printf '%s' "$cmd" | tr '\r\n' ';;' | tr -s ' ')"

block() { echo "BLOCKED by block-dangerous-git: $1" >&2; exit 2; }

# --- The allowlist -------------------------------------------------------------
# ~/.claude/repo-allowlist answers two questions per repo, keyed by REMOTE URL, both
# defaulting to no. See repo-allowlist.sample. This lookup is duplicated verbatim in
# block-infra-staging.sh on purpose: a shared file you can forget to copy turns a
# guardrail into one that silently stops guarding, which is the failure this whole
# directory is built to avoid. Duplication is loud; a missing include is not.
allowlist_says() { # <push|claude-md> — exit 0 = yes, 1 = no
    local field="$1" file="$HOME/.claude/repo-allowlist" dir remote key push own
    [ -r "$file" ] || return 1
    # Prefer the payload's cwd if the harness sends one; fall back to ours.
    dir="$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null || true)"
    [ -n "$dir" ] && [ -d "$dir" ] || dir="$PWD"
    remote="$(git -C "$dir" config --get remote.origin.url 2>/dev/null || true)"
    [ -n "$remote" ] || return 1
    while read -r key push own; do
        case "$key" in ''|\#*) continue ;; esac
        case "$remote" in *"$key"*) ;; *) continue ;; esac
        case "$field" in
            push)      [ "$push" = "yes" ] && return 0 ;;
            claude-md) [ "$own"  = "yes" ] && return 0 ;;
        esac
    done < "$file"
    return 1
}

# --- Hard blocks ---------------------------------------------------------------
# git push — the human pushes manually, unless this repo is allowlisted for it.
if printf '%s' "$norm" | grep -Eiq '(^|[;&|] *)git +push'; then
    if ! allowlist_says push; then
        block "git push is not allowed here — this repo is not in ~/.claude/repo-allowlist with push: yes. Push manually, or add a line."
    fi
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
