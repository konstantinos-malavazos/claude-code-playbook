#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash / PowerShell).
# Blocks irreversible or policy-violating git operations. Exit 2 = block.
#
# Wire in ~/.claude/settings.json under hooks.PreToolUse (see settings-hooks.snippet.json).

set -euo pipefail

block() { echo "BLOCKED by block-dangerous-git: $1" >&2; exit 2; }

# --- Reading the payload, and failing CLOSED ------------------------------------
# The harness passes the tool call as JSON on stdin. python parses it, not jq. jq is
# absent from most machines, and hand-rolling the two filters with sed/grep is not the
# cheap option it looks like: a real command arrives with its line breaks encoded as the
# two characters \n, and decoding those by hand re-opens the multi-line flatten bug this
# directory has already shipped once. The dependency is swapped, not removed — python is
# a dependency too, and it wins on being present and on being a real JSON reader.
#
# python3 first, then python. On Windows the Microsoft Store `python` stub resolves but
# is not python: it fails the parse, which blocks — correct on purpose, not by luck.
#
# NO PARSER, OR A PARSE THAT ERRORS, IS A BLOCK. Claude Code treats every exit code
# other than 2 as a non-blocking error and lets the tool call through, so 127 is not a
# near-miss of 2 — it is the same class as success, and a hook that cannot read the
# command would allow it. A prompt was considered and rejected: `permissionDecision:
# "ask"` needs no parser and is the honest verdict, but "yes, and don't ask again" makes
# the approval durable, so one keystroke turns the guard off for good. A prompt is not a
# guardrail; it is trust with an extra keystroke. See README.md.
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

cmd="$(parse command)" || block "the payload did not parse as JSON — refusing to guess what this command does."

# Normalize for matching. Newlines become ';' because a separate LINE is a separate
# command: collapsing it to a space hides `git push` on every line after the first, since
# the patterns below anchor on a start-of-string or a [;&|] separator. \r is mapped too so
# a CRLF payload behaves the same.
norm="$(printf '%s' "$cmd" | tr '\r\n' ';;' | tr -s ' ')"

# --- The allowlist -------------------------------------------------------------
# ~/.claude/repo-allowlist answers two questions per repo, keyed by REMOTE URL, both
# defaulting to no. See repo-allowlist.sample. This lookup is duplicated verbatim in
# block-infra-staging.sh on purpose: a shared file you can forget to copy turns a
# guardrail into one that silently stops guarding, which is the failure this whole
# directory is built to avoid. Duplication is loud; a missing include is not.
allowlist_says() { # <push|claude-md> — exit 0 = yes, 1 = no
    local field="$1" file="$HOME/.claude/repo-allowlist" dir remote key push own
    [ -r "$file" ] || return 1
    # Prefer the payload's cwd if the harness sends one; fall back to ours. A payload
    # that PARSES and simply carries no cwd is the fallback case; a payload that will
    # not parse at all is the fail-closed case, same rule as the command above.
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
