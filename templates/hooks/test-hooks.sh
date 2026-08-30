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

echo "block-dangerous-git.sh — the allowlist, listed repo"
HOOK_HOME="$ALLOW_HOME"
run $GIT_HOOK Bash       "git push origin master"                          0
run $GIT_HOOK PowerShell "git push"                                        0
# Allowlisted for push is not allowlisted for everything: force and the sweep still go.
run $GIT_HOOK Bash       "git push --force"                                2
run $GIT_HOOK Bash       "git add -A"                                      2
run $GIT_HOOK Bash       "git reset --hard origin/main"                    2
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
    echo "All cases behaved: the patterns match, and every blocking hook fails closed."
    exit 0
fi
echo "$fail case(s) FAILED — a guardrail is not guarding."
exit 1
