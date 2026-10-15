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
_lib="${BASH_SOURCE[0]//\\//}"
case "$_lib" in */*) _lib="${_lib%/*}/_lib/common.sh" ;; *) _lib="_lib/common.sh" ;; esac
HOOK_LIB_LOADED=
# shellcheck source=/dev/null
if ! . "$_lib" 2>/dev/null || [ "$HOOK_LIB_LOADED" != 1 ]; then
    block "the shared hook library is missing or broken at $_lib — re-run the installer."
fi

[ "${#PY_LIST[@]}" -gt 0 ] || block "no python3 or python on PATH — this hook cannot read the command it exists to check."

hook_read_payload

parse() { # <command|cwd> — prints the field; non-zero if the payload will not parse
    py_run "$HOOK_PAYLOAD" '
import json, sys
# Bytes decoded as UTF-8. A text-mode read uses the Windows code page, and a byte that page
# has no character for comes back as a surrogate, which the UTF-8 write below refuses.
d = json.loads(sys.stdin.buffer.read())
if sys.argv[1] == "cwd":
    v = d.get("cwd") or ""
else:
    ti = d.get("tool_input") or {}
    v = ti.get("command") or ti.get("script") or ""
# BINARY buffer, UTF-8, and no newline added. A text-mode write turns every \n in the
# command into CR LF on Windows, and staged_args() joins line continuations, which is
# the transform that turns a doubled CR into a wrong answer. See the note headed "BOTH
# FIELDS ARE WRITTEN THROUGH THE BINARY BUFFER" in block-dangerous-git.sh for both reasons.
sys.stdout.buffer.write(v.encode("utf-8"))
' "$1"
}

cmd="$(parse command)" || block "the payload did not parse as JSON — refusing to guess what this command stages. $(py_tried)"

# --- What does this command actually STAGE? ------------------------------------
# Every check below reads the ARGUMENTS of a git add/commit/stage, never the command text.
#
# The text scan this replaces refused any command in which a never-stage name APPEARED at
# all. `git commit -m "stop tracking MEMORY.md"` was blocked. So was a heredoc writing a
# note about the rule — twice while #112 was being fixed, once in the notes for #112
# itself. And because a compound command dies whole, anything chained in FRONT of the
# mention never ran either, so the failure read as if that first step was the problem.
# Anchoring the patterns to a path boundary did not close this: in prose a name has a space
# on each side, and a space IS a path boundary.
#
# So the tokenizer, staged_args() in _lib/common.sh, answers the only question worth
# asking — WHICH WORDS are paths handed to a staging verb — and the checks compare a whole
# path COMPONENT against a whole name. That is exact, so the anchor regexes are gone:
# `garden-memory.md` is one component and it is not `MEMORY.md`, no boundary class required.
#
# Case folding stays, and is the decision recorded in #112: Windows resolves .Serena and
# .serena to one directory, so a different spelling must not be a way through.
#
# A command that will not tokenize is a BLOCK, exactly as an unreadable payload is: the
# hook did not find out what it was being asked to clear, so it does not clear it.

# The pre-filter never asks for the verb: `git -C <dir> add …` does not put the verb
# next to the program name, and a filter that demanded that let the whole command past.
# The same rule as may_be_git, over the command with line breaks, quotes and backslash
# deleted and a backtick read as a dollar: pass on git, or on g or gi then a dollar.
# The `,,` is load-bearing: drop it and the filter stops being case-insensitive, which is a
# guardrail quietly narrowing.
sq=${cmd//$'\n'/}
sq=${sq//$'\r'/}
sq=${sq//'"'/}
sq=${sq//"'"/}
sq=${sq//"\\"/}
sq=${sq//'`'/'$'}
if [[ ${sq,,} == *git* || ${sq,,} == *'g$'* || ${sq,,} == *'gi$'* ]]; then
    # Rows include commands nested in $( ), backticks and any multi-word argument
    # (bash -c, ssh, eval), up to MAX_DEPTH. A commit message and the arguments of echo,
    # printf, grep, rg and gh (NO_EXEC) with no pipe after them are not read as commands.
    # These shapes reach a shell unjudged. The list is what has been measured, not a set
    # anyone has closed — each entry below was found after the one above it, so treat a
    # shape that is absent as unlooked-for rather than absent:
    #   - text a shell reads on stdin: a heredoc body fed to bash;
    #   - NO_EXEC output put back through a substitution or a process substitution —
    #     `eval "$(echo "git add -A")"`, `echo "git add -A" > >(bash)`;
    #   - an option whose VALUE is a command — `git rebase --exec="git add -A"`,
    #     `git -c alias.x="!git add -A" x`, `ssh -o ProxyCommand="git add -A" host`;
    #   - a git word split by an expansion whose whitespace value this payload does not
    #     show — `git${IFS:0:1}add -A`, `git$(printf " ")add -A`;
    #   - text one command writes to a file and the next command runs —
    #     `echo "git add -A" > x.sh; bash x.sh`. A redirect only: `tee` is not in
    #     NO_EXEC, so the same shape through a pipe is judged.
    args="$(staged_args "$cmd" 0)" || block "this command could not be read well enough to tell what it stages — refusing rather than guessing. Rewrite it with plain quoting (no nested, escaped or unbalanced quotes), or ask the user to run it."

    while IFS="$(printf '\t')" read -r sub kind arg; do
        [ -n "$kind" ] || continue

        # Bare `git add -A`/`.` can sweep infra files in — nudge to explicit paths. The
        # allowlist never unlocks this one; it is the accidental sweep the rule exists for.
        # An ARGUMENT of add, so a commit message that merely says "-A" is not one.
        if [ "$sub" = add ] && { [ "$arg" = "-A" ] || [ "$arg" = "--all" ] || { [ "$kind" = path ] && [ "$arg" = "." ]; }; }; then
            block "git add -A / git add . can sweep in .claude/ or a memory file — stage explicit paths."
        fi
        [ "$kind" = path ] || continue

        # One lower-case, forward-slash copy for every comparison below, wrapped in slashes
        # so a whole COMPONENT can be matched with an ordinary glob.
        # SET1 is A-Z plus one literal backslash (tr spells that with two). ShellCheck
        # reads it as a quoting mistake; it is not.
        # shellcheck disable=SC1003
        low="/$(printf '%s' "$arg" | tr 'A-Z\\' 'a-z/')/"

        # Never, whatever the allowlist says: your machine, not the project.
        case "$low" in
            */.serena/*|*/.forgetful/*|*/memory.md/*)
                block "attempt to stage AI-infra path '$arg' — a fresh clone never needs it." ;;
        esac

        # .claude/ is a TWO-WAY sort, not a blanket block. agents/ and skills/ are generated
        # from this repo's CLAUDE.md and a fresh clone needs them; everything else under
        # .claude/ regenerates or belongs to your machine. Checked per argument, so one
        # allowed path in the command does not license the others beside it.
        case "$low" in
            */.claude/*)
                case "$low" in
                    */.claude/agents/*|*/.claude/skills/*) ;;
                    *) block "attempt to stage '$arg' — only .claude/agents/ and .claude/skills/ are product files; the rest regenerates or is yours." ;;
                esac ;;
        esac

        # CLAUDE.md: the one path the allowlist decides. On a repo you have answered `yes`
        # for, this file IS the product — nothing else will ever commit it, and without it a
        # fresh clone re-derives the stack, the chain and the Serena verdict from nothing.
        case "$low" in
            */claude.md/)
                cwd="$(parse cwd)" || block "the payload did not parse as JSON — refusing to guess which repo this is. $(py_tried)"
                allowlist_says claude-md "$cwd" || block "attempt to stage CLAUDE.md — this repo is not in ~/.claude/repo-allowlist with own-claude-md: yes." ;;
        esac
    done <<< "$args"
fi

exit 0
