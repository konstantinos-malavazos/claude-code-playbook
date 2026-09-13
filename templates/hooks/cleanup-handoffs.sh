#!/usr/bin/env bash
# SessionEnd hook. Deletes ephemeral pipeline handoff dirs so in-flight state never
# lingers or leaks into memory. Skips when the session ended for a resume.

set -euo pipefail

# python parses the payload, not jq — see block-dangerous-git.sh for why.
#
# THIS HOOK CANNOT FAIL CLOSED, and is not made to try. The five blocking hooks exit 2
# when they cannot read their payload. This one is SessionEnd, where Claude Code ignores
# the exit code entirely — there is no verdict to return, so exit 2 would be a number
# nobody reads. The asymmetry with the blocking hooks is the harness's, not an oversight.
#
# It fails SAFE instead, and in the direction that keeps data: without the reason it
# cannot tell a resume from a real end, and deleting the handoffs the resume flow is
# about to want is the expensive mistake. Leaving them costs a stale directory.
#
# THE INTERPRETER LIST IS BYTE-IDENTICAL to the one in the five blocking hooks and in
# test-hooks.sh — only what this hook DOES when none of them works differs, and that
# asymmetry is the harness's, described above. Why a WindowsApps python3 goes to the END
# of the list and is never dropped, and why nothing is probed until we are already giving
# up, is in the notes in block-dangerous-git.sh.
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

if [ "${#PY_LIST[@]}" -eq 0 ]; then
    echo "cleanup-handoffs: no python3 or python on PATH — leaving the handoffs in place." >&2
    exit 0
fi

# `read -d ""` rather than $(cat). A command substitution forks a subshell and then execs
# cat, which measured 37ms on Windows — more than choosing the interpreter above and more
# than the parse itself on an ordinary payload, for reading one string off stdin. `-d ""`
# reads to EOF (a JSON payload carries no NUL), `-r` keeps backslashes literal, `IFS=`
# keeps leading and trailing whitespace, and the non-zero exit at EOF is the expected
# outcome, not a failure. The only difference from $(cat) is that a trailing newline
# survives, and no JSON reader cares. Measured faster at 4KB as well as at 60 bytes.
IFS= read -r -d '' payload || true
reason="$(py_run "$payload" '
import json, sys
sys.stdout.write(json.load(sys.stdin).get("reason") or "")
')" || { echo "cleanup-handoffs: the payload did not parse as JSON — leaving the handoffs in place. $(py_tried)" >&2; exit 0; }

# Don't wipe if the session is being resumed — the resume flow needs the handoffs.
if [ "$reason" = "resume" ]; then
    exit 0
fi

# Point this at your workspace's handoffs root.
HANDOFFS_ROOT="${WORKSPACE_HANDOFFS_ROOT:-$PWD/.claude/handoffs}"

if [ -d "$HANDOFFS_ROOT" ]; then
    # Remove per-ticket handoff dirs but keep the root.
    find "$HANDOFFS_ROOT" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
fi

exit 0
