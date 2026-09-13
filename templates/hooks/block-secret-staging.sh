#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash / PowerShell).
# Blocks staging/committing credential-shaped paths, and obvious token literals anywhere
# in the command. Exit 2 = block.
#
# WHY THIS EXISTS, since it is not general hygiene: the push block was quietly doing
# secret-leak protection. While a human ran every push, a committed key was survivable —
# you see the diff. Once a repo is allowlisted for push (see repo-allowlist.sample),
# nobody does. The failure is concrete: the agent writes .env with a live key, commits,
# pushes; the repo is private so it feels fine; six months later you make it public to
# show someone and the key is in the history.
#
# WHAT IT CANNOT DO: it sees the command, not the file. `git add config.yml` with a
# password inside passes. This blocks credential-shaped NAMES and pasted-in literals —
# it is not a secret scanner, and calling it one would be the kind of guardrail that
# reports success while guarding nothing.

set -euo pipefail

block() { echo "BLOCKED by block-secret-staging: $1" >&2; exit 2; }

# python parses the payload and a payload it cannot read is a BLOCK, never a pass.
# Duplicated from block-dangerous-git.sh, deliberately — the reasoning for all of it (why
# python and not jq or sed, why 127 is the same class as success, why a WindowsApps
# python3 goes to the END of the list and is never dropped, and why nothing is probed
# until we are refusing anyway) is in the notes there. The code below is byte-identical in
# all seven hooks and in test-hooks.sh. This hook needs one filter, so it has no `parse`
# helper.
PY_LIST=()
PY_LAST=()
# ONE command substitution, not one per candidate. A fork costs ~30ms on Windows and this
# runs on every single hook invocation, so asking twice cost measurably more than the
# whole ordering decision it feeds. The `true` keeps the list non-fatal when neither name
# resolves; the empty-line guard is what a missing candidate looks like here.
while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    case "${_p,,}" in
        */windowsapps/*) PY_LAST+=("$_p") ;;
        *)               PY_LIST+=("$_p") ;;
    esac
done <<< "$(command -v python3 2>/dev/null; command -v python 2>/dev/null; true)"
PY_LIST+=(${PY_LAST[@]+"${PY_LAST[@]}"})

py_tried() { # the refusal's evidence: every candidate by resolved path, with a verdict
    local _c _out=""
    for _c in ${PY_LIST[@]+"${PY_LIST[@]}"}; do
        if "$_c" -c "pass" >/dev/null 2>&1; then
            _out="${_out}${_out:+, }${_c} (is python)"
        else
            _out="${_out}${_out:+, }${_c} (on PATH, but not a working python)"
        fi
    done
    printf 'interpreter tried: %s' "${_out:-none — no python3 or python on PATH}"
}

py_run() { # <stdin> <program> [args…] — first candidate that answers wins
    local _in="$1" _prog="$2" _c _rc=127
    shift 2
    for _c in ${PY_LIST[@]+"${PY_LIST[@]}"}; do
        _rc=0
        printf '%s' "$_in" | "$_c" -c "$_prog" "$@" 2>/dev/null || _rc=$?
        [ "$_rc" -eq 0 ] && return 0
        # 3 is the PROGRAM saying no, not the interpreter failing to be python. Handing
        # the same input to a different interpreter would get the same answer.
        [ "$_rc" -eq 3 ] && return 3
    done
    return "$_rc"
}

[ "${#PY_LIST[@]}" -gt 0 ] || block "no python3 or python on PATH — this hook cannot read the command it exists to check."

# `read -d ""` rather than $(cat). A command substitution forks a subshell and then execs
# cat, which measured 37ms on Windows — more than choosing the interpreter above and more
# than the parse itself on an ordinary payload, for reading one string off stdin. `-d ""`
# reads to EOF (a JSON payload carries no NUL), `-r` keeps backslashes literal, `IFS=`
# keeps leading and trailing whitespace, and the non-zero exit at EOF is the expected
# outcome, not a failure. The only difference from $(cat) is that a trailing newline
# survives, and no JSON reader cares. Measured faster at 4KB as well as at 60 bytes.
IFS= read -r -d '' payload || true
cmd="$(py_run "$payload" '
import json, sys
ti = json.load(sys.stdin).get("tool_input") or {}
# The buffer, not text mode: a text-mode write turns every \n into \r\n on Windows, and
# tr maps both characters, so one newline would leave TWO separators in the normalised
# command below instead of one, and no whitespace at all where the command had a line
# continuation. The sibling hooks write through the buffer for the same reason.
sys.stdout.buffer.write((ti.get("command") or ti.get("script") or "").encode("utf-8"))
')" || block "the payload did not parse as JSON — refusing to guess whether this command carries a credential. $(py_tried)"
norm="$(printf '%s' "$cmd" | tr '\r\n' ';;' | tr -s ' ')"

# Token literals: blocked wherever they appear, including on a read command. A live key
# on a command line has already leaked — into shell history and into the transcript —
# whether or not git ever sees it, so "was this a write?" is the wrong question to ask.
# The cost is a false positive on something like `grep -r AKIA .`, which is rare and
# loud; the alternative is a pattern that has to guess which commands write.
for pat in \
    'sk-[A-Za-z0-9_-]{20,}' \
    'ghp_[A-Za-z0-9]{20,}' \
    'github_pat_[A-Za-z0-9_]{20,}' \
    'xox[baprs]-[A-Za-z0-9-]{10,}' \
    'AKIA[0-9A-Z]{16}' \
    'AIza[0-9A-Za-z_-]{30,}' \
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'
do
    # -e is load-bearing: without it a pattern starting with `-` is parsed as options and
    # grep exits 2 on usage, which this `if` reads as "no match" and waves the command
    # through. The PRIVATE KEY pattern below is exactly that shape, and it failed open for
    # as long as it has existed. Found by running the hook, not by reading it.
    if printf '%s' "$norm" | grep -Eq -e "$pat"; then
        block "a credential literal matching /$pat/ is in this command — do not put it on a command line at all."
    fi
done

# Credential-shaped paths: only on git add / commit / stage.
# Options may sit between git and the verb (`git -C dir add`), but the gap excludes
# ; & | so the verb must be in the same command segment. Newlines are ; in $norm.
# The verb ends at anything but a name character or ; & |, so add.sh is not add while
# add"" and add\<newline> still are: bash removes those before git reads the verb.
#
# The breaks beside git and at the left edge of a path are COMPLEMENT classes listing
# the characters that CONTINUE a shell word, so a construct nobody listed lands outside
# the list and blocks, instead of walking past a list of separators somebody had to
# think of first. Quotes, $, braces, parens, backtick and backslash are deliberately
# not word characters: each can expand to nothing, so `git"" add .env` and
# `git add ${x}.env` are both really `git add .env`. wpath drops `/`, since `/`
# separates path components and dir/.env really is .env. The verb's right-hand boundary
# is not one of these classes — it is a literal alphabet, which can only fail to match,
# so it errs towards blocking.
wcont='A-Za-z0-9_.,:=@%+^~!?*/#['
wpath='A-Za-z0-9_.,:=@%+^~!?*#['
# A word break beside git or the verb: an escaped character, or one character that
# neither continues a word nor separates segments. A backslash-newline arrives here as
# `\;`, because $norm turned the newline into `;`, and that is a continuation. pbrk is
# the same idea at the left edge of a path, where a segment separator is a fine break.
brk='(\\.|[^]'"$wcont"';&|-])'
pbrk='(^|[^]'"$wpath"'-])'
# The gap has to hold one literal whitespace, which is what separates `git"" add .env`
# — really `git add .env` — from `git""add .env`, the single word gitadd, which stages
# nothing. Known limit: a construct that expands TO whitespace makes the same boundary
# with no literal whitespace in the text, so `git${IFS}add .env` really stages and this
# gate reads it as one word. Telling that apart from gitadd takes word splitting, which
# a regex over the raw text cannot do.
gate="git(${brk}[^;&|]*)?[[:space:]]([^;&|]*${brk})?"
gate="$gate"'(add|commit|stage)([^A-Za-z0-9_.;&|-]|$)'
if printf '%s' "$norm" | grep -Eiq -e "$gate"; then
    # `.env.example` and friends are the committed TEMPLATE — the one file in this family
    # that is supposed to be in the repo. Remove those tokens before matching rather than
    # trying to write a not-followed-by pattern, which ERE cannot express. This was found
    # by the suite, not by reading: the `.env` pattern matched the template too.
    scan="$(printf '%s' "$norm" | sed -E 's/\.env\.(example|sample|template|dist)//gI')"
    for pat in \
        "$pbrk"'\.env($|[^A-Za-z0-9_-])' \
        '\.env\.(local|prod|production|staging|dev)\b' \
        '\.(pem|p12|pfx|jks|keystore|ppk)\b' \
        'id_(rsa|dsa|ecdsa|ed25519)\b' \
        "$pbrk"'(credentials|secrets?|service-account)\.(json|ya?ml|toml|ini)\b' \
        '\.npmrc\b' \
        '\.pypirc\b' \
        '\.netrc\b'
    do
        if printf '%s' "$scan" | grep -Eiq -e "$pat"; then
            block "attempt to stage a credential-shaped path matching /$pat/ — put it in .gitignore instead."
        fi
    done
fi

exit 0
