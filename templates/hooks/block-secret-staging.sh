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
# Duplicated from block-dangerous-git.sh, deliberately — the reasoning is in the note
# there. This hook needs one filter, so it has no `parse` helper.
PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || block "no python3 or python on PATH — this hook cannot read the command it exists to check."

payload="$(cat)"
cmd="$(printf '%s' "$payload" | "$PY" -c '
import json, sys
ti = json.load(sys.stdin).get("tool_input") or {}
sys.stdout.write(ti.get("command") or ti.get("script") or "")
' 2>/dev/null)" || block "the payload did not parse as JSON — refusing to guess whether this command carries a credential."
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
    if printf '%s' "$norm" | grep -Eq "$pat"; then
        block "a credential literal matching /$pat/ is in this command — do not put it on a command line at all."
    fi
done

# Credential-shaped paths: only on git add / commit / stage.
if printf '%s' "$norm" | grep -Eiq 'git +(add|commit|stage)'; then
    # `.env.example` and friends are the committed TEMPLATE — the one file in this family
    # that is supposed to be in the repo. Remove those tokens before matching rather than
    # trying to write a not-followed-by pattern, which ERE cannot express. This was found
    # by the suite, not by reading: the `.env` pattern matched the template too.
    scan="$(printf '%s' "$norm" | sed -E 's/\.env\.(example|sample|template|dist)//gI')"
    for pat in \
        '(^|[ /"'"'"';])\.env($|[. /"'"'"';])' \
        '\.env\.(local|prod|production|staging|dev)\b' \
        '\.(pem|p12|pfx|jks|keystore|ppk)\b' \
        'id_(rsa|dsa|ecdsa|ed25519)\b' \
        '(^|[ /])(credentials|secrets?|service-account)\.(json|ya?ml|toml|ini)\b' \
        '\.npmrc\b' \
        '\.pypirc\b' \
        '\.netrc\b'
    do
        if printf '%s' "$scan" | grep -Eiq "$pat"; then
            block "attempt to stage a credential-shaped path matching /$pat/ — put it in .gitignore instead."
        fi
    done
fi

exit 0
