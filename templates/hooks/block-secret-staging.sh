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
_lib="${BASH_SOURCE[0]//\\//}"
case "$_lib" in */*) _lib="${_lib%/*}/_lib/common.sh" ;; *) _lib="_lib/common.sh" ;; esac
HOOK_LIB_LOADED=
# shellcheck source=/dev/null
if ! . "$_lib" 2>/dev/null || [ "$HOOK_LIB_LOADED" != 1 ]; then
    block "the shared hook library is missing or broken at $_lib — re-run the installer."
fi

[ "${#PY_LIST[@]}" -gt 0 ] || block "no python3 or python on PATH — this hook cannot read the command it exists to check."

hook_read_payload
cmd="$(py_run "$HOOK_PAYLOAD" '
import json, sys
# Bytes decoded as UTF-8. A text-mode read uses the Windows code page, and a byte that page
# has no character for comes back as a surrogate, which the UTF-8 write below refuses.
ti = json.loads(sys.stdin.buffer.read()).get("tool_input") or {}
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

# Credential-shaped paths: only on git add / commit / stage, and only over the WORDS that
# verb is handed. Which words those are is a tokenizer's answer, not a regex's.
#
# staged_args() is in _lib/common.sh. This hook asks it for the glued view as well (the
# 1 below), because it judges the path word itself: a path written inside an unquoted
# substitution must still be read (`git add $(echo .env)`).

# The left edge of a path INSIDE one word, as a COMPLEMENT class: wpath lists the
# characters that CONTINUE a word, so a construct nobody listed lands outside the list and
# blocks, instead of walking past a list of separators somebody had to think of first.
# Quotes, $, braces, parens, backtick and backslash are deliberately not word characters:
# each can expand to nothing, so `git add ${x}.env` is really `git add .env`. wpath drops
# `/`, since `/` separates path components and dir/.env really is .env.
wpath='A-Za-z0-9_.,:=@%+^~!?*#['
pbrk='(^|[^]'"$wpath"'-])'
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
    args="$(staged_args "$cmd" 1)" || block "this command could not be read well enough to tell what it stages — refusing rather than guessing. Rewrite it with plain quoting (no nested, escaped or unbalanced quotes), or ask the user to run it."

    # The subcommand does not change the answer here: add, stage and commit all put the
    # path in the repo. Only path rows are read — an option word is never a path.
    while IFS="$(printf '\t')" read -r _ kind arg; do
        [ "$kind" = path ] || continue

        # `.env.example` and friends are the committed TEMPLATE — the one file in this
        # family that is supposed to be in the repo. Remove those tokens before matching
        # rather than trying to write a not-followed-by pattern, which ERE cannot express.
        scan="$(printf '%s' "$arg" | sed -E 's/\.env\.(example|sample|template|dist)//gI')"
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
    done <<< "$args"
fi

exit 0
