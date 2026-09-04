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

# --- python ---------------------------------------------------------------------
# The hooks parse their payload with python, and so does this suite when it builds one.
# There is nothing left to shim: when the parser is missing the hooks are SUPPOSED to
# block, which is a case the suite tests rather than papers over.
PY=$(command -v python3 || command -v python)
if [ -z "$PY" ]; then
    echo "SKIP: no python3 or python available — cannot run the suite." >&2
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

run() { # <script> <tool-name> <command> <expected-exit>
    local payload
    payload=$(printf '{"tool_name":"%s","cwd":%s,"tool_input":{"command":%s}}' "$2" \
        "$("$PY" -c "import json,sys;print(json.dumps(sys.argv[1]))" "$HOOK_CWD")" \
        "$("$PY" -c "import json,sys;print(json.dumps(sys.argv[1]))" "$3")")
    printf '%s' "$payload" | HOME="$HOOK_HOME" PATH="$HOOK_PATH" "$BASH_BIN" "$1" >/dev/null 2>&1
    local got=$?
    local shown
    shown=$(printf '%s' "$3" | tr '\n' '~' | tr '\r' '^')
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

echo "block-dangerous-git.sh — must ALLOW (exit 0), the KNOWN GAP filed as issue #140"
# These four REALLY EXECUTE, and the text scan this hook replaces blocked them. They are
# allowed here knowingly: git_args() reads the command it was handed, and none of these
# puts the git command where a tokenizer can see it — it is DATA inside another command's
# argument, or a substitution inside double quotes that never separates into words.
# Closing them properly means parsing a shell rather than tokenizing one, and a half-fix
# that catches `bash -c` but not `sh -c` reads as coverage and stops the next person
# looking. Inherited from block-infra-staging.sh (#112), which behaves identically.
# The same boundary is written at the tokenizer's call site in the hook.
# Green before this re-review and after it — they record a decision, they prove nothing.
run $GIT_HOOK Bash       'bash -c "git push --force"'                                   0
run $GIT_HOOK Bash       "sh -c 'git reset --hard HEAD~1'"                              0
run $GIT_HOOK Bash       "eval 'git push --force'"                                      0
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'echo "$(git branch -D f)"'                                    0
# Unquoted, both of these still block — it is the double-quoted form that gets through.
# shellcheck disable=SC2016
run $GIT_HOOK Bash       '$(git push --force)'                                          2
# shellcheck disable=SC2016
run $GIT_HOOK Bash       'echo `git push --force`'                                      2

echo "block-dangerous-git.sh — must ALLOW (exit 0), the RECORDED RESIDUE of the heredoc fix"
# One shape, and it is a REGRESSION this pass takes knowingly rather than a gap it
# inherited. A FALSE heredoc — the operator is inside a quoted string, so bash never sees
# one — whose terminator WORD then happens to appear alone on a later line. Refusing to
# swallow an unterminated heredoc is what closed the whole comment/quote class above; when
# the word does coincide, the lines between are still read as a body and the force push in
# them is not judged. It measured 2 at 84ae124, by the same shlex accident as the six cases
# above, and it is 0 now.
#
# Not closable at this size: it needs the tokenizer to decide whether <<WORD is a real
# operator — not inside quotes, not after a # — which is parsing a shell rather than
# tokenizing one, the same boundary #140 draws. Written down here so the trade is a
# decision in the suite and not a discovery in the next review.
run $GIT_HOOK Bash       "echo \"use <<EOF now\"
git push --force
EOF
git status"                                                                             0

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

echo "block-secret-staging.sh — must ALLOW (exit 0)"
run $SECRET_HOOK Bash     "git add src/main.py"                            0
run $SECRET_HOOK Bash     "git add .env.example"                           0
run $SECRET_HOOK Bash     "git add docs/environment.md"                    0
run $SECRET_HOOK Bash     "npm test"                                       0
run $SECRET_HOOK Bash     "git commit -m 'feat: read config from environment'" 0

echo "block-mcp-writes.sh — the read-only veto (the command is ignored; the NAME is the input)"
run $MCP_HOOK mcp__tracker__get_issue        "" 0
run $MCP_HOOK mcp__github__list_issues       "" 0
run $MCP_HOOK mcp__tracker__search_issues    "" 0
run $MCP_HOOK mcp__tracker__create_issue     "" 2
run $MCP_HOOK mcp__gitlab__update_issue      "" 2
run $MCP_HOOK mcp__github__add_issue_comment "" 2
# Not a policed server: not this hook's business, whatever the verb.
run $MCP_HOOK mcp__serena__replace_symbol_body "" 0
run $MCP_HOOK Bash                             "" 0
# The second fail-open: a parse that SUCCEEDS and returns nothing used to fall through
# the case to exit 0, allowing the call on the strength of a name nobody read.
run $MCP_HOOK "" "" 2

echo "every blocking hook — an unreadable payload must BLOCK (exit 2)"
# The other half of failing closed: the parser is present and the payload defeats it.
# Same verdict as no parser at all, for the same reason — the hook did not find out what
# it was being asked to clear, so it does not clear it.
run_raw $GIT_HOOK    "not JSON at all"          'not json at all'  2
run_raw $INFRA_HOOK  "truncated JSON"           '{"tool_input":'   2
run_raw $SECRET_HOOK "empty payload"            ''                 2
run_raw $MCP_HOOK    "valid JSON, wrong shape"  '[]'               2

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
    HOOK_PATH="$PATH"
fi

echo ""
if [ "$fail" -eq 0 ]; then
    echo "All $ran cases behaved: the patterns match, and every blocking hook fails closed."
    exit 0
fi
echo "$fail of $ran case(s) FAILED — a guardrail is not guarding."
exit 1
