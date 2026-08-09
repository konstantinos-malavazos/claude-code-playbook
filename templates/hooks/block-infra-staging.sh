#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash / PowerShell).
# Sorts AI-infra paths into what may enter a product repo and what may not. Exit 2 = block.
#
# The rule is about PROVENANCE, not location: would a fresh clone on a new laptop need
# this file? Paths were a good proxy until the bootstrap started legitimately producing
# files at those paths. See docs/solo/07-guardrails-when-solo.md.
#
#   never          .claude/ (the generated views, handoffs), .serena, .forgetful, MEMORY.md
#   always fine    .claude/agents/**, .claude/skills/**  — facts about THIS codebase
#   ask the file   CLAUDE.md — allowlisted per repo in ~/.claude/repo-allowlist

set -euo pipefail

block() { echo "BLOCKED by block-infra-staging: $1" >&2; exit 2; }

# python parses the payload and a payload it cannot read is a BLOCK, never a pass.
# Duplicated verbatim from block-dangerous-git.sh, deliberately — the full reasoning for
# both halves (why python and not jq or sed, why 127 is the same class as success, and
# why a permission prompt was rejected) is in the note there.
PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || block "no python3 or python on PATH — this hook cannot read the command it exists to check."

payload="$(cat)"

parse() { # <command|cwd> — prints the field; non-zero if the payload will not parse
    printf '%s' "$payload" | "$PY" -c '
import json, sys
d = json.load(sys.stdin)
if sys.argv[1] == "cwd":
    sys.stdout.write(d.get("cwd") or "")
else:
    ti = d.get("tool_input") or {}
    sys.stdout.write(ti.get("command") or ti.get("script") or "")
' "$1" 2>/dev/null
}

cmd="$(parse command)" || block "the payload did not parse as JSON — refusing to guess what this command stages."

# Newlines become ';' — see block-dangerous-git.sh. A separate line is a separate command,
# and `git add .` on any line but the first would otherwise slip past the pattern below.
norm="$(printf '%s' "$cmd" | tr '\r\n' ';;' | tr -s ' ')"

# --- The allowlist -------------------------------------------------------------
# Duplicated verbatim from block-dangerous-git.sh, deliberately — see the note there.
allowlist_says() { # <push|claude-md> — exit 0 = yes, 1 = no
    local field="$1" file="$HOME/.claude/repo-allowlist" dir remote key push own
    [ -r "$file" ] || return 1
    dir="$(parse cwd)" || block "the payload did not parse as JSON — refusing to guess which repo this is."
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

# Only inspect git add / commit / stage commands.
if printf '%s' "$norm" | grep -Eiq 'git +(add|commit|stage)'; then

    # Never, whatever the allowlist says: your machine, not the project.
    for pat in '\.serena' '\.forgetful' 'MEMORY\.md'; do
        if printf '%s' "$norm" | grep -Eiq -e "$pat"; then
            block "attempt to stage AI-infra path matching /$pat/ — a fresh clone never needs it."
        fi
    done

    # .claude/ is a TWO-WAY sort, not a blanket block. agents/ and skills/ are generated
    # from this repo's CLAUDE.md and a fresh clone needs them; everything else under
    # .claude/ regenerates or belongs to your machine. Check every reference, not the
    # first — one allowed path in the command does not license the others beside it.
    # Backslashes become '/' first, so one pattern covers both path separators.
    paths="$(printf '%s' "$norm" | tr 'A-Z\\' 'a-z/')"
    refs="$(printf '%s' "$paths" | grep -Eo '\.claude(/[a-z0-9_./-]*)?' || true)"
    if [ -n "$refs" ]; then
        while read -r ref; do
            [ -n "$ref" ] || continue
            case "$ref" in
                .claude/agents|.claude/agents/*|.claude/skills|.claude/skills/*) continue ;;
            esac
            block "attempt to stage '$ref' — only .claude/agents/ and .claude/skills/ are product files; the rest regenerates or is yours."
        done <<< "$refs"
    fi

    # CLAUDE.md: the one path the allowlist decides. On a repo you have answered `yes`
    # for, this file IS the product — nothing else will ever commit it, and without it a
    # fresh clone re-derives the stack, the chain and the Serena verdict from nothing.
    if printf '%s' "$norm" | grep -Eiq 'CLAUDE\.md'; then
        if ! allowlist_says claude-md; then
            block "attempt to stage CLAUDE.md — this repo is not in ~/.claude/repo-allowlist with own-claude-md: yes."
        fi
    fi

    # Bare `git add -A`/`.` can sweep infra files in — nudge to explicit paths. The
    # allowlist never unlocks this one; it is the accidental sweep the rule exists for.
    if printf '%s' "$norm" | grep -Eiq 'git +add +(-A\b|--all\b|\. *($|[;&|]))'; then
        block "git add -A / git add . can sweep in .claude/ or a memory file — stage explicit paths."
    fi
fi

exit 0
