#!/usr/bin/env bash
# PostToolUse hook (matcher: Write / Edit / MultiEdit).
# Auto-formats the file that was just edited, per its extension. Non-blocking.

set -euo pipefail

# python parses the payload, not jq — see block-dangerous-git.sh for why.
#
# THIS HOOK CANNOT FAIL CLOSED, and is not made to try. The four blocking hooks exit 2
# when they cannot read their payload, because a guard that cannot see the command must
# stop it. This one is PostToolUse: it runs AFTER the edit it would be objecting to, so
# there is nothing left to stop and exit 2 would only report a failure on work already
# done. No parser, or a payload that will not parse, means it formats nothing and says
# so. The asymmetry with the blocking hooks is the harness's, not an oversight here.
#
# THE INTERPRETER LIST IS BYTE-IDENTICAL to the one in the four blocking hooks and in
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
    echo "format-on-edit: no python3 or python on PATH — skipping the format." >&2
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
file="$(py_run "$payload" '
import json, sys
ti = json.load(sys.stdin).get("tool_input") or {}
sys.stdout.write(ti.get("file_path") or "")
')" || { echo "format-on-edit: the payload did not parse as JSON — skipping the format. $(py_tried)" >&2; exit 0; }
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

# Map extensions to your formatters. Fail-soft: never block an edit on a format error.
case "$file" in
    *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md)  npx --no-install prettier --write "$file" 2>/dev/null || true ;;
    *.py)                                     black "$file" 2>/dev/null || true ;;
    *.go)                                     gofmt -w "$file" 2>/dev/null || true ;;
    *.rs)                                     rustfmt "$file" 2>/dev/null || true ;;
    *.cs)                                     dotnet format --include "$file" 2>/dev/null || true ;;
    *) : ;;
esac

exit 0
