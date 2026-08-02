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
# Stand-in for: jq -r '.tool_input.command // .tool_input.script // ""'
"$PY" -c "
import sys, json
ti = json.load(sys.stdin).get('tool_input', {})
print(ti.get('command') or ti.get('script') or '')
"
SHIM
    chmod +x "$SHIM_DIR/jq"
    PATH="$SHIM_DIR:$PATH"
    echo "NOTE: jq not found — using a python shim for the payload parse."
    echo "      The matching logic below is still the real thing."
    echo ""
fi
trap '[ -n "$SHIM_DIR" ] && rm -rf "$SHIM_DIR"' EXIT

PY=$(command -v python3 || command -v python)
fail=0

run() { # <script> <tool-name> <command> <expected-exit>
    local payload
    payload=$(printf '{"tool_name":"%s","tool_input":{"command":%s}}' "$2" \
        "$("$PY" -c "import json,sys;print(json.dumps(sys.argv[1]))" "$3")")
    printf '%s' "$payload" | bash "$1" >/dev/null 2>&1
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

echo "block-infra-staging.sh — must BLOCK (exit 2)"
run $INFRA_HOOK Bash     "git add CLAUDE.md"                               2
run $INFRA_HOOK Bash     "git add .claude/settings.json"                   2
run $INFRA_HOOK Bash     "git add .serena/project.yml"                     2
run $INFRA_HOOK Bash     "git add -A"                                      2
run $INFRA_HOOK Bash     "git status
git add CLAUDE.md"                                                         2
run $INFRA_HOOK Bash     "git add .
git commit -m x"                                                           2

echo "block-infra-staging.sh — must ALLOW (exit 0)"
run $INFRA_HOOK Bash     "git add src/main.py"                             0
run $INFRA_HOOK Bash     "git commit -m 'docs: update readme'"             0
run $INFRA_HOOK Bash     "npm test"                                        0

echo ""
if [ "$fail" -eq 0 ]; then
    echo "All cases behaved."
    exit 0
fi
echo "$fail case(s) FAILED — a guardrail is not guarding."
exit 1
