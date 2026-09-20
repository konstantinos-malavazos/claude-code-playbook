#!/usr/bin/env bash
# Regression suite for the blocking hooks.
#
# A guardrail that stops guarding keeps reporting success, so these cannot be verified by
# reading them. Run this after editing any hook, and after a Claude Code release that
# changes the PreToolUse payload shape.
#
#   bash templates/hooks/test-hooks.sh
#
# A GREEN RUN MEANS TWO THINGS, and it needs both: the patterns match what they should
# match, AND every blocking hook stops the call when it cannot read the payload. The
# second half is why the no-parser section at the bottom exists. Failing closed is new
# code in every one of those scripts, and this directory has twice shipped a guardrail
# whose new code was never run.
#
# WHAT IT STILL CANNOT TELL YOU: whether the hooks are wired into your settings.json.
# The suite invokes the scripts directly and never sees your Claude Code config, so a
# fully green run is compatible with no hook firing on your machine at all. That question
# is answered by the live check in docs/shared/03-setup.md, and only by it.
#
# Exit 0 = every case behaved. Exit 1 = at least one guardrail is not guarding.

set -uo pipefail
# If this cd fails every path below is resolved against the wrong directory and
# the results are meaningless, so refuse rather than "pass" somewhere else.
cd "$(dirname "$0")" || exit 1

GIT_HOOK=./block-dangerous-git.sh
INFRA_HOOK=./block-infra-staging.sh
SECRET_HOOK=./block-secret-staging.sh
MCP_HOOK=./block-mcp-writes.sh
HOLD_HOOK=./block-unexplained-long-hold.sh

# --- python ---------------------------------------------------------------------
# The hooks parse their payload with python, and so does this suite when it builds one.
# There is nothing left to shim for the MISSING parser: when it is missing the hooks are
# SUPPOSED to block, which is a case the suite tests rather than papers over. What it does
# shim, at the bottom of this file, is the parser that is PRESENT and is not python.
#
# THE CANDIDATE LIST IS BYTE-IDENTICAL to the one in all seven hooks, and it has to be. If
# the suite picked its interpreter by a different rule from the hooks it tests, it would
# be building payloads with one python and judging a hook that chose another — and the
# case it would miss is exactly the one at the bottom of this file. Why a WindowsApps
# python3 goes to the END of the list and is never dropped is in block-dangerous-git.sh.
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

# The one place this file probes rather than letting the first real use decide: a harness
# that cannot build a payload has no cases to run at all, so it may as well find out now,
# once, instead of 240 times. The hooks are in the opposite position and do the opposite
# thing — see the note there.
PY=""
for _c in ${PY_LIST[@]+"${PY_LIST[@]}"}; do
    if "$_c" -c "pass" >/dev/null 2>&1; then
        PY="$_c"
        break
    fi
done
if [ -z "$PY" ]; then
    echo "SKIP: no working python3 or python available — cannot run the suite." >&2
    if [ "${#PY_LIST[@]}" -gt 0 ]; then
        echo "       on PATH, but not a working python: ${PY_LIST[*]}" >&2
    fi
    exit 1
fi

# bash by absolute path, because the no-parser cases run hooks under a stripped PATH and
# a PATH assignment governs the lookup of the command it prefixes.
BASH_BIN=$(command -v bash)

# Both counters are DERIVED by running. Nothing in this repo writes the case count down by
# hand any more: three passes of #117 hand-set it in the README (84, then 162, then 187) and
# it was wrong at some point in every one of them. A number nobody derives is a number that
# rots, and a suite is the one place that can always count itself.
ran=0
fail=0

# --- the allowlist, both ways --------------------------------------------------
# Two hooks now consult ~/.claude/repo-allowlist, keyed by the repo's remote URL. To
# exercise both answers the suite builds a scratch repo with a known remote and two
# throwaway HOMEs — one holding a line for it, one holding nothing.
#
# It does NOT key on this playbook's own remote. A test that passes only in the clone
# it was written in is a test that reports success somewhere it never ran.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

REPO="$SCRATCH/repo"
mkdir -p "$REPO"
git init -q "$REPO" 2>/dev/null
git -C "$REPO" remote add origin https://github.com/example/allowed-repo.git 2>/dev/null

DENY_HOME="$SCRATCH/home-unlisted"          # no allowlist at all — the default state
mkdir -p "$DENY_HOME/.claude"
ALLOW_HOME="$SCRATCH/home-listed"
mkdir -p "$ALLOW_HOME/.claude"
cat > "$ALLOW_HOME/.claude/repo-allowlist" <<'ALLOWLIST'
# a comment line, which must be skipped
github.com/example/allowed-repo    yes    yes
github.com/example/push-only       yes    no
ALLOWLIST

HOOK_HOME="$DENY_HOME"   # every case runs unlisted unless it says otherwise
HOOK_CWD="$REPO"
HOOK_PATH="$PATH"        # the no-parser section swaps this for one with no python

# HOOK_CWD is assigned once and never reassigned, so its JSON encoding is the same string
# for every case in this file. It used to be recomputed inside run(), which is one python
# process per case for an answer that cannot change — the largest single spawn saving in
# the suite, and invisible to every case. HOOK_HOME and HOOK_PATH DO move between cases;
# neither is part of the payload.
HOOK_CWD_JSON=$("$PY" -c "import json,sys;print(json.dumps(sys.argv[1]))" "$HOOK_CWD")

# $TILDE is a variable rather than a literal because the replacement half of a
# ${var//pat/repl} is tilde-expanded.
TILDE='~'

run() { # <script> <tool-name> <command> <expected-exit>
    local payload
    # `printf -v`, not payload=$(printf …). The substitution form forks a subshell for a
    # string bash can assemble in the shell it is already in; that fork measured ~30ms on
    # Windows, per case, for nothing. The remaining substitution is the one real python
    # call left in the payload build — it was two before the HOOK_CWD hoist above.
    printf -v payload '{"tool_name":"%s","cwd":%s,"tool_input":{"command":%s}}' "$2" \
        "$HOOK_CWD_JSON" \
        "$("$PY" -c "import json,sys;print(json.dumps(sys.argv[1]))" "$3")"
    printf '%s' "$payload" | HOME="$HOOK_HOME" PATH="$HOOK_PATH" "$BASH_BIN" "$1" >/dev/null 2>&1
    local got=$?
    local shown
    # Parameter expansion, not two `tr` processes. On Windows a process spawn costs more
    # than everything else this function does; these two ran on every case.
    shown=${3//$'\n'/$TILDE}
    shown=${shown//$'\r'/^}
    ran=$((ran + 1))
    if [ "$got" = "$4" ]; then
        printf '  ok   [%s] %s\n' "$2" "$shown"
    else
        printf '  FAIL [%s] exit=%s want=%s  %s\n' "$2" "$got" "$4" "$shown"
        fail=$((fail + 1))
    fi
}

run_raw() { # <script> <label> <raw-payload> <expected-exit>
    printf '%s' "$3" | HOME="$HOOK_HOME" PATH="$HOOK_PATH" "$BASH_BIN" "$1" >/dev/null 2>&1
    local got=$?
    ran=$((ran + 1))
    if [ "$got" = "$4" ]; then
        printf '  ok   [%s]\n' "$2"
    else
        printf '  FAIL [%s] exit=%s want=%s\n' "$2" "$got" "$4"
        fail=$((fail + 1))
    fi
}

# The only case shape that reads the hook's MESSAGE rather than just its exit code. An
# exit code alone cannot tell a refusal that explains itself from one that does not, and
# for the interpreter cases at the bottom of this file the message IS the behaviour under
# test: the block was always correct, it just talked about JSON while the real cause was
# which python3 PATH resolved to (#146).
run_msg() { # <script> <tool-name> <command> <expected-exit> <substring the message must contain>
    local payload out got=0 shown
    printf -v payload '{"tool_name":"%s","cwd":%s,"tool_input":{"command":%s}}' "$2" \
        "$HOOK_CWD_JSON" \
        "$("$PY" -c "import json,sys;print(json.dumps(sys.argv[1]))" "$3")"
    # stderr captured, stdout discarded — the hooks say why they refused on stderr.
    out=$(printf '%s' "$payload" | HOME="$HOOK_HOME" PATH="$HOOK_PATH" "$BASH_BIN" "$1" 2>&1 >/dev/null) || got=$?
    shown=${3//$'\n'/$TILDE}
    ran=$((ran + 1))
    if [ "$got" = "$4" ] && [ "${out#*"$5"}" != "$out" ]; then
        printf '  ok   [%s] %s — refusal names %s\n' "$2" "$shown" "$5"
    else
        printf '  FAIL [%s] exit=%s want=%s  expected the message to name %s\n' "$2" "$got" "$4" "$5"
        printf '       message was: %s\n' "$out"
        fail=$((fail + 1))
    fi
}

# The tool run_hold builds its payload for. `Bash` unless a section says otherwise — the
# PowerShell section flips it and flips it back. It is a variable rather than a parameter
# because every case in a section shares it, and a per-case argument that is the same on
# forty lines is a column of noise nobody reads.
HOLD_TOOL=Bash

run_hold() { # <label> <timeout-literal|OMIT> <description> <expected-exit> [substring the message must contain]
    # block-unexplained-long-hold.sh reads `tool_input.timeout`, not `tool_input.command`,
    # so none of the helpers above can build a payload for it. $2 is spliced into the JSON
    # VERBATIM rather than being encoded, which is the only way a case can hand the hook a
    # timeout that is not a number and see whether it fails closed on it. OMIT leaves the
    # field out altogether — the "no timeout was asked for" case, which must be untouched.
    local payload desc_json out got=0
    desc_json=$("$PY" -c "import json,sys;print(json.dumps(sys.argv[1]))" "$3")
    if [ "$2" = "OMIT" ]; then
        printf -v payload '{"tool_name":"%s","cwd":%s,"tool_input":{"command":"bash tests/test-docs.sh","description":%s}}' \
            "$HOLD_TOOL" "$HOOK_CWD_JSON" "$desc_json"
    else
        printf -v payload '{"tool_name":"%s","cwd":%s,"tool_input":{"command":"bash tests/test-docs.sh","description":%s,"timeout":%s}}' \
            "$HOLD_TOOL" "$HOOK_CWD_JSON" "$desc_json" "$2"
    fi
    # stderr captured, stdout discarded — an exit code cannot tell a refusal that carries
    # its remedy from one that just says no, and the remedy IS the behaviour under test.
    out=$(printf '%s' "$payload" | HOME="$HOOK_HOME" PATH="$HOOK_PATH" "$BASH_BIN" "$HOLD_HOOK" 2>&1 >/dev/null) || got=$?
    ran=$((ran + 1))
    if [ "$got" != "$4" ]; then
        printf '  FAIL [%s/%s] exit=%s want=%s  timeout=%s desc=%s\n' "$HOLD_TOOL" "$1" "$got" "$4" "$2" "$3"
        printf '       message was: %s\n' "$out"
        fail=$((fail + 1))
    elif [ -n "${5-}" ] && [ "${out#*"$5"}" = "$out" ]; then
        printf '  FAIL [%s/%s] exit=%s (correct) but the message never named %s\n' "$HOLD_TOOL" "$1" "$got" "$5"
        printf '       message was: %s\n' "$out"
        fail=$((fail + 1))
    elif [ -n "${5-}" ]; then
        printf '  ok   [%s/%s] timeout=%s — refusal names %s\n' "$HOLD_TOOL" "$1" "$2" "$5"
    else
        printf '  ok   [%s/%s] timeout=%s\n' "$HOLD_TOOL" "$1" "$2"
    fi
}

echo "block-dangerous-git.sh — must BLOCK (exit 2)"
run $GIT_HOOK Bash       "git push origin master"                          2
run $GIT_HOOK Bash       "git push --force"                                2
run $GIT_HOOK Bash       "cd /tmp && git push"                             2
run $GIT_HOOK Bash       "git reset --hard origin/main"                    2
run $GIT_HOOK Bash       "git clean -fd"                                   2
run $GIT_HOOK Bash       "git branch -D feature"                           2
# `-D` is one of EIGHT spellings git accepts for the same destructive operation, and for
# a long time it was the only one blocked — measured, seven of these sailed through (#115).
# A guardrail that stops one spelling of eight is not a guardrail, and nothing in a green
# run said so, because no case here had ever asked.
run $GIT_HOOK Bash       "git branch --delete --force feature"             2
run $GIT_HOOK Bash       "git branch --force --delete feature"             2
run $GIT_HOOK Bash       "git branch -d --force feature"                   2
run $GIT_HOOK Bash       "git branch -fd feature"                          2
run $GIT_HOOK Bash       "git branch -df feature"                          2
# --force on git branch MOVES a ref over existing history. Destructive without deleting.
run $GIT_HOOK Bash       "git branch -f main origin/other"                 2
run $GIT_HOOK Bash       "git branch --force main origin/other"            2
run $GIT_HOOK Bash       "git commit --no-verify -m x"                     2
run $GIT_HOOK Bash       "git add -A"                                      2
# PowerShell is a SEPARATE tool from Bash and populates the same tool_input.command.
run $GIT_HOOK PowerShell "git push origin master"                          2
run $GIT_HOOK PowerShell "git reset --hard origin/main"                    2
run $GIT_HOOK PowerShell "& git push origin main"                          2
# Multi-line: every line is its own command. These evaded until newlines became ';'.
run $GIT_HOOK Bash       "git add -p
git commit -m x
git push origin main"                                                      2
run $GIT_HOOK PowerShell "git status
git push"                                                                  2
run $GIT_HOOK Bash       "git add .
git commit -m x"                                                           2
run $GIT_HOOK Bash       "$(printf 'git status\r\ngit push')"              2
# Q3 — `%(refname)` splits at '(' / ')' during tokenizing (measured fail-open, risk R2):
# the stripped placeholder must not swallow the force-delete flag that follows it.
run $GIT_HOOK Bash       "git branch --format=%(refname) -D feature"              2
# Exact-equality on --force would silently stop blocking a real force flag once ported —
# guard against that regression directly.
run $GIT_HOOK Bash       "git push --force-with-lease"                            2
# --no-verify/--no-gpg-sign are deliberately NOT git-scoped (Q2): they stay raw-text
# greps so the guard still covers non-git commands. No `git` appears in this payload —
# that absence is the point.
run $GIT_HOOK Bash       "npm publish --no-verify"                                2
# A command we cannot tokenise is a BLOCK, for the same reason an unreadable payload is:
# the hook did not find out what it was being asked to do, so it does not allow it.
run $GIT_HOOK Bash       "git push 'unterminated"                                 2

# --- The command is not always the first word (#117 re-pass) ----------------------
# Every case below was BLOCKED by the text scan this hook replaces and ALLOWED by the
# first cut of the tokenizer, which required word 0 of a segment to be `git` and gave up
# otherwise. Measured against both hooks, not read off a diff. They are here because the
# four must-BLOCK cases added in the first pass were all ALREADY GREEN on master: they
# asserted the old grep, not the new code, and this whole class went untested while the
# suite stayed green.
#
# A wrapper carries the command:
run $GIT_HOOK Bash       "sudo git push --force"                                  2
run $GIT_HOOK Bash       "env git branch -D x"                                    2
run $GIT_HOOK Bash       "time git push --force"                                  2
run $GIT_HOOK Bash       "command git push --force"                               2
run $GIT_HOOK Bash       "sudo env git branch -D x"                               2
# xargs, and the canonical delete-merged-branches idiom. CLAUDE.md forbids deleting a
# branch unasked, so this is the shape that must not be allowed to slip.
run $GIT_HOOK Bash       "xargs -n1 git push --force"                             2
run $GIT_HOOK Bash       "git branch --merged | xargs git branch -D"              2
run $GIT_HOOK Bash       "git branch --format='%(refname:short)' --merged | xargs git branch -D"  2
# A shell keyword leads the segment after the separator. Single-quoted on purpose: the
# `$b` and the backticks below must reach the hook as literal text, exactly as the harness
# would deliver them, so no expansion may happen here.
run $GIT_HOOK Bash       "if true; then git branch -D f; fi"                      2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'for b in a b; do git branch -D $b; done'                2
# Backticks are command substitution. shlex does not know that, so without an explicit
# separator the whole span is ONE token whose basename is not `git`.
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'echo `git branch -D f`'                                 2
# The percent-paren strip must not run out of one command and into the next. With an
# unbounded span these collapsed to `echo %` and the git command in the middle vanished.
run $GIT_HOOK Bash       "echo '%(' ; git branch -D feature ; echo ')'"           2
run $GIT_HOOK Bash       "echo '%(' && git push --force && echo ')'"              2
# A literal `git` as an ARGUMENT VALUE must not eat the scan. The tokenizer judges EVERY
# git occurrence in a segment, not the first: in the first case below the first `git` is
# the value of `-u`, so `git` became the "subcommand" and the real command was never
# judged. All three measured 0 at 94d7d66 and 2 on the text scan this hook replaces.
run $GIT_HOOK Bash       "sudo -u git git push --force"                          2
run $GIT_HOOK Bash       "sudo -u git git branch -D feature"                     2
run $GIT_HOOK Bash       "docker run --user git img git push --force"            2

# --- A line continuation is ONE command, not two (#117 re-review) -----------------
# Turning every newline into a segment separator split a continued command in half, and
# the flag landed in a segment nothing judged. Measured 0 at 94d7d66, 2 on master.
#
# SINGLE-QUOTED on purpose, and this is the trap the shape sets: in a DOUBLE-quoted case
# the continuation is eaten by THIS script's own shell, the hook is handed the one-line
# command, it blocks, and the case goes green having tested the control instead of the
# shape it was written for.
#
# `git push` is NOT here — see the allowlisted section at the bottom. Unlisted, the
# orphaned bare `git push` is still caught by the plain-push rule, so a push case here
# would pass at 94d7d66 too and prove nothing.
run $GIT_HOOK Bash       'git branch \
-D f'                                                                            2
run $GIT_HOOK Bash       'git reset \
--hard HEAD~1'                                                                   2
run $GIT_HOOK Bash       'git clean \
-fd'                                                                             2
run $GIT_HOOK Bash       'git add \
-A'                                                                              2
# PowerShell continues a line with a BACKTICK, and PowerShell is a wired matcher. The same
# bytes mean different things in the two shells, so each shell gets its own case.
# shellcheck disable=SC2016
run $GIT_HOOK PowerShell 'git branch `
-D f'                                                                            2

# --- The SAME continuations, with a CRLF line ending (#117 third re-review) --------
# The cases above are LF-only, and the join they assert was defeated by a CRLF payload:
# parse() wrote its output in TEXT mode, which doubled the CR; python then read those
# three bytes back as TWO newlines, the join ate one, and the flag was orphaned again. Every
# LF case above stayed green through all of it — LF-only coverage is what let it ship.
# Built with printf, exactly like the CRLF payload in the must-BLOCK section above
# (`"$(printf 'git status\r\ngit push')"`): this suite already conceded
# that a CRLF payload is a real shape, so the omission was the continuation, not the shape.
# CRLF is what a Windows editor produces by default, and this repo is Windows-primary.
run $GIT_HOOK Bash       "$(printf 'git branch \\\r\n-D f')"                     2
run $GIT_HOOK Bash       "$(printf 'git reset \\\r\n--hard HEAD~1')"             2
run $GIT_HOOK Bash       "$(printf 'git clean \\\r\n-fd')"                       2
run $GIT_HOOK Bash       "$(printf 'git add \\\r\n-A')"                          2
# shellcheck disable=SC2016
run $GIT_HOOK PowerShell "$(printf 'git branch `\r\n-D f')"                      2
# The twin of the must-ALLOW unicode cases below: a payload can carry a character outside
# the machine ANSI codepage AND be a real force push. Fixing the false positive must not
# turn this one into an allow.
run $GIT_HOOK Bash       "$(printf 'git push --force # \344\275\240\345\245\275')" 2

# --- A backslash before the hyphen is not a path (#117 fifth re-review) ------------
# lex.escape is "" so the tokenizer keeps a backslash LITERAL — deliberate, and a Windows
# path depends on it (the must-ALLOW twins are further down). But bash removes that
# backslash before git runs, so the flag was filed as kind=path and every rule is gated on
# kind=opt. Measured with a git shim on PATH: bash really ran `add -A`, `reset --hard` and
# `clean -fd`. These three were 0 in BOTH allowlist states on master AND at 23eb109, so they
# are a TIGHTENING this fix brings with it rather than a regression it repairs — red at
# 23eb109 either way. NOT allowlist-scoped: `git add -A` is one nothing can unlock.
# SINGLE-QUOTED on purpose, or the backslash never reaches the hook.
run $GIT_HOOK Bash       'git add \-A'                                           2
run $GIT_HOOK Bash       'git reset \--hard HEAD~1'                              2
run $GIT_HOOK Bash       'git clean \-fd'                                        2

# --- The forward scan is a TRADE, and both directions are recorded here ------------
# Scanning forward for the git program means an UNQUOTED mention is judged as a command.
# These four were ALLOWED by the text scan this hook replaces — its plain-push rule was
# the one ANCHORED pattern in the file — and are BLOCKED now. They are genuine FALSE
# POSITIVES on harmless commands, and they are the price paid for the tightenings below.
# Green before this re-review and after it: they record the cost, they prove no fix.
# A QUOTED mention still passes, which is the must-ALLOW section further down.
run $GIT_HOOK Bash       "man git push"                                          2
run $GIT_HOOK Bash       "type git push"                                         2
run $GIT_HOOK Bash       "apropos git push"                                      2
run $GIT_HOOK Bash       "echo git push origin main"                             2
# The other side of the same trade: real dangerous commands the text scan let through,
# because its regexes demanded `git` and the verb be adjacent. All four were 0 on master.
run $GIT_HOOK Bash       "git -C /tmp/repo branch -D f"                          2
run $GIT_HOOK Bash       "git --no-pager branch -D f"                            2
run $GIT_HOOK Bash       "git.exe push --force"                                  2
run $GIT_HOOK Bash       '"git" push --force'                                    2

# --- A heredoc line is not only a heredoc (#117 fourth re-review) ------------------
# strip_heredocs() truncated the line AT the operator and threw the rest away. In bash the
# BODY starts on the next line, so whatever follows the operator on this one is a real
# command — measured with a git shim on PATH that records the argv bash actually passed,
# and every one of these ran. All were 2 on the text scan this hook replaces.
#
# This class is NOT allowlist-scoped, which is why it lives here in the unlisted section:
# `git add -A` and `git add .` returned 0 in BOTH states, and those two are the ones
# repo-allowlist.sample says nothing can unlock. Every heredoc case written before this
# pass put the operator LAST on its line, where the discarded remainder is empty — which is
# how four passes and 199 green cases went by without one of them asking.
run $GIT_HOOK Bash       "cat <<EOF ; git branch -D feature
body
EOF"                                                                              2
run $GIT_HOOK Bash       "cat <<EOF > n.txt && git add -A
body
EOF"                                                                              2
run $GIT_HOOK Bash       "cat <<EOF ; git add .
body
EOF"                                                                              2
run $GIT_HOOK Bash       "cat <<EOF ; git reset --hard HEAD~1
body
EOF"                                                                              2
run $GIT_HOOK Bash       "cat <<EOF ; git clean -fd
body
EOF"                                                                              2
run $GIT_HOOK Bash       "cat <<EOF ; git push --force
body
EOF"                                                                              2
run $GIT_HOOK Bash       "read x <<EOF ; git branch -D feature
body
EOF"                                                                              2
# The quoted-terminator and tab-indent spellings take the same path and must not be a
# second way in, and a pipe before the separator must not hide it either.
run $GIT_HOOK Bash       "cat <<'EOF' ; git branch -D feature
body
EOF"                                                                              2
run $GIT_HOOK Bash       "cat <<-EOF ; git branch -D feature
body
EOF"                                                                              2
run $GIT_HOOK Bash       "cat <<EOF | grep x ; git add -A
body
EOF"                                                                              2

# --- A <<WORD that is not a heredoc must not blind the rest of the payload ---------
# The heredoc regex fires on <<WORD ANYWHERE on the line — inside a # comment, inside a
# quoted string, in prose — and the old loop then discarded every following line until one
# equalled the terminator. When the terminator never comes, that is the whole rest of the
# command, judged by nothing. Both states, all shim-confirmed as really running.
#
# An unterminated heredoc is a shape bash itself refuses to run, so refusing to swallow
# here cannot cost a real false positive — the must-ALLOW twin two sections down proves the
# ordinary comment case still passes.
run $GIT_HOOK Bash       "git status   # the notes use <<EOF below
git add -A"                                                                       2
run $GIT_HOOK Bash       "npm test  # see the <<PY note
git push --force"                                                                 2
run $GIT_HOOK Bash       "# build the file with <<EOF
git reset --hard HEAD~1"                                                          2
run $GIT_HOOK Bash       "# use <<'EOF' to stop expansion
git clean -fd"                                                                    2

# --- The six shapes that used to block BY ACCIDENT --------------------------------
# These were green before this pass and are green after it, and they are the point of the
# section. At 84ae124 they blocked for the wrong reason: truncating at the operator cut the
# quoted mention in half, shlex raised ValueError and the hook exited 3 — fail-closed by
# accident. The obvious one-line repair of the truncation above REPAIRS THE QUOTE TOO, and
# all six then walk into the swallow and return 0 in both states. That fix was measured and
# rejected for exactly this: an accidental fail-closed becoming a deliberate fail-open.
# They are here so a future refactor of strip_heredocs cannot make that trade silently.
run $GIT_HOOK Bash       "echo \"use <<EOF for multiline\"
git push --force"                                                                 2
run $GIT_HOOK Bash       "echo \"see <<EOF\"
git add -A"                                                                       2
run $GIT_HOOK Bash       "echo \"the <<PY idiom\"
git reset --hard HEAD~1"                                                          2
run $GIT_HOOK Bash       "echo \"docs mention <<-EOF here\"
git clean -fd"                                                                    2
# A C++ stream shift reads as a heredoc operator to that regex, and this one is not
# hypothetical: it is what someone reviewing this hook types.
run $GIT_HOOK Bash       "grep -n \"cout << endl\" a.cpp
git branch -D feature"                                                            2
run $GIT_HOOK Bash       "grep -n \"<<'PY'\" install.sh
git push --force"                                                                 2

echo "block-dangerous-git.sh — the git word itself is built by the shell"
# Two shapes the raw "is there a git in this text" pre-filter misses. A construct INSIDE
# the word means no `git` appears in the text at all, so the tokenizer never runs. A
# construct that expands to WHITESPACE gets past the pre-filter, but shlex reads
# git${IFS}push as one glued word whose basename is not git, so no rule is ever offered it.
# Single-quoted, or this script's own shell eats the dollar and the case tests nothing.
run $GIT_HOOK Bash       'g""it push --force'                                     2
run $GIT_HOOK Bash       "g\$''it push --force"                                   2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'git${IFS}push --force'                                  2
run $GIT_HOOK Bash       "x=' '; git\${x}push --force"                            2
# A span GLUED to the program word, or to the verb. Each expands to nothing, so bash runs
# git push --force either way — but shlex keeps the span inside the token, and neither the
# basename nor the subcommand it hands back is the word a rule is keyed on.
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'git${x} push --force'                                   2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'git push${x} --force'                                   2
run $GIT_HOOK Bash       "git pu\$''sh --force"                                   2
# The line those two are drawn either side of, and the one thing here that must stay 0:
# empty quotes GLUE, so bash runs the single word `gitpush` and no git command exists. Only
# a whitespace-valued expansion SPLITS.
run $GIT_HOOK Bash       'git""push --force'                                      0

echo "block-dangerous-git.sh — must ALLOW (exit 0)"
run $GIT_HOOK Bash       "git status"                                      0
run $GIT_HOOK Bash       "git log --oneline -5"                            0
# The pair above at :112 is only half a test. `-d` REFUSES an unmerged branch and `-D`
# throws it away, so blocking both is not "cautious" — it stops the safe form and then
# reports the dangerous one, which is what #115 hit. A pattern asserted only in the
# blocking direction cannot tell you it blocks too much; this is the other direction.
run $GIT_HOOK Bash       "git branch -d merged-feature"                    0
run $GIT_HOOK Bash       "git branch --delete merged-feature"              0
# The force pattern keys on a SHORT cluster containing D or f. These three prove it does
# not spill onto the long options and the harmless short ones — `--format` in particular
# begins with an f one character after a dash, which a looser pattern would swallow.
run $GIT_HOOK Bash       "git branch --format=%(refname)"                  0
run $GIT_HOOK Bash       "git branch -a"                                   0
run $GIT_HOOK Bash       "git branch -m oldname newname"                   0
run $GIT_HOOK PowerShell "Get-ChildItem"                                   0
run $GIT_HOOK Bash       "git add src/main.py
git commit -m 'x'"                                                         0
run $GIT_HOOK Bash       "npm test
npm run build"                                                             0
# A character OUTSIDE the machine ANSI codepage. parse() used to write its output in text
# mode, which encodes with that codepage, so this raised UnicodeEncodeError; `2>/dev/null`
# ate the traceback and `|| block` reported "the payload did not parse as JSON" — a false
# positive carrying a false diagnostic, in the hook that exists to remove false positives.
# It was invisible for as long as it was because no payload in this suite held a non-ANSI
# byte. Written with printf octal escapes so the bytes are UTF-8 whatever wrote this file.
run $GIT_HOOK Bash       "$(printf 'echo \344\275\240\345\245\275')"       0
run $GIT_HOOK Bash       "$(printf 'git commit -m \344\275\240\345\245\275')" 0

# The direction the fix above must NOT move. A backslash is a Windows path separator here,
# which is the whole reason lex.escape is empty, and deb() reads through it for the OPTION
# decision only — a path word is still emitted exactly as it was written. None of these is
# an option, and all four were 0 before the escape-aware option test and are 0 after it.
run $GIT_HOOK PowerShell 'git add C:\Users\kmala\notes\release.md'         0
run $GIT_HOOK Bash       'git add ..\docs\a.md'                            0
run $GIT_HOOK PowerShell 'git commit -F C:\tmp\msg.txt'                    0
run $GIT_HOOK Bash       'git checkout -- src\a.cs'                        0

echo "block-dangerous-git.sh — must ALLOW (exit 0), the mention is not the act"
# The five false positives from issue #117 — measured exit=2 want=0 on master before this
# fix landed. A guard that reads command TEXT instead of command ARGUMENTS blocks any of
# these, because the dangerous string merely appears in the payload.
run $GIT_HOOK Bash       "echo \"never run git push --force here\""                    0
run $GIT_HOOK Bash       "git commit -m \"document why git add -A is banned\""          0
run $GIT_HOOK Bash       "grep -rn \"git branch -D\" docs/"                             0
run $GIT_HOOK Bash       "printf \"%s\" \"git branch -D feature\" > case.txt"           0
run $GIT_HOOK Bash       "cat > note.md <<'EOF'
Do not use git push --force on this repo.
EOF"                                                                                    0
# A commit message that names the flag it explains is prose, not the act — the same shape
# that blocked writing this ticket's own grilling notes (.claude/handoffs/117/grilling.md).
run $GIT_HOOK Bash       "git commit -m 'explain why git branch -D is dangerous'"       0
# A heredoc body is DATA, not a command — the same push line as a REAL command still
# blocks (`run $GIT_HOOK Bash "git push origin master" 2`, in the must-BLOCK section);
# only the heredoc form is data.
run $GIT_HOOK Bash       "cat > note.md <<'EOF'
git push origin main
EOF"                                                                                    0
# The other direction of the two heredoc fixes above, and the reason they cost no false
# positives. Keeping the rest of the operator line must not invent a command where there is
# none, and refusing to swallow an UNTERMINATED heredoc must not turn an ordinary comment
# that mentions one into a block.
run $GIT_HOOK Bash       "cat <<EOF ; echo done
body
EOF"                                                                                    0
run $GIT_HOOK Bash       "# the <<EOF form
git status"                                                                             0
run $GIT_HOOK Bash       "echo \"a << EOF b\" ; echo done"                              0
# The repo's own house style for a multi-line python program — install.sh and
# tests/test-docs.sh both write it, with a redirection after the operator, which is the
# same syntactic slot the fix above stopped discarding.
run $GIT_HOOK Bash       "python - <<'PY' > out.txt
print(1)
PY"                                                                                     0
# Backticks became segment separators in the #117 re-pass so `` `git branch -D f` `` cannot
# hide a command. This is the other direction: a backtick inside a QUOTED argument is still
# prose. Green before that change and after it — it records the boundary, it does not prove
# the fix. (The blocking half is in the must-BLOCK section above.)
run $GIT_HOOK Bash       "git commit -m 'use \`git branch -D\` only when asked'"        0
# The rules are case-SENSITIVE on long options, where the text greps they replace folded
# case. Recorded here as a decision rather than left in a handoff: git's own parser is
# case-sensitive, so `--HARD` is not a command git would run — it exits 129, unknown
# option. Green before the re-pass and after it; these assert the narrowing is intended.
run $GIT_HOOK Bash       "git reset --HARD origin/main"                                 0
run $GIT_HOOK Bash       "git branch --Force x"                                         0
run $GIT_HOOK Bash       "git clean --FORCE"                                            0

echo "block-dangerous-git.sh — must BLOCK (exit 2), a git command nested in another command"
# The git command is DATA inside another command, or a substitution inside double quotes:
# one token at the top level, so only the nested views see it.
run $GIT_HOOK Bash       'bash -c "git push --force"'                                   2
run $GIT_HOOK Bash       "sh -c 'git reset --hard HEAD~1'"                              2
run $GIT_HOOK Bash       "eval 'git push --force'"                                      2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'echo "$(git branch -D f)"'                                    2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       '$(git push --force)'                                          2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'echo `git push --force`'                                      2

echo "block-dangerous-git.sh — must BLOCK (exit 2), a false heredoc with a coincidental terminator"
# The <<EOF is inside quotes, so bash sees no heredoc; the EOF line alone later must not
# turn the force push between them into a body.
run $GIT_HOOK Bash       "echo \"use <<EOF now\"
git push --force
EOF
git status"                                                                             2

echo "block-dangerous-git.sh — must BLOCK (exit 2), more wrappers around a nested git command"
run $GIT_HOOK Bash       'pwsh -c "git push --force"'                                   2
run $GIT_HOOK Bash       "ssh host 'git push --force'"                                  2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'x="$(git push --force)"'                                      2
run $GIT_HOOK Bash       "zsh -c 'git push --force'"                                    2
run $GIT_HOOK Bash       "xargs sh -c 'git push --force'"                               2
# The echo before the pipe does not exempt the shell after it.
run $GIT_HOOK Bash       'echo x | bash -c "git push --force"'                          2
# Text piped out of echo or printf may be run by the next command, so it is judged.
run $GIT_HOOK Bash       'echo "git push --force" | bash'                               2
run $GIT_HOOK Bash       'printf "%s" "git push --force" | sh'                          2
# rg --pre runs a command, so its arguments are judged.
run $GIT_HOOK Bash       'rg --pre "git push --force" x'                                2
run $GIT_HOOK Bash       'rg --pre="git push --force" x'                                2
# A heredoc word ends where bash ends it: EOF-1 is not EOF, so the EOF line ends no body.
run $GIT_HOOK Bash       "cat <<EOF-1
git push --force
EOF"                                                                                    2
# A bare here-string (<<<EOF) opens no heredoc, so the force push after it is judged.
run $GIT_HOOK Bash       "cat <<<EOF
git push --force
EOF
git status"                                                                             2
# Nesting deeper than the tokenizer follows is refused, whatever the innermost command.
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'echo $(echo $(echo $(echo $(echo $(git status)))))'           2

echo "block-dangerous-git.sh — must ALLOW (exit 0), where the nested views stop"
# A commit message is not read as a command, even when it names one.
run $GIT_HOOK Bash       "git commit -m \"bash -c git push --force\""                   0
# Nor is an argument of a command that never runs its arguments (echo, printf, grep, rg, gh).
run $GIT_HOOK Bash       "gh issue create --body \"run git push --force later\""       0
run $GIT_HOOK Bash       "grep -n \"git add -A\" file"                                  0
run $GIT_HOOK Bash       'echo "git push --force"'                                      0
run $GIT_HOOK Bash       'rg "git push --force" docs/'                                  0
# An inner string shlex refuses (the apostrophe) is still split and judged, not refused.
run $GIT_HOOK Bash       "bash -c \"echo it's fine; git status\""                       0
# Four levels deep is inside the limit.
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'echo $(echo $(echo $(echo $(git status))))'                   0
# A closed heredoc body is data.
run $GIT_HOOK Bash       "cat <<'EOF'
git push --force
EOF"                                                                                     0

echo "block-dangerous-git.sh — the allowlist, listed repo"
HOOK_HOME="$ALLOW_HOME"
run $GIT_HOOK Bash       "git push origin master"                          0
run $GIT_HOOK PowerShell "git push"                                        0
# Allowlisted for push is not allowlisted for everything: force and the sweep still go.
run $GIT_HOOK Bash       "git push --force"                                2
run $GIT_HOOK Bash       "git add -A"                                      2
run $GIT_HOOK Bash       "git reset --hard origin/main"                    2
# A line continuation must not orphan the force flag, and THIS is the only state where
# that regressed: unlisted, the leftover bare `git push` is caught by the plain-push rule
# and the call exits 2 anyway, so the same case there would go green against nothing.
# Allowlisted, it returned 0 at 94d7d66 and the force push ran. Single-quoted on purpose
# — a double-quoted case is a continuation to this script's own shell, not to the hook.
run $GIT_HOOK Bash       'git push \
--force'                                                                   2
run $GIT_HOOK Bash       'git push \
--force-with-lease'                                                        2
# shellcheck disable=SC2016
run $GIT_HOOK PowerShell 'git push `
--force'                                                                   2
# And the same three with a CRLF line ending — the shapes that still ran at 6fc17b4, when
# the three LF cases above were already green. Here, and only here, they were 0 and the
# force push went to the remote. Same reason as the LF trio for living in this section.
run $GIT_HOOK Bash       "$(printf 'git push \\\r\n--force')"              2
run $GIT_HOOK Bash       "$(printf 'git push \\\r\n--force-with-lease')"   2
# shellcheck disable=SC2016
run $GIT_HOOK PowerShell "$(printf 'git push `\r\n--force')"               2
# A CRLF chain in front of the continuation: the newline that separates two commands and
# the newline inside a continuation are the same two bytes, and only one of them splits.
run $GIT_HOOK Bash       "$(printf 'echo a\r\ngit push \\\r\n--force')"    2
# A DOUBLED line ending, which is the same bug through a different door. The payload is
# read with universal newlines, where a lone \r is a line ending too, so \r\r\n, \n\r and
# \r\r each arrive as TWO newlines — a single-\n join eats one and the survivor orphans the
# flag exactly as no join at all did. parse() was fixed to stop MANUFACTURING that
# doubling; these assert the join survives one that arrives in the payload. Measured 0 here
# at 84ae124 with all four cases above already green.
run $GIT_HOOK Bash       "$(printf 'git push \\\r\r\n--force')"            2
run $GIT_HOOK Bash       "$(printf 'git push \\\n\r--force')"              2
run $GIT_HOOK Bash       "$(printf 'git push \\\r\r--force')"              2
# shellcheck disable=SC2016
run $GIT_HOOK PowerShell "$(printf 'git push `\r\r\n--force')"             2
# THE FIFTH FAIL-OPEN CLASS, and the only allowlist state it lives in. lex.escape is ""
# so a backslash stays literal and a Windows path survives — but bash strips it before git
# runs, so an escaped flag arrived as a token that did not start with a hyphen, was filed
# as kind=path, and every rule below is gated on kind=opt. No rule ever looked at it. A
# git shim on PATH recorded bash passing the real flag to git while the hook returned 0.
# Unlisted, the leftover bare `git push` is caught by the plain-push rule and the call
# exits 2 anyway, so these four would go green against nothing there — the same trap as
# the continuation cases above. Allowlisted, push is permitted by design and stopping the
# force flag is the whole job that rule has left. All four measured 0 here at 23eb109 with
# every case above already green. Single-quoted, or the backslash never reaches the hook.
run $GIT_HOOK Bash       'git push \--force'                               2
run $GIT_HOOK Bash       'git push \-f'                                    2
run $GIT_HOOK Bash       'git push \--force-with-lease'                    2
# Not an evasion trick: $'...' is ordinary ANSI-C quoting anyone may type, and shlex
# leaves the dollar sign glued to the front of the word where bash does not pass it on.
run $GIT_HOOK Bash       "git push \$'--force'"                            2
# The shell-built git word again, and this is the state where the answer is load-bearing.
# Unlisted, the plain-push rule blocks every one of them on the bare `git push` alone, so
# they would go green there without the force flag ever being judged. Allowlisted, push is
# permitted and the force flag is the whole remaining job.
run $GIT_HOOK Bash       'g""it push --force'                              2
run $GIT_HOOK Bash       "g\$''it push --force"                            2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'git${IFS}push --force'                           2
run $GIT_HOOK Bash       "x=' '; git\${x}push --force"                     2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'git${x} push --force'                            2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'git push${x} --force'                            2
run $GIT_HOOK Bash       "git pu\$''sh --force"                            2
run $GIT_HOOK Bash       'git""push --force'                               0
HOOK_HOME="$DENY_HOME"

echo "block-infra-staging.sh — must BLOCK (exit 2), repo not listed"
run $INFRA_HOOK Bash     "git add CLAUDE.md"                               2
run $INFRA_HOOK Bash     "git add .claude/settings.json"                   2
run $INFRA_HOOK Bash     "git add .serena/project.yml"                     2
run $INFRA_HOOK Bash     "git add -A"                                      2
run $INFRA_HOOK Bash     "git status
git add CLAUDE.md"                                                         2
run $INFRA_HOOK Bash     "git add .
git commit -m x"                                                           2

echo "block-infra-staging.sh — the git word itself is built by the shell"
# Same two shapes as in the git hook: a construct inside the word keeps `git` out of the
# text the pre-filter reads, and a whitespace-valued expansion splits the word for bash
# while shlex keeps it glued. Single-quoted, or the dollar never reaches the hook.
run $INFRA_HOOK Bash     'g""it add -A'                                    2
run $INFRA_HOOK Bash     "g\$''it add -A"                                  2
# shellcheck disable=SC2016
run $INFRA_HOOK Bash     'git${IFS}add -A'                                 2
# A span GLUED to the program word, or to the verb. Each expands to nothing, so bash runs
# git add either way — but shlex keeps the span inside the token, and neither the basename
# nor the subcommand it hands back is a word this hook is keyed on.
# shellcheck disable=SC2016
run $INFRA_HOOK Bash     'git${x} add -A'                                  2
# shellcheck disable=SC2016
run $INFRA_HOOK Bash     'git add${x} -A'                                  2
run $INFRA_HOOK Bash     "git add\$'' -A"                                  2
# shellcheck disable=SC2016
run $INFRA_HOOK Bash     'git${x} add .claude/settings.json'               2
# Empty quotes glue: `gitadd -A` stages nothing.
run $INFRA_HOOK Bash     'git""add -A'                                     0

echo "block-infra-staging.sh — both sides of the .claude/ line"
# These do not depend on the allowlist: agents/ and skills/ are product files anywhere.
run $INFRA_HOOK Bash     "git add .claude/agents/backend.md"               0
run $INFRA_HOOK Bash     "git add .claude/skills/backend-standards/SKILL.md" 0
run $INFRA_HOOK PowerShell "git add .claude\\agents\\backend.md"           0
run $INFRA_HOOK Bash     "git add .claude/dependency-graph.html"           2
run $INFRA_HOOK Bash     "git add .claude/handoffs/T-1/planner.md"         2
run $INFRA_HOOK Bash     "git add .claude"                                 2
run $INFRA_HOOK Bash     "git add .claude/"                                2
run $INFRA_HOOK PowerShell "git add .claude\\dependency-graph.html"        2
# One allowed path does not license the ones beside it.
run $INFRA_HOOK Bash     "git add .claude/agents/backend.md .claude/dependency-graph.html" 2

echo "block-infra-staging.sh — CLAUDE.md flips, listed repo"
HOOK_HOME="$ALLOW_HOME"
run $INFRA_HOOK Bash     "git add CLAUDE.md"                               0
run $INFRA_HOOK Bash     "git add CLAUDE.md .claude/agents/backend.md"     0
# Still blocked on a listed repo: the flip is one path, not an amnesty.
run $INFRA_HOOK Bash     "git add MEMORY.md"                               2
run $INFRA_HOOK Bash     "git add .serena/project.yml"                     2
run $INFRA_HOOK Bash     "git add .claude/dependency-graph.html"           2
run $INFRA_HOOK Bash     "git add -A"                                      2
HOOK_HOME="$DENY_HOME"

echo "block-infra-staging.sh — the two answers are independent"
# github.com/example/push-only says push yes, own-claude-md NO.
HOOK_HOME="$ALLOW_HOME"
git -C "$REPO" remote set-url origin https://github.com/example/push-only.git 2>/dev/null
run $GIT_HOOK   Bash     "git push origin main"                            0
run $INFRA_HOOK Bash     "git add CLAUDE.md"                               2
git -C "$REPO" remote set-url origin https://github.com/example/allowed-repo.git 2>/dev/null
HOOK_HOME="$DENY_HOME"

echo "block-infra-staging.sh — a never-stage name counts only at a path boundary"
# The hook matches the three never-stage names against the COMMAND TEXT. While those
# patterns were bare substrings, ANY path whose basename merely CONTAINED one was refused —
# including this repo's own templates/commands/garden-memory.md, which is a tracked file
# and was unstageable for as long as the pattern was unanchored. The suite was green the
# whole time, because the only case it ever asserted was the true positive. Same shape as
# the finding in issue #29: the direction nobody ran is the direction that breaks.
#
# So: one case per name, in BOTH directions. The true positives come first, because an
# anchor loose enough to let the real thing through is the failure that actually costs
# something.
run $INFRA_HOOK Bash     "git add MEMORY.md"                               2
run $INFRA_HOOK Bash     "git add docs/MEMORY.md"                          2
run $INFRA_HOOK Bash     "git add .forgetful/index.json"                   2
run $INFRA_HOOK Bash     "git add .serena"                                 2
run $INFRA_HOOK PowerShell "git add .serena\\project.yml"                  2
# -i STAYS, and this is the case that says so. Windows resolves .Serena and .serena to one
# directory, so a different spelling of the real infra dir must not become a way through.
run $INFRA_HOOK Bash     "git add .Serena/project.yml"                     2

# ...and a path that merely CONTAINS a name goes through. These are the cases that were
# never written, and every one of them was a false BLOCK.
run $INFRA_HOOK Bash     "git add templates/commands/garden-memory.md"     0
run $INFRA_HOOK Bash     "git add src/inmemory.md"                         0
# .serenade, not .serenity — `.serenity` is `.seren`+`ity` and never contained the name at
# all, so it passed before the anchor existed. A case that is green either way proves the
# token is covered when it is not.
run $INFRA_HOOK Bash     "git add docs/api.serenade.md"                    0
run $INFRA_HOOK Bash     "git add notes.forgetfulness.md"                  0
# The uppercase variant goes the SAME way as the lowercase one, and that is the point of
# keeping -i: the ANCHOR is what makes this file stageable, not the case of its letters.
run $INFRA_HOOK Bash     "git add garden-MEMORY.md"                        0

echo "block-infra-staging.sh — CLAUDE.md is a path too, not a substring"
# The allowlist flip had the identical unanchored defect, ten lines below the loop above.
# Unlisted repo, so the real file is still refused — but a name that merely ends in it is
# not the file the allowlist is being asked about.
run $INFRA_HOOK Bash     "git add CLAUDE.md"                               2
run $INFRA_HOOK Bash     "git add docs/about-claude.md"                    0
run $INFRA_HOOK Bash     "git add CLAUDE.md.bak"                           0

echo "block-infra-staging.sh — it stages, or it only MENTIONS: the arguments, not the text"
# The scan used to read the whole command as text, so a command that merely NAMED an infra
# path was refused as if it were staging one. Writing a note ABOUT this rule was blocked
# twice while #112 was being fixed, once in the notes for #112 itself. Because a compound
# command dies whole, anything chained in FRONT of the mention never ran either, and the
# failure read as if that first step was the problem.
#
# A name only counts when it is an ARGUMENT of git add / commit / stage.
run $INFRA_HOOK Bash     "git commit -m 'stop tracking MEMORY.md'"         0
run $INFRA_HOOK Bash     "git commit -m 'move .serena out of the repo'"    0
run $INFRA_HOOK Bash     "git add src/main.py && echo 'never commit MEMORY.md' >> notes.txt" 0
run $INFRA_HOOK Bash     "echo 'git add -A is blocked here'"               0
run $INFRA_HOOK Bash     "grep -r .forgetful docs/"                        0
run $INFRA_HOOK Bash     "grep -n \"git add -A\" file"                     0
# A heredoc body is DATA, not a command. A line inside one that starts with a stage verb is
# prose about staging — which is exactly what this repo's own docs are full of.
run $INFRA_HOOK Bash     "cat > notes.md <<'EOF'
git add .serena/project.yml
EOF"                                                                       0
run $INFRA_HOOK Bash     "git add docs/hooks.md && cat >> docs/hooks.md <<'EOF'
never stage MEMORY.md or .forgetful/index.json
EOF"                                                                       0

echo "block-infra-staging.sh — an ARGUMENT still blocks, wherever it sits"
run $INFRA_HOOK Bash     "git add docs/MEMORY.md && echo done"             2
run $INFRA_HOOK Bash     "echo starting; git add .serena/project.yml"      2
run $INFRA_HOOK Bash     "git commit MEMORY.md"                            2
run $INFRA_HOOK Bash     "git -C /tmp/repo add .serena/project.yml"        2
run $INFRA_HOOK Bash     "git add -- .forgetful/index.json"                2
# The FIRST of these is the Windows carriage-return case, and it needs two things at once
# that are easy to get wrong. On Windows a text-mode stdout turns the tokenizer's newlines
# into CR LF; the stray CR rides on the last field of every line EXCEPT the final one,
# which the command substitution strips. So the name must sit on a NON-FINAL line — hence
# an argument after it — AND be the LAST COMPONENT of its path, so the CR lands where the
# comparison looks. Measured against a hand-tampered hook: this case goes red.
run $INFRA_HOOK Bash     "git add MEMORY.md src/main.py"                   2
# The second does NOT catch that bug and is not claimed to: `.serena` is a middle component,
# so a CR after project.yml leaves the match intact. It is here for what it does prove —
# that a second git command in the same call is extracted, not just the first.
run $INFRA_HOOK Bash     "git add .serena/project.yml; git add src/main.py" 2
# The sweep is an argument too, and only on add: a commit message saying "-A" is not one.
run $INFRA_HOOK Bash     "git add -A && echo swept"                        2
run $INFRA_HOOK Bash     "git commit -m 'document git add -A'"             0
# A command we cannot tokenise is a BLOCK, for the same reason an unreadable payload is:
# the hook did not find out what it was being asked to clear, so it does not clear it.
run $INFRA_HOOK Bash     "git add 'unterminated"                           2

echo "block-infra-staging.sh — must ALLOW (exit 0)"
run $INFRA_HOOK Bash     "git add src/main.py"                             0
run $INFRA_HOOK Bash     "git commit -m 'docs: update readme'"             0
run $INFRA_HOOK Bash     "npm test"                                        0

echo "block-infra-staging.sh — must BLOCK (exit 2), a wrapped or nested git add"
# Seeing the git command does not depend on the allowlist, so each case runs in both states.
run $INFRA_HOOK Bash     "sudo git add -A"                                 2
run $INFRA_HOOK Bash     "git ls-files | xargs git add -A"                 2
run $INFRA_HOOK Bash     "if true; then git add -A; fi"                    2
run $INFRA_HOOK Bash     'bash -c "git add -A"'                            2
run $INFRA_HOOK Bash     'echo "git add -A" | bash'                        2
run $INFRA_HOOK Bash     'printf "git add -A" | sh'                        2
run $INFRA_HOOK Bash     'rg --pre "git add -A" x'                         2
run $INFRA_HOOK Bash     "cat <<EOF-1
git add -A
EOF"                                                                       2
# shellcheck disable=SC2016
run $INFRA_HOOK Bash     'echo "$( git add .claude/x )"'                   2
# A backtick span spanning a newline, glued to the path: the empty substitution leaves
# git add .claude/hooks/x.sh.
run $INFRA_HOOK Bash     "$(printf 'git add \140\n\140.claude/hooks/x.sh')" 2
# A here-string and a real heredoc on one line; the command after the body is judged.
run $INFRA_HOOK Bash     "cat <<< \"data\" <<EOF
body
EOF
git add -A"                                                                2
HOOK_HOME="$ALLOW_HOME"
run $INFRA_HOOK Bash     "sudo git add -A"                                 2
run $INFRA_HOOK Bash     "git ls-files | xargs git add -A"                 2
run $INFRA_HOOK Bash     "if true; then git add -A; fi"                    2
run $INFRA_HOOK Bash     'bash -c "git add -A"'                            2
run $INFRA_HOOK Bash     'echo "git add -A" | bash'                        2
run $INFRA_HOOK Bash     'printf "git add -A" | sh'                        2
run $INFRA_HOOK Bash     'rg --pre "git add -A" x'                         2
run $INFRA_HOOK Bash     "cat <<EOF-1
git add -A
EOF"                                                                       2
# shellcheck disable=SC2016
run $INFRA_HOOK Bash     'echo "$( git add .claude/x )"'                   2
run $INFRA_HOOK Bash     "$(printf 'git add \140\n\140.claude/hooks/x.sh')" 2
run $INFRA_HOOK Bash     "cat <<< \"data\" <<EOF
body
EOF
git add -A"                                                                2
HOOK_HOME="$DENY_HOME"

echo "block-secret-staging.sh — must BLOCK (exit 2)"
run $SECRET_HOOK Bash     "git add .env"                                   2
run $SECRET_HOOK Bash     "git add config/.env.production"                 2
run $SECRET_HOOK Bash     "git add certs/server.pem"                       2
run $SECRET_HOOK Bash     "git add ~/.ssh/id_rsa"                          2
run $SECRET_HOOK Bash     "git add service-account.json"                   2
run $SECRET_HOOK Bash     "git add .npmrc"                                 2
run $SECRET_HOOK PowerShell "git add .env"                                 2
run $SECRET_HOOK Bash     "git status
git add .env"                                                              2
# Literals go wherever they appear — a key on a command line has already leaked.
run $SECRET_HOOK Bash     "echo AKIAIOSFODNN7EXAMPLE > .env"               2
run $SECRET_HOOK PowerShell "\$k = 'ghp_0123456789abcdefghijklmnopqrstuvwx'" 2
# Every literal in the list gets a case, because the list is not checked uniformly: the
# PRIVATE KEY pattern is the one that starts with `-`, and grep read it as options and
# exited 2, which the caller's `if` treats as "no match". It failed open on the single
# most valuable credential a repo can leak while this suite ran green — the suite only
# ever exercised .pem by PATH, which the separate path rule catches. One case per pattern.
run $SECRET_HOOK Bash     "echo -----BEGIN RSA PRIVATE KEY----- > k.txt"   2
run $SECRET_HOOK Bash     "echo -----BEGIN OPENSSH PRIVATE KEY----- > k"   2
run $SECRET_HOOK Bash     "echo -----BEGIN PRIVATE KEY----- > k"           2
run $SECRET_HOOK Bash     "echo sk-0123456789abcdefghijklmnop"             2
run $SECRET_HOOK Bash     "echo github_pat_0123456789abcdefghijklmnop"     2
run $SECRET_HOOK Bash     "echo xoxb-0123456789abcdef"                     2
run $SECRET_HOOK Bash     "echo AIzaSyA0123456789abcdefghijklmnopqrstuvw"  2
run $SECRET_HOOK Bash     "git -C dir add .env"                            2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     '"$(git add .env)"'                              2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'echo `git add .env`'                            2
# A tab after the verb separates words in bash, as a space does.
run $SECRET_HOOK Bash     "$(printf 'git add\t.env.local')"                2
run $SECRET_HOOK Bash     "$(printf 'git commit\t-a id_rsa')"              2
# bash drops empty quotes, an empty expansion and a backslash-newline, so git still sees add.
run $SECRET_HOOK Bash     'git add"" .env'                                 2
run $SECRET_HOOK Bash     "git add\$'' .env"                               2
run $SECRET_HOOK Bash     "git add\${x} .env"                              2
run $SECRET_HOOK Bash     "git add\$(true) .env"                           2
run $SECRET_HOOK Bash     "$(printf 'git add\\\n .env')"                   2
run $SECRET_HOOK Bash     "$(printf 'git\tadd .env')"                      2
# The same constructs glued onto git, where the gap between git and the verb is all the
# hook has to go on. bash removes each one, so git is still the command word.
run $SECRET_HOOK Bash     'git"" add .env'                                 2
run $SECRET_HOOK Bash     "git'' add .env"                                 2
run $SECRET_HOOK Bash     "git\$'' add .env"                               2
run $SECRET_HOOK Bash     "git\${x} commit -a .env"                        2
run $SECRET_HOOK Bash     "git\$(true) add id_rsa"                         2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git`true` add .env'                             2
run $SECRET_HOOK Bash     "$(printf 'git\\\n add .env')"                   2
run $SECRET_HOOK Bash     'git ""add .env'                                 2
run $SECRET_HOOK Bash     "$(printf 'git \\\nadd .env')"                   2
# And glued onto the path, where what is left of the word is .env.
run $SECRET_HOOK Bash     "git add \${x}.env"                              2
run $SECRET_HOOK Bash     "git commit -a \$(true).env"                     2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git stage `true`.env'                           2
run $SECRET_HOOK Bash     "$(printf 'git add \t.env')"                     2
# A construct INSIDE the word, in each of the two words the gate reads. Every glue case
# above leaves `git` and the verb intact as text; these do not, so a gate that reads the
# text rather than the argv sees neither word.
run $SECRET_HOOK Bash     'g""it add .env'                                 2
run $SECRET_HOOK Bash     "g\$''it add .env"                               2
run $SECRET_HOOK Bash     'git ad""d .env'                                 2
# And the whitespace-valued expansion, which bash splits into two words where the text
# holds one.
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git${IFS}add .env'                              2
# An UNQUOTED substitution standing in a path argument. shlex reads its open paren as a
# segment separator, so the path inside it lands in no segment of its own — the word the
# command really stages has to be read out of the span text.
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git add $(echo .env)'                           2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git add ./$(echo .env)'                         2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git add $(echo .env)/x'                         2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git add $(echo .env) x'                         2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git commit -a $(echo .env)'                     2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git add $(echo id_rsa)'                         2
# The shapes that never split — quoted, backticked, or glued after the path — are the
# controls for the six rows above: they must go on blocking.
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git add "$(echo .env)"'                         2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git add `echo .env`'                            2
# shellcheck disable=SC2016
run $SECRET_HOOK Bash     'git add .env$(true)'                            2

echo "block-secret-staging.sh — must ALLOW (exit 0)"
run $SECRET_HOOK Bash     "git add src/main.py"                            0
run $SECRET_HOOK Bash     "git add .env.example"                           0
run $SECRET_HOOK Bash     "git add docs/environment.md"                    0
run $SECRET_HOOK Bash     "npm test"                                       0
run $SECRET_HOOK Bash     "git commit -m 'feat: read config from environment'" 0
run $SECRET_HOOK Bash     'echo "path is .env"'                            0
run $SECRET_HOOK Bash     "git status; cat .env"                           0
run $SECRET_HOOK Bash     "git log | grep .env"                            0
# The verb is a whole word: add.sh is a file name, not git add.
run $SECRET_HOOK Bash     "git blame add.sh .env"                          0
# Glue with no whitespace in it leaves one word: git""add is gitadd, --grep=add is one
# option. Neither is git add, and neither stages anything.
run $SECRET_HOOK Bash     'git""add .env'                                  0
run $SECRET_HOOK Bash     "git log --grep=add .env"                        0
# A segment break between the verb and the path means git never sees the path.
run $SECRET_HOOK Bash     "git add;.env"                                   0
run $SECRET_HOOK Bash     "git add&&cat .env"                              0

echo "block-mcp-writes.sh — the read-only veto (the command is ignored; the NAME is the input)"
run $MCP_HOOK mcp__tracker__get_issue        "" 0
run $MCP_HOOK mcp__github__list_issues       "" 0
run $MCP_HOOK mcp__tracker__search_issues    "" 0
run_msg $MCP_HOOK mcp__tracker__create_issue "" 2 "write-class MCP call"
run $MCP_HOOK mcp__gitlab__update_issue      "" 2
run $MCP_HOOK mcp__github__add_issue_comment "" 2
run_msg $MCP_HOOK mcp__tracker__get_or_create_issue "" 2 "mixes words with and/or/then"
run $MCP_HOOK mcp__github__list_then_delete "" 2
run $MCP_HOOK mcp__tracker__read_and_update "" 2
run $MCP_HOOK mcp__tracker__search_then_create_comment "" 2
run $MCP_HOOK mcp__tracker__validate_and_delete "" 2
run $MCP_HOOK mcp__tracker__delete_and_lint "" 2
run $MCP_HOOK mcp__tracker__get_and_clone_repo "" 2
run $MCP_HOOK mcp__tracker__getOrCreateIssue "" 2
run $MCP_HOOK mcp__tracker__get_or_remove_issue "" 2
run $MCP_HOOK mcp__tracker__read_then_push "" 2
run $MCP_HOOK mcp__tracker__whoami_and_update "" 2
run $MCP_HOOK mcp__tracker__validate_then_merge "" 2
run $MCP_HOOK mcp__tracker__get_remove_issue "" 2
run $MCP_HOOK mcp__tracker__validate_delete "" 2
run $MCP_HOOK mcp__tracker__read_update "" 2
run $MCP_HOOK mcp__tracker__read_issue "" 0
run $MCP_HOOK mcp__tracker__download_attachment "" 0
run $MCP_HOOK mcp__tracker__whoami "" 0
run $MCP_HOOK mcp__tracker__health "" 0
run $MCP_HOOK mcp__tracker__validate_issue "" 0
run $MCP_HOOK mcp__tracker__foo_lint "" 0
run $MCP_HOOK mcp__tracker__getIssue "" 0
run_msg $MCP_HOOK mcp__tracker__frobnicate "" 2 "not recognised as a safe read shape"
# Not a policed server: not this hook's business, whatever the verb.
run $MCP_HOOK mcp__serena__replace_symbol_body "" 0
run $MCP_HOOK Bash                             "" 0
# The second fail-open: a parse that SUCCEEDS and returns nothing used to fall through
# the case to exit 0, allowing the call on the strength of a name nobody read.
run $MCP_HOOK "" "" 2

# Proves the hook's verdicts do not depend on the allowlist.
HOOK_HOME="$ALLOW_HOME"
run $MCP_HOOK mcp__tracker__get_issue        "" 0
run $MCP_HOOK mcp__github__list_issues       "" 0
run $MCP_HOOK mcp__tracker__search_issues    "" 0
run_msg $MCP_HOOK mcp__tracker__create_issue "" 2 "write-class MCP call"
run $MCP_HOOK mcp__gitlab__update_issue      "" 2
run $MCP_HOOK mcp__github__add_issue_comment "" 2
run_msg $MCP_HOOK mcp__tracker__get_or_create_issue "" 2 "mixes words with and/or/then"
run $MCP_HOOK mcp__github__list_then_delete "" 2
run $MCP_HOOK mcp__tracker__read_and_update "" 2
run $MCP_HOOK mcp__tracker__search_then_create_comment "" 2
run $MCP_HOOK mcp__tracker__validate_and_delete "" 2
run $MCP_HOOK mcp__tracker__delete_and_lint "" 2
run $MCP_HOOK mcp__tracker__get_and_clone_repo "" 2
run $MCP_HOOK mcp__tracker__getOrCreateIssue "" 2
run $MCP_HOOK mcp__tracker__get_or_remove_issue "" 2
run $MCP_HOOK mcp__tracker__read_then_push "" 2
run $MCP_HOOK mcp__tracker__whoami_and_update "" 2
run $MCP_HOOK mcp__tracker__validate_then_merge "" 2
run $MCP_HOOK mcp__tracker__get_remove_issue "" 2
run $MCP_HOOK mcp__tracker__validate_delete "" 2
run $MCP_HOOK mcp__tracker__read_update "" 2
run $MCP_HOOK mcp__tracker__read_issue "" 0
run $MCP_HOOK mcp__tracker__download_attachment "" 0
run $MCP_HOOK mcp__tracker__whoami "" 0
run $MCP_HOOK mcp__tracker__health "" 0
run $MCP_HOOK mcp__tracker__validate_issue "" 0
run $MCP_HOOK mcp__tracker__foo_lint "" 0
run $MCP_HOOK mcp__tracker__getIssue "" 0
run_msg $MCP_HOOK mcp__tracker__frobnicate "" 2 "not recognised as a safe read shape"
# Not a policed server: not this hook's business, whatever the verb.
run $MCP_HOOK mcp__serena__replace_symbol_body "" 0
run $MCP_HOOK Bash                             "" 0
# The second fail-open: a parse that SUCCEEDS and returns nothing used to fall through
# the case to exit 0, allowing the call on the strength of a name nobody read.
run $MCP_HOOK "" "" 2
HOOK_HOME="$DENY_HOME"

echo "block-unexplained-long-hold.sh — must BLOCK (exit 2), a long hold with nothing said about it"
# The gap this hook closes is NOT an unbounded hang. The Bash tool is already bounded, so
# what is left is the LONG HOLD: a call reaching past the default and saying nothing about
# why. Every case below asks for more than the default; they differ only in what the
# description says, which is the whole judgement.
run_hold "no description at all"   300000 ""                                  2
run_hold "a description with no expectation" 300000 "run the regression suite" 2
run_hold "a reason that is not a duration"   600000 "it is slow on Windows"    2
# The boundary, both sides. One millisecond over the default is over the default; a hook
# that only fires at some round number above it has an interval nobody can see.
run_hold "one ms over the default" 120001 "run the regression suite"           2
# A timeout that is not a number is a payload this hook could not judge, and an unjudged
# call does not go — same rule as an unreadable payload.
run_hold "a non-numeric timeout"   '"5 minutes"' "run the regression suite"    2
# Past the tool's maximum the tool itself will refuse, so the remedy is not "state the
# expectation" — it is "run it in the background". Different message, same exit code, and
# only a message assertion can tell the two apart.
run_hold "past the maximum"        900000 "run the regression suite; expect 12 minutes" 2 \
    "goes to the BACKGROUND by design"

echo "block-unexplained-long-hold.sh — the refusal must carry a remedy runnable from where it fired"
# An exit code cannot tell a stop that can be acted on from one that strands the reader.
# This repo has already shipped a hard stop whose remedy could not be run from the point
# of the stop, so the remedy text is asserted, not assumed. The refusal also quotes the
# convention verbatim: a hook that refuses in different words from the rule it enforces is
# a second, undocumented rule.
run_hold "the remedy is in the message" 300000 "" 2 \
    "re-issue the SAME call with the expectation in its description"
run_hold "the refusal quotes the rule"  300000 "" 2 \
    "A call you expect to run long carries an explicit timeout"
# The hook is matched on two tools, so the refusal has to say which one it is talking
# about. "this call" is ambiguous in a transcript where both tools are in play, and the
# reader acting on the remedy needs to know which call to re-issue.
run_hold "the refusal names the tool"   300000 "" 2 "this Bash call"

echo "block-unexplained-long-hold.sh — must ALLOW (exit 0)"
# A guardrail that fires on a quick call is a guardrail nobody keeps. Everything at or
# under the default is untouched, deliberately, whatever the description says.
run_hold "exactly the default"        120000 ""                          0
run_hold "well under the default"      60000 ""                          0
run_hold "no timeout field at all"      OMIT ""                          0
run_hold "no timeout, no description"   OMIT ""                          0
# `null` is ABSENT, not unreadable, and the difference decides the verdict. The first cut
# of this case expected a BLOCK on the fail-closed reasoning and was wrong: a null timeout
# is a call that asked for no timeout, so blocking it would refuse an ordinary call in the
# name of a long hold nobody requested. A timeout the hook genuinely cannot compare — the
# string case above — still blocks. Kept as a case because the two look alike in a payload
# and read as one rule until someone writes both down.
run_hold "a null timeout"               null ""                          0
# Over the default WITH the expectation stated: the case the rule exists to produce.
run_hold "seconds stated"             300000 "run the hook suite; expect ~75s"        0
run_hold "minutes stated"             480000 "full installer sweep; expect 6 minutes" 0
run_hold "milliseconds stated"        300000 "fetch the index; expect 90000ms"        0
run_hold "the estimate sits mid-sentence" 300000 "clone and build — I expect this to take about 4 min on this laptop" 0

echo "block-unexplained-long-hold.sh — PowerShell is a SEPARATE tool and gets the same verdicts"
# The shipped matcher is Bash|PowerShell. PowerShell carries a timeout of its own with the
# same default and the same maximum, and on a Windows machine it can be the shell the model
# reaches for first — so a guard matched on Bash alone stops nothing the moment it does.
#
# BE HONEST ABOUT WHAT THESE CASES CAN AND CANNOT PROVE. The suite invokes the script
# directly and never sees settings.json, so NOTHING here can prove the matcher covers
# PowerShell — that is this file's standing blind spot, stated at the top. What these cases
# do prove is that the script REACHES THE SAME VERDICT on a PowerShell payload, which is the
# half that would rot silently: a later edit keying any of the judgement off the tool name
# would leave the matcher correct and the behaviour split, and only these lines would say so.
# The tool-naming case below is the one that was genuinely red before the matcher landed.
HOLD_TOOL=PowerShell
run_hold "no description at all"         300000 ""                             2
run_hold "a reason that is not a duration" 600000 "it is slow on Windows"      2
run_hold "one ms over the default"       120001 "run the regression suite"     2
run_hold "a non-numeric timeout"    '"5 minutes"' "run the regression suite"   2
run_hold "past the maximum"              900000 "run the regression suite"     2
run_hold "exactly the default"           120000 ""                             0
run_hold "a null timeout"                  null ""                             0
run_hold "no timeout field at all"         OMIT ""                             0
run_hold "the estimate is stated"        300000 "the full sweep; expect 6 minutes" 0
run_hold "the refusal names the tool"    300000 "" 2 "this PowerShell call"
run_hold "the refusal quotes the rule"   300000 "" 2 \
    "A call you expect to run long carries an explicit timeout"
run_hold "the remedy is in the message"  300000 "" 2 \
    "re-issue the SAME call with the expectation in its description"
HOLD_TOOL=Bash

echo "every blocking hook — an unreadable payload must BLOCK (exit 2)"
# The other half of failing closed: the parser is present and the payload defeats it.
# Same verdict as no parser at all, for the same reason — the hook did not find out what
# it was being asked to clear, so it does not clear it.
run_raw $GIT_HOOK    "not JSON at all"          'not json at all'  2
run_raw $INFRA_HOOK  "truncated JSON"           '{"tool_input":'   2
run_raw $SECRET_HOOK "empty payload"            ''                 2
run_raw $MCP_HOOK    "valid JSON, wrong shape"  '[]'               2
run_raw $HOLD_HOOK   "not JSON (long hold)"     'timeout=300000'   2
run_raw $HOLD_HOOK   "valid JSON, wrong shape (long hold)" '[]'    2

echo "every blocking hook — no parser on PATH must BLOCK (exit 2)"
# The layer no code inside a hook can test for itself: what happens when the thing the
# hook parses with is not there. A hook that exits 127 is not a near-miss of 2 — Claude
# Code treats every code but 2 as a non-blocking error and runs the tool call anyway, so
# these five cases are the difference between a guardrail and a decoration.
#
# The stripped PATH is the real PATH minus every directory holding a python, rather than
# an empty one: the hooks still need cat, grep and tr to reach the point of refusing.
NOPY_PATH=""
while IFS= read -r d; do
    [ -n "$d" ] || continue
    for p in python python3 python.exe python3.exe; do
        [ -x "$d/$p" ] && continue 2
    done
    NOPY_PATH="${NOPY_PATH:+$NOPY_PATH:}$d"
done <<< "$(printf '%s' "$PATH" | tr ':' '\n')"

if PATH="$NOPY_PATH" command -v python >/dev/null 2>&1 || PATH="$NOPY_PATH" command -v python3 >/dev/null 2>&1; then
    # Not a skip. A suite that quietly drops the cases it cannot set up is the green run
    # that means less than it looks like — the thing this file exists to prevent.
    printf '  FAIL [setup] python is still reachable after stripping PATH — the no-parser cases did not run\n'
    fail=$((fail + 1))
else
    HOOK_PATH="$NOPY_PATH"
    run $GIT_HOOK    Bash "git status"                    2
    run $INFRA_HOOK  Bash "git add src/main.py"           2
    run $SECRET_HOOK Bash "git add src/main.py"           2
    run $MCP_HOOK    mcp__tracker__get_issue          "" 2
    # Even a command the hook would have waved through is blocked: the point is that it
    # never found out which kind it was.
    run $GIT_HOOK    Bash "npm test"                      2
    # Same shape for the long-hold hook, and the payload matters: `run` builds one with no
    # `timeout` field at all, which with a parser present is an ALLOW. So the 2 here is
    # entirely about not having found out what was being asked.
    run $HOLD_HOOK   Bash "npm test"                      2
    HOOK_PATH="$PATH"
fi

echo "block-dangerous-git.sh — a python3 that is NOT python must BLOCK and name it (exit 2)"
# The layer between "there is a python3" and "there is a python". On Windows `python3` on
# PATH is often the Microsoft Store app-execution alias, which resolves like a real
# program and, where the Store package is not installed, prints an advert and exits 9009.
# The hook blocked — it has always blocked — but it blocked with a message about JSON,
# which points the reader at the payload when the payload was fine. Nothing in the refusal
# named the interpreter, so there was nothing to act on. #146.
#
# THE STUB IS DELIBERATELY THE SAME SHAPE AS CI'S OWN SHIM. .github/workflows/tests.yml
# writes a /bin/sh script named python3 onto PATH for the Windows job (see the "Give Git
# Bash a python3" step) because Windows has no python3.exe. Any discriminator based on
# SHAPE — the extension, the file type, the size, "is it a script" — rejects that shim and
# turns the Windows job red across all four suites, quietly and somewhere else. This stub
# is byte-for-byte the same KIND of object and differs only in BEHAVIOUR: it does not run
# python. So a shape-based check fails this case here, loudly, instead of failing CI.
STUBDIR="$SCRATCH/pystub"
mkdir -p "$STUBDIR"
printf '#!/bin/sh\necho "Python was not found; run without arguments to install from the Microsoft Store." >&2\nexit 9009\n' > "$STUBDIR/python3"
chmod +x "$STUBDIR/python3"

if [ -z "${NOPY_PATH:-}" ] || [ "$(PATH="$STUBDIR:$NOPY_PATH" command -v python3 2>/dev/null)" != "$STUBDIR/python3" ]; then
    # Not a skip, for the same reason as the setup guard above.
    printf '  FAIL [setup] the stub is not what python3 resolves to on the test PATH — the stub case did not run\n'
    fail=$((fail + 1))
else
    HOOK_PATH="$STUBDIR:$NOPY_PATH"
    # `git status` is a command the hook would otherwise wave through, so the exit 2 is
    # entirely about not being able to read the payload — and the message must say which
    # interpreter it tried, by RESOLVED PATH. "python3" would name the thing the user
    # already typed; the path is the thing they can act on.
    run_msg $GIT_HOOK Bash "git status" 2 "$STUBDIR/python3"
    HOOK_PATH="$PATH"
fi

echo "block-dangerous-git.sh — a WindowsApps python3 is DEMOTED, never DROPPED"
# The two lines the whole ticket is named after, and until now the only two with no case
# at all: the `*/windowsapps/*` arm that moves a candidate to the END of the list, and the
# line that appends that held-back list back on. Both were verified by hand during review
# and both were right — but the suite would have stayed green if a later edit turned the
# demotion into an exclusion, which is exactly the promise three documents make about this
# code. A behaviour nothing executes is a behaviour nobody will notice losing.
#
# Neither case can be written with a bare exit code alone:
#   * the hook's py_run() TRIES EVERY CANDIDATE IN TURN, so with a stub first and a real
#     python second it exits 0 whatever the order is. Order is observable only in WHICH
#     interpreter actually ran — so the WindowsApps python here is a working one that
#     touches a marker file before exec'ing the real thing. Marker present = it went
#     first = it was not demoted.
#   * dropping, by contrast, is visible in the exit code, but only when the demoted
#     candidate is the ONLY python there is. That is the second case.
#
# The paths carry a literal `WindowsApps` component because that is what the hook keys on
# (case-insensitively, via `${_p,,}`); nothing here depends on being on Windows.
WAPPS_MIX="$SCRATCH/mixed/WindowsApps"   # a WORKING python3 that records that it ran
WAPPS_REAL="$SCRATCH/onlywapps/WindowsApps"  # the only python on the PATH
REALDIR="$SCRATCH/realpy"                # a real python NOT under a WindowsApps path
WMARK="$SCRATCH/wapps-ran"
mkdir -p "$WAPPS_MIX" "$WAPPS_REAL" "$REALDIR"

# NOT "$PY" — ask the interpreter where it actually lives, and call THAT, absolutely.
# $PY is whatever `command -v python3` returned, and that is allowed to be a shim which
# re-resolves `python` BY NAME. CI installs precisely such a shim (`#!/bin/sh exec python
# "$@"`), because setup-python gives Windows a python.exe and no python3. These stubs put
# a `python` of their own on the hook's PATH, so a by-name shim reached from in here finds
# THIS stub, which execs the shim, which resolves `python` again — an exec loop with no
# growth in process count and no output, i.e. indistinguishable from a hang until the job
# is killed. It cost a 30-minute CI timeout, and it is invisible on any machine whose
# python3 is a real binary, which is every machine this suite was developed on.
REALPY="$("$PY" -c 'import sys; sys.stdout.buffer.write(sys.executable.encode())' 2>/dev/null || true)"
if [ -n "$REALPY" ] && command -v cygpath >/dev/null 2>&1; then
    REALPY="$(cygpath -u "$REALPY" 2>/dev/null || printf '%s' "$REALPY")"
fi

printf '#!/bin/sh\n: > "%s"\nexec "%s" "$@"\n' "$WMARK" "$REALPY" > "$WAPPS_MIX/python3"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$REALPY" > "$WAPPS_REAL/python3"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$REALPY" > "$REALDIR/python"
chmod +x "$WAPPS_MIX/python3" "$WAPPS_REAL/python3" "$REALDIR/python"

# The guard below proves PATH resolves to these stubs. This one proves the stubs are a
# real python that ANSWERS — the check the exec loop would have failed, made before any
# stub is put on a PATH where it could loop. A stub that cannot run is a setup fault, so
# it fails loudly here rather than being read as a verdict about the hook.
if [ -z "$REALPY" ] || [ "$("$REALPY" -c 'print(1+1)' 2>/dev/null)" != "2" ]; then
    printf '  FAIL [setup] could not resolve %s to a real interpreter (got "%s") — the ordering cases did not run\n' "$PY" "$REALPY"
    fail=$((fail + 1))
elif [ -z "${NOPY_PATH:-}" ] \
   || [ "$(PATH="$WAPPS_MIX:$REALDIR:$NOPY_PATH" command -v python3 2>/dev/null)" != "$WAPPS_MIX/python3" ] \
   || [ "$(PATH="$WAPPS_MIX:$REALDIR:$NOPY_PATH" command -v python 2>/dev/null)" != "$REALDIR/python" ] \
   || [ "$(PATH="$WAPPS_REAL:$NOPY_PATH" command -v python3 2>/dev/null)" != "$WAPPS_REAL/python3" ]; then
    # Not a skip, for the same reason as the two guards above.
    printf '  FAIL [setup] the WindowsApps/real pair is not what PATH resolves to — the ordering cases did not run\n'
    fail=$((fail + 1))
else
    # (a) both work; the real one is second on PATH and must still be the one that runs.
    rm -f "$WMARK"
    HOOK_PATH="$WAPPS_MIX:$REALDIR:$NOPY_PATH"
    run $GIT_HOOK Bash "git status" 0
    ran=$((ran + 1))
    if [ -e "$WMARK" ]; then
        printf '  FAIL [order] the WindowsApps python3 ran — the real python beside it was not preferred\n'
        fail=$((fail + 1))
    else
        printf '  ok   [order] a WindowsApps python3 was demoted behind the real python beside it\n'
    fi

    # (b) the WindowsApps python is the ONLY python. Demoted it still runs and the hook
    # judges the command; dropped, the hook has no parser and blocks a `git status` it
    # should have waved through. A guardrail that bricks the machine is not the safer
    # failure — this expects 0, deliberately.
    HOOK_PATH="$WAPPS_REAL:$NOPY_PATH"
    run $GIT_HOOK Bash "git status" 0
    HOOK_PATH="$PATH"
fi

echo ""
if [ "$fail" -eq 0 ]; then
    echo "All $ran cases behaved: the patterns match, and every blocking hook fails closed."
    exit 0
fi
echo "$fail of $ran case(s) FAILED — a guardrail is not guarding."
exit 1
