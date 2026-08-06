#!/usr/bin/env bash
# Regression suite for the blocking hooks.
#
# A guardrail that stops guarding keeps reporting success, so these cannot be verified by
# reading them. Run this after editing any hook, and after a Claude Code release that
# changes the PreToolUse payload shape.
#
#   bash templates/hooks/test-hooks.sh
#
# Exit 0 = every case behaved. Exit 1 = at least one guardrail is not guarding.

set -uo pipefail
cd "$(dirname "$0")"

GIT_HOOK=./block-dangerous-git.sh
INFRA_HOOK=./block-infra-staging.sh
SECRET_HOOK=./block-secret-staging.sh

# --- jq ------------------------------------------------------------------------
# The hooks parse their payload with jq. If it is missing we shim the one filter they
# use, so the suite still exercises the matching logic — and we say so, because a green
# run that silently skipped the real parser would be its own kind of lie.
SHIM_DIR=""
if ! command -v jq >/dev/null 2>&1; then
    if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
        echo "SKIP: neither jq nor python is available — cannot run the suite." >&2
        exit 1
    fi
    PY=$(command -v python3 || command -v python)
    SHIM_DIR="$(mktemp -d)"
    cat > "$SHIM_DIR/jq" <<SHIM
#!/usr/bin/env bash
# Stand-in for the two filters the hooks use:
#   -r '.tool_input.command // .tool_input.script // ""'
#   -r '.cwd // ""'
"$PY" -c "
import sys, json
args = sys.argv[1:]
d = json.load(sys.stdin)
if any('cwd' in a for a in args):
    print(d.get('cwd') or '')
else:
    ti = d.get('tool_input', {})
    print(ti.get('command') or ti.get('script') or '')
" "\$@"
SHIM
    chmod +x "$SHIM_DIR/jq"
    PATH="$SHIM_DIR:$PATH"
    echo "NOTE: jq not found — using a python shim for the payload parse."
    echo "      The matching logic below is still the real thing."
    echo ""
fi

PY=$(command -v python3 || command -v python)
fail=0

# --- the allowlist, both ways --------------------------------------------------
# Two hooks now consult ~/.claude/repo-allowlist, keyed by the repo's remote URL. To
# exercise both answers the suite builds a scratch repo with a known remote and two
# throwaway HOMEs — one holding a line for it, one holding nothing.
#
# It does NOT key on this playbook's own remote. A test that passes only in the clone
# it was written in is a test that reports success somewhere it never ran.
SCRATCH="$(mktemp -d)"
trap '[ -n "$SHIM_DIR" ] && rm -rf "$SHIM_DIR"; rm -rf "$SCRATCH"' EXIT

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

run() { # <script> <tool-name> <command> <expected-exit>
    local payload
    payload=$(printf '{"tool_name":"%s","cwd":%s,"tool_input":{"command":%s}}' "$2" \
        "$("$PY" -c "import json,sys;print(json.dumps(sys.argv[1]))" "$HOOK_CWD")" \
        "$("$PY" -c "import json,sys;print(json.dumps(sys.argv[1]))" "$3")")
    printf '%s' "$payload" | HOME="$HOOK_HOME" bash "$1" >/dev/null 2>&1
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

echo "block-dangerous-git.sh — must BLOCK (exit 2)"
run $GIT_HOOK Bash       "git push origin master"                          2
run $GIT_HOOK Bash       "git push --force"                                2
run $GIT_HOOK Bash       "cd /tmp && git push"                             2
run $GIT_HOOK Bash       "git reset --hard origin/main"                    2
run $GIT_HOOK Bash       "git clean -fd"                                   2
run $GIT_HOOK Bash       "git branch -D feature"                           2
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

echo "block-secret-staging.sh — must ALLOW (exit 0)"
run $SECRET_HOOK Bash     "git add src/main.py"                            0
run $SECRET_HOOK Bash     "git add .env.example"                           0
run $SECRET_HOOK Bash     "git add docs/environment.md"                    0
run $SECRET_HOOK Bash     "npm test"                                       0
run $SECRET_HOOK Bash     "git commit -m 'feat: read config from environment'" 0

echo ""
if [ "$fail" -eq 0 ]; then
    echo "All cases behaved."
    exit 0
fi
echo "$fail case(s) FAILED — a guardrail is not guarding."
exit 1
