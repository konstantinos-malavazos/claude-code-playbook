#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash / PowerShell).
# Blocks a call that asks to hold the session open far past the tool's default timeout
# without saying how long it expects to take. Exit 2 = block.
#
# BOTH SHELLS, and it is not a widening for its own sake. PowerShell is a SEPARATE tool
# from Bash with a timeout of its own on the same 120000/600000 bounds, and on Windows it
# can be the shell the model reaches for first. A guard matched on Bash alone therefore
# stops nothing the moment it does — the failure shape README.md calls the worst one a
# guardrail has, because it keeps reporting success. Nothing in this script reads the tool
# name to decide anything; it is named in the refusal and nowhere else.
#
# Wire in ~/.claude/settings.json under hooks.PreToolUse (see settings-hooks.snippet.json).
#
# WHAT THIS IS NOT. It is not a guard against an unbounded hang: the tool is ALREADY
# bounded, and asking it to run forever is not a thing the payload can express. What is
# unbounded is the *unexplained long hold* — a call reaching for materially more than the
# default while saying nothing about why, which is how a session quietly becomes an
# overrun nobody can measure because nobody stated what to measure against.
#
# Catches: tool_input.timeout > 120000 with no expectation in tool_input.description.
#   The two figures are the harness's, not this repo's. They are READ OFF THE BASH TOOL,
#   and applied to PowerShell on the ASSUMPTION that it is bounded the same way —
#   assumed, not verified, and nobody has cited a source for the PowerShell figures.
#   If PowerShell's default is lower, this hook fires on PowerShell calls that were
#   never long holds; the cost is a false refusal whose remedy is one field, not a
#   guardrail that fails open. Check it against your own harness before trusting the
#   PowerShell half. They are written HERE and in
#   test-hooks.sh's boundary cases, and nowhere in prose — templates/agents/README.md
#   states the rule without numbers on purpose, because a convention bullet is not re-run
#   when the harness bumps its version and these two files are.
#   IF THOSE FIGURES MOVE, this is the line to change and test-hooks.sh's boundary cases
#   are the other one; they must agree, and what tells you the boundary still lands where
#   you think it does is running that suite.
#
# WHY THE THRESHOLD IS THE DEFAULT AND NOT SOME ROUND NUMBER ABOVE IT. Anything at or
# under the default is untouched, deliberately. A rule that fires on `ls` is a rule nobody
# keeps, and a guardrail nobody keeps is worse than none. Picking 5 minutes, or twice the
# default, would put the trigger somewhere no one can read off the tool — the default is
# the one boundary the caller already knows, so it is the one they can predict.

set -euo pipefail

block() { echo "BLOCKED by block-unexplained-long-hold: $1" >&2; exit 2; }

# python parses the payload and a payload it cannot read is a BLOCK, never a pass.
# Duplicated from block-dangerous-git.sh, deliberately — the reasoning for all of it (why
# python and not jq or sed, why 127 is the same class as success, why a WindowsApps
# python3 goes to the END of the list and is never dropped, and why nothing is probed
# until we are refusing anyway) is in the notes there. The code below is byte-identical in
# all seven hooks and in test-hooks.sh.
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

[ "${#PY_LIST[@]}" -gt 0 ] || block "no python3 or python on PATH — this hook cannot read the timeout it exists to check."

# `read -d ""` rather than $(cat) — the reasoning is in block-mcp-writes.sh.
IFS= read -r -d '' payload || true

# ONE program does the whole judgement, and it reports through the EXIT CODE, not through
# a string bash then has to re-parse. Exit 3 is the finding ("this is an unexplained long
# hold"), which py_run passes back untouched; exit 0 is "nothing to see"; anything else is
# the interpreter or the payload failing, which is a different refusal with a different
# message. Splitting the read from the judgement would mean two python processes on every
# Bash call, and #146 is the ticket about what that costs.
#
# WHAT COUNTS AS AN EXPECTATION: a number and a time unit, anywhere in the description.
# It is deliberately mechanical. The hook cannot know whether 90s is a good guess; it can
# know whether a guess was made, and the value of the rule is in having a number to judge
# the wait against at all. Writing it out in words ("about four minutes") does not pass —
# and the refusal says exactly what shape does, so the remedy is one edit away.
rc=0
detail="$(py_run "$payload" '
import json, re, sys

DEFAULT_MS = 120000          # the Bash tool default; ASSUMED equal for PowerShell
MAX_MS     = 600000          # the Bash tool maximum;  ASSUMED equal for PowerShell
                             # Uncited for PowerShell — see the Catches note at the top.

ESTIMATE = re.compile(
    r"\b\d+(?:\.\d+)?\s*"
    r"(?:ms|msec|s|sec|secs|second|seconds|m|min|mins|minute|minutes|h|hr|hrs|hour|hours)\b",
    re.I)

data = json.load(sys.stdin)
ti = data.get("tool_input")
if not isinstance(ti, dict):
    # A well-formed payload with no tool_input asked for no timeout. Nothing to judge.
    sys.exit(0)

# The refusal names the tool it is refusing. "this call" is ambiguous in a transcript with
# both tools in it, and the reader acting on the remedy has to know which call to re-issue.
# Anything that is not a plain identifier is not echoed back — a refusal is not a place to
# print unvalidated payload text, and the shell below splits this line on whitespace.
tool = data.get("tool_name")
if not isinstance(tool, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,32}", tool):
    tool = "tool"

timeout = ti.get("timeout")
if timeout is None:
    sys.exit(0)                                  # no timeout requested — untouched
if isinstance(timeout, bool) or not isinstance(timeout, (int, float)):
    # A timeout this hook cannot compare is a timeout it did not read. Same rule as an
    # unreadable payload: it does not get to pass because the check was inconclusive.
    # The TYPE name, not the value: the value can contain spaces ("5 minutes") and the
    # shell below splits this line on whitespace. What the reader needs is which shape
    # arrived, not a quoted echo of what they already typed.
    sys.stdout.buffer.write(("NONNUMERIC %s %s" % (tool, type(timeout).__name__)).encode())
    sys.exit(3)
if timeout <= DEFAULT_MS:
    sys.exit(0)                                  # at or under the default — untouched

# THE MAXIMUM IS CHECKED BEFORE THE DESCRIPTION, and the order is the whole point. Past the
# maximum the tool refuses the call whatever anyone wrote in the description, so a stated
# estimate does not make the request runnable — it makes it a well-documented request for
# something that will not happen. The first cut of this hook checked the description first
# and therefore ALLOWED a 900000ms call that said "expect 12 minutes"; the case that caught
# it is "past the maximum" in test-hooks.sh, and it was added after the code, not before.
# (No backticks in this program text: a backtick pair inside the single-quoted heredoc-ish
# string reads to shellcheck as a command substitution that will not expand — SC2016.)
if timeout > MAX_MS:
    sys.stdout.buffer.write(("OVERMAX %s %d %d %d" % (tool, timeout, DEFAULT_MS, MAX_MS)).encode())
    sys.exit(3)

desc = ti.get("description")
if isinstance(desc, str) and ESTIMATE.search(desc):
    sys.exit(0)                                  # the expectation is stated — allowed

sys.stdout.buffer.write(("LONGHOLD %s %d %d %d" % (tool, timeout, DEFAULT_MS, MAX_MS)).encode())
sys.exit(3)
')" || rc=$?

case "$rc" in
    0) exit 0 ;;
    3) : ;;   # the finding — the message is built below
    *) block "the payload did not parse as JSON — refusing to guess how long this call means to run. $(py_tried)" ;;
esac

# shellcheck disable=SC2086  # the split IS the parse: $detail is one line of whitespace-
# separated fields this script wrote itself, with no user text and no glob character in
# any of them (the value that could carry spaces is emitted as a type name above).
set -- $detail
kind="${1:-LONGHOLD}"
tool="${2:-tool}"

# THE REFUSAL QUOTES THE CONVENTION, WORD FOR WORD. A hook that refuses in different words
# from the rule it enforces is a second rule, and the second one is written down nowhere.
RULE='"A call you expect to run long carries an explicit timeout and, in the same breath, what you expect this call to take." (templates/agents/README.md)'

# AND IT CARRIES ITS OWN REMEDY, runnable from exactly where the stop fired. A hard stop
# that sends the reader somewhere else to find out what to do is the loop this repo has
# already filed once: the remedy has to be performable at the point of refusal, and here
# that is one field on the very call that was just refused.
REMEDY='REMEDY: re-issue the SAME call with the expectation in its description, as a number and a unit — description="<what it does>; expect ~90s". Nothing else here has to change. "90s", "6 minutes" and "90000ms" all read; "about four minutes" does not, because it carries no number. NOTE this is the only thing THIS hook wants. Other guardrails run on the same call and judge the command itself, so if the re-issued call is refused again it will be by a different hook, for a different reason, naming itself — read that refusal on its own terms rather than adding a longer estimate.'

if [ "$kind" = "NONNUMERIC" ]; then
    block "this $tool call's timeout arrived as a JSON ${3:-value of the wrong kind} rather than a number of milliseconds, so nothing here could compare it to the default. An unjudged call does not go. Pass the timeout as a plain number. $RULE $REMEDY"
fi

if [ "$kind" = "OVERMAX" ]; then
    block "this $tool call asks for a ${3}ms timeout, past the tool's ${5}ms maximum, so the tool will reject it whatever this hook says — and stating an expectation does not change that. Work you expect to run that long goes to the BACKGROUND by design, decided before you launch it and not after it appears to hang. $RULE"
fi

block "this $tool call asks to hold for ${3}ms — more than the ${4}ms default — and its description says nothing about how long you expect it to take. That is the unexplained long hold: a wait with nothing to measure it against, so nobody can tell a slow run from a stuck one. $RULE $REMEDY"
