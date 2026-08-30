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
# So the tokenizer below answers the only question worth asking — WHICH WORDS are paths
# handed to a staging verb — and the checks compare a whole path COMPONENT against a whole
# name. That is exact, so the anchor regexes are gone: `garden-memory.md` is one component
# and it is not `MEMORY.md`, no boundary class required.
#
# Case folding stays, and is the decision recorded in #112: Windows resolves .Serena and
# .serena to one directory, so a different spelling must not be a way through.
#
# A command that will not tokenize is a BLOCK, exactly as an unreadable payload is: the
# hook did not find out what it was being asked to clear, so it does not clear it.
staged_args() { # prints "<subcommand>\t<opt|path>\t<word>" per argument; exit 3 = unparsable
    printf '%s' "$cmd" | "$PY" -c '
import re, shlex, sys

SUB = {"add": "add", "stage": "add", "commit": "commit"}

# The options git itself takes BEFORE the subcommand. These four take a separate value.
GLOBAL_VAL = {"-C", "-c", "--git-dir", "--work-tree", "--exec-path", "--namespace"}

# Options whose value is a message, a mode or a file to READ — never a path to stage.
# Options that may OMIT their value (-S, -u) are deliberately absent: skipping the word
# after one of those would swallow a real path, and that fails OPEN.
VAL = {
    "add": {"--chmod", "--pathspec-from-file"},
    "commit": {"-m", "--message", "-F", "--file", "-C", "--reuse-message",
               "-c", "--reedit-message", "--author", "--date", "--cleanup",
               "--squash", "--fixup", "-t", "--template", "--trailer",
               "--pathspec-from-file"},
}

OPS = (";", "&&", "||", "|", "&", "|&", "(", ")")

def strip_heredocs(s):
    # A heredoc body is DATA, not a command. A line inside one that begins with a stage
    # verb is prose ABOUT staging, which is what this repo is full of.
    lines = s.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out, i = [], 0
    while i < len(lines):
        m = re.search(r"<<-?\s*([\x27\x22]?)([A-Za-z_][A-Za-z0-9_]*)\1", lines[i])
        out.append(lines[i][:m.start()] if m else lines[i])
        i += 1
        if m:
            term = m.group(2)
            while i < len(lines) and lines[i].strip() != term:
                i += 1
            i += 1
    return "\n".join(out)

# Newlines become an explicit separator BEFORE tokenizing: shlex treats one as plain
# whitespace, which would run two commands together into one segment.
src = strip_heredocs(sys.stdin.read()).replace("\n", " ; ")

lex = shlex.shlex(src, posix=True, punctuation_chars=True)
lex.whitespace_split = True
lex.escape = ""      # a backslash is a Windows path separator here, never an escape
lex.commenters = ""
try:
    toks = list(lex)
except ValueError:
    sys.exit(3)

segs, cur = [], []
for t in toks:
    if t in OPS:
        segs.append(cur)
        cur = []
    else:
        cur.append(t)
segs.append(cur)

out = []
for seg in segs:
    words, k = [], 0
    while k < len(seg):                       # drop redirections and their targets
        if seg[k] and all(c in "<>" for c in seg[k]):
            k += 2
            continue
        words.append(seg[k])
        k += 1

    j = 0                                     # leading VAR=value assignments
    while j < len(words) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[j]):
        j += 1
    if j >= len(words):
        continue
    if words[j].replace("\\", "/").rsplit("/", 1)[-1].lower() not in ("git", "git.exe"):
        continue

    j += 1
    while j < len(words) and words[j].startswith("-"):
        j += 2 if words[j] in GLOBAL_VAL else 1
    if j >= len(words):
        continue
    sub = SUB.get(words[j].lower())
    if sub is None:
        continue

    j += 1
    rest_are_paths = False
    while j < len(words):
        w = words[j]
        if not rest_are_paths and w == "--":
            rest_are_paths = True
            j += 1
        elif not rest_are_paths and w.startswith("-") and w != "-":
            out.append(sub + "\t" + "opt" + "\t" + w)
            j += 2 if w in VAL[sub] else 1
        else:
            out.append(sub + "\t" + "path" + "\t" + w)
            j += 1

# Written through the BINARY buffer on purpose. On Windows a text-mode stdout rewrites
# every newline as CR LF, and the CR then travels on the LAST FIELD of the line, so read
# hands bash an argument of dot-plus-carriage-return, which matches no path and no name.
# That fails OPEN — and only on Windows, and only from the second line onward, which is to
# say only for a call that runs more than one command. Caught by the suite on
# "git add ." followed by a commit.
sys.stdout.buffer.write("".join(line + "\n" for line in out).encode("utf-8"))
' 2>/dev/null
}

# The pre-filter is deliberately just "git": `git -C <dir> add …` does not put the verb
# next to the program name, and a filter that demanded that let the whole command past.
if printf '%s' "$norm" | grep -Eiq 'git'; then
    args="$(staged_args)" || block "this command could not be read well enough to tell what it stages — refusing rather than guessing."

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
                allowlist_says claude-md || block "attempt to stage CLAUDE.md — this repo is not in ~/.claude/repo-allowlist with own-claude-md: yes." ;;
        esac
    done <<< "$args"
fi

exit 0
