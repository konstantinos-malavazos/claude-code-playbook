#!/usr/bin/env bash
# Test driver for issue #85. Drives install.sh with redirected HOME / CLAUDE_HOME
# so nothing touches the real ~/.claude. Run from anywhere.
#
#   bash tests/test-installer.sh            # all tests
#   bash tests/test-installer.sh 5 8        # only these
# Some sections share state; how long a run takes and how to split one safely are in
# README.md, section "Running the installer suite".

# The repo is the parent of tests/. The sandbox and the logs go to a temp dir, never
# into the repo: every run redirects HOME and CLAUDE_HOME into it, so a stray path
# here would be the one thing this suite must never do — touch the real ~/.claude.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

# Every argument must name a section, or it would match no `want` and run nothing,
# green. The valid ids are read from this file's own `want <id>` calls, before any
# setup, so a typo stops the run before it touches anything.
if [ "$#" -gt 0 ]; then
    _ids=" $(grep -vE '^[[:space:]]*#' "${BASH_SOURCE[0]}" \
             | grep -oE '(^|[^[:alnum:]_])want [[:alnum:]]+' | sed 's/.*want //' \
             | sort -u | tr '\n' ' ')"
    if [ -z "${_ids// /}" ]; then
        echo "found no sections in ${BASH_SOURCE[0]}" >&2
        exit 2
    fi
    _bad=0
    for _a in "$@"; do
        case "$_ids" in
            *" $_a "*) ;;
            *) echo "unknown section id: $_a" >&2; _bad=1 ;;
        esac
    done
    [ "$_bad" = "0" ] || exit 2
fi

SCRATCH="${PLAYBOOK_TEST_DIR:-${TMPDIR:-/tmp}/playbook-install-tests}"
SANDBOX="$SCRATCH/sandbox"
LOGS="$SCRATCH/logs"

# --- python ---------------------------------------------------------------------
# This suite drives install.sh and then reads back the JSON it wrote, and every one of
# those reads is a python process. WHICH python matters here. On Windows `python3` on
# PATH is often the Microsoft Store app-execution alias, which resolves like a real
# program and, where the Store package is not installed, prints an advert and exits
# 9009. `with_memory()` below pipes a heredoc into it with no error check, so a stub
# would build the sandbox wrong and every later failure would point at the installer
# instead of at the interpreter — correct by luck, and the diagnostic lies (#146).
#
# The candidates are the hooks' own, so the suite picks its interpreter by the same rule
# as the code it tests.
HOOK_LIB_LOADED=
# shellcheck source-path=SCRIPTDIR source=../templates/hooks/_lib/common.sh
if ! . "$REPO/templates/hooks/_lib/common.sh" || [ "${HOOK_LIB_LOADED-}" != 1 ]; then
    echo "FAIL: $REPO/templates/hooks/_lib/common.sh is missing or did not load — no interpreter list to run with." >&2
    exit 1
fi

# Probed once, here, rather than letting the first real use decide. A driver that
# cannot read the files install.sh writes has no tests to run at all, and finding that
# out now beats finding it out thirty spawns in, with a sandbox that was built wrong
# and a failure list that blames install.sh. The hooks are in the opposite position —
# one invocation, no spare process to pay — and do the opposite thing.
PY=""
for _c in ${PY_LIST[@]+"${PY_LIST[@]}"}; do
    if "$_c" -c "pass" >/dev/null 2>&1; then
        PY="$_c"
        break
    fi
done
if [ -z "$PY" ]; then
    echo "SKIP: no working python3 or python available — cannot run the installer suite." >&2
    if [ "${#PY_LIST[@]}" -gt 0 ]; then
        echo "       on PATH, but not a working python: ${PY_LIST[*]}" >&2
    fi
    exit 1
fi

PASS=0; FAIL=0
FAILED_NAMES=()
SECTION_LABEL=""; SECTION_START=0
SECTION_ROWS=()

pass() { PASS=$((PASS+1)); printf '    PASS  %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); printf '    FAIL  %s\n' "$1"; }
chk()  { if [ "$1" = "0" ]; then pass "$2"; else fail "$2"; fi; }
yn()   { if [ "$1" = "0" ]; then pass "$2"; else fail "$2"; fi; }

# $SECONDS, not date: a fork per banner costs ~30ms on Windows.
close_section() {
    [ -n "$SECTION_LABEL" ] || return 0
    local row
    printf -v row '%5ss  %s' "$((SECONDS - SECTION_START))" "$SECTION_LABEL"
    SECTION_ROWS+=("$row")
}

banner() {
    close_section
    SECTION_LABEL="$1"; SECTION_START=$SECONDS
    printf '\n=== %s\n' "$1"
}

fresh_env() {
  HOME_DIR="$SANDBOX/$1/home"
  CH="$SANDBOX/$1/claude"
  rm -rf "${SANDBOX:?}/${1:?}"
  mkdir -p "$HOME_DIR" "$CH"
}

with_serena() {
  mkdir -p "$HOME_DIR"
  cat > "$HOME_DIR/.claude.json" <<'JSON'
{ "mcpServers": { "serena": { "command": "uvx", "args": ["serena"] } } }
JSON
}

# with_memory - a registered Forgetful, MERGED into whatever .claude.json is there.
# Merged rather than written, so the call order of with_serena/with_memory cannot
# silently decide which pillar the sandbox has.
with_memory() {
  mkdir -p "$HOME_DIR"
  "$PY" - "$HOME_DIR/.claude.json" <<'PY'
import json, os, sys
p = sys.argv[1]
d = {}
if os.path.exists(p):
    try:
        d = json.load(open(p, encoding="utf-8"))
    except Exception:
        d = {}
if not isinstance(d, dict):
    d = {}
d.setdefault("mcpServers", {})["forgetful"] = {"command": "forgetful-mcp"}
json.dump(d, open(p, "w", encoding="utf-8"), indent=2)
PY
}

# with_memory_connector - Forgetful reached as a claude.ai CONNECTOR, which is a
# FOURTH registration route: it never lands under mcpServers, only in this
# historical list. This is the shape of the maintainer's own machine, where
# The name is lower-case on purpose: the tool prefix keeps the case of whatever
# is recorded here, so "claude.ai forgetful" is mcp__claude_ai_forgetful__.
with_memory_connector() {
  mkdir -p "$HOME_DIR"
  "$PY" - "$HOME_DIR/.claude.json" <<'PY'
import json, os, sys
p = sys.argv[1]
d = {}
if os.path.exists(p):
    try:
        d = json.load(open(p, encoding="utf-8"))
    except Exception:
        d = {}
if not isinstance(d, dict):
    d = {}
d["claudeAiMcpEverConnected"] = ["claude.ai Gmail", "claude.ai forgetful"]
json.dump(d, open(p, "w", encoding="utf-8"), indent=2)
PY
}

# with_servers - BOTH pillars. This is the only state a normal install runs in now,
# so it is what every case that expects a completed install must set up. A case that
# calls only with_serena is deliberately testing the memory gate.
with_servers() { with_serena; with_memory; }

# clone_repo DIR - the installer and its templates, in a sandbox directory, so a
# case can run install.sh with a DIFFERENT $PWD without writing into the real repo.
# The project-scope .mcp.json cases need this: $PWD is where install.sh looks for
# one, and the real repo is not a scratch directory.
clone_repo() {
  mkdir -p "$1"
  ( cd "$REPO" && tar -cf - install.sh install-lib.py templates ) | ( cd "$1" && tar xf - )
}

# keys LOG key...  — stage keystrokes for the next run of LOG
keys()   { local log="$1"; shift; printf '%s\n' "$@" > "$LOGS/$log.in"; }
nokeys() { : > "$LOGS/$1.in"; }

# run MODE LOG — NOT a pipeline: the right side of a pipe is a subshell and RC
# would never make it back out.
run() {
  local mode="$1" log="$2"
  [ -f "$LOGS/$log.in" ] || : > "$LOGS/$log.in"
  ( cd "$REPO" && HOME="$HOME_DIR" CLAUDE_HOME="$CH" PLAYBOOK_SCRIPTED_INPUT=1 \
    bash ./install.sh "$mode" ) \
    < "$LOGS/$log.in" > "$LOGS/$log.out" 2> "$LOGS/$log.err"
  RC=$?
  return 0
}

# run_raw MODE LOG - like run(), but WITHOUT PLAYBOOK_SCRIPTED_INPUT and with stdin
# closed. run() sets that flag so the scripted cases can drive the real prompts,
# which means every other case deliberately walks past the door check. These two
# guards therefore need a runner that does not hold the door open.
#
# `timeout` matters more than it looks: the bug these cases exist for was a menu
# that re-rendered forever, so a regression must FAIL rather than hang the suite.
# 857KB in 4 minutes was the observed shape; 60s and 20KB are both far outside a
# healthy run, which refuses in about a second and 200 bytes.
TIMEOUT=""
command -v timeout >/dev/null 2>&1 && TIMEOUT="timeout 60"
run_raw() {
  local mode="$1" log="$2"
  # $TIMEOUT is deliberately unquoted: it is empty, or the two words "timeout 60".
  # shellcheck disable=SC2086
  ( cd "$REPO" && HOME="$HOME_DIR" CLAUDE_HOME="$CH" \
    $TIMEOUT bash ./install.sh "$mode" ) \
    < /dev/null > "$LOGS/$log.out" 2> "$LOGS/$log.err"
  RC=$?
  return 0
}

# bytes LOG - size of a run's output, the loop tripwire. Both streams: a runaway
# menu prints to stdout, and the refusal that should replace it goes to stderr.
bytes() { cat "$LOGS/$1.out" "$LOGS/$1.err" 2>/dev/null | wc -c | tr -d ' '; }

# inboth / notinboth LOG TEXT NAME - die() writes to stderr, so a refusal is not
# in .out. Note the flags: `grep -qiF` SIGABRTs on the GNU grep 3.0 that ships with
# Git Bash here - -qF, -qi and -q are each fine, it is -i and -F together that dies,
# leaving the grep.exe.stackdump this repo has collected. Match case-sensitively
# instead, which is what the rest of this suite already does.
bothgrep() {
  grep -qF -- "$2" "$LOGS/$1.out" 2>/dev/null && return 0
  grep -qF -- "$2" "$LOGS/$1.err" 2>/dev/null
}
inboth()    { if bothgrep "$1" "$2"; then pass "$3"; else fail "$3"; fi; }
notinboth() { if bothgrep "$1" "$2"; then fail "$3"; else pass "$3"; fi; }

n_files() { find "$CH" -type f 2>/dev/null | wc -l | tr -d ' '; }
has() { grep -qF -- "$2" "$LOGS/$1.out"; }
inlog() { if has "$1" "$2"; then pass "$3"; else fail "$3"; fi; }
notinlog() { if has "$1" "$2"; then fail "$3"; else pass "$3"; fi; }

mkdir -p "$SANDBOX" "$LOGS"

# The happy-path keystrokes for a fresh interactive install:
#   banner · discover · menu:5 · tracker:4(local-markdown) · back · i
#   serena route(default) · serena pause
#   strong · fast · memory-READ · memory-WRITE · placeholder pause
#   hooks-warning pause · "Write these?" y
#   <workspace> · tracker pause
#
# The two memory entries are the #105 change. They are Enter, and Enter now TAKES
# the suggested tool names - it used to delete the grant. Every array below that
# drives a completed install carries them; leaving them out does not "skip" the
# prompts, it feeds the following answer into them and shifts everything after.
FULL=( '' '' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" '' )

WANT="$*"
want() { [ -z "$WANT" ] && return 0; case " $WANT " in *" $1 "*) return 0;; esac; return 1; }

# ---------------------------------------------------------------- 13 static
if want 13; then
banner "13 · static checks"
( cd "$REPO" && bash -n install.sh ) ; chk $? "bash -n install.sh"
( cd "$REPO" && "$PY" -m py_compile install-lib.py && rm -rf __pycache__ ) >/dev/null 2>&1
chk $? "python3 -m py_compile install-lib.py"
( cd "$REPO/templates/skills/memory-lint" && "$PY" -m py_compile lint.py garden_check.py tests.py && rm -rf __pycache__ ) >/dev/null 2>&1
chk $? "python3 -m py_compile the memory-lint scripts"
( cd "$REPO" && "$PY" -I templates/skills/memory-lint/tests.py ) > "$LOGS/memory-lint-tests.out" 2>&1
chk $? "python3 -I templates/skills/memory-lint/tests.py (log: $LOGS/memory-lint-tests.out)"
yn "$([ ! -e "$REPO/templates/skills/memory-lint/__pycache__" ] && echo 0 || echo 1)" \
   "the memory-lint skill directory holds no __pycache__ (it installs as a whole directory)"
( cd "$REPO/templates/skills/context-checkpoint" && "$PY" -m py_compile occupancy.py tests.py && rm -rf __pycache__ ) >/dev/null 2>&1
chk $? "python3 -m py_compile the context-checkpoint scripts"
( cd "$REPO" && "$PY" -I templates/skills/context-checkpoint/tests.py ) > "$LOGS/context-checkpoint-tests.out" 2>&1
chk $? "python3 -I templates/skills/context-checkpoint/tests.py (log: $LOGS/context-checkpoint-tests.out)"
yn "$([ ! -e "$REPO/templates/skills/context-checkpoint/__pycache__" ] && echo 0 || echo 1)" \
   "the context-checkpoint skill directory holds no __pycache__ (it installs as a whole directory)"
( cd "$REPO/templates/serena" && "$PY" -m py_compile serena_route.py && rm -rf __pycache__ ) >/dev/null 2>&1
chk $? "python3 -m py_compile the route C kit"
( cd "$REPO/tests" && "$PY" -m py_compile fake_serena.py && rm -rf __pycache__ ) >/dev/null 2>&1
chk $? "python3 -m py_compile tests/fake_serena.py"
yn "$([ ! -e "$REPO/templates/serena/__pycache__" ] && echo 0 || echo 1)" \
   "the route C kit directory holds no __pycache__ (it installs as a whole directory)"
if command -v shellcheck >/dev/null 2>&1; then
  ( cd "$REPO" && shellcheck install.sh ) ; chk $? "shellcheck install.sh"
  ( cd "$REPO" && shellcheck -x templates/hooks/*.sh ) ; chk $? "shellcheck the hooks"
  ( cd "$REPO" && shellcheck -x templates/serena/*.sh ) ; chk $? "shellcheck the route C kit's wrappers"
  ( cd "$REPO" && shellcheck -x tests/test-installer.sh ) ; chk $? "shellcheck this suite"
  ( cd "$REPO" && shellcheck -x tests/test-wiring.sh ) ; chk $? "shellcheck the wiring scrub"
  ( cd "$REPO" && shellcheck -x tests/test-docs.sh ) ; chk $? "shellcheck the docs scrub"
else
  printf '    SKIP  shellcheck — NOT INSTALLED on this machine, so NOT run\n'
fi
# A section id that matches no `want` must stop the run, not run nothing and pass. The
# child gets its own PLAYBOOK_TEST_DIR so it can never touch this run's sandbox.
( PLAYBOOK_TEST_DIR="$SCRATCH/typo" bash "$HERE/test-installer.sh" NO_SUCH_SECTION ) \
  > "$LOGS/typo.out" 2>&1
TYPO_RC=$?
yn "$([ "$TYPO_RC" != "0" ] && echo 0 || echo 1)" "an unknown section id exits non-zero (rc=$TYPO_RC)"
yn "$(grep -qF 'NO_SUCH_SECTION' "$LOGS/typo.out" && echo 0 || echo 1)" \
   "an unknown section id is named in the output"
fi

# ------------------------------------------------- 17 the documented Windows command
# Windows PowerShell ships set to `Restricted`, so a bare `.\install.ps1` dies with
# "running scripts is disabled on this system" before the script's first line runs.
#
# The install.ps1 suite cannot catch it, and never will: it launches the script with
# -ExecutionPolicy Bypass itself (see New-Run in tests/test-install-ps1.ps1), because
# it has to in order to test anything at all. So the one thing a real user hits first
# is invisible to it, and to CI. This section covers the DOCS instead, which is where
# the bug actually lived, and it runs on every platform.
#
# Catches: any doc block that tells someone to run install.ps1 without saying how to
# get past the execution policy, and the deletion of the explanation itself.
if want 17; then
banner "17 · the docs give a Windows command that actually runs"

DOCFAIL=$(cd "$REPO" && "$PY" - <<'PY'
import os, re

targets = ["README.md"]
for root, _dirs, files in os.walk("docs"):
    for fn in files:
        if fn.endswith(".md"):
            targets.append(os.path.join(root, fn))

fence = re.compile(r"^\s*(?:>\s*)?```")
for path in sorted(targets):
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    block, inside = [], False
    for line in lines:
        if fence.match(line):
            if inside:
                text = "\n".join(block)
                # Only a line that STARTS with the invocation is telling someone to
                # run it. A repo-tree block that merely names the file is not, and
                # a block quoting the ERROR is the one place the bare form belongs.
                runs = any(re.match(r"^\s*(?:>\s*)?\.?\\?install\.ps1\b", b)
                           for b in block)
                if runs and "cannot be loaded" not in text:
                    if "-ExecutionPolicy" not in text:
                        print("BARE %s" % path)
                block, inside = [], False
            else:
                inside = True
            continue
        if inside:
            block.append(line)

readme = open("README.md", encoding="utf-8").read()
if "-ExecutionPolicy Bypass -File" not in readme:
    print("NOCOMMAND README.md")
if "running scripts is disabled" not in readme:
    print("NOSYMPTOM README.md")
PY
)

if [ -z "$DOCFAIL" ]; then
  pass "every doc block that runs install.ps1 gets past the execution policy"
else
  printf '%s\n' "$DOCFAIL" | sed -n 's/^BARE /          bare .\\install.ps1 in: /p'
  printf '%s\n' "$DOCFAIL" | sed -n 's/^NOCOMMAND /          no working command documented in: /p'
  printf '%s\n' "$DOCFAIL" | sed -n 's/^NOSYMPTOM /          the error it fixes is no longer named in: /p'
  fail "a documented Windows command would die on 'running scripts is disabled'"
fi

# The help text inside install.ps1 is the other copy of the same instruction, and it
# is what `Get-Help .\install.ps1` prints.
if grep -qF -- '-ExecutionPolicy Bypass -File .\install.ps1' "$REPO/install.ps1"; then
  pass "install.ps1's own .EXAMPLE block shows the command that runs"
else
  fail "install.ps1's .EXAMPLE block still shows a bare .\\install.ps1"
fi
fi

# ---------------------------------------------------------------- 1 list
if want 1; then
banner "1 · list on an empty CLAUDE_HOME"
fresh_env t1; nokeys t1; run list t1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "exit 0"
inlog t1 "nothing installed by this script" "reports nothing installed"
yn "$([ "$(n_files)" = "0" ] && echo 0 || echo 1)" "wrote nothing"
fi

# ---------------------------------------------------------------- 2 serena gate fires
if want 2; then
banner "2 · Serena gate FIRES (no .claude.json anywhere)"
fresh_env t2; keys t2 "${FULL[@]}"; run install t2
yn "$([ "$RC" != "0" ] && echo 0 || echo 1)" "exits non-zero (rc=$RC)"
inlog t2 "Serena is not set up on this machine" "prints the refusal"
inlog t2 "serena plugin from the official marketplace" "prints route A"
inlog t2 "mcpServers.serena" "prints route B"
inlog t2 "docs/shared/03-setup.md" "points at the doc rather than copying it"
yn "$([ "$(n_files)" = "0" ] && echo 0 || echo 1)" "CLAUDE_HOME still empty ($(n_files) files)"
LASTLINE="$(grep -v '^[[:space:]]*$' "$LOGS/t2.out" | tail -1)"
case "$LASTLINE" in *".claude/plugins"*) pass "the steps are the LAST thing on screen" ;;
  *) fail "the steps are the LAST thing on screen (last line: $LASTLINE)" ;; esac
fi

# ---------------------------------------------------------------- 3 serena gate passes
if want 3; then
banner "3 · Serena gate PASSES (mcpServers.serena present)"
fresh_env t3; with_servers; keys t3 "${FULL[@]}"; run install t3
notinlog t3 "Serena is not set up" "gate does not fire"
inlog t3 "which tool names" "reaches the Serena route stage"
inlog t3 "mcpServers.serena" "shows the evidence it found"
inlog t3 "Install complete" "runs to completion"
fi

# ---------------------------------------------------------------- 4 tracker gate
if want 4; then
banner "4 · tracker is a required choice"
fresh_env t4; with_servers
keys t4 '' '' 'i' '' 'q'
run install t4
inlog t4 "No tracker is selected" "refuses i while tracker is none"
inlog t4 "ticket-analyzer" "states the cost (start-ticket's first step)"
notinlog t4 "which tool names" "did NOT proceed past selection"
yn "$([ "$(n_files)" = "0" ] && echo 0 || echo 1)" "nothing written"

banner "4b · the explicit 'later' escape"
fresh_env t4b; with_servers
keys t4b '' '' 'i' 'later' '' '' '' '' '' '' '' '' 'y' ''
run install t4b
inlog t4b "which tool names" "'later' lets the install proceed"
inlog t4b "no tracker selected" "tracker stage still warns"
inlog t4b "Install complete" "completes"
fi

# ---------------------------------------------------------------- 5 confirm NO
if want 5; then
banner "5 · confirm stage — answering no"
fresh_env t5; with_servers
keys t5 '' '' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'n'
run install t5
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "exits 0"
inlog t5 "Nothing was written" "says nothing was written"
yn "$([ "$(n_files)" = "0" ] && echo 0 || echo 1)" "CLAUDE_HOME has zero files ($(n_files))"
yn "$([ ! -f "$CH/.playbook-install.json" ] && echo 0 || echo 1)" "no manifest"
inlog t5 "settings.json" "listed the settings.json keys it would add"
inlog t5 "start-ticket.md" "listed destination paths"
inlog t5 "repo-allowlist" "hooks warning names the allowlist"
inlog t5 "github.com/you/weekend-project    yes    yes" "hooks warning shows the worked example line"
inlog t5 "typed by you in your own terminal, is untouched" "says your own git push is unaffected"
fi

# ---------------------------------------------------------------- 6/7 confirm YES
if want 6 || want 7 || want 9 || want 10; then
banner "6 · confirm stage — answering yes (full install)"
fresh_env t6; with_servers
keys t6 '' '' 'r' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run install t6
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "exits 0"
for f in commands/start-ticket.md agents/ticket-analyzer.md hooks/block-dangerous-git.sh \
         repo-allowlist tracker.md CLAUDE.md settings.json .playbook-install.json; do
  yn "$([ -e "$CH/$f" ] && echo 0 || echo 1)" "wrote $f"
done
yn "$([ -d "$CH/skills/adapt-to-stack" ] && echo 0 || echo 1)" "wrote skills/adapt-to-stack"
if grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$CH/repo-allowlist" | grep -q .; then
  fail "repo-allowlist installs EMPTY"
else pass "repo-allowlist installs EMPTY (comments only)"; fi
"$PY" - "$CH/settings.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert d.get("hooks"), "no hooks block"
PY
chk $? "settings.json has a hooks block"
inlog t6 "github.com/you/weekend-project    yes    yes" "closing summary repeats the allowlist line"
# agent(s)" on a correct install. local-markdown reads files off the disk, so the
# deleted tracker token was never a lost grant.
inlog t6 "every installed agent carries the tools its template declared"          "check 1b is GREEN on a clean local-markdown install"
fi

if want 7; then
banner "7 · recommended includes the two new units"
"$PY" - "$CH/.playbook-install.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
u=m["units"]
missing=[k for k in ("skill:adapt-to-stack","command:resume-ticket") if k not in u]
if missing: raise SystemExit("missing: %s" % missing)
PY
chk $? "manifest records skill:adapt-to-stack and command:resume-ticket"
fi

# ---------------------------------------------------------------- 9 backup cap
if want 9; then
banner "9 · backup cap"
mkdir -p "$CH/.playbook-backups"
for i in 01 02 03 04 05 06 07 08 09 10 11 12 13 14; do
  cp "$CH/settings.json" "$CH/.playbook-backups/settings.json.200001$i-000000"
done
BEFORE=$(find "$CH/.playbook-backups" -name 'settings.json.*' 2>/dev/null | wc -l | tr -d ' ')
nokeys bk1; run update bk1
AFTER=$(find "$CH/.playbook-backups" -name 'settings.json.*' 2>/dev/null | wc -l | tr -d ' ')
printf '    (before=%s after=%s)\n' "$BEFORE" "$AFTER"
yn "$([ "$BEFORE" -gt 10 ] && echo 0 || echo 1)" "primed with more than 10 backups ($BEFORE)"
yn "$([ "$AFTER" -le 10 ] && echo 0 || echo 1)" "at most 10 backups remain ($AFTER)"
yn "$([ ! -e "$CH/.playbook-backups/settings.json.20000101-000000" ] && echo 0 || echo 1)" "oldest pruned"
yn "$([ -e "$CH/.playbook-backups/settings.json.20000114-000000" ] && echo 0 || echo 1)" "newest kept"
fi

# ---------------------------------------------------------------- 10 update
if want 10; then
banner "10 · update is non-interactive"
nokeys up1; run update up1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "exit 0 with stdin closed"
inlog up1 "Update complete" "completes"
if grep -qE '\[y/N\]|Write the files|Ready to start' "$LOGS/up1.out"; then
  fail "asked no questions"; else pass "asked no questions"; fi
if grep -q '<workspace>' "$CH/tracker.md"; then fail "tracker values replayed"
else pass "tracker values replayed"; fi
fi

# ---------------------------------------------------------------- 11 remove
if want 11; then
banner "11 · remove reverses a normal install"
fresh_env t11; with_servers
mkdir -p "$CH"
printf '{\n  "model": "my-own-model",\n  "verbose": true\n}\n' > "$CH/settings.json"
keys t11 "${FULL[@]}"; run install t11
yn "$([ -f "$CH/commands/start-ticket.md" ] && echo 0 || echo 1)" "installed first"
keys rm1 '' 'y'; run remove rm1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "remove exits 0"
yn "$([ ! -e "$CH/commands/start-ticket.md" ] && echo 0 || echo 1)" "files gone"
yn "$([ ! -e "$CH/.playbook-install.json" ] && echo 0 || echo 1)" "manifest gone"
"$PY" - "$CH/settings.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert d.get("model")=="my-own-model", "user key lost: %r" % d
assert d.get("verbose") is True, "user key lost: %r" % d
assert "hooks" not in d, "hook entries left behind: %r" % d.get("hooks")
PY
chk $? "hook entries removed, user's own settings keys untouched"
yn "$([ -d "$CH/.playbook-backups" ] && echo 0 || echo 1)" "backups survive remove"
fi

# ---------------------------------------------------------------- 8 adoption
if want 8; then
banner "8 · adopt a hand-install"
fresh_env t8; with_servers
mkdir -p "$CH/commands"
cp "$REPO/templates/commands/end-of-day.md" "$CH/commands/end-of-day.md"
BYHAND=$("$PY" -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/commands/end-of-day.md")
# adopt_screen inserts: confirm(y) + pause, between the hooks pause and "Write these?"
keys t8 '' '' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' '' 'y' "$SANDBOX/ws" ''
run install t8
inlog t8 "Files already here that this script did not install" "offers adoption"
inlog t8 "command:end-of-day" "names the foreign unit"
"$PY" - "$CH/.playbook-install.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
rec=m["units"].get("command:end-of-day")
assert rec, "not recorded in manifest"
assert rec.get("adopted") is True, 'no "adopted": true -- %r' % rec
PY
chk $? 'manifest records "adopted": true'
NOW=$("$PY" -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/commands/end-of-day.md")
yn "$([ "$BYHAND" = "$NOW" ] && echo 0 || echo 1)" "the user's file was not rewritten"
keys rm8 '' 'y'; run remove rm8
inlog rm8 "adopted" "remove reports keep-adopted"
yn "$([ -f "$CH/commands/end-of-day.md" ] && echo 0 || echo 1)" "ADOPTED FILE SURVIVES remove"
yn "$([ ! -f "$CH/commands/start-ticket.md" ] && echo 0 || echo 1)" "non-adopted files still removed"

banner "8b · adoption REFUSED leaves it foreign"
fresh_env t8b; with_servers
mkdir -p "$CH/commands"
cp "$REPO/templates/commands/end-of-day.md" "$CH/commands/end-of-day.md"
keys t8b '' '' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'n' '' 'y' "$SANDBOX/ws" ''
run install t8b
"$PY" - "$CH/.playbook-install.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
assert "command:end-of-day" not in m["units"], "adopted without consent!"
PY
chk $? "declining adoption leaves it out of the manifest"
fi

# ------------------------------------------------- 14 install with no one there
# Regression for #87. A closed stdin used to fall through to the Stage 3 menu and
# re-render until something killed it, because the read helpers end `|| true` and
# an empty answer is legal at every menu here.
if want 14; then
banner "14 - install refuses when stdin is not a terminal"
fresh_env t14; with_servers
run_raw install t14
yn "$([ "$RC" != "0" ] && echo 0 || echo 1)" "exits non-zero (rc=$RC)"
yn "$([ "$(bytes t14)" -lt 20000 ] && echo 0 || echo 1)" "no runaway output ($(bytes t14) bytes)"
yn "$([ "$(n_files)" = "0" ] && echo 0 || echo 1)" "wrote nothing ($(n_files) files)"
inboth t14 "stdin is not a terminal" "says why"
fi

if want 19; then
banner "19 - install.sh refuses the removed mode aliases"
for t19word in uninstall upgrade status; do
  fresh_env "t19$t19word"; with_servers
  run_raw "$t19word" "t19$t19word"
  yn "$([ "$RC" != "0" ] && echo 0 || echo 1)" "$t19word: exits non-zero (rc=$RC)"
  inboth "t19$t19word" "unknown mode: $t19word" "$t19word: says unknown mode"
  yn "$([ "$(n_files)" = "0" ] && echo 0 || echo 1)" "$t19word: wrote nothing ($(n_files) files)"
done
fi

# ------------------------------------------------- 15 remove with no one there
# `confirm` at EOF used to read as "no", so remove exited 0 reporting "nothing
# changed" - a decline the user never made. Silence must not answer for them.
if want 15; then
banner "15 - remove refuses when stdin is not a terminal"
fresh_env t15; with_servers
keys t15 "${FULL[@]}"
run install t15
BEFORE=$(n_files)
yn "$([ "$BEFORE" -gt 0 ] && echo 0 || echo 1)" "installed first ($BEFORE files)"
run_raw remove t15r
yn "$([ "$RC" != "0" ] && echo 0 || echo 1)" "exits non-zero (rc=$RC)"
yn "$([ "$(n_files)" = "$BEFORE" ] && echo 0 || echo 1)" "install intact ($BEFORE -> $(n_files))"
yn "$([ "$(bytes t15r)" -lt 20000 ] && echo 0 || echo 1)" "no runaway output ($(bytes t15r) bytes)"
notinboth t15r "nothing changed" "did not fake a decline the user never made"
inboth t15r "stdin is not a terminal" "says why"
fi

# ---------------------------------------------------------------- 16 apostrophe path
# Git Bash hands arguments to a WINDOWS python and msys rewrites /c/... into C:/... on
# the way — for every argument EXCEPT one containing an apostrophe, which it leaves
# alone. python then reads /c/Users/O'Brien/... as C:\c\Users\O'Brien\... and the
# install dies at discovery, several stages after preflight said everything was fine.
# install.sh does that one conversion itself now, in py().
#
# On Linux and macOS an apostrophe in a path was never a problem, so on those runners
# this section guards the other direction: that the conversion is a no-op there and did
# not break the ordinary case. It is the same assertions either way — which is the
# point, since the bug it covers only exists on one of them.
if want 16; then
banner "16 · a clone and a CLAUDE_HOME with an apostrophe in the path"
fresh_env t16; with_servers
APOS_REPO="$SANDBOX/t16/o'brien clone"
APOS_HOME="$SANDBOX/t16/o'brien home/.claude"
mkdir -p "$APOS_REPO" "$APOS_HOME"
( cd "$REPO" && tar -cf - install.sh install-lib.py templates ) | ( cd "$APOS_REPO" && tar xf - )
keys t16 "${FULL[@]}"
( cd "$APOS_REPO" && HOME="$HOME_DIR" CLAUDE_HOME="$APOS_HOME" PLAYBOOK_SCRIPTED_INPUT=1 \
  bash ./install.sh install ) < "$LOGS/t16.in" > "$LOGS/t16.out" 2>&1
RC=$?
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "install exits 0 (rc=$RC)"
inlog t16 "Install complete" "runs to completion"
notinlog t16 "discovery failed" "discovery does not fail"
notinlog t16 "can't open file" "python opened every path it was handed"
APOS_N=$(find "$APOS_HOME" -type f 2>/dev/null | wc -l | tr -d ' ')
yn "$([ "$APOS_N" -gt 0 ] && echo 0 || echo 1)" "wrote into the apostrophe CLAUDE_HOME ($APOS_N files)"
fi

# ---------------------------------------------------------------- 18 interpreter order
# Both orders exit 0, so an exit code cannot show which python ran. The stub that must
# not win leaves a marker file instead, and the case asserts the marker is absent. The
# paths carry a literal `WindowsApps` component because that is what install.sh keys on;
# nothing here needs Windows.
if want 18; then
banner "18 · a WindowsApps python is tried last, and never dropped"
fresh_env t18
T18="$(cd "$SANDBOX/t18" && pwd)"
T18_MIX="$T18/mixed/WindowsApps"
T18_ONLY="$T18/onlywapps/WindowsApps"
T18_REAL="$T18/realpy"
T18_WMARK="$T18/wapps-ran"
T18_OMARK="$T18/only-ran"
# Stubs exec a resolved path; a by-name python here re-finds the stub and loops.
T18_PY="$("$PY" -c 'import sys; sys.stdout.buffer.write(sys.executable.encode())' 2>/dev/null || true)"
if [ -n "$T18_PY" ] && command -v cygpath >/dev/null 2>&1; then
  T18_PY="$(cygpath -u "$T18_PY" 2>/dev/null || printf '%s' "$T18_PY")"
fi
T18_SETUP=1
if [ -n "$T18_PY" ] && [ "$("$T18_PY" -c 'print(1+1)' 2>/dev/null)" = "2" ] \
   && mkdir -p "$T18_MIX" "$T18_ONLY" "$T18_REAL" \
   && printf '#!/bin/sh\n: > "%s"\nexec "%s" "$@"\n' "$T18_WMARK" "$T18_PY" > "$T18_MIX/python3" \
   && printf '#!/bin/sh\n: > "%s"\nexec "%s" "$@"\n' "$T18_OMARK" "$T18_PY" > "$T18_ONLY/python3" \
   && printf '#!/bin/sh\n: > "%s"\nexec "%s" "$@"\n' "$T18_OMARK" "$T18_PY" > "$T18_ONLY/python" \
   && printf '#!/bin/sh\nexec "%s" "$@"\n' "$T18_PY" > "$T18_REAL/python" \
   && chmod +x "$T18_MIX/python3" "$T18_ONLY/python3" "$T18_ONLY/python" "$T18_REAL/python" \
   && [ "$(PATH="$T18_MIX:$T18_REAL:$PATH" command -v python3 2>/dev/null)" = "$T18_MIX/python3" ] \
   && [ "$(PATH="$T18_MIX:$T18_REAL:$PATH" command -v python 2>/dev/null)" = "$T18_REAL/python" ] \
   && [ "$(PATH="$T18_ONLY:$PATH" command -v python3 2>/dev/null)" = "$T18_ONLY/python3" ] \
   && [ "$(PATH="$T18_ONLY:$PATH" command -v python 2>/dev/null)" = "$T18_ONLY/python" ] \
   && printf '    ok    [setup] stubs written, PATH resolves to them, %s answers\n' "$T18_PY"; then
  T18_SETUP=0
fi
if [ "$T18_SETUP" != "0" ]; then
  fail "[setup] the WindowsApps and real python stubs were not set up (python '$T18_PY')"
else
  # (a) both work; the real python is second on PATH and must still be the one used.
  rm -f "$T18_WMARK"
  ( cd "$REPO" && PATH="$T18_MIX:$T18_REAL:$PATH" HOME="$HOME_DIR" CLAUDE_HOME="$CH" \
    PLAYBOOK_SCRIPTED_INPUT=1 bash ./install.sh list ) \
    < /dev/null > "$LOGS/t18a.out" 2> "$LOGS/t18a.err"
  RC=$?
  yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 beside a WindowsApps python3 (rc=$RC)"
  yn "$([ -e "$T18_WMARK" ] && echo 1 || echo 0)" "a real python beside a working WindowsApps python3 is chosen"

  # (b) the WindowsApps python is the only one. Demoted it still runs; dropped, preflight dies.
  rm -f "$T18_OMARK"
  ( cd "$REPO" && PATH="$T18_ONLY:$PATH" HOME="$HOME_DIR" CLAUDE_HOME="$CH" \
    PLAYBOOK_SCRIPTED_INPUT=1 bash ./install.sh list ) \
    < /dev/null > "$LOGS/t18b.out" 2> "$LOGS/t18b.err"
  RC=$?
  yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 with only a WindowsApps python (rc=$RC)"
  yn "$([ -e "$T18_OMARK" ] && echo 0 || echo 1)" "a WindowsApps python that is the only one is still used"
fi
fi

# ══════════════════════════════════════════════════════════════════════════
# M1-M6 · issue #105 — the memory gate, and the prompt where Enter used to delete
# ══════════════════════════════════════════════════════════════════════════
# Each case names the failure it catches. The bug: placeholder_stage asked for
# memory tool names with no suggested answer under a stage whose opening line says
# "Press Enter at any question to take the suggested answer", so Enter deleted the
# grant from 13 agents and the install reported success anyway.

# run_in DIR MODE LOG — run() with a different $PWD. The project-scope .mcp.json
# case needs one, and it must never be the real repo.
run_in() {
  local dir="$1" mode="$2" log="$3"
  [ -f "$LOGS/$log.in" ] || : > "$LOGS/$log.in"
  ( cd "$dir" && HOME="$HOME_DIR" CLAUDE_HOME="$CH" PLAYBOOK_SCRIPTED_INPUT=1 \
    bash ./install.sh "$mode" ) \
    < "$LOGS/$log.in" > "$LOGS/$log.out" 2> "$LOGS/$log.err"
  RC=$?
  return 0
}

# agents_with_memory — the agent FILENAMES whose template declares a memory tool.
# Derived from the tree on every run. The number was written down by hand twice in
agents_with_memory() {
  ( cd "$REPO" && grep -lE '^tools:.*<memory-(read|write)-tools>' templates/agents/*.md ) \
    | sed 's#.*/##'
}

# memory_keys - MEMORY_SERVER_KEYS read out of install-lib.py, space-separated, so no
# case here keeps its own copy of the list. The file name has a hyphen, hence the
# loader. Bytecode is suppressed so importing it leaves no __pycache__ in the repo.
memory_keys() {
  "$PY" - "$REPO/install-lib.py" <<'PY'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("install_lib", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
sys.stdout.buffer.write((" ".join(mod.MEMORY_SERVER_KEYS) + "\n").encode("utf-8"))
PY
}

# never_install_agents - the agent filenames in install-lib.py's NEVER_INSTALL, one
# per line, read through the same loader as memory_keys.
never_install_agents() {
  "$PY" - "$REPO/install-lib.py" <<'PY'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("install_lib", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
names = sorted(p.split("/", 1)[1] for p in mod.NEVER_INSTALL if p.startswith("agents/"))
sys.stdout.buffer.write("".join(n + "\n" for n in names).encode("utf-8"))
PY
}

# ---------------------------------------------------------------- M1
# Catches: the gate silently regressing to a note(), which is what it was before.
if want M1; then
banner "M1 · the memory gate FIRES (Serena present, no memory server)"
fresh_env m1; with_serena; keys m1 "${FULL[@]}"; run install m1
yn "$([ "$RC" != "0" ] && echo 0 || echo 1)" "exits non-zero (rc=$RC)"
inlog m1 "No memory server is set up on this machine" "prints the refusal"
inlog m1 "mcpServers.forgetful in ~/.claude.json" "prints route A"
inlog m1 "workspace .mcp.json" "prints route B"
inlog m1 "claude.ai connector" "prints route C"
inlog m1 "/mcp in Claude Code" "says how to check it worked"
inlog m1 "docs/shared/03-setup.md" "points at the doc rather than copying it"
# Catches: a refusal that leaves a user with an unlisted server name stuck, and a
# key list typed into install.sh that drifts from MEMORY_SERVER_KEYS.
M1KEYS="$(memory_keys)"
yn "$([ -n "$M1KEYS" ] && echo 0 || echo 1)" "the key list was read from install-lib.py"
inlog m1 "registered as one of: ${M1KEYS// /, }" "names every key the installer looks for"
notinlog m1 "Serena is not set up" "it is the MEMORY gate that fired, not Serena's"
yn "$([ "$(n_files)" = "0" ] && echo 0 || echo 1)" "CLAUDE_HOME still empty ($(n_files) files)"
M1LAST="$(grep -v '^[[:space:]]*$' "$LOGS/m1.out" | tail -1)"
case "$M1LAST" in *".claude/plugins"*) pass "the steps are the LAST thing on screen" ;;
  *) fail "the steps are the LAST thing on screen (last line: $M1LAST)" ;; esac
fi

# ---------------------------------------------------------------- M2
# Catches: project-scope, plugin and connector registrations still reading as
# absent. The old server_registered read ~/.claude.json and nothing else, while
# serena_detect had been reading three locations all along; the connector list is
# the fourth, which NEITHER of them could see.
if want M2; then
banner "M2 · the memory gate PASSES and shows its evidence — all four locations"

banner "M2a · registered globally in ~/.claude.json"
fresh_env m2a; with_servers; keys m2a "${FULL[@]}"; run install m2a
notinlog m2a "No memory server is set up" "gate does not fire"
inlog m2a "found a memory server (forgetful)" "names the server it found"
inlog m2a "mcpServers.forgetful" "shows the evidence"
inlog m2a "Install complete" "runs to completion"

banner "M2b · registered in the PROJECT .mcp.json"
fresh_env m2b; with_serena
M2DIR="$SANDBOX/m2b/clone"; clone_repo "$M2DIR"
cat > "$M2DIR/.mcp.json" <<'JSON'
{ "mcpServers": { "forgetful": { "command": "forgetful-mcp" } } }
JSON
keys m2b "${FULL[@]}"; run_in "$M2DIR" install m2b
notinlog m2b "No memory server is set up" "gate does not fire"
inlog m2b ".mcp.json" "names the file it found it in"
inlog m2b "Install complete" "runs to completion"

banner "M2c · installed as a PLUGIN, with no mcpServers entry at all"
fresh_env m2c; with_serena
mkdir -p "$HOME_DIR/.claude/plugins/cache/forgetful-mcp"
printf '{}\n' > "$HOME_DIR/.claude/plugins/cache/forgetful-mcp/plugin.json"
keys m2c "${FULL[@]}"; run install m2c
notinlog m2c "No memory server is set up" "gate does not fire"
inlog m2c "forgetful plugin files" "shows the evidence"
inlog m2c "Install complete" "runs to completion"

# M2d catches: the gate refusing the maintainer's OWN machine. mcpServers there is
# empty and every server is reached as a claude.ai connector, a route _server_scan
# could not see - so the gate fired on a machine that has a memory server and the
# installer could not be run at all. Second half of the same gap: a connector's
# tools are mcp__claude_ai_<name>__*, so detection alone would still have pre-filled
# names that do not resolve, which is the exact failure #105 exists to remove.
banner "M2d · reached as a claude.ai CONNECTOR, with mcpServers empty"
fresh_env m2d; with_serena; with_memory_connector
keys m2d "${FULL[@]}"; run install m2d
notinlog m2d "No memory server is set up" "gate does not fire"
inlog m2d "claude.ai forgetful" "names the connector it found"
inlog m2d "ever connected" "says the list is historical, not a live connection"
inlog m2d "Install complete" "runs to completion"
M2D_TOOLS="$(sed -n '/^tools:/p' "$CH/agents/context-gatherer.md" 2>/dev/null)"
case "$M2D_TOOLS" in
  *mcp__claude_ai_forgetful__execute_forgetful_tool*)
    pass "the agents carry the CONNECTOR-prefixed tool names" ;;
  *) fail "the agents carry the CONNECTOR-prefixed tool names (tools: $M2D_TOOLS)" ;;
esac
case "$M2D_TOOLS" in
  *mcp__forgetful__*) fail "the bare mcp__forgetful__ form is NOT used for a connector" ;;
  *) pass "the bare mcp__forgetful__ form is NOT used for a connector" ;;
esac
# The agents and the memory-schema skill have to agree. The Forgetful variant
# hardcodes the REGISTERED prefix, so shipping it unrewritten next to
# connector-prefixed agents hands the model a call shape that does not resolve.
M2D_SKILL="$CH/skills/memory-schema/SKILL.md"
if [ -f "$M2D_SKILL" ]; then
  if grep -qF 'mcp__claude_ai_forgetful__execute_forgetful_tool' "$M2D_SKILL"; then
    pass "memory-schema SKILL.md carries the connector prefix too"
  else
    fail "memory-schema SKILL.md carries the connector prefix too"
  fi
  if grep -qF 'mcp__forgetful__' "$M2D_SKILL"; then
    fail "no registered-form prefix left in the memory-schema skill"
  else
    pass "no registered-form prefix left in the memory-schema skill"
  fi
else
  fail "memory-schema SKILL.md is installed (not found at $M2D_SKILL)"
fi

# M2e catches: a memory server other than Forgetful, installed as a plugin, reading
# as absent when the plugin scan matches only the name "forgetful". Nothing is
# pre-filled for such a server, so the two memory answers are typed here; Enter
# would be refused and every answer after it would shift.
banner "M2e · a non-Forgetful memory server installed as a PLUGIN"
fresh_env m2e; with_serena
mkdir -p "$HOME_DIR/.claude/plugins/cache/mem0-mcp"
printf '{}\n' > "$HOME_DIR/.claude/plugins/cache/mem0-mcp/plugin.json"
M2E_KEYS=("${FULL[@]}")
M2E_KEYS[10]='mcp__mem0__search_memory'
M2E_KEYS[11]='mcp__mem0__add_memory'
keys m2e "${M2E_KEYS[@]}"; run install m2e
notinlog m2e "No memory server is set up" "gate does not fire"
inlog m2e "found a memory server (mem0)" "names the server it found"
inlog m2e "mem0 plugin files" "shows the evidence"
inlog m2e "Enter will not answer this one for you" "nothing is pre-filled for a non-Forgetful server"
inlog m2e "Install complete" "runs to completion"

# M2f catches: one key of MEMORY_SERVER_KEYS being left out of the plugin scan. A
# loop is only as tested as its least-tested element, so each key gets its own
# named result. forgetful is the control: it is detected even by a scan that knows
# no other key, so a loop that never ran would show up as a missing line, not a
# green one.
banner "M2f · every memory key is detected as a PLUGIN, and only Forgetful is pre-filled"
M2F_CWD="$SANDBOX/m2f-cwd"
rm -rf "${M2F_CWD:?}" && mkdir -p "$M2F_CWD"
read -ra M2F_KEYS <<< "$(memory_keys)"
yn "$([ "${#M2F_KEYS[@]}" -gt 0 ] && echo 0 || echo 1)" "the key list was read from install-lib.py (${#M2F_KEYS[@]} keys)"
for k in "${M2F_KEYS[@]}"; do
  fresh_env "m2f-$k"
  mkdir -p "$HOME_DIR/.claude/plugins/cache/$k-mcp"
  printf '{}\n' > "$HOME_DIR/.claude/plugins/cache/$k-mcp/plugin.json"
  "$PY" "$REPO/install-lib.py" memory-detect "$HOME_DIR" "$M2F_CWD" > "$LOGS/m2f-$k.json" 2>/dev/null
  M2F_VERDICT="$("$PY" - "$LOGS/m2f-$k.json" "$k" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
key = sys.argv[2]
if not d["server"]:
    out = "undetected"
elif key == "forgetful":
    out = "ok" if d["suggest"] else "no-suggestion"
else:
    out = "ok" if d["suggest"] == "" and d["prefix"] == "" else "prefilled"
sys.stdout.buffer.write(out.encode("utf-8"))
PY
)"
  yn "$([ "$M2F_VERDICT" = "ok" ] && echo 0 || echo 1)" "plugin $k-mcp is detected ($M2F_VERDICT)"
done

# M2g catches: a plugin whose name holds two memory keys being claimed by the wrong
# one. The plugin match is a substring test, so "forgetful-memory-mcp" contains both
# "forgetful" and "memory"; Forgetful has to win, because only Forgetful's tool names
# are pre-filled.
banner "M2g · a plugin name containing both forgetful and memory is Forgetful"
fresh_env m2g
mkdir -p "$HOME_DIR/.claude/plugins/cache/forgetful-memory-mcp"
printf '{}\n' > "$HOME_DIR/.claude/plugins/cache/forgetful-memory-mcp/plugin.json"
"$PY" "$REPO/install-lib.py" memory-detect "$HOME_DIR" "$M2F_CWD" > "$LOGS/m2g.json" 2>/dev/null
M2G_VERDICT="$("$PY" - "$LOGS/m2g.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
if d["server"] != "forgetful":
    out = "server=%s" % d["server"]
elif "mcp__forgetful__" not in d["suggest"]:
    out = "no-forgetful-names"
else:
    out = "ok"
sys.stdout.buffer.write(out.encode("utf-8"))
PY
)"
yn "$([ "$M2G_VERDICT" = "ok" ] && echo 0 || echo 1)" "detected as forgetful with its pre-filled tool names ($M2G_VERDICT)"
fi

# ---------------------------------------------------------------- M8
# Catches: the gate testing the LENGTH OF THE EVIDENCE LIST instead of what was
# found. _server_scan appends an evidence row for an unparseable ~/.claude.json,
# so a corrupt config counted as a reason to continue: the gate passed on a machine
# with no memory server, placeholder_stage announced "found a memory server ()"
# with an empty name and nothing to suggest, and the run died several unanswerable
# prompts later. Serena is supplied as a PLUGIN here so its own gate is satisfied
# and it is provably the MEMORY gate under test.
if want M8; then
banner "M8 · a corrupt ~/.claude.json does not open the memory gate"
fresh_env m8
mkdir -p "$HOME_DIR/.claude/plugins/cache/serena"
printf '{}
' > "$HOME_DIR/.claude/plugins/cache/serena/plugin.json"
printf '{ this is not json
' > "$HOME_DIR/.claude.json"
keys m8 "${FULL[@]}"; run install m8
yn "$([ "$RC" != "0" ] && echo 0 || echo 1)" "exits non-zero (rc=$RC)"
inlog m8 "No memory server is set up on this machine" "the memory gate fires"
notinlog m8 "Serena is not set up" "it is the MEMORY gate that fired, not Serena's"
notinlog m8 "found a memory server" "it never claims to have found one"
yn "$([ "$(n_files)" = "0" ] && echo 0 || echo 1)" "CLAUDE_HOME still empty ($(n_files) files)"
fi

# ---------------------------------------------------------------- M3
# Catches: THE regression this issue is about. Enter at both memory prompts must
# leave the tools IN the agents.
if want M3; then
banner "M3 · Enter FILLS the memory tools — it does not delete them"
# The `e` preset — everything — so this covers every memory-declaring agent the
# installer can place, not just the handful in the default selection: every template
# that declares the tools, less the per-repo generated ones in NEVER_INSTALL.
fresh_env m3; with_servers
keys m3 '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run install m3
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "exits 0"
M3_NEVER="$(never_install_agents | tr '\n' ' ')"
yn "$([ -n "${M3_NEVER// /}" ] && echo 0 || echo 1)" \
   "NEVER_INSTALL's agents were read from install-lib.py (${M3_NEVER% })"
M3_MISSING=""; M3_ABSENT=""; M3_N=0; M3_WANT=0
while IFS= read -r a; do
  [ -n "$a" ] || continue
  case " $M3_NEVER " in *" $a "*) continue ;; esac
  M3_WANT=$((M3_WANT + 1))
  if [ ! -f "$CH/agents/$a" ]; then M3_ABSENT="$M3_ABSENT $a"; continue; fi
  M3_N=$((M3_N + 1))
  grep -qF 'mcp__forgetful__execute_forgetful_tool' "$CH/agents/$a" \
    || M3_MISSING="$M3_MISSING $a"
done < <(agents_with_memory)
yn "$([ "$M3_WANT" -gt 0 ] && [ -z "$M3_ABSENT" ] && echo 0 || echo 1)" \
   "$M3_N of $M3_WANT installable memory-declaring agents installed (absent:${M3_ABSENT:- none})"
yn "$([ -z "$M3_MISSING" ] && echo 0 || echo 1)" "every one of them carries the tools (missing:${M3_MISSING:- none})"
notinlog m3 "take the blank out instead" "the old delete-by-default prompt is gone"
# Only the tools: line. A `<memory-read-tools>` in a BODY is prose that is meant to
# survive. apply_placeholders rewrites name:/model:/tools: lines and, since #135,
# the two token names in BODY_FILL_TOKENS (<strong-model-id>, <fast-model-id>)
# anywhere in the file — nothing else. The memory tokens are NOT in that allow-list,
# so this assertion is the standing proof that the #135 narrowing did not leak: a
# body <memory-read-tools> still survives, and a tools: one still gets filled.
if grep -rqE '^tools:.*<memory-(read|write)-tools>' "$CH/agents" 2>/dev/null; then
  fail "no memory placeholder left unfilled in any tools: line"
else
  pass "no memory placeholder left unfilled in any tools: line"
fi
inlog m3 "Enter never removes a tool grant" "the stage says Enter cannot delete"
fi

# ---------------------------------------------------------------- M4 / M6
# M4 catches: replacing a silent default with a silent impossibility — a deliberate
#             delete must still be available, and must be reported.
# M6 catches: the green tick over a memory-less install. verify_stage's original
#             check greps for blanks STILL THERE, and a deleted token is not one.
if want M4 || want M6; then
banner "M4 · a deliberate delete is still possible, and is REPORTED"
fresh_env m4; with_servers
#        banner discover  5    4   back  i  route pause strong fast  READ  ok WRITE ok  pause hooks  y   ws   pause
keys m4     ''    ''     '5'  '4'  ''  'i'  ''    ''    ''    ''    '-'  'y'  '-' 'y'   ''    ''   'y' "$SANDBOX/ws" ''
run install m4
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "exits 0 (rc=$RC)"
inlog m4 "Removing that grant means" "says what it costs BEFORE accepting"
inlog m4 "context-gatherer" "names the agents that lose it"
inlog m4 "Remove it anyway?" "asks a second time rather than taking it on one key"
if grep -qF 'mcp__forgetful' "$CH/agents/context-gatherer.md" 2>/dev/null; then
  fail "the grant really was removed"; else pass "the grant really was removed"; fi
inlog m4 "You removed <memory-read-tools>" "leaves a TODO naming what was lost"

banner "M6 · verify REPORTS the missing tool grants (same run)"
inlog m4 "Did the tools actually make it into the agents?" "verify asks the presence question"
inlog m4 "NO memory" "verify names memory as missing"
notinlog m4 "yes — nothing was silently dropped" "verify does NOT tick this install off"
fi

# ---------------------------------------------------------------- M5
# Catches: the install shipping a placeholder skill to a user whose exact server
# this repo already documents — the filled-in variant shipped beside it, unused,
# and the `mv` its own header asks for was never performed by anything.
if want M5; then
banner "M5 · the Forgetful memory-schema is the one that loads"
fresh_env m5; with_servers
keys m5 '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run install m5
M5SK="$CH/skills/memory-schema/SKILL.md"
yn "$([ -f "$M5SK" ] && echo 0 || echo 1)" "memory-schema/SKILL.md is installed"
if grep -qF 'Memory schema — Forgetful' "$M5SK" 2>/dev/null; then
  pass "it is the FILLED-IN Forgetful variant"; else fail "it is the FILLED-IN Forgetful variant"; fi
if grep -qE '<[a-z][a-z-]*-tool>' "$M5SK" 2>/dev/null; then
  fail "no <...> placeholder left in it"; else pass "no <...> placeholder left in it"; fi
yn "$([ ! -f "$CH/skills/memory-schema/forgetful.SKILL.md" ] && echo 0 || echo 1)" \
   "the unused duplicate is gone"
inlog m5 "loaded the Forgetful variant" "the installer says it did the swap"
fi

# ---------------------------------------------------------------- P1
# Catches: issue #135, two stacked faults. (1) the two model-id placeholders
# shipped UPPERCASE — this repo's reserved namespace for prose the installer
# must never fill. (2) even lowercased, apply_placeholders only ever
# substitutes into the three frontmatter blocking keys (name/model/tools), so
# a prose BODY token had no path to be filled at all. start-ticket.md already
if want P1; then
banner "P1 · the two model-id tokens are FILLED in command bodies, never left blank"
fresh_env p1; with_servers
keys p1 "${FULL[@]}"; run install p1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "exits 0 (rc=$RC)"

# P1a — whole-file, not anchored to any key: neither lowercase token may
# survive in any installed .md once the install has run. Mirrors verify check 1c
# exactly, INCLUDING its --include='*.md'. That is not a loosening: the fill path
# only ever opens .md, and .playbook-install.json legitimately RECORDS both token
# names as the keys of the answers an update replays, so an unrestricted grep is
# red on a perfectly healthy install and asserts nothing.
if grep -rlE --include='*.md' '<(fast|strong)-model-id>' "$CH" >/dev/null 2>&1; then
  fail "P1a: <fast-model-id> / <strong-model-id> appear nowhere in an installed .md"
else
  pass "P1a: <fast-model-id> / <strong-model-id> appear nowhere in an installed .md"
fi

# P1b — read the RECORDED answer back out of the manifest (same pattern as
# U3/U7/T2 above); do NOT hardcode a model id, so this still means
# something for a user who typed a different id at the prompt.
P1_STRONG="$("$PY" -c 'import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
print(d["config"]["placeholders"]["values"].get("<strong-model-id>",""))' \
  "$CH/.playbook-install.json" 2>/dev/null)"
P1_FAST="$("$PY" -c 'import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
print(d["config"]["placeholders"]["values"].get("<fast-model-id>",""))' \
  "$CH/.playbook-install.json" 2>/dev/null)"
P1_MISSING=""
if [ -z "$P1_STRONG" ] || [ -z "$P1_FAST" ]; then
  P1_MISSING="ids-not-recorded-in-manifest"
else
  for c in start-ticket fix-ticket build-chart-ticket; do
    f="$CH/commands/$c.md"
    if [ ! -f "$f" ]; then P1_MISSING="$P1_MISSING $c(missing-file)"; continue; fi
    grep -qF -- "$P1_STRONG" "$f" || P1_MISSING="$P1_MISSING $c(no-strong)"
    grep -qF -- "$P1_FAST" "$f" || P1_MISSING="$P1_MISSING $c(no-fast)"
  done
fi
yn "$([ -z "$P1_MISSING" ] && echo 0 || echo 1)" \
   "P1b: all three commands carry the RECORDED ids (missing:${P1_MISSING:- none})"

# P1c — Catches a regression back to the deleted-cheap-id design (Q2): the
# fast id must be load-bearing in start-ticket.md too, and the light arm must
# SET a tier rather than disclaim one.
# All THREE commands, not just start-ticket: the light arm was reworded in every
# one of them, so checking a single file leaves two of the three fixes untested.
#
# The negative half matches the wording all three files ACTUALLY had, which is not
# one string. start-ticket.md said "no model override"; fix-ticket.md said "no
# override, so the specialist runs on its own pinned model"; build-chart-ticket.md
# said the same thing with the line wrapped between "no" and "model override".
# So: flatten newlines first (the wrap is real, and a per-line grep cannot see
# across it), and accept the optional "model" word. Keyed to the literal
#
# `tr -d '\r'` BEFORE the flatten, and it is load-bearing, not hygiene. These .md
# files reach the sandbox through git on Windows, so the wrap point is "no\r\n" —
# flattening newlines alone leaves "no\r model override" and the pattern misses the
# one variant the flatten was added for. Watched: with the CR left in, the wrapped
# file passes a check that should fail it.
P1C_MISSING=""
for c in start-ticket fix-ticket build-chart-ticket; do
  f="$CH/commands/$c.md"
  if [ -f "$f" ] && [ -n "$P1_FAST" ] \
     && grep -qF -- "$P1_FAST" "$f" \
     && ! tr -d '\r' <"$f" | tr '\n' ' ' | grep -qE 'no( model)? override'; then
    :
  else
    P1C_MISSING="$P1C_MISSING $c"
  fi
done
if [ -z "$P1C_MISSING" ]; then
  pass "P1c: all three commands carry the fast id, and no light arm still disclaims a tier"
else
  fail "P1c: all three commands carry the fast id, and no light arm still disclaims a tier (missing:$P1C_MISSING)"
fi

# P1d/P1e — verify check 1c's OTHER arm. P1a only ever exercises the green side:
# it proves a healthy install has no surviving token, which is also what a check
# that had been deleted would report. Plant one and watch it fire, the U3 shape.
#
# The two halves are planted separately on purpose, because 1c's fence is the thing
# under test as much as its grep is. $CLAUDE_HOME is NOT the same set as "files this
# installer manages": it also holds projects/**/memory/, the file-based memory store
# the end-of-session writeback lands in. A note about THIS ticket quotes both token
# names, no installer run could ever remove it, and a check that goes permanently red
# over a file nobody can fix teaches the reader to ignore it — with a TODO naming a
# remedy that does nothing. So: an unmanaged .md must NOT fire 1c, and a managed one
# must, in the same install.
mkdir -p "$CH/projects/p1proj/memory"
cat > "$CH/projects/p1proj/memory/session-note.md" <<'MEMO'
# what #135 was about
The installer fills <fast-model-id> and <strong-model-id> in command bodies now.
MEMO
nokeys p1u; run update p1u
inlog p1u "yes — both model ids were filled in everywhere they are named" \
  "P1d: a memory note quoting both tokens does NOT turn 1c red — it is not a managed file"
notinlog p1u "session-note.md" "P1d: and 1c does not name it"

# Now the managed half. Appending makes the file user-edited, so the update leaves it
# alone (skip-edited) and the planted token is still there when verify runs.
# shellcheck disable=SC2016
printf '\nDispatch on the tier `<strong-model-id>` belongs to.\n' >> "$CH/commands/start-ticket.md"
nokeys p1e; run update p1e
inlog p1e "no — these files still say <fast-model-id> or <strong-model-id>:" \
  "P1e: 1c goes RED when a managed command still carries a token"
inlog p1e "commands/start-ticket.md" "P1e: and it names the file"
notinlog p1e "session-note.md" "P1e: still without dragging in the unmanaged memory note"
inlog p1e "Re-run ./install.sh: it asks for both ids" \
  "P1e: the TODO fires, and names a remedy that works on a file the installer owns"
inlog p1e "the installer will not rewrite it" \
  "P1e: and says what to do for the one file re-running cannot fix"
fi

# ---------------------------------------------------------------- MS1
# Catches: an install that writes no per-model effort default, one that overwrites the
# user's own effortLevel, a remove that takes the user's entry out with ours, and an
# alias written as a modelSettings key. The harness reads full model ids there, so an
# alias key is a setting that does nothing, and nothing says so.
#
# ms1_ids — the recorded strong and fast ids, read from the manifest, one per line.
ms1_ids() {
  "$PY" - "$CH/.playbook-install.json" <<'PY'
import json, sys
v = json.load(open(sys.argv[1], encoding="utf-8"))["config"]["placeholders"]["values"]
sys.stdout.buffer.write(("%s\n%s\n" % (v.get("<strong-model-id>", ""), v.get("<fast-model-id>", ""))).encode("utf-8"))
PY
}

# ms1_check PREFIX STRONG FAST STRONG_LEVEL FAST_LEVEL — one named case per printed line.
# A level of "-" asserts the id has no entry at all.
ms1_check() {
  local verdict name
  while IFS='|' read -r verdict name; do
    [ -n "$name" ] || continue
    if [ "$verdict" = ok ]; then pass "$1 $name"; else fail "$1 $name"; fi
  done < <("$PY" - "$CH/settings.json" "$2" "$3" "$4" "$5" <<'PY'
import json, sys
path, strong, fast, level_strong, level_fast = sys.argv[1:6]
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("ok" if ok else "no", name)).encode("utf-8"))
try:
    ms = json.load(open(path, encoding="utf-8")).get("modelSettings") or {}
except Exception as exc:
    ms = {}
    say(False, "settings.json reads as JSON (%s)" % exc)
for mid, level in ((strong, level_strong), (fast, level_fast)):
    got = (ms.get(mid) or {}).get("effortLevel") if mid in ms else None
    if level == "-":
        say(mid not in ms, "modelSettings has no entry for %s (got %r)" % (mid, ms.get(mid)))
    else:
        say(got == level, "modelSettings[%s].effortLevel is %s (got %r)" % (mid, level, got))
say(all("claude-" in k for k in ms), "every modelSettings key is a full model id (%s)" % ", ".join(sorted(ms)))
PY
)
}

# ms1_cr LOG TEXT — the CR bytes on the log lines holding TEXT, read as bytes: Git
# Bash's grep strips CR from what it prints, so a grep pipeline counts 0 either way.
ms1_cr() {
  "$PY" -c 'import sys
t = sys.argv[2].encode("utf-8")
n = sum(l.count(b"\r") for l in open(sys.argv[1], "rb").read().split(b"\n") if t in l)
sys.stdout.buffer.write(str(n).encode("utf-8"))' "$LOGS/$1.out" "$2"
}

if want MS1; then
banner "MS1 · per-model effort defaults are merged into settings.json, never over yours"
fresh_env ms1; with_servers
keys ms1 "${FULL[@]}"; run install ms1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "MS1a exits 0 (rc=$RC)"
MS1_IDS="$(ms1_ids)"
MS1_STRONG="$(printf '%s\n' "$MS1_IDS" | sed -n 1p)"
MS1_FAST="$(printf '%s\n' "$MS1_IDS" | sed -n 2p)"
yn "$([ -n "$MS1_STRONG" ] && [ -n "$MS1_FAST" ] && [ "$MS1_STRONG" != "$MS1_FAST" ] && echo 0 || echo 1)" \
   "MS1a the manifest records two different model ids (strong=$MS1_STRONG fast=$MS1_FAST)"
ms1_check MS1a "$MS1_STRONG" "$MS1_FAST" medium high
inlog ms1 "modelSettings / $MS1_STRONG / effortLevel=medium" \
  "MS1a the confirm screen lists the strong id's effort default before anything is written"
inlog ms1 "modelSettings / $MS1_FAST / effortLevel=high" \
  "MS1a the confirm screen lists the fast id's effort default before anything is written"
inlog ms1 "merged per-model effort defaults (modelSettings)" "MS1a the install says it merged them"

# MS1e — on a settings.json that had no modelSettings, the user then adds an id of their
# own and edits a level we wrote. Remove takes back only the entry still as we wrote it.
"$PY" - "$CH/settings.json" "$MS1_FAST" <<'PY'
import json, sys
path, fast = sys.argv[1:3]
d = json.load(open(path, encoding="utf-8"))
d["modelSettings"]["claude-haiku-5"] = {"effortLevel": "low"}
d["modelSettings"][fast]["effortLevel"] = "xhigh"
json.dump(d, open(path, "w", encoding="utf-8"), indent=2)
PY
keys ms1er '' 'y'; run remove ms1er
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "MS1e remove exits 0 (rc=$RC)"
ms1_check MS1e "$MS1_STRONG" "$MS1_FAST" - xhigh
MS1E_OWN="$("$PY" -c 'import json,sys
d = json.load(open(sys.argv[1], encoding="utf-8")).get("modelSettings") or {}
sys.stdout.buffer.write(str((d.get("claude-haiku-5") or {}).get("effortLevel")).encode("utf-8"))' \
  "$CH/settings.json" 2>/dev/null)"
yn "$([ "$MS1E_OWN" = "low" ] && echo 0 || echo 1)" \
   "MS1e an id the user added after install survives remove (got: $MS1E_OWN)"
inlog ms1er "modelSettings/$MS1_FAST — kept, you changed it since install" \
  "MS1e remove reports the edited level it kept"
yn "$(ms1_cr ms1er "modelSettings/$MS1_FAST")" \
   "MS1e the kept line carries no CR byte"

# MS1f — a hook-less install still merges the effort defaults, and wires no hooks.
fresh_env ms1f; with_servers
keys ms1f '' '' '1' 'n' '' '2' 'n' '' '3' 'n' '1' '' '4' 'n' '' '6' 'n' '' '7' \
          'i' 'later' '' '' '' '' '' '' '' '' 'y' '' '' '' ''
run install ms1f
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "MS1f aligner-only install exits 0 (rc=$RC)"
notinlog ms1f "merged hook wiring" "MS1f setup: no hook wiring is merged"
MS1F_IDS="$(ms1_ids)"
ms1_check MS1f "$(printf '%s\n' "$MS1F_IDS" | sed -n 1p)" "$(printf '%s\n' "$MS1F_IDS" | sed -n 2p)" medium high
inlog ms1f "merged per-model effort defaults (modelSettings)" "MS1f the install says it merged them"
yn "$("$PY" -c 'import json,sys
sys.exit(0 if "hooks" not in json.load(open(sys.argv[1], encoding="utf-8")) else 1)' "$CH/settings.json" 2>/dev/null; echo $?)" \
   "MS1f settings.json carries no hooks key"

# MS1b — the user's own level for the strong id is kept and reported; the fast one lands.
fresh_env ms1b; with_servers
"$PY" - "$CH/settings.json" "$MS1_STRONG" <<'PY'
import json, sys
json.dump({"modelSettings": {sys.argv[2]: {"effortLevel": "low"}}}, open(sys.argv[1], "w", encoding="utf-8"), indent=2)
PY
keys ms1b "${FULL[@]}"; run install ms1b
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "MS1b exits 0 with a modelSettings of the user's own (rc=$RC)"
ms1_check MS1b "$MS1_STRONG" "$MS1_FAST" low high
inlog ms1b "modelSettings/$MS1_STRONG/effortLevel — kept yours ('low')" \
  "MS1b the kept value is reported as a conflict"
yn "$(ms1_cr ms1b "kept yours ('low')")" \
   "MS1b the conflict line carries no CR byte"

# MS1c — remove takes back our entry and only ours.
keys ms1r '' 'y'; run remove ms1r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "MS1c remove exits 0 (rc=$RC)"
ms1_check MS1c "$MS1_STRONG" "$MS1_FAST" low -

# MS1d — an alias is never written as a key; the skip is named.
mkdir -p "$SANDBOX/ms1d"
printf '{"paths": [], "values": {"<strong-model-id>": "opus", "<fast-model-id>": "claude-sonnet-5"}, "delete": []}\n' \
  > "$SANDBOX/ms1d/spec.json"
( cd "$REPO" && "$PY" install-lib.py model-settings "$SANDBOX/ms1d/spec.json" ) \
  > "$SANDBOX/ms1d/out.json" 2> "$SANDBOX/ms1d/err.txt"
chk $? "MS1d install-lib.py model-settings runs (stderr in $SANDBOX/ms1d/err.txt)"
MS1D="$("$PY" -c 'import json,sys
d = json.load(open(sys.argv[1], encoding="utf-8")).get("modelSettings") or {}
sys.stdout.buffer.write((" ".join(sorted(d)) + "|" + str((d.get("claude-sonnet-5") or {}).get("effortLevel"))).encode("utf-8"))' \
  "$SANDBOX/ms1d/out.json" 2>/dev/null)"
yn "$([ "$MS1D" = "claude-sonnet-5|high" ] && echo 0 || echo 1)" \
   "MS1d only the full id is written, at high (got: $MS1D)"
yn "$(grep -qF 'opus' "$SANDBOX/ms1d/err.txt" && echo 0 || echo 1)" \
   "MS1d the skipped alias is named on stderr"

# One model for both tiers is a supported setup; the strong level stands for it.
printf '{"paths": [], "values": {"<strong-model-id>": "claude-x-1", "<fast-model-id>": "claude-x-1"}, "delete": []}\n' \
  > "$SANDBOX/ms1d/same.json"
MS1E="$( ( cd "$REPO" && "$PY" install-lib.py model-settings "$SANDBOX/ms1d/same.json" ) 2>/dev/null \
  | "$PY" -c 'import json,sys
d = json.load(sys.stdin).get("modelSettings") or {}
sys.stdout.buffer.write((" ".join(sorted(d)) + "|" + str((d.get("claude-x-1") or {}).get("effortLevel"))).encode("utf-8"))' 2>/dev/null)"
yn "$([ "$MS1E" = "claude-x-1|medium" ] && echo 0 || echo 1)" \
   "MS1d one id for both tiers gets the strong level (got: $MS1E)"
fi

# ══════════════════════════════════════════════════════════════════════════
# U1-U6 · issue #106 — what an `update` may and may not carry forward
# ══════════════════════════════════════════════════════════════════════════
# `update` is non-interactive: it replays the answers recorded at install time.
# These six ask what that replay is allowed to do. U1/U2 lock in behaviour that
#
# A case that has to MUTATE a template does it in a throwaway clone_repo, never in
# $REPO: the mutation IS the case, and the real tree must not move underneath the
# rest of the suite.
#
# What may NOT be asserted here. Check 3 ("Fill in <repo>") is ALREADY RED on a clean
# sandbox install, so a case keying on the generic tick, on the ✗ line, or on "verify
# is clean" is born green and proves nothing. Every string below is either absent from
# the tree before this branch, or specific to that case's own planted mutation.

# ---------------------------------------------------------------- U1
# Catches: the update path silently no-opping — a fixed template that never
# reaches an install which already exists. This is the question that opened #106.
if want U1; then
banner "U1 · a changed template REACHES an existing install"
fresh_env u1; with_servers; clone_repo "$SANDBOX/u1/repo"
keys u1 "${FULL[@]}"; run_in "$SANDBOX/u1/repo" install u1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
yn "$([ -f "$CH/commands/start-ticket.md" ] && echo 0 || echo 1)" "start-ticket.md is installed"
# Asserted BEFORE the update as well as after: without this, a marker that was
# somehow present all along would read as a successful update.
if grep -qF 'U1-CHANGED-TEMPLATE-MARKER' "$CH/commands/start-ticket.md" 2>/dev/null; then
  fail "the marker is absent before the update"; else pass "the marker is absent before the update"; fi
printf '\nU1-CHANGED-TEMPLATE-MARKER\n' >> "$SANDBOX/u1/repo/templates/commands/start-ticket.md"
nokeys u1u; run_in "$SANDBOX/u1/repo" update u1u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the update exits 0 (rc=$RC)"
if grep -qF 'U1-CHANGED-TEMPLATE-MARKER' "$CH/commands/start-ticket.md" 2>/dev/null; then
  pass "the template edit reached the installed command"
else fail "the template edit reached the installed command"; fi
fi

# ---------------------------------------------------------------- U2
# Catches: an edge-discovery regression stranding every new skill — a skill added
# upstream and referenced from a command you already have, that no update installs.
if want U2; then
banner "U2 · a NEW referenced unit is pulled in by the update"
fresh_env u2; with_servers; clone_repo "$SANDBOX/u2/repo"
keys u2 "${FULL[@]}"; run_in "$SANDBOX/u2/repo" install u2
yn "$([ -f "$CH/commands/start-ticket.md" ] && echo 0 || echo 1)" "start-ticket.md is installed to reference from"
# The skill did not exist when the install ran, so it cannot have been selected:
# the only route into $CLAUDE_HOME is the backtick edge out of start-ticket.
mkdir -p "$SANDBOX/u2/repo/templates/skills/u2-newskill"
printf -- '---\nname: u2-newskill\ndescription: shipped after the install ran\n---\n\nBody.\n' \
  > "$SANDBOX/u2/repo/templates/skills/u2-newskill/SKILL.md"
# The backticks are the POINT — _link_dependencies greps `name` out of the body to
# find the skill edge — so they must reach the file literally, not run as a command.
# shellcheck disable=SC2016
printf '\nLoad the `u2-newskill` skill before starting.\n' \
  >> "$SANDBOX/u2/repo/templates/commands/start-ticket.md"
yn "$([ ! -d "$CH/skills/u2-newskill" ] && echo 0 || echo 1)" "the new skill is absent before the update"
nokeys u2u; run_in "$SANDBOX/u2/repo" update u2u
yn "$([ -f "$CH/skills/u2-newskill/SKILL.md" ] && echo 0 || echo 1)" "the backtick reference dragged the new skill in"
fi

# ---------------------------------------------------------------- U3
# Catches: THE finding this whole ticket exists for — a recorded answer whose
# meaning has since changed, replayed onto every file forever, under a green tick.
if want U3; then
banner "U3 · a STALE recorded answer does not silently survive an update"
fresh_env u3; with_servers
keys u3 "${FULL[@]}"; run install u3
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
# Age the manifest into a pre-#105 install: contract 0, and <memory-read-tools>
# recorded as DELETED. That is exactly what pressing Enter used to record. A fresh
# install stamps contract 2 and FILLS the token in, so this state cannot arise by
# accident here — the gate fires for no other case in this suite.
"$PY" - "$CH/.playbook-install.json" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p, encoding="utf-8"))
ph = m["config"]["placeholders"]
ph["contract"] = 0
ph["values"].pop("<memory-read-tools>", None)
ph["delete"] = sorted(set(ph.get("delete") or []) | {"<memory-read-tools>"})
json.dump(m, open(p, "w", encoding="utf-8"), indent=2)
PY
chk $? "aged the manifest to a pre-#105 install"
nokeys u3u; run update u3u
yn "$([ "$RC" != "0" ] && echo 0 || echo 1)" "the update REFUSES (rc=$RC)"
# inboth, not inlog: contract_gate prints alongside die(), which writes to stderr.
inboth u3u "Some of your recorded answers are no longer valid." "says the recorded answers are stale"
inboth u3u "your recorded answer for <memory-read-tools> was given under older rules" "names the token"
inboth u3u "Run ./install.sh — it asks the question again." "says how to clear it"
# The remedy is a mode `update` never calls require_tty for, so on a machine with no
# terminal the two modes used to refer the user to each other forever. Assert the
# caveat, not just the pointer: the pointer alone is what made the loop.
inboth u3u "That one needs a terminal." "says the remedy needs a terminal"
inboth u3u "update stopped — nothing was written." "stops instead of warning and carrying on"
notinboth u3u "Update complete" "the refused update did not complete"
fi

# ---------------------------------------------------------------- U4
# Catches: a dead command reported as healthy — a unit renamed or removed upstream
# that `list` keeps calling `current`, i.e. "the same version this clone ships".
if want U4; then
banner "U4 · a renamed template leaves an ORPHAN, not a healthy unit"
fresh_env u4; with_servers; clone_repo "$SANDBOX/u4/repo"
keys u4 "${FULL[@]}"; run_in "$SANDBOX/u4/repo" install u4
yn "$([ -f "$CH/commands/fix-ticket.md" ] && echo 0 || echo 1)" "fix-ticket.md is installed to orphan"
mv "$SANDBOX/u4/repo/templates/commands/fix-ticket.md" \
   "$SANDBOX/u4/repo/templates/commands/fix-ticket-renamed.md"
nokeys u4l; run_in "$SANDBOX/u4/repo" list u4l
# grep -E rather than the -F helpers, and the uid on the SAME line as the state:
# list_mode prints the word "orphaned" unconditionally in its legend, so keying on
# the bare word would pass with no row at all.
if grep -qE 'orphaned +command:fix-ticket' "$LOGS/u4l.out"; then
  pass "list reports command:fix-ticket as orphaned"
else fail "list reports command:fix-ticket as orphaned"; fi
if grep -qE 'current +command:fix-ticket' "$LOGS/u4l.out"; then
  fail "list does NOT call the orphan current"; else pass "list does NOT call the orphan current"; fi
nokeys u4u; run_in "$SANDBOX/u4/repo" update u4u
inlog u4u "is still installed, but this clone no longer ships command:fix-ticket" \
  "the update TODO names the orphaned file"
notinlog u4u "Retired units still on disk" "an orphan that is not a retired unit prints no retired-units block"
fi

# ---------------------------------------------------------------- U5
# Catches: a frozen file mentioned once and never again — skip-edited summarised
# into a class that scrolls past, and absent from the list of things left to do.
if want U5; then
banner "U5 · an edited file is raised as a TODO, with its diff command"
fresh_env u5; with_servers
keys u5 "${FULL[@]}"; run install u5
yn "$([ -f "$CH/commands/end-of-day.md" ] && echo 0 || echo 1)" "end-of-day.md is installed to edit"
printf '\nU5-EDITED-BY-HAND-AFTER-INSTALL\n' >> "$CH/commands/end-of-day.md"
nokeys u5u; run update u5u
inlog u5u "was kept, so this update did not refresh it" "the edited file is raised as a TODO"
inlog u5u "See what this clone would have written: diff " "the TODO carries the diff command"
if grep -qF 'U5-EDITED-BY-HAND-AFTER-INSTALL' "$CH/commands/end-of-day.md" 2>/dev/null; then
  pass "skip-edited still means LEFT ALONE"; else fail "skip-edited still means LEFT ALONE"; fi
fi

# ---------------------------------------------------------------- U6
# Catches: a stranded user told a blank exists but not how to fill it. The TODO
# assertion is the real control here: check 1 going red is the setup half, and the
# case proves check 1 was GREEN beforehand so that half is not born red either.
if want U6; then
banner "U6 · a NEW unfilled token tells the user how to answer it"
fresh_env u6; with_servers; clone_repo "$SANDBOX/u6/repo"
keys u6 "${FULL[@]}"; run_in "$SANDBOX/u6/repo" install u6
inlog u6 "yes — nothing left unfilled" "check 1 is GREEN before the token is planted"
# A token this installer never asks about, on a tools: line of ONE agent template.
# Check 1 greps agents/ and skills/ for ^(name|model|tools): lines carrying
# <[a-z][a-z-]*>, so the name must be letters and hyphens only — a digit in it
# would never be seen, and the case would pass for the wrong reason.
sed -i 's/^tools: .*/&, <never-asked-token>/' "$SANDBOX/u6/repo/templates/agents/aligner.md"
if grep -qF '<never-asked-token>' "$SANDBOX/u6/repo/templates/agents/aligner.md"; then
  pass "planted the token in one agent template"; else fail "planted the token in one agent template"; fi
nokeys u6u; run_in "$SANDBOX/u6/repo" update u6u
inlog u6u "no — these blanks were not filled in:" "check 1 goes RED on the update"
inlog u6u "<never-asked-token>" "check 1 names the planted token"
inlog u6u "or re-run ./install.sh, which asks for it." "the TODO says HOW to answer it"
fi


# ---------------------------------------------------------------- U7
# Catches: the contract stamp never being WRITTEN. U3 hand-plants the stamp it then
# reads, so it proves contract_gate REACTS to one and nothing more - delete all three
# stamp sites and U3 still passes, green. The stamp is what tells a later run which
# rules an answer was given under, so an install that never records one is the same
# silent replay this ticket exists to stop, arriving one release later.
if want U7; then
banner "U7 - the contract stamp is WRITTEN by install and SURVIVES an update"
fresh_env u7; with_servers
# Derived, never written down: the expected number comes from the same constant the
# installer stamps with, so a deliberate bump cannot leave this case pinned to an old
# value that then has to be remembered.
WANT_CONTRACT="$("$PY" "$REPO/install-lib.py" contract-version)"
chk $? "read the current contract from install-lib.py"
keys u7 "${FULL[@]}"; run install u7
stamp_is() {
  "$PY" - "$CH/.playbook-install.json" "$WANT_CONTRACT" <<'PYSTAMP'
import json, sys
ph = json.load(open(sys.argv[1], encoding="utf-8"))["config"]["placeholders"]
sys.exit(0 if ph.get("contract") == int(sys.argv[2]) else 1)
PYSTAMP
}
# Locks stamp sites 1 and 2 - placeholder_stage writing it into the spec, and
# write_manifest carrying it from the spec into the manifest. Remove either, red.
stamp_is; chk $? "install RECORDS contract $WANT_CONTRACT in the manifest"
nokeys u7u; run update u7u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the update completes (rc=$RC)"
# Locks stamp site 3 - load_recorded_config carrying it back into the replayed spec.
# Without it this run's own write_manifest resets the stamp to 0, which arms a false
# stop later that cannot be cleared. This is the assertion that fails on its own.
stamp_is; chk $? "the update KEEPS the stamp instead of resetting it"
fi

# ---------------------------------------------------------------- U8
# Catches: an update that leaves retired units on disk without telling the user
# what they are, that nothing was deleted, and where the removal steps live - and
# a block that keeps naming files the user has already deleted.
if want U8; then
banner "U8 · an update over the retired encode units names them and deletes nothing"
fresh_env u8; with_servers; R="$SANDBOX/u8/repo"; clone_repo "$R"
U8_RELS=( commands/encode-codebase.md agents/encoder.md agents/encode-recon.md
          agents/encode-rechecker.md agents/encode-corrector.md skills/memory-tag-lint )
U8_UIDS=( command:encode-codebase agent:encoder agent:encode-recon
          agent:encode-rechecker agent:encode-corrector skill:memory-tag-lint )
# Frontmatter only: no placeholder token and no tools: line, so the stubs add no
# prompt and the key list below stays T5's.
for n in encoder encode-recon encode-rechecker encode-corrector; do
  printf -- '---\nname: %s\ndescription: retired stub\n---\n' "$n" > "$R/templates/agents/$n.md"
done
printf -- '---\ndescription: retired stub\n---\n' > "$R/templates/commands/encode-codebase.md"
mkdir -p "$R/templates/skills/memory-tag-lint"
printf -- '---\nname: memory-tag-lint\ndescription: retired stub\n---\n' \
  > "$R/templates/skills/memory-tag-lint/SKILL.md"
keys u8 '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run_in "$R" install u8
u8_missing=0
for rel in "${U8_RELS[@]}"; do [ -e "$CH/$rel" ] || u8_missing=1; done
yn "$u8_missing" "all six retired stubs are installed"
for rel in "${U8_RELS[@]}"; do rm -rf "${R:?}/templates/$rel"; done

# The installer prints paths through cygpath -m when it has one; match that form.
u8_shown() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
# The per-file orphan to-dos name every path too, so block assertions read only
# from the block's heading to the end of the run.
u8_block() { sed -n '/Retired units still on disk/,$p' "$LOGS/$1.out" > "$LOGS/$1.block"; }
inblock()    { if grep -qF -- "$2" "$LOGS/$1.block"; then pass "$3"; else fail "$3"; fi; }
notinblock() { if grep -qF -- "$2" "$LOGS/$1.block"; then fail "$3"; else pass "$3"; fi; }

nokeys u8u; run_in "$R" update u8u; u8_block u8u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "u8u: the update completes (rc=$RC)"
u8_missing=0
for rel in "${U8_RELS[@]}"; do [ -e "$CH/$rel" ] || u8_missing=1; done
yn "$u8_missing" "u8u: all six retired files are still on disk"
for uid in "${U8_UIDS[@]}"; do
  inlog u8u "is still installed, but this clone no longer ships $uid " \
    "u8u: the per-file orphan to-do names $uid"
done
yn "$([ "$(grep -cF 'Retired units still on disk' "$LOGS/u8u.out")" = "1" ] && echo 0 || echo 1)" \
  "u8u: the retired-units heading appears exactly once"
inblock u8u "Nothing was deleted" "u8u: the block says nothing was deleted"
for rel in "${U8_RELS[@]}"; do
  inblock u8u "$(u8_shown "$CH/$rel")" "u8u: the block lists $rel"
done
inblock u8u "$(u8_shown "$CH/skills/memory-tag-lint") (folder)" "u8u: the skill is marked as a folder"
inblock u8u "## Memory encoding" "u8u: the block names the CLAUDE.md section to delete"
inblock u8u "docs/shared/03-setup.md#retired-units" "u8u: the block points at the removal steps"

rm -f "$CH/agents/encoder.md"; rm -rf "$CH/skills/memory-tag-lint"
nokeys u8p; run_in "$R" update u8p; u8_block u8p
for rel in commands/encode-codebase.md agents/encode-recon.md agents/encode-rechecker.md agents/encode-corrector.md; do
  inblock u8p "$(u8_shown "$CH/$rel")" "u8p: the block still lists $rel"
done
notinblock u8p "$(u8_shown "$CH/agents/encoder.md")" "u8p: the block no longer lists the deleted agents/encoder.md"
notinblock u8p "$(u8_shown "$CH/skills/memory-tag-lint")" "u8p: the block no longer lists the deleted skill folder"

rm -f "$CH/commands/encode-codebase.md" "$CH/agents/encode-recon.md" \
      "$CH/agents/encode-rechecker.md" "$CH/agents/encode-corrector.md"
nokeys u8z; run_in "$R" update u8z
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "u8z: the update completes (rc=$RC)"
notinlog u8z "Retired units still on disk" "u8z: with none on disk the block is not printed"
fi

# ---------------------------------------------------------------- U9
# Catches: a unit this clone no longer ships, whose file the user already deleted,
# kept in the manifest and reported as "still installed" on every run after.
if want U9; then
banner "U9 · an orphan whose file is gone stops being tracked"
fresh_env u9; with_servers; R9="$SANDBOX/u9/repo"; clone_repo "$R9"
keys u9 "${FULL[@]}"; run_in "$R9" install u9
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
yn "$([ -f "$CH/commands/fix-ticket.md" ] && echo 0 || echo 1)" "fix-ticket.md is installed to orphan and keep"
yn "$([ -f "$CH/commands/resume-ticket.md" ] && echo 0 || echo 1)" "resume-ticket.md is installed to orphan and delete"
# New names that do not begin with the old ones, so no assertion keyed on an old uid
# can match the renamed unit.
mv "$R9/templates/commands/fix-ticket.md" "$R9/templates/commands/u9-renamed-fix.md"
mv "$R9/templates/commands/resume-ticket.md" "$R9/templates/commands/u9-renamed-resume.md"
rm -f "$CH/commands/resume-ticket.md"
u9_recorded() {
  "$PY" - "$CH/.playbook-install.json" "$1" <<'PYU9'
import json, sys
sys.exit(0 if sys.argv[2] in json.load(open(sys.argv[1], encoding="utf-8"))["units"] else 1)
PYU9
}
nokeys u9u; run_in "$R9" update u9u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "u9u: the update exits 0 (rc=$RC)"
inlog u9u "no longer tracked (" "u9u: the summary has a no-longer-tracked class"
inlog u9u "command:resume-ticket — its file is gone" "u9u: the summary names command:resume-ticket as gone"
notinlog u9u "is still installed, but this clone no longer ships command:resume-ticket" \
  "u9u: no still-installed to-do for the deleted file"
if u9_recorded command:resume-ticket; then
  fail "u9u: the manifest no longer records command:resume-ticket"
else pass "u9u: the manifest no longer records command:resume-ticket"; fi
yn "$([ -f "$CH/commands/fix-ticket.md" ] && echo 0 || echo 1)" "u9u: fix-ticket.md is still on disk"
u9_recorded command:fix-ticket; chk $? "u9u: the manifest still records command:fix-ticket"
inlog u9u "is still installed, but this clone no longer ships command:fix-ticket" \
  "u9u: the orphan still on disk keeps its to-do"
nokeys u9l; run_in "$R9" list u9l
# Keyed on the uid as U4 does: the legend prints both state words on every run.
if grep -qE '(missing|orphaned) +command:resume-ticket' "$LOGS/u9l.out"; then
  fail "u9l: list shows no row for command:resume-ticket"
else pass "u9l: list shows no row for command:resume-ticket"; fi
nokeys u9v; run_in "$R9" update u9v
notinlog u9v "command:resume-ticket" "u9v: the next update does not mention command:resume-ticket"
notinlog u9v "no longer tracked (" "u9v: the next update has no no-longer-tracked class"
fi

# ---------------------------------------------------------------- S1
# Catches: an installed unit that was upgraded upstream being permanently marked
# skip-edited because its hash on disk differs from rec["hash"]. When the disk
# content matches a past committed revision of the template, list must report
# outdated and update must pull the newest template version.
if want S1; then
banner "S1 · stale via git history is outdated, not edited"
fresh_env s1; with_servers; R="$SANDBOX/s1/repo"; clone_repo "$R"
cp "$REPO/.gitattributes" "$R/"
printf 'S1 second file\n' > "$R/templates/skills/diagnose/notes.md"
s1commit() {
  local msg="$1"
  git -C "$R" add .gitattributes install.sh install-lib.py templates && \
  git -C "$R" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit -qm "$msg" >/dev/null
}
if git -C "$R" init -q && s1commit v1; then
  pass "S1 setup: committed v1"
else
  fail "S1 setup: committed v1"
fi
keys s1 "${FULL[@]}"; run_in "$R" install s1
nokeys s1l0; run_in "$R" list s1l0
if grep -qE 'current +skill:diagnose' "$LOGS/s1l0.out"; then
  pass "S1 precondition: list shows skill:diagnose current"
else
  fail "S1 precondition: list shows skill:diagnose current"
fi
if printf '\nS1-V2-MARKER\n' >> "$R/templates/hooks/block-dangerous-git.sh" && \
   printf '\nS1-V2-MARKER\n' >> "$R/templates/hooks/block-infra-staging.sh" && \
   printf '\nS1-V2-MARKER\n' >> "$R/templates/skills/diagnose/SKILL.md" && \
   s1commit v2 && \
   cp "$R/templates/hooks/block-dangerous-git.sh" "$CH/hooks/" && \
   cp "$R/templates/hooks/block-infra-staging.sh" "$CH/hooks/" && \
   rm -rf "$CH/skills/diagnose" && cp -R "$R/templates/skills/diagnose" "$CH/skills/diagnose" && \
   printf '\nS1-V3-MARKER\n' >> "$R/templates/hooks/block-dangerous-git.sh" && \
   printf '\nS1-V3-MARKER\n' >> "$R/templates/hooks/block-infra-staging.sh" && \
   printf '\nS1-V3-MARKER\n' >> "$R/templates/skills/diagnose/SKILL.md" && \
   s1commit v3; then
  pass "S1 setup: drifted to v2 and v3"
else
  fail "S1 setup: drifted to v2 and v3"
fi
printf '\nS1-HAND-EDIT-NEVER-COMMITTED\n' >> "$CH/hooks/block-secret-staging.sh"
printf '\nS1-HAND-EDIT-NEVER-COMMITTED\n' >> "$CH/skills/tdd/SKILL.md"
nokeys s1l; run_in "$R" list s1l
if grep -qE 'outdated +hook:block-dangerous-git' "$LOGS/s1l.out"; then pass "S1 list reports hook:block-dangerous-git as outdated"; else fail "S1 list reports hook:block-dangerous-git as outdated"; fi
if grep -qE 'outdated +hook:block-infra-staging' "$LOGS/s1l.out"; then pass "S1 list reports hook:block-infra-staging as outdated"; else fail "S1 list reports hook:block-infra-staging as outdated"; fi
if grep -qE 'outdated +skill:diagnose' "$LOGS/s1l.out"; then pass "S1 list reports skill:diagnose as outdated"; else fail "S1 list reports skill:diagnose as outdated"; fi
if grep -qE 'edited +hook:block-secret-staging' "$LOGS/s1l.out"; then pass "S1 list reports hook:block-secret-staging as edited"; else fail "S1 list reports hook:block-secret-staging as edited"; fi
if grep -qE 'edited +skill:tdd' "$LOGS/s1l.out"; then pass "S1 list reports skill:tdd as edited"; else fail "S1 list reports skill:tdd as edited"; fi
nokeys s1u; run_in "$R" update s1u
if grep -qF 'S1-V3-MARKER' "$CH/hooks/block-dangerous-git.sh"; then pass "S1 update wrote V3 hook:block-dangerous-git"; else fail "S1 update wrote V3 hook:block-dangerous-git"; fi
if grep -qF 'S1-V3-MARKER' "$CH/hooks/block-infra-staging.sh"; then pass "S1 update wrote V3 hook:block-infra-staging"; else fail "S1 update wrote V3 hook:block-infra-staging"; fi
if grep -qF 'S1-V3-MARKER' "$CH/skills/diagnose/SKILL.md"; then pass "S1 update wrote V3 skill:diagnose"; else fail "S1 update wrote V3 skill:diagnose"; fi
notinlog s1u "hooks/block-dangerous-git.sh was kept" "S1 update did not keep hook:block-dangerous-git"
notinlog s1u "hooks/block-infra-staging.sh was kept" "S1 update did not keep hook:block-infra-staging"
notinlog s1u "skills/diagnose was kept" "S1 update did not keep skill:diagnose"
if grep -qF 'S1-HAND-EDIT-NEVER-COMMITTED' "$CH/hooks/block-secret-staging.sh"; then pass "S1 marker survived in hook:block-secret-staging"; else fail "S1 marker survived in hook:block-secret-staging"; fi
if grep -qF 'S1-HAND-EDIT-NEVER-COMMITTED' "$CH/skills/tdd/SKILL.md"; then pass "S1 marker survived in skill:tdd"; else fail "S1 marker survived in skill:tdd"; fi
inlog s1u "hooks/block-secret-staging.sh was kept" "S1 update kept edited hook:block-secret-staging"
inlog s1u "skills/tdd was kept" "S1 update kept edited skill:tdd"
fi

# ---------------------------------------------------------------- S2
# Catches: an installed unit that already matches the current template being
# marked skip-edited because rec["hash"] is older. An update must recognise the
# current template even without git history, and a second update must still not
# keep the unit.
if want S2; then
banner "S2 · stale against the current template, no git"
fresh_env s2; with_servers; R="$SANDBOX/s2/repo"; clone_repo "$R"
keys s2 "${FULL[@]}"; run_in "$R" install s2
printf '\nS2-MARKER\n' >> "$R/templates/hooks/block-dangerous-git.sh"
cp "$R/templates/hooks/block-dangerous-git.sh" "$CH/hooks/block-dangerous-git.sh"
printf '\nS2-MARKER\n' >> "$R/templates/skills/diagnose/SKILL.md"
rm -rf "$CH/skills/diagnose" && cp -R "$R/templates/skills/diagnose" "$CH/skills/diagnose"
nokeys s2u; run_in "$R" update s2u
notinlog s2u "hooks/block-dangerous-git.sh was kept" "S2 update did not keep hook:block-dangerous-git"
notinlog s2u "skills/diagnose was kept" "S2 update did not keep skill:diagnose"
nokeys s2u2; run_in "$R" update s2u2
notinlog s2u2 "hooks/block-dangerous-git.sh was kept" "S2 second update did not keep hook:block-dangerous-git"
notinlog s2u2 "skills/diagnose was kept" "S2 second update did not keep skill:diagnose"
fi

# ---------------------------------------------------------------- S3
# Catches: an edited stub skill receiving the generic skip-edited TODO message
# advising the user to copy the new template over by hand. For stub skills that
# users fill in, copying the template over would erase user configuration.
if want S3; then
banner "S3 · stub skill review-guidelines TODO wording"
fresh_env s3; with_servers
keys s3 "${FULL[@]}"; run install s3
yn "$([ -f "$CH/skills/review-guidelines/SKILL.md" ] && echo 0 || echo 1)" "S3 review-guidelines is installed"
printf '\nS3-FILLED-IN-RULE\n' >> "$CH/skills/review-guidelines/SKILL.md"
nokeys s3u; run update s3u
line="$(grep -F "skills/review-guidelines was kept" "$LOGS/s3u.out")"
if [ -n "$line" ]; then pass "S3 TODO line is non-empty"; else fail "S3 TODO line is non-empty"; fi
case "$line" in
  *"It ships as an unfilled stub"*) pass "S3 TODO explains stub skill" ;;
  *) fail "S3 TODO explains stub skill" ;;
esac
case "$line" in
  *"copy the new one over it by hand"*) fail "S3 TODO does not advise copying over" ;;
  *) pass "S3 TODO does not advise copying over" ;;
esac
if grep -qF 'S3-FILLED-IN-RULE' "$CH/skills/review-guidelines/SKILL.md"; then
  pass "S3 filled-in marker survived in review-guidelines"
else
  fail "S3 filled-in marker survived in review-guidelines"
fi
fi

# ---------------------------------------------------------------- S4
# Catches: memory-schema stub skill receiving the generic overwrite advice.
# A user-customized memory schema must be kept on update, and the TODO must
# warn not to overwrite the filled-in stub with the upstream template.
if want S4; then
banner "S4 · stub skill memory-schema TODO wording"
fresh_env s4; with_servers
keys s4 "${FULL[@]}"; run install s4
yn "$([ -f "$CH/skills/memory-schema/SKILL.md" ] && echo 0 || echo 1)" "S4 memory-schema is installed"
printf '\nS4-FILLED-IN-RULE\n' >> "$CH/skills/memory-schema/SKILL.md"
nokeys s4u; run update s4u
line="$(grep -F "skills/memory-schema was kept" "$LOGS/s4u.out")"
if [ -n "$line" ]; then pass "S4 TODO line is non-empty"; else fail "S4 TODO line is non-empty"; fi
case "$line" in
  *"It ships as an unfilled stub"*) pass "S4 TODO explains stub skill" ;;
  *) fail "S4 TODO explains stub skill" ;;
esac
case "$line" in
  *"copy the new one over it by hand"*) fail "S4 TODO does not advise copying over" ;;
  *) pass "S4 TODO does not advise copying over" ;;
esac
if grep -qF 'S4-FILLED-IN-RULE' "$CH/skills/memory-schema/SKILL.md"; then
  pass "S4 filled-in marker survived in memory-schema"
else
  fail "S4 filled-in marker survived in memory-schema"
fi
fi

# ---------------------------------------------------------------- S5
# Catches: a hook equal to the current template only modulo CRLF being listed
# current and never rewritten, so a CRLF shebang ships to Linux and macOS. A
# markdown unit whose only difference is its line endings must stay current and
# untouched.
if want S5; then
banner "S5 · a CRLF-only hook is outdated and rewritten LF; a markdown unit is not"
fresh_env s5; with_servers
keys s5 "${FULL[@]}"; run install s5
S5H="$CH/hooks/block-dangerous-git.sh"; S5M="$CH/skills/diagnose/SKILL.md"
if [ "$(tr -cd '\r' < "$S5H" | wc -c)" -eq 0 ] && sed -i 's/$/\r/' "$S5H" && \
   [ "$(tr -cd '\r' < "$S5H" | wc -c)" -gt 0 ]; then
  pass "S5 setup: hook:block-dangerous-git converted to CRLF"
else
  fail "S5 setup: hook:block-dangerous-git converted to CRLF"
fi
if [ "$(tr -cd '\r' < "$S5M" | wc -c)" -gt 0 ]; then s5flip='s/\r$//'; else s5flip='s/$/\r/'; fi
if cp "$S5M" "$SANDBOX/s5/skill.orig" && sed -i "$s5flip" "$S5M" && \
   ! cmp -s "$S5M" "$SANDBOX/s5/skill.orig" && cp "$S5M" "$SANDBOX/s5/skill.flipped"; then
  pass "S5 setup: skill:diagnose line endings flipped"
else
  fail "S5 setup: skill:diagnose line endings flipped"
fi
nokeys s5l; run list s5l
if grep -qE 'outdated +hook:block-dangerous-git' "$LOGS/s5l.out"; then pass "S5 list reports CRLF hook:block-dangerous-git as outdated"; else fail "S5 list reports CRLF hook:block-dangerous-git as outdated"; fi
if grep -qE 'current +skill:diagnose' "$LOGS/s5l.out"; then pass "S5 list reports flipped skill:diagnose as current"; else fail "S5 list reports flipped skill:diagnose as current"; fi
nokeys s5u; run update s5u
if [ "$(tr -cd '\r' < "$S5H" | wc -c)" -eq 0 ]; then pass "S5 update rewrote hook:block-dangerous-git as LF"; else fail "S5 update rewrote hook:block-dangerous-git as LF"; fi
if cmp -s "$S5H" "$REPO/templates/hooks/block-dangerous-git.sh"; then pass "S5 update wrote the current template to hook:block-dangerous-git"; else fail "S5 update wrote the current template to hook:block-dangerous-git"; fi
notinlog s5u "hooks/block-dangerous-git.sh was kept" "S5 update did not keep hook:block-dangerous-git"
if cmp -s "$S5M" "$SANDBOX/s5/skill.flipped"; then pass "S5 update left flipped skill:diagnose untouched"; else fail "S5 update left flipped skill:diagnose untouched"; fi
notinlog s5u "skills/diagnose was kept" "S5 update did not keep skill:diagnose"
fi

# ---------------------------------------------------------------- S6
# Catches: remove keeping a unit as "you changed it" when its content equals a
# version this clone ships, so an uninstall leaves installer-written files behind.
# A unit edited by hand must still be kept.
if want S6; then
banner "S6 · remove deletes a unit equal to a shipped version, keeps a hand-edited one"
fresh_env s6; with_servers; R="$SANDBOX/s6/repo"; clone_repo "$R"
keys s6 "${FULL[@]}"; run_in "$R" install s6
if printf '\nS6-MARKER\n' >> "$R/templates/hooks/block-dangerous-git.sh" && \
   cp "$R/templates/hooks/block-dangerous-git.sh" "$CH/hooks/block-dangerous-git.sh" && \
   printf '\nS6-MARKER\n' >> "$R/templates/skills/diagnose/SKILL.md" && \
   rm -rf "$CH/skills/diagnose" && cp -R "$R/templates/skills/diagnose" "$CH/skills/diagnose" && \
   printf '\nS6-HAND-EDIT-NEVER-SHIPPED\n' >> "$CH/hooks/block-secret-staging.sh" && \
   printf '\nS6-HAND-EDIT-NEVER-SHIPPED\n' >> "$CH/skills/tdd/SKILL.md"; then
  pass "S6 setup: two units moved to the current template, two edited by hand"
else
  fail "S6 setup: two units moved to the current template, two edited by hand"
fi
keys s6r '' 'y'; run_in "$R" remove s6r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "S6 remove exits 0 (rc=$RC)"
yn "$([ ! -e "$CH/hooks/block-dangerous-git.sh" ] && echo 0 || echo 1)" "S6 remove deleted hook:block-dangerous-git"
yn "$([ ! -e "$CH/skills/diagnose" ] && echo 0 || echo 1)" "S6 remove deleted skill:diagnose"
if grep -qF 'S6-HAND-EDIT-NEVER-SHIPPED' "$CH/hooks/block-secret-staging.sh" 2>/dev/null; then pass "S6 remove kept hand-edited hook:block-secret-staging"; else fail "S6 remove kept hand-edited hook:block-secret-staging"; fi
if grep -qF 'S6-HAND-EDIT-NEVER-SHIPPED' "$CH/skills/tdd/SKILL.md" 2>/dev/null; then pass "S6 remove kept hand-edited skill:tdd"; else fail "S6 remove kept hand-edited skill:tdd"; fi
fi

# ══════════════════════════════════════════════════════════════════════════
# T1-T3 · issues #122 / #123 — what a DELETED tracker token means
# ══════════════════════════════════════════════════════════════════════════
# Two halves of one fact. On a route with no MCP server to name, deleting
# <tracker-read-tools> is the CORRECT answer, so counting it a lost grant painted a
# correct install red (#122). And on the CLI routes that same delete is what left
# @ticket-analyzer — the FIRST agent /start-ticket dispatches — with no way to run a
# single `gh` command (#123). One is a check that has to stop going red; the other
# is a grant that has to start being made.
#
# Test 6 already carries the local-markdown half of #122: it is the FULL keystroke
# path, and a red 1b there now fails that case.

# ---------------------------------------------------------------- T1
# Catches: #123 on the route it was reported from. github is CLI-driven, so the read
# token is correctly deleted and a shell has to arrive in its place.
if want T1 || want T2; then
banner "T1 · the github adapter grants @ticket-analyzer a shell"
fresh_env t1; with_servers
#       banner discover menu:5 tracker:1(github) back i · serena x2 · models x2
#       memory x2 · pause x2 · y · owner · repo · tracker pause
keys t1 '' '' '5' '1' '' 'i' '' '' '' '' '' '' '' '' 'y' 'octo' 'weekend-project' ''
run install t1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "exits 0 (rc=$RC)"
T1TOOLS="$(sed -n '/^tools:/p' "$CH/agents/ticket-analyzer.md" 2>/dev/null)"
printf '    (%s)\n' "$T1TOOLS"
case "$T1TOOLS" in
  *Bash*) pass "@ticket-analyzer installs WITH a shell" ;;
  *)      fail "@ticket-analyzer installs WITH a shell ($T1TOOLS)" ;;
esac
case "$T1TOOLS" in
  *"<tracker-"*) fail "no tracker placeholder left in its tools: line" ;;
  *)             pass "no tracker placeholder left in its tools: line" ;;
esac
inlog t1 "@ticket-analyzer gets Bash" "the installer says it granted the shell"
inlog t1 "every installed agent carries the tools its template declared" \
         "check 1b is GREEN on a correct github install"
notinlog t1 "some agents are installed without a capability" "1b does not go red"
fi

# ---------------------------------------------------------------- T2
# Catches: #122's fix going too far, so that 1b can no longer go red at ALL. The two
# answers differ only in what the audit is told about the route, which is exactly
# what the fix added — so this drives the audit directly over T1's finished install
# rather than re-walking the installer three times to change one argument.
if want T1 || want T2; then
banner "T2 · a genuinely stripped grant still turns 1b red"
T2SPEC="$LOGS/t2-spec.json"
t2audit() {
  "$PY" "$REPO/install-lib.py" audit-grants \
    "$T2SPEC" "$REPO/templates/agents" "$CH/agents" "$1" "$2" \
  | "$PY" -c 'import json,sys;print(len(json.load(sys.stdin)["agents"]))'
}
# T1's OWN recorded answers, read back out of its manifest, so this is the real spec
# rather than a hand-written stand-in that could drift from what install.sh writes.
"$PY" - "$CH/.playbook-install.json" "$T2SPEC" <<'PYT2'
import json, sys
ph = json.load(open(sys.argv[1], encoding="utf-8"))["config"]["placeholders"]
json.dump({"paths": [], "values": ph.get("values", {}), "delete": ph.get("delete", [])},
          open(sys.argv[2], "w"), indent=2)
PYT2
chk $? "read T1's recorded answers back out of its manifest"
yn "$([ "$(t2audit github '')" = "0" ] && echo 0 || echo 1)" \
   "green on the github route it was actually installed with"
# Same files, same answers, a different route: an adapter that reads through an MCP
# server, with one registered. There the delete threw away a grant that could have
# been filled in, and that is a real loss.
yn "$([ "$(t2audit jira tracker)" != "0" ] && echo 0 || echo 1)" \
   "red when the route HAD a server to name and the token was deleted anyway"
# The other half — revert #123's grant by hand, on the route that needs it.
"$PY" - "$CH/agents/ticket-analyzer.md" <<'PYT2B'
import io, sys
p = sys.argv[1]
lines = io.open(p, encoding="utf-8").read().split("\n")
for i, line in enumerate(lines):
    if line.startswith("tools:"):
        lines[i] = ", ".join(x for x in line.split(", ") if x.strip() != "Bash")
io.open(p, "w", encoding="utf-8", newline="").write("\n".join(lines))
PYT2B
chk $? "stripped Bash back out of the installed @ticket-analyzer"
yn "$([ "$(t2audit github '')" != "0" ] && echo 0 || echo 1)" \
   "red once the shell grant is taken away again"
fi

# ---------------------------------------------------------------- T3
# Catches: the #123 token landing on an install that predates it. `update` replays
# the recorded answers and there IS no recorded answer for a token nothing ever asked
# about — so it survives apply-placeholders and reaches the installed file as a
# literal blank, which is the silent-strip failure 1b exists to catch, arriving one
# release later. Installs from a clone carrying the pre-#123 template, then restores
# the current one, which is what a `git pull` does.
if want T3; then
banner "T3 · an update fills a token the recorded answers never had"
fresh_env t3; with_servers; clone_repo "$SANDBOX/t3/repo"
T3TPL="$SANDBOX/t3/repo/templates/agents/ticket-analyzer.md"
"$PY" - "$T3TPL" <<'PYT3A'
import io, sys
p = sys.argv[1]
t = io.open(p, encoding="utf-8", newline="").read()
old = "tools: Read, Write, Glob, <tracker-shell-tools>, <tracker-read-tools>"
new = "tools: Read, Write, Glob, <tracker-read-tools>"
assert t.count(old) == 1, "pre-#123 tools line not found"
io.open(p, "w", encoding="utf-8", newline="").write(t.replace(old, new))
PYT3A
chk $? "planted the pre-#123 template in the clone"
keys t3 '' '' '5' '1' '' 'i' '' '' '' '' '' '' '' '' 'y' 'octo' 'weekend-project' ''
run_in "$SANDBOX/t3/repo" install t3
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
# Rewind the recording too. The pre-#123 installer never wrote an answer for the
# token, either way, so leaving one here would test nothing.
"$PY" - "$CH/.playbook-install.json" <<'PYT3'
import json, sys
p = sys.argv[1]
m = json.load(open(p, encoding="utf-8"))
ph = m["config"]["placeholders"]
ph["values"].pop("<tracker-shell-tools>", None)
ph["delete"] = [x for x in ph.get("delete", []) if x != "<tracker-shell-tools>"]
json.dump(m, open(p, "w", encoding="utf-8"), indent=2)
PYT3
chk $? "rewound the manifest to a pre-#123 recording"
cp "$REPO/templates/agents/ticket-analyzer.md" "$T3TPL"
nokeys t3u; run_in "$SANDBOX/t3/repo" update t3u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the update completes (rc=$RC)"
T3TOOLS="$(sed -n '/^tools:/p' "$CH/agents/ticket-analyzer.md" 2>/dev/null)"
printf '    (%s)\n' "$T3TOOLS"
case "$T3TOOLS" in
  *"<tracker-shell-tools>"*) fail "the token is not left in the file as a literal blank" ;;
  *)                         pass "the token is not left in the file as a literal blank" ;;
esac
case "$T3TOOLS" in
  *Bash*) pass "the update derives the shell grant from the recorded adapter" ;;
  *)      fail "the update derives the shell grant from the recorded adapter ($T3TOOLS)" ;;
esac
notinlog t3u "no — these blanks were not filled in:" "check 1 stays green on the update"
fi


# ---------------------------------------------------------------- T4
# Catches: the #123 backfill reading the adapter from the WRONG place. It took
# config.tracker.adapter from the manifest, while its three sibling call sites all
# read $SELECTED. Those two disagree for any adapter tracker_stage returns early
# on — gitlab-shape has no fields to ask about, so tracker.json is never written
# and write_manifest leaves config.tracker unset. The manifest then answers "",
# which routes to TRACKER_ROUTE_UNKNOWN, whose shell is "" — so the update DELETED
# the shell grant on the one other adapter whose route says Bash. And because the
# backfill only ever adds, the wrong answer would never be revisited.
#
# github cannot catch this: it records an adapter, so both sources agree there.
if want T4; then
banner "T4 · the update reads the adapter from the selection, not the manifest"
fresh_env t4t; with_servers; clone_repo "$SANDBOX/t4t/repo"
T4TPL="$SANDBOX/t4t/repo/templates/agents/ticket-analyzer.md"
"$PY" - "$T4TPL" <<'PYT4'
import io, sys
p = sys.argv[1]
t = io.open(p, encoding="utf-8", newline="").read()
old = "tools: Read, Write, Glob, <tracker-shell-tools>, <tracker-read-tools>"
new = "tools: Read, Write, Glob, <tracker-read-tools>"
assert t.count(old) == 1, "pre-#123 tools line not found"
io.open(p, "w", encoding="utf-8", newline="").write(t.replace(old, new))
PYT4
chk $? "planted the pre-#123 template in the clone"
#       banner discover menu:5 tracker:2(gitlab-shape) back i · serena x2 · models x2
#       memory x2 · pause x2 · y · the shape warning's pause
keys t4t '' '' '5' '2' '' 'i' '' '' '' '' '' '' '' '' 'y' ''
run_in "$SANDBOX/t4t/repo" install t4t
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
yn "$(grep -qF 'tracker:gitlab-shape' "$CH/.playbook-install.json" && echo 0 || echo 1)" \
   "gitlab-shape is the adapter that got installed"
# The precondition that makes the bug reachable, asserted rather than assumed: if
# this ever starts recording an adapter, this case stops testing what it says.
"$PY" - "$CH/.playbook-install.json" <<'PYT4M'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
rec = ((m.get("config") or {}).get("tracker") or {}).get("adapter") or ""
print("recorded adapter: %r" % rec)
sys.exit(1 if rec else 0)
PYT4M
chk $? "gitlab-shape records no config.tracker.adapter (the trap the bug fell into)"
# Rewind the recording, exactly as T3 does — a pre-#123 install wrote no answer.
"$PY" - "$CH/.playbook-install.json" <<'PYT4'
import json, sys
p = sys.argv[1]
m = json.load(open(p, encoding="utf-8"))
ph = m["config"]["placeholders"]
ph["values"].pop("<tracker-shell-tools>", None)
ph["delete"] = [x for x in ph.get("delete", []) if x != "<tracker-shell-tools>"]
json.dump(m, open(p, "w", encoding="utf-8"), indent=2)
PYT4
chk $? "rewound the manifest to a pre-#123 recording"
cp "$REPO/templates/agents/ticket-analyzer.md" "$T4TPL"
nokeys t4u; run_in "$SANDBOX/t4t/repo" update t4u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the update completes (rc=$RC)"
T4TOOLS="$(sed -n '/^tools:/p' "$CH/agents/ticket-analyzer.md" 2>/dev/null)"
printf '    (%s)\n' "$T4TOOLS"
case "$T4TOOLS" in
  *Bash*) pass "gitlab-shape keeps the shell grant its route says it needs" ;;
  *)      fail "gitlab-shape keeps the shell grant its route says it needs ($T4TOOLS)" ;;
esac
case "$T4TOOLS" in
  *"<tracker-shell-tools>"*) fail "no literal blank left in the tools: line" ;;
  *)                         pass "no literal blank left in the tools: line" ;;
esac
notinlog t4u "some agents are installed without a capability" "check 1b stays green"
fi

# ---------------------------------------------------------------- T5
# Catches: the #122-era damage that no re-run ever repaired. An agent whose
# TEMPLATE still declares <memory-read-tools>/<memory-write-tools>, but whose
# INSTALLED file lost the filled-in names to the pre-#105 "Enter deletes a grant"
# bug, plans as `current` — its template has not moved since install — so
# install_stage_body never re-copies it, and apply_placeholders has no literal
# token left in the file to fill. The file stays dead through every update.
#
# Three wrong-greens this case is SHAPED to dodge. Each one goes green with the
# fix reverted, which is why T3/T4 must not be copied blindly here:
#   1. Mutating the template in the clone (the T3/T4 idiom) changes source_hash,
#      flips the unit to `upgrade`, and repairs it by the ORDINARY path. So the
#      clone's template is left byte-identical — and that is asserted, not assumed.
#   2. Damaging the installed file without rewriting the recorded hash classifies
#      it `skip-edited`, which is deliberately left alone. So the manifest's
#      units[<uid>].hash is recomputed with the installer's own hasher.
#   3. Rewinding the recorded memory answer to a delete trips contract_gate and the
#      update refuses — that is U3, not this. So config.placeholders is left alone:
#      this population has a CORRECT recorded answer and a DEAD installed file.
if want T5; then
banner "T5 · an update repairs a memory grant lost from an UNCHANGED agent"
fresh_env t5; with_servers; clone_repo "$SANDBOX/t5/repo"
T5TPL="$SANDBOX/t5/repo/templates/agents/tester.md"
T5AGENT="$CH/agents/tester.md"
# The `e` preset is what installs @tester; its template declares both memory
# tokens, so there is a memory grant in the installed file to lose.
keys t5 '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run_in "$SANDBOX/t5/repo" install t5
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
yn "$([ -f "$T5AGENT" ] && echo 0 || echo 1)" "@tester is installed"
# The healthy file, kept byte for byte. The repair must restore the lost fill and
# change NOTHING ELSE, so the repaired file has to come back identical to this.
cp "$T5AGENT" "$SANDBOX/t5/tester.healthy"
# The damage: the memory tool names deleted from the installed tools: line, which
# is exactly what the pre-#105 run left behind. Only that line, and only within it,
# so the file's line endings and everything else survive untouched.
"$PY" - "$T5AGENT" <<'PYT5D'
import io, re, sys
p = sys.argv[1]
t = io.open(p, encoding="utf-8", newline="").read()
m = re.search(r"(?m)^tools:.*$", t)
assert m, "no tools: line in the installed @tester"
old = m.group(0).rstrip("\r")
names = [x.strip() for x in old.split(":", 1)[1].split(",") if x.strip()]
mem = [x for x in names if x.startswith("mcp__forgetful__")]
assert mem, "the installed tools: line carries no memory tools to strip"
new = "tools: " + ", ".join(x for x in names if x not in mem)
io.open(p, "w", encoding="utf-8", newline="").write(t.replace(old, new, 1))
PYT5D
chk $? "stripped the memory tools out of the installed @tester"
# Control. A blanking step that silently no-ops is a fourth wrong-green.
yn "$(grep -qE '^tools:.*mcp__forgetful__' "$T5AGENT" && echo 1 || echo 0)" \
   "the damaged tools: line really has lost the memory tools"
# Record the damaged file's OWN hash, so it plans `current` and not `skip-edited`.
# source_hash is deliberately left alone: the template did not move.
"$PY" - "$SANDBOX/t5/repo" "$CH/.playbook-install.json" "$T5AGENT" <<'PYT5H'
import json, subprocess, sys
repo, manifest_path, dest = sys.argv[1], sys.argv[2], sys.argv[3]
h = json.loads(subprocess.check_output(
    [sys.executable, repo + "/install-lib.py", "hash", dest]))["hash"]
m = json.load(open(manifest_path, encoding="utf-8"))
units = m["units"]
uids = [u for u, r in units.items()
        if (r.get("dest") or "").replace("\\", "/").endswith("/agents/tester.md")]
assert len(uids) == 1, "expected exactly one recorded unit for @tester: %r" % uids
assert units[uids[0]]["hash"] != h, "the damage did not change the file's hash"
units[uids[0]]["hash"] = h
json.dump(m, open(manifest_path, "w", encoding="utf-8"), indent=2)
sys.stdout.write("    (damaged unit: %s)\n" % uids[0])
PYT5H
chk $? "recorded the damaged file's own hash (so it plans \`current\`, not \`skip-edited\`)"
# A2 — the guard on wrong-green 1. If the template had moved, source_hash would
# differ, the unit would plan `upgrade`, and the ordinary path would repair it.
yn "$(cmp -s "$REPO/templates/agents/tester.md" "$T5TPL" && echo 0 || echo 1)" \
   "the clone's @tester template never moved (so the unit really is \`current\`)"
nokeys t5u; run_in "$SANDBOX/t5/repo" update t5u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the update completes (rc=$RC)"
T5TOOLS="$(sed -n '/^tools:/p' "$T5AGENT" 2>/dev/null)"
printf '    (%s)\n' "$T5TOOLS"
# A1 — THE assertion. Check 1b is not proof: audit_grants matches the first name
# only, so this greps for the tool name itself.
case "$T5TOOLS" in
  *mcp__forgetful__execute_forgetful_tool*)
    pass "A1 the update puts the lost memory grant back into @tester" ;;
  *)
    fail "A1 the update puts the lost memory grant back into @tester ($T5TOOLS)" ;;
esac
# A3 — only ADDS. The repair re-copies from the template and replays the whole
# answer set, so this is where a replayed delete would show up.
case "$T5TOOLS" in
  *mcp__serena__find_symbol*) pass "A3 the repaired @tester kept its non-memory tools" ;;
  *) fail "A3 the repaired @tester kept its non-memory tools ($T5TOOLS)" ;;
esac
case "$(sed -n '/^tools:/p' "$CH/agents/context-gatherer.md" 2>/dev/null)" in
  *mcp__forgetful__execute_forgetful_tool*)
    pass "A3 an undamaged memory agent still carries its memory tools" ;;
  *)
    fail "A3 an undamaged memory agent still carries its memory tools" ;;
esac
# The re-copy is a whole-file rewrite, so "it only added the grant back" has to be
# proved on the whole file, not on the tools: line.
yn "$(cmp -s "$SANDBOX/t5/tester.healthy" "$T5AGENT" && echo 0 || echo 1)" \
   "the repair restored the lost fill and changed nothing else in the file"
# A4
notinlog t5u "some agents are installed without a capability" "check 1b is green on the update"
fi

# ------------------------------------------- T6 the confirm screen tells the truth
# The repair in #127 is computed by install_stage_body. But confirm_stage does NOT
# reuse that plan — it runs the SAME subcommand a second time, from its own inputs,
# to show the user what is about to happen. The two calls drifted: only one of them
# was handed the recorded answers, so a damaged agent was listed on the consent
# screen under the `current` heading — "UNCHANGED — already this version", which at the
# time said "already exactly this version" and nothing else — and was then rewritten by
# the very run the user had just approved. The comment above that call promises the
# opposite in so many words: "the plan shown here is the plan that runs".
#
# It matters on this path specifically, because the interactive ./install.sh re-run
# is the remedy #127 names for the damaged population — so it is the screen every
# affected user reads.
#
# The case asserts AGREEMENT across the two calls, on one damaged unit, in one run:
#   the preview classifies it `upgrade`  AND  the run really does rewrite it.
# The second half is green with the fix reverted. That is deliberate: it is the
# control that proves the two halves DISAGREED, which is the whole bug. Without it
# the case would only be a slower restatement of T5.
#
# The damaged fixture is T5's, step for step (see T5's header for the three
# wrong-greens it is shaped to dodge, all of which apply here too). It is rebuilt
# rather than shared because T5 must answer the confirm screen only once, and this
# case needs a SECOND interactive run against an already-damaged install.
if want T6; then
banner "T6 · the confirm preview and the plan that runs agree about a damaged agent"
fresh_env t6p; with_servers; clone_repo "$SANDBOX/t6p/repo"
T6TPL="$SANDBOX/t6p/repo/templates/agents/tester.md"
T6AGENT="$CH/agents/tester.md"
keys t6p '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run_in "$SANDBOX/t6p/repo" install t6p
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
yn "$([ -f "$T6AGENT" ] && echo 0 || echo 1)" "@tester is installed"
# The damage, exactly as T5 inflicts it: the memory tool names deleted from the
# installed tools: line and nothing else, which is what the pre-#105 run left.
"$PY" - "$T6AGENT" <<'PYT6D'
import io, re, sys
p = sys.argv[1]
t = io.open(p, encoding="utf-8", newline="").read()
m = re.search(r"(?m)^tools:.*$", t)
assert m, "no tools: line in the installed @tester"
old = m.group(0).rstrip("\r")
names = [x.strip() for x in old.split(":", 1)[1].split(",") if x.strip()]
mem = [x for x in names if x.startswith("mcp__forgetful__")]
assert mem, "the installed tools: line carries no memory tools to strip"
new = "tools: " + ", ".join(x for x in names if x not in mem)
io.open(p, "w", encoding="utf-8", newline="").write(t.replace(old, new, 1))
PYT6D
chk $? "stripped the memory tools out of the installed @tester"
yn "$(grep -qE '^tools:.*mcp__forgetful__' "$T6AGENT" && echo 1 || echo 0)" \
   "the damaged tools: line really has lost the memory tools"
"$PY" - "$SANDBOX/t6p/repo" "$CH/.playbook-install.json" "$T6AGENT" <<'PYT6H'
import json, subprocess, sys
repo, manifest_path, dest = sys.argv[1], sys.argv[2], sys.argv[3]
h = json.loads(subprocess.check_output(
    [sys.executable, repo + "/install-lib.py", "hash", dest]))["hash"]
m = json.load(open(manifest_path, encoding="utf-8"))
units = m["units"]
uids = [u for u, r in units.items()
        if (r.get("dest") or "").replace("\\", "/").endswith("/agents/tester.md")]
assert len(uids) == 1, "expected exactly one recorded unit for @tester: %r" % uids
assert units[uids[0]]["hash"] != h, "the damage did not change the file's hash"
units[uids[0]]["hash"] = h
json.dump(m, open(manifest_path, "w", encoding="utf-8"), indent=2)
PYT6H
chk $? "recorded the damaged file's own hash (so it plans \`current\`, not \`skip-edited\`)"
yn "$(cmp -s "$REPO/templates/agents/tester.md" "$T6TPL" && echo 0 || echo 1)" \
   "the clone's @tester template never moved (so the unit really is \`current\`)"
# The remedy #127 tells these users to run: a plain interactive re-install, and the
# consent screen is answered `y` so the preview can be held against what happened.
keys t6p2 '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run_in "$SANDBOX/t6p/repo" install t6p2
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the re-run exits 0 (rc=$RC)"
# THE assertion — which heading of the consent screen owns the damaged agent? The
# headings are matched on ASCII fragments, never on the em-dash, and the tally is
# reset at every "What this will write" so only the final screen is read.
"$PY" - "$LOGS/t6p2.out" <<'PYT6P'
import io, sys
HEADS = [
    ("do not exist yet",             "install"),
    ("will replace them",            "upgrade"),
    ("already exactly this version", "current"),
    ("you edited these yourself",    "skip-edited"),
    ("did not put them there",       "skip-foreign"),
    ("no longer ships them",         "orphan"),
]
cur, hits = None, []
for line in io.open(sys.argv[1], encoding="utf-8", errors="replace"):
    s = line.strip()
    if "last question before anything is written" in s:
        break
    if "What this will write" in s:
        cur, hits = None, []
        continue
    head = [a for frag, a in HEADS if frag in s]
    if head:
        cur = head[0]
        continue
    if cur is not None and s.replace("\\", "/").endswith("/agents/tester.md"):
        hits.append(cur)
sys.stdout.write("    (previewed as: %s)\n" % (", ".join(hits) or "<not listed at all>"))
sys.exit(0 if hits == ["upgrade"] else 1)
PYT6P
chk $? "the confirm preview classifies the damaged @tester as \`upgrade\`"
# The control. This half is green either way: install_stage_body always had the
# answers, so the run rewrites the file whatever the screen said. Holding the two
# together is what makes the screen's claim falsifiable.
case "$(sed -n '/^tools:/p' "$T6AGENT" 2>/dev/null)" in
  *mcp__forgetful__execute_forgetful_tool*)
    pass "the run really did rewrite the file, as the preview must have said" ;;
  *)
    fail "the run really did rewrite the file, as the preview must have said" ;;
esac
fi

# ------------------------------------------- T7 `list` tells the truth as well
# The same divergence as T6, surviving on the OTHER consumer of the plan.
# `list_mode` plans through `pb plan-state`, which was never handed the recorded
# answers, so a unit whose fill was lost prints as `current` — under the legend
# "you have the same version this clone ships" — is left out of the closing
# "N would be brought up to date by: ./install.sh update" count, and is then
# rewritten by the very update the listing said was unnecessary.
#
# `list` writes nothing, so this is a reporting bug and not a data-loss one. It
# matters because `list` is how a user decides whether to run `update` at all.
#
# The damaged fixture is T5's, step for step — see T5's header for the three
# wrong-greens it is shaped to dodge, all of which apply here unchanged. It is
# rebuilt rather than shared for the same reason T6 rebuilds it: T5's damaged
# install is consumed by T5's own update, and this case needs one that is still
# damaged at the moment `list` runs.
#
# The counting assertion is separate from the row assertion on purpose. A row can
# be printed in the right colour and still not reach n_out, and the sentence the
# user acts on is the count, not the row.
if want T7; then
banner "T7 · \`list\` calls a damaged agent outdated, and counts it in the update total"
fresh_env t7; with_servers; clone_repo "$SANDBOX/t7/repo"
T7TPL="$SANDBOX/t7/repo/templates/agents/tester.md"
T7AGENT="$CH/agents/tester.md"
keys t7 '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run_in "$SANDBOX/t7/repo" install t7
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
yn "$([ -f "$T7AGENT" ] && echo 0 || echo 1)" "@tester is installed"
# The damage, exactly as T5 and T6 inflict it: the memory tool names deleted from
# the installed tools: line and nothing else, which is what the pre-#105 run left.
"$PY" - "$T7AGENT" <<'PYT7D'
import io, re, sys
p = sys.argv[1]
t = io.open(p, encoding="utf-8", newline="").read()
m = re.search(r"(?m)^tools:.*$", t)
assert m, "no tools: line in the installed @tester"
old = m.group(0).rstrip("\r")
names = [x.strip() for x in old.split(":", 1)[1].split(",") if x.strip()]
mem = [x for x in names if x.startswith("mcp__forgetful__")]
assert mem, "the installed tools: line carries no memory tools to strip"
new = "tools: " + ", ".join(x for x in names if x not in mem)
io.open(p, "w", encoding="utf-8", newline="").write(t.replace(old, new, 1))
PYT7D
chk $? "stripped the memory tools out of the installed @tester"
yn "$(grep -qE '^tools:.*mcp__forgetful__' "$T7AGENT" && echo 1 || echo 0)" \
   "the damaged tools: line really has lost the memory tools"
# Record the damaged file's OWN hash, so it lists `current` and not `edited`, and
# hand the unit id back out: the row assertions must key on the state AND the uid
# on the same line, because list_mode prints every state word in its legend too.
"$PY" - "$SANDBOX/t7/repo" "$CH/.playbook-install.json" "$T7AGENT" "$SANDBOX/t7/uid.txt" <<'PYT7H'
import json, io, subprocess, sys
repo, manifest_path, dest, uid_out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
h = json.loads(subprocess.check_output(
    [sys.executable, repo + "/install-lib.py", "hash", dest]))["hash"]
m = json.load(open(manifest_path, encoding="utf-8"))
units = m["units"]
uids = [u for u, r in units.items()
        if (r.get("dest") or "").replace("\\", "/").endswith("/agents/tester.md")]
assert len(uids) == 1, "expected exactly one recorded unit for @tester: %r" % uids
assert units[uids[0]]["hash"] != h, "the damage did not change the file's hash"
units[uids[0]]["hash"] = h
json.dump(m, open(manifest_path, "w", encoding="utf-8"), indent=2)
io.open(uid_out, "w", encoding="utf-8").write(uids[0])
PYT7H
chk $? "recorded the damaged file's own hash (so it lists \`current\`, not \`edited\`)"
T7UID="$(cat "$SANDBOX/t7/uid.txt" 2>/dev/null)"
yn "$([ -n "$T7UID" ] && echo 0 || echo 1)" "recovered the damaged unit id from the manifest ($T7UID)"
# The guard on wrong-green 1. If the template had moved, source_hash would differ
# and plan_state would say `outdated` for the ordinary reason, proving nothing.
yn "$(cmp -s "$REPO/templates/agents/tester.md" "$T7TPL" && echo 0 || echo 1)" \
   "the clone's @tester template never moved (so the unit really is version-current)"
nokeys t7l; run_in "$SANDBOX/t7/repo" list t7l
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 (rc=$RC)"
# A1 — the row. grep -E with the uid anchored to end of line, as U4 does: the
# legend line "outdated  = this clone has a newer version..." starts with the same
# word, so the bare word would pass with no row at all.
if grep -qE "outdated +$T7UID\$" "$LOGS/t7l.out"; then
  pass "A1 list reports the damaged $T7UID as \`outdated\`"
else fail "A1 list reports the damaged $T7UID as \`outdated\`"; fi
# A2 — and does not still call it current.
if grep -qE "current +$T7UID\$" "$LOGS/t7l.out"; then
  fail "A2 list does NOT call the damaged $T7UID \`current\`"
else pass "A2 list does NOT call the damaged $T7UID \`current\`"; fi
# A3 — the count. The sentence the user acts on. Held against the rows actually
# printed, so a count that drifts from its own listing fails here too.
"$PY" - "$LOGS/t7l.out" "$T7UID" <<'PYT7C'
import io, re, sys
log, uid = sys.argv[1], sys.argv[2]
rows, counted = [], 0
for line in io.open(log, encoding="utf-8", errors="replace"):
    s = re.sub(r"\x1b\[[0-9;]*m", "", line).strip()
    m = re.match(r"^outdated\s+(\S+)$", s)
    if m:
        rows.append(m.group(1))
    m = re.match(r"^(\d+) would be brought up to date", s)
    if m:
        counted = int(m.group(1))
sys.stdout.write("    (outdated rows: %s | counted: %d)\n"
                 % (", ".join(rows) or "<none>", counted))
sys.exit(0 if uid in rows and counted == len(rows) and counted >= 1 else 1)
PYT7C
chk $? "A3 the damaged unit is counted in \"N would be brought up to date\""
fi

# ══════════════════════════════════════════════════════════════════════════
# R1-R3 · remove: what it keeps, and what it reports
# ══════════════════════════════════════════════════════════════════════════

# ---------------------------------------------------------------- R1
# Catches: remove taking back too much or too little of settings.json — the user's own
# key and hook must come through unchanged, ours must not stay wired — and a recorded
# file left on disk.
if want R1; then
banner "R1 · remove keeps the user's settings and leaves no recorded file behind"
fresh_env r1; with_servers
cat > "$CH/settings.json" <<'JSON'
{
  "model": "r1-own-model",
  "hooks": {
    "PreToolUse": [
      { "matcher": "Write", "hooks": [ { "type": "command", "command": "echo r1-user-hook" } ] }
    ]
  }
}
JSON
"$PY" - "$CH/settings.json" "$SANDBOX/r1/user.json" <<'PYR1A'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
json.dump({"model": d["model"], "hooks": d["hooks"]}, open(sys.argv[2], "w", encoding="utf-8"),
          sort_keys=True)
PYR1A
chk $? "recorded the user's own settings key and hook"
keys r1 "${FULL[@]}"; run install r1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
cp "$CH/.playbook-install.json" "$SANDBOX/r1/manifest.json" 2>/dev/null
chk $? "kept a copy of the manifest"
"$PY" - "$CH/settings.json" <<'PYR1B'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
cmds = [h.get("command", "") for blocks in (d.get("hooks") or {}).values()
        for b in blocks for h in b.get("hooks") or []]
sys.exit(0 if any(c != "echo r1-user-hook" for c in cmds) else 1)
PYR1B
chk $? "the install wired its own hooks in beside the user's"
keys r1r '' 'y'; run remove r1r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "remove exits 0 (rc=$RC)"
"$PY" - "$CH/settings.json" "$SANDBOX/r1/user.json" <<'PYR1C'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
want = json.load(open(sys.argv[2], encoding="utf-8"))
got = {"model": d.get("model"), "hooks": d.get("hooks")}
sys.exit(0 if json.dumps(got, sort_keys=True) == json.dumps(want, sort_keys=True) else 1)
PYR1C
chk $? "the user's key and hook survive exactly, and none of ours is left wired"
"$PY" - "$SANDBOX/r1/manifest.json" <<'PYR1D'
import json, os, sys
units = json.load(open(sys.argv[1], encoding="utf-8"))["units"]
dests = [r["dest"] for r in units.values() if r.get("dest") and not r.get("adopted")]
left = [d for d in dests if os.path.exists(d)]
sys.stdout.write("    (%d recorded, %d left: %s)\n" % (len(dests), len(left), ", ".join(left[:3])))
sys.exit(0 if dests and not left else 1)
PYR1D
chk $? "no file the manifest recorded is left on disk"
fi

# ---------------------------------------------------------------- R2
# Catches: remove deleting a file the user changed after it was installed.
if want R2; then
banner "R2 · remove keeps a file the user changed, and says so"
fresh_env r2; with_servers
keys r2 "${FULL[@]}"; run install r2
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
R2F="$CH/commands/start-ticket.md"
if [ -f "$R2F" ] && printf '\nR2-USER-EDIT\n' >> "$R2F"; then
  pass "R2 setup: edited the installed start-ticket.md"
else
  fail "R2 setup: edited the installed start-ticket.md"
fi
keys r2r '' 'y'; run remove r2r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "remove exits 0 (rc=$RC)"
yn "$(grep -qF 'R2-USER-EDIT' "$R2F" 2>/dev/null && echo 0 || echo 1)" \
   "the edited file is still there with the user's change in it"
yn "$(grep -qE 'command:start-ticket.*\(you changed it\)' "$LOGS/r2r.out" && echo 0 || echo 1)" \
   "the preview names it as kept because the user changed it"
yn "$([ ! -e "$CH/agents/ticket-analyzer.md" ] && echo 0 || echo 1)" "an unedited file beside it is removed"
fi

# ---------------------------------------------------------------- R3
# Catches: remove passing over a unit whose file is already gone without a word.
if want R3; then
banner "R3 · remove reports a unit whose file was already deleted"
fresh_env r3; with_servers
keys r3 "${FULL[@]}"; run install r3
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
if [ -f "$CH/commands/start-ticket.md" ] && rm -f "$CH/commands/start-ticket.md"; then
  pass "R3 setup: deleted the installed start-ticket.md"
else
  fail "R3 setup: deleted the installed start-ticket.md"
fi
keys r3r '' 'y'; run remove r3r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "remove exits 0 (rc=$RC)"
yn "$(grep -qE 'command:start-ticket.*already deleted' "$LOGS/r3r.out" && echo 0 || echo 1)" \
   "the preview names command:start-ticket as already deleted"
inlog r3r "1 already gone from disk, so there is nothing to delete" "the preview counts it"
fi

# ══════════════════════════════════════════════════════════════════════════
# L1-L4 · list and update report the true state
# ══════════════════════════════════════════════════════════════════════════

# ---------------------------------------------------------------- L1
# Catches: `list` offering the other tracker adapters as additions — installing one
# would replace the tracker.md already there, not add to it.
if want L1; then
banner "L1 · list does not offer a second tracker"
fresh_env l1; with_servers
keys l1 "${FULL[@]}"; run install l1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
nokeys l1l; run list l1l
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 (rc=$RC)"
"$PY" - "$LOGS/l1l.out" <<'PYL1'
import io, re, sys
rows, trk, counted = [], [], 0
for line in io.open(sys.argv[1], encoding="utf-8", errors="replace"):
    s = re.sub(r"\x1b\[[0-9;]*m", "", line).strip()
    m = re.match(r"^(\S+)\s+(tracker:\S+)$", s)
    if m:
        trk.append(m.group(1) + " " + m.group(2))
    m = re.match(r"^available\s+(\S+)$", s)
    if m:
        rows.append(m.group(1))
    m = re.match(r"^(\d+) more could be added", s)
    if m:
        counted = int(m.group(1))
offered = [u for u in rows if u.startswith("tracker:")]
sys.stdout.write("    (tracker rows: %s | available: %d | counted: %d)\n"
                 % (", ".join(trk) or "<none>", len(rows), counted))
ok = (any(t.startswith("current ") for t in trk) and not offered
      and rows and counted == len(rows))
sys.exit(0 if ok else 1)
PYL1
chk $? "the installed tracker is listed, no other tracker is available, and the count matches the rows"
fi

# ---------------------------------------------------------------- L2
# Catches: `list` showing a missing unit and not saying what brings it back.
if want L2; then
banner "L2 · list says how to restore a missing unit"
fresh_env l2; with_servers
keys l2 "${FULL[@]}"; run install l2
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
if [ -f "$CH/commands/start-ticket.md" ] && rm -f "$CH/commands/start-ticket.md"; then
  pass "L2 setup: deleted the installed start-ticket.md"
else
  fail "L2 setup: deleted the installed start-ticket.md"
fi
nokeys l2l; run list l2l
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 (rc=$RC)"
yn "$(grep -qE 'missing +command:start-ticket' "$LOGS/l2l.out" && echo 0 || echo 1)" \
   "list reports command:start-ticket as missing"
yn "$(grep -E 'would be restored by:' "$LOGS/l2l.out" | grep -qF './install.sh update' && echo 0 || echo 1)" \
   "list says ./install.sh update would restore it"
nokeys l2u; run update l2u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "update exits 0 (rc=$RC)"
yn "$([ -f "$CH/commands/start-ticket.md" ] && echo 0 || echo 1)" "and update really does put it back"
fi

# ---------------------------------------------------------------- L3
# Catches: update's "N other unit(s) available" disagreeing with the rows `list` prints.
if want L3; then
banner "L3 · update's available count matches list"
fresh_env l3; with_servers
keys l3 "${FULL[@]}"; run install l3
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
nokeys l3u; run update l3u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "update exits 0 (rc=$RC)"
nokeys l3l; run list l3l
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 (rc=$RC)"
"$PY" - "$LOGS/l3u.out" "$LOGS/l3l.out" <<'PYL3'
import io, re, sys
def lines(p):
    for line in io.open(p, encoding="utf-8", errors="replace"):
        yield re.sub(r"\x1b\[[0-9;]*m", "", line).strip()
n = None
for s in lines(sys.argv[1]):
    m = re.match(r"^(\d+) other unit\(s\) available and not installed", s)
    if m:
        n = int(m.group(1))
rows = []
for s in lines(sys.argv[2]):
    m = re.match(r"^available\s+(\S+)$", s)
    if m:
        rows.append(m.group(1))
trk = [u for u in rows if u.startswith("tracker:")]
sys.stdout.write("    (update says: %s | list rows: %d | tracker rows: %s)\n"
                 % (n, len(rows), ", ".join(trk) or "<none>"))
sys.exit(0 if n is not None and n == len(rows) and not trk else 1)
PYL3
chk $? "update's count is present and equals list's available rows, with no tracker among them"
fi

# ---------------------------------------------------------------- L4
# Catches: `list` exiting 0 when the plan-state classifier crashes, so anything keyed
# on the exit code reads a traceback as a successful listing.
if want L4; then
banner "L4 · list exits non-zero when plan-state fails"
fresh_env l4; with_servers
L4R="$SANDBOX/l4/repo"
clone_repo "$L4R"
chk $? "copied the installer into a sandbox clone"
keys l4 "${FULL[@]}"; run_in "$L4R" install l4
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
# Breaks plan-state alone: preflight, discover and the recorded-config read that list
# runs before it still work, so a non-zero exit can only come from plan-state.
"$PY" - "$L4R/install-lib.py" <<'PYL4'
import sys
p = sys.argv[1]
src = open(p, "rb").read()
sig = b"def plan_state(manifest, units, spec=None):\n"
assert src.count(sig) == 1, "plan_state signature not found exactly once"
open(p, "wb").write(src.replace(sig, sig + b"    raise RuntimeError('L4 forced plan-state failure')\n"))
PYL4
chk $? "broke plan-state in the clone's install-lib.py"
nokeys l4l; run_in "$L4R" list l4l
yn "$(grep -qF 'L4 forced plan-state failure' "$LOGS/l4l.err" && echo 0 || echo 1)" \
   "list reached the broken plan-state (its error is on stderr)"
yn "$([ "$RC" != "0" ] && echo 0 || echo 1)" "list exits non-zero (rc=$RC)"
fi

# ══════════════════════════════════════════════════════════════════════════
# SW1-SW2 · picking a different tracker on a re-run
# ══════════════════════════════════════════════════════════════════════════

# ---------------------------------------------------------------- SW1
# Catches: the new adapter planned as a hand-copied stranger, so tracker.md keeps the
# old adapter and the manifest keeps the old record.
if want SW1 || want SW2; then
banner "SW1 · re-running install with jira replaces the local-markdown adapter"
fresh_env sw; with_servers
keys sw1 "${FULL[@]}"; run install sw1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
# One line found only in each adapter, read from the templates, never written here.
"$PY" - "$REPO/templates/trackers/jira.md" "$REPO/templates/trackers/local-markdown.md" \
       "$SANDBOX/sw/markers.txt" <<'PYSW1'
import io, sys
def body(p):
    return [l.strip() for l in io.open(p, encoding="utf-8").read().splitlines()]
j, l = body(sys.argv[1]), body(sys.argv[2])
def only(a, b):
    for s in a:
        if len(s) >= 20 and "<" not in s and ">" not in s and s not in b:
            return s
    raise SystemExit("no line found only in one adapter")
io.open(sys.argv[3], "w", encoding="utf-8", newline="\n").write(only(j, l) + "\n" + only(l, j) + "\n")
PYSW1
chk $? "found a marker line unique to each adapter"
SWJ="$(sed -n 1p "$SANDBOX/sw/markers.txt" 2>/dev/null)"
SWL="$(sed -n 2p "$SANDBOX/sw/markers.txt" 2>/dev/null)"
yn "$(grep -qF -- "$SWL" "$CH/tracker.md" 2>/dev/null && echo 0 || echo 1)" \
   "before the switch tracker.md is the local-markdown adapter"
#       banner discover seeded-pause menu:5 tracker:3(jira) back i · serena x2 · models x2
#       memory x2 · pause x2 · y · jira fields x3 · tracker pause
keys sw2 '' '' '' '5' '3' '' 'i' '' '' '' '' '' '' '' '' 'y' '' '' '' ''
run install sw2
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the second install exits 0 (rc=$RC)"
yn "$(grep -qF -- "$SWJ" "$CH/tracker.md" 2>/dev/null && echo 0 || echo 1)" \
   "tracker.md now carries the jira adapter"
yn "$(grep -qF -- "$SWL" "$CH/tracker.md" 2>/dev/null && echo 1 || echo 0)" \
   "tracker.md no longer carries the local-markdown adapter"
"$PY" - "$CH/.playbook-install.json" <<'PYSW2'
import json, sys
u = json.load(open(sys.argv[1], encoding="utf-8"))["units"]
trk = sorted(k for k in u if k.startswith("tracker:"))
sys.stdout.write("    (recorded trackers: %s)\n" % (", ".join(trk) or "<none>"))
sys.exit(0 if trk == ["tracker:jira"] else 1)
PYSW2
chk $? "the manifest records tracker:jira and nothing for local-markdown"
fi

# ---------------------------------------------------------------- SW2
# Catches: the adopt screen offering the installer's own tracker.md back to the user.
if want SW1 || want SW2; then
banner "SW2 · the switch does not offer tracker.md for adoption"
inlog sw2 "UPDATED — this installer wrote these before" "the confirm screen plans an update"
notinlog sw2 "Files already here that this script did not install" "no adopt screen"
notinlog sw2 "LEFT ALONE — already here, and this installer did not put them there" \
         "nothing is planned as a stranger's file"
yn "$(grep -qE 'tracker:[a-z-]+ — present but not installed' "$LOGS/sw2.out" && echo 1 || echo 0)" \
   "no tracker is reported as present but not installed"
# Unticking plans nothing, so the seeded menu must not promise a removal.
notinlog sw2 "Untick something to have it removed" "the seeded menu does not promise that unticking removes"
inlog sw2 "Unticking leaves it installed" "the seeded menu says unticking leaves a unit installed"
fi

# ══════════════════════════════════════════════════════════════════════════
# SW3-SW5 · a tracker switch from an adopted, an edited or a damaged record
# ══════════════════════════════════════════════════════════════════════════

# sw_markers OUT - line 1 is found only in jira.md, line 2 only in local-markdown.md.
# Read from the templates, never written here.
sw_markers() {
  "$PY" - "$REPO/templates/trackers/jira.md" "$REPO/templates/trackers/local-markdown.md" \
         "$1" <<'PYSWM'
import io, sys
def body(p):
    return [l.strip() for l in io.open(p, encoding="utf-8").read().splitlines()]
j, l = body(sys.argv[1]), body(sys.argv[2])
def only(a, b):
    for s in a:
        if len(s) >= 20 and "<" not in s and ">" not in s and s not in b:
            return s
    raise SystemExit("no line found only in one adapter")
io.open(sys.argv[3], "w", encoding="utf-8", newline="\n").write(only(j, l) + "\n" + only(l, j) + "\n")
PYSWM
}

# sw_state - "<tracker records>|<config.tracker.adapter>". Records are sorted and
# comma-joined, each suffixed "+adopted" when it carries "adopted": true, or with the
# raw value when the key holds anything else.
sw_state() {
  "$PY" - "$CH/.playbook-install.json" <<'PYSWS'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
u = m.get("units") or {}
def tag(k):
    if "adopted" not in u[k]:
        return k
    return k + ("+adopted" if u[k]["adopted"] is True else "+adopted=%r" % (u[k]["adopted"],))
trk = ",".join(tag(k) for k in sorted(u) if k.startswith("tracker:"))
ad = ((m.get("config") or {}).get("tracker") or {}).get("adapter")
sys.stdout.buffer.write(("%s|%s" % (trk, ad)).encode("utf-8"))
PYSWS
}

# ---------------------------------------------------------------- SW3
# Catches: the adopted flag dropped when a switch replaces an adopted tracker, so a
# later remove deletes a tracker.md this script did not write.
if want SW3; then
banner "SW3 · an adopted tracker stays adopted when you switch it"
fresh_env sw3; with_servers
sw_markers "$SANDBOX/sw3/markers.txt"; chk $? "found a marker line unique to each adapter"
SW3J="$(sed -n 1p "$SANDBOX/sw3/markers.txt" 2>/dev/null)"
cp "$REPO/templates/trackers/local-markdown.md" "$CH/tracker.md"
#       banner discover menu:5 tracker:4(local-markdown) back i · serena x2 · models x2
#       memory x2 · pause x2 · adopt y · adopt pause · y · <workspace> · tracker pause
keys sw3 '' '' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' '' 'y' "$SANDBOX/ws" ''
run install sw3
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
SW3S="$(sw_state)"
yn "$([ "${SW3S%%|*}" = "tracker:local-markdown+adopted" ] && echo 0 || echo 1)" \
   "setup: the manifest records tracker:local-markdown as adopted ($SW3S)"
#       banner discover seeded-pause menu:5 tracker:3(jira) back i · serena x2 · models x2
#       memory x2 · pause x2 · y · jira fields x3 · tracker pause
keys sw3j '' '' '' '5' '3' '' 'i' '' '' '' '' '' '' '' '' 'y' '' '' '' ''
run install sw3j
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the switch exits 0 (rc=$RC)"
yn "$(grep -qF -- "$SW3J" "$CH/tracker.md" 2>/dev/null && echo 0 || echo 1)" \
   "tracker.md now carries the jira adapter"
SW3S="$(sw_state)"; SW3T="${SW3S%%|*}"
yn "$([ "${SW3T//+adopted/}" = "tracker:jira" ] && echo 0 || echo 1)" \
   "the manifest records tracker:jira and no other tracker ($SW3S)"
yn "$([ "$SW3T" = "tracker:jira+adopted" ] && echo 0 || echo 1)" \
   "tracker:jira inherits adopted: true from the record it replaced ($SW3S)"
notinlog sw3j "repaired the install record" "a healthy switch prints no manifest repair"
fi

# ---------------------------------------------------------------- SW4
# Catches: a switch onto an edited tracker.md recording the new adapter in the
# manifest config while the file on disk is still the old adapter.
if want SW4; then
banner "SW4 · a switch onto an edited tracker.md keeps the old adapter recorded"
fresh_env sw4; with_servers
sw_markers "$SANDBOX/sw4/markers.txt"; chk $? "found a marker line unique to each adapter"
SW4L="$(sed -n 2p "$SANDBOX/sw4/markers.txt" 2>/dev/null)"
keys sw4 "${FULL[@]}"; run install sw4
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
printf '\nSW4-EDITED-BY-HAND-AFTER-INSTALL\n' >> "$CH/tracker.md"
SW4H="$("$PY" -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/tracker.md")"
#       banner discover seeded-pause menu:5 tracker:3(jira) back i · serena x2 · models x2
#       memory x2 · pause x2 · y · jira fields x3 · tracker pause
keys sw4j '' '' '' '5' '3' '' 'i' '' '' '' '' '' '' '' '' 'y' '' '' '' ''
run install sw4j
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the switch exits 0 (rc=$RC)"
SW4S="$(sw_state)"
yn "$([ "${SW4S#*|}" = "local-markdown" ] && echo 0 || echo 1)" \
   "config.tracker.adapter still says local-markdown ($SW4S)"
inlog sw4j "so it was left alone and jira is not set up" "the run warns that the switch to jira did not happen"
inlog sw4j "and re-run ./install.sh to pick jira again" "the to-do says how to finish the switch"
SW4N="$("$PY" -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/tracker.md")"
yn "$([ "$SW4H" = "$SW4N" ] && echo 0 || echo 1)" "tracker.md is byte-identical to the user's edited file"
yn "$(grep -qF 'SW4-EDITED-BY-HAND-AFTER-INSTALL' "$CH/tracker.md" && grep -qF -- "$SW4L" "$CH/tracker.md" && echo 0 || echo 1)" \
   "tracker.md still carries the user's line and the local-markdown adapter"
yn "$([ "${SW4S%%|*}" = "tracker:local-markdown" ] && echo 0 || echo 1)" \
   "the manifest still records only tracker:local-markdown ($SW4S)"
inlog sw4j "tracker:jira — not set up: tracker.md was edited since install" \
      "the summary lists tracker:jira as left alone and not set up"
notinlog sw4j "tracker:jira — you edited it since install; diff against" \
         "the summary offers no diff against jira.md, which was never installed"
notinlog sw4j "trackers/jira.md — then either keep yours, or copy the new one over it by hand" \
         "no to-do offers jira.md to copy over the local-markdown tracker.md"
# The tracker.md this run left alone is not checked for blanks, so no fill-in to-do
# can name jira's blanks for a file that is still local-markdown.
SW4F="$(grep -F 'Fill in <' "$LOGS/sw4j.out" | grep -F 'tracker.md')"
yn "$([ -z "$SW4F" ] && echo 0 || echo 1)" \
   "no fill-in to-do for the tracker.md that was left alone (${SW4F:-none})"
inlog sw4j "this run did not write it, so its blanks were not checked" \
      "check 3 says it left the edited tracker.md alone"
fi

# ---------------------------------------------------------------- SW5
# Catches: a manifest with two tracker records, one falsely adopted, carried forward
# by update, so remove keeps a tracker.md this script wrote.
if want SW5; then
banner "SW5 · update repairs a manifest with two trackers, one adopted"
fresh_env sw5; with_servers
sw_markers "$SANDBOX/sw5/markers.txt"; chk $? "found a marker line unique to each adapter"
SW5L="$(sed -n 2p "$SANDBOX/sw5/markers.txt" 2>/dev/null)"
keys sw5 "${FULL[@]}"; run install sw5
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
"$PY" - "$REPO/install-lib.py" "$REPO/templates" "$CH" "$CH/.playbook-install.json" <<'PYSW5'
import importlib.util, json, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("pblib", sys.argv[1])
pblib = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pblib)
src = pblib.discover(sys.argv[2], sys.argv[3])["tracker:jira"]["source_hash"]
m = json.load(open(sys.argv[4], encoding="utf-8"))
lm = m["units"]["tracker:local-markdown"]
m["units"]["tracker:jira"] = {"kind": lm["kind"], "dest": lm["dest"], "hash": lm["hash"],
                              "source_hash": src, "adopted": True}
m.setdefault("config", {}).setdefault("tracker", {})["adapter"] = "jira"
with open(sys.argv[4], "w", encoding="utf-8") as fh:
    json.dump(m, fh, indent=2, sort_keys=True)
    fh.write("\n")
PYSW5
chk $? "planted an adopted tracker:jira record over local-markdown's tracker.md"
SW5S="$(sw_state)"
yn "$([ "$SW5S" = "tracker:jira+adopted,tracker:local-markdown|jira" ] && echo 0 || echo 1)" \
   "setup: two tracker records, exactly one adopted ($SW5S)"
nokeys sw5u; run update sw5u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the update exits 0 (rc=$RC)"
inlog sw5u "repaired the install record: dropped tracker:jira" "the update names the repair"
SW5S="$(sw_state)"
yn "$([ "${SW5S%%|*}" = "tracker:local-markdown" ] && echo 0 || echo 1)" \
   "the manifest records only tracker:local-markdown, not adopted ($SW5S)"
yn "$([ "${SW5S#*|}" = "local-markdown" ] && echo 0 || echo 1)" \
   "config.tracker.adapter says local-markdown ($SW5S)"
yn "$(grep -qF -- "$SW5L" "$CH/tracker.md" 2>/dev/null && echo 0 || echo 1)" \
   "tracker.md still carries the local-markdown adapter"
keys sw5r '' 'y'; run remove sw5r
yn "$([ ! -e "$CH/tracker.md" ] && echo 0 || echo 1)" "remove deletes the tracker.md this script wrote"
fi

# ══════════════════════════════════════════════════════════════════════════
# SW6-SW7 · a tracker.md left alone without a tracker switch
# ══════════════════════════════════════════════════════════════════════════

# ---------------------------------------------------------------- SW6
# Catches: a re-run with the SAME tracker after a hand edit to tracker.md being
# treated as a failed switch, telling the user to delete their own file.
if want SW6; then
banner "SW6 · a same-tracker re-run after editing tracker.md is not a switch"
fresh_env sw6; with_servers
keys sw6 "${FULL[@]}"; run install sw6
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
printf '\nSW6-EDITED-BY-HAND-AFTER-INSTALL\n' >> "$CH/tracker.md"
SW6H="$("$PY" -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/tracker.md")"
#       banner discover seeded-pause i · serena x2 · models x2 · memory x2 · pause x2
#       y · tracker pause (<workspace> is already filled, so it is not asked)
keys sw6r '' '' '' 'i' '' '' '' '' '' '' '' '' 'y' ''
run install sw6r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the re-run exits 0 (rc=$RC)"
inlog sw6r "Setting up your tracker" "the re-run reached the tracker stage"
notinlog sw6r "so it was left alone and local-markdown is not set up" \
         "no warning that local-markdown is not set up"
notinlog sw6r "Finish switching to" "no to-do to delete tracker.md and switch"
SW6S="$(sw_state)"
yn "$([ "$SW6S" = "tracker:local-markdown|local-markdown" ] && echo 0 || echo 1)" \
   "the manifest and config.tracker.adapter still say local-markdown ($SW6S)"
SW6N="$("$PY" -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/tracker.md")"
yn "$([ "$SW6H" = "$SW6N" ] && echo 0 || echo 1)" "tracker.md is byte-identical to the user's edited file"
fi

# ---------------------------------------------------------------- SW7
# Catches: a hand-copied tracker.md whose adoption was declined being filled in
# anyway, and its adapter recorded with no tracker unit in the manifest.
if want SW7; then
banner "SW7 · a hand-copied tracker.md left alone is not filled or recorded"
fresh_env sw7; with_servers
cp "$REPO/templates/trackers/local-markdown.md" "$CH/tracker.md"
SW7H="$("$PY" -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/tracker.md")"
#       banner discover menu:5 tracker:4(local-markdown) back i · serena x2 · models x2
#       memory x2 · pause x2 · adopt n · adopt pause · y · <workspace> · tracker pause
keys sw7 '' '' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'n' '' 'y' "$SANDBOX/ws" ''
run install sw7
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
inlog sw7 "Files already here that this script did not install" "the adopt screen offered tracker.md"
inlog sw7 "Left alone. They stay yours" "adoption was declined"
inlog sw7 "LEFT ALONE — already here, and this installer did not put them there" \
      "the confirm screen lists tracker.md as left alone"
SW7N="$("$PY" -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/tracker.md")"
yn "$([ "$SW7H" = "$SW7N" ] && echo 0 || echo 1)" "tracker.md is byte-identical to the hand-copied file"
SW7S="$(sw_state)"
yn "$([ "$SW7S" = "|None" ] && echo 0 || echo 1)" \
   "the manifest records no tracker and no config.tracker.adapter ($SW7S)"
inlog sw7 "this installer did not put it there, so it was left alone and local-markdown is not set up" \
      "the run warns that local-markdown is not set up"
inlog sw7 "say yes when it offers to adopt" "the to-do says how to set the tracker up"
fi

# ---------------------------------------------------------------- SW8
# Catches: the tracker tool grants following the adapter picked in the menu when
# tracker.md is left alone, so agents get github's shell while the file on disk is
# local-markdown, or while no tracker is set up at all. Also jira's "register a
# tracker MCP" to-do surviving into the final list for a jira that is not set up.
if want SW8; then
banner "SW8 · a tracker that is not set up does not decide the tracker grants"
# read=…;shell=… from the recorded answers, then @ticket-analyzer's tools: line.
sw8_grants() {
  "$PY" - "$CH/.playbook-install.json" "$CH/agents/ticket-analyzer.md" <<'PYSW8'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
ph = (m.get("config") or {}).get("placeholders") or {}
out = []
for name, tok in (("read", "<tracker-read-tools>"), ("shell", "<tracker-shell-tools>")):
    if tok in (ph.get("values") or {}):
        out.append("%s=%s" % (name, ph["values"][tok]))
    else:
        out.append("%s=%s" % (name, "deleted" if tok in (ph.get("delete") or []) else "unset"))
tools = [l.rstrip("\r\n") for l in open(sys.argv[2], encoding="utf-8") if l.startswith("tools:")]
out.append("ta=" + (tools[0] if tools else "none"))
sys.stdout.buffer.write(";".join(out).encode("utf-8"))
PYSW8
}
fresh_env sw8; with_servers
keys sw8 "${FULL[@]}"; run install sw8
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
SW8G="$(sw8_grants)"
yn "$(case "$SW8G" in "read=deleted;shell=deleted;ta=tools:"*) echo 0;; *) echo 1;; esac)" \
   "setup: local-markdown recorded no tracker grants ($SW8G)"
printf '\nSW8-EDITED-BY-HAND-AFTER-INSTALL\n' >> "$CH/tracker.md"
#       banner discover seeded-pause menu:5 tracker:1(github) back i · serena x2 · models x2
#       memory x2 · pause x2 · y · tracker pause
keys sw8g '' '' '' '5' '1' '' 'i' '' '' '' '' '' '' '' '' 'y' ''
run install sw8g
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the switch exits 0 (rc=$RC)"
inlog sw8g "so it was left alone and github is not set up" "the switch to github was skipped"
SW8N="$(sw8_grants)"
yn "$([ "$SW8N" = "$SW8G" ] && echo 0 || echo 1)" \
   "the recorded tracker grants and @ticket-analyzer's tools are unchanged ($SW8N)"
notinlog sw8g "some agents are installed without a capability" \
         "the grant check does not call github's shell lost for a tracker that is not set up"
#       the same edited tracker.md, now jira picked: an MCP-route adapter, no tracker MCP
#       banner discover seeded-pause menu:5 tracker:3(jira) back i · serena x2 · models x2
#       memory x2 · pause x2 · y · tracker pause
keys sw8j '' '' '' '5' '3' '' 'i' '' '' '' '' '' '' '' '' 'y' '' '' '' ''
run install sw8j
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the switch to jira exits 0 (rc=$RC)"
inlog sw8j "so it was left alone and jira is not set up" "the switch to jira was skipped"
inlog sw8j "No tracker MCP server is registered" "setup: jira's route was checked for a tracker MCP"
notinlog sw8j "No tracker MCP was found, so <tracker-read-tools> was removed from" \
         "no to-do asks for a tracker MCP for a skipped switch to jira"
#       a hand-copied local-markdown tracker.md, github picked, adoption declined
fresh_env sw8f; with_servers
cp "$REPO/templates/trackers/local-markdown.md" "$CH/tracker.md"
#       banner discover menu:5 tracker:1(github) back i · serena x2 · models x2
#       memory x2 · pause x2 · adopt n · adopt pause · y · tracker pause
keys sw8f '' '' '5' '1' '' 'i' '' '' '' '' '' '' '' '' 'n' '' 'y' ''
run install sw8f
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the declined install exits 0 (rc=$RC)"
inlog sw8f "so it was left alone and github is not set up" "the declined tracker is not set up"
SW8F="$(sw8_grants)"
yn "$(case "$SW8F" in "read=deleted;shell=deleted;ta=tools:"*) echo 0;; *) echo 1;; esac)" \
   "no tracker grants are recorded for a tracker that is not set up ($SW8F)"
yn "$(case "${SW8F#*;ta=}" in *Bash*) echo 1;; *) echo 0;; esac)" \
   "@ticket-analyzer gets no shell for a github tracker that is not set up"
notinlog sw8f "some agents are installed without a capability" \
         "the grant check calls nothing lost when no tracker is set up"
#       a hand-copied local-markdown tracker.md, jira picked, adoption declined
fresh_env sw8k; with_servers
cp "$REPO/templates/trackers/local-markdown.md" "$CH/tracker.md"
#       banner discover menu:5 tracker:3(jira) back i · serena x2 · models x2
#       memory x2 · pause x2 · adopt n · adopt pause · y · tracker pause
keys sw8k '' '' '5' '3' '' 'i' '' '' '' '' '' '' '' '' 'n' '' 'y' '' '' '' ''
run install sw8k
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the declined jira install exits 0 (rc=$RC)"
inlog sw8k "so it was left alone and jira is not set up" "the declined jira tracker is not set up"
inlog sw8k "No tracker MCP server is registered" "setup: the declined jira's route was checked for a tracker MCP"
notinlog sw8k "No tracker MCP was found, so <tracker-read-tools> was removed from" \
         "no to-do asks for a tracker MCP for a declined jira"
#       a fresh jira install with no tracker MCP: the to-do stays
fresh_env sw8n; with_servers
#       banner discover menu:5 tracker:3(jira) back i · serena x2 · models x2
#       memory x2 · pause x2 · y · jira fields x3 · tracker pause
keys sw8n '' '' '5' '3' '' 'i' '' '' '' '' '' '' '' '' 'y' '' '' '' ''
run install sw8n
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the jira install exits 0 (rc=$RC)"
notinlog sw8n "is not set up" "setup: the jira install set the tracker up"
inlog sw8n "No tracker MCP was found, so <tracker-read-tools> was removed from" \
      "a jira install with no tracker MCP keeps the to-do to register one"
fi

# ══════════════════════════════════════════════════════════════════════════
# ST1-ST4 · a filled, rewritten or swapped file that only drifted is not "edited"
# ══════════════════════════════════════════════════════════════════════════

# ---------------------------------------------------------------- ST1
# Catches: a placeholder-filled unit whose line endings changed being called edited,
# and then kept by remove as the user's work.
if want ST1; then
banner "ST1 · a filled agent that only changed line endings is current"
fresh_env st1; with_servers
keys st1 "${FULL[@]}"; run install st1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
"$PY" "$REPO/install-lib.py" discover "$REPO/templates" "$CH" > "$SANDBOX/st1/units.json"
chk $? "discovered the units"
"$PY" - "$SANDBOX/st1/units.json" "$CH/.playbook-install.json" "$SANDBOX/st1/uid.txt" <<'PYST1'
import hashlib, io, json, sys
units = json.load(open(sys.argv[1], encoding="utf-8"))
m = json.load(open(sys.argv[2], encoding="utf-8"))
assert (m.get("config") or {}).get("placeholders", {}).get("values"), "no recorded answers"
def lf(p):
    return open(p, "rb").read().replace(b"\r\n", b"\n")
pick = None
for uid, rec in sorted(m["units"].items()):
    u = units.get(uid)
    if u and u["kind"] == "agent" and rec["dest"].endswith(".md") and lf(rec["dest"]) != lf(u["src"]):
        pick = (uid, rec)
        break
assert pick, "no recorded agent differs from its template"
uid, rec = pick
data = open(rec["dest"], "rb").read()
flip = data.replace(b"\r\n", b"\n") if b"\r\n" in data else data.replace(b"\n", b"\r\n")
open(rec["dest"], "wb").write(flip)
assert hashlib.sha256(flip).hexdigest() != rec["hash"], "flipping endings did not change the hash"
io.open(sys.argv[3], "w", encoding="utf-8", newline="\n").write(uid + "\t" + rec["dest"])
PYST1
chk $? "flipped the line endings of a filled agent (so its hash no longer matches)"
ST1UID="$(cut -f1 "$SANDBOX/st1/uid.txt" 2>/dev/null)"
ST1DEST="$(cut -f2 "$SANDBOX/st1/uid.txt" 2>/dev/null)"
nokeys st1l; run list st1l
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 (rc=$RC)"
yn "$(grep -qE "current +$ST1UID\$" "$LOGS/st1l.out" && echo 0 || echo 1)" "list reports $ST1UID as current"
yn "$(grep -qE "edited +$ST1UID\$" "$LOGS/st1l.out" && echo 1 || echo 0)" "list does not call $ST1UID edited"
keys st1r '' 'y'; run remove st1r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "remove exits 0 (rc=$RC)"
yn "$([ -n "$ST1DEST" ] && [ ! -e "$ST1DEST" ] && echo 0 || echo 1)" "remove deletes it rather than keeping it as edited"
fi

# ---------------------------------------------------------------- ST2
# Catches: a Serena-rewritten unit being called edited when the rewrite is on record.
if want ST2; then
banner "ST2 · an agent with the recorded Serena prefix rewrite is current"
fresh_env st2; with_servers
keys st2 "${FULL[@]}"; run install st2
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
"$PY" "$REPO/install-lib.py" discover "$REPO/templates" "$CH" > "$SANDBOX/st2/units.json"
chk $? "discovered the units"
"$PY" - "$SANDBOX/st2/units.json" "$CH/.playbook-install.json" "$SANDBOX/st2" <<'PYST2A'
import io, json, os, sys
units = json.load(open(sys.argv[1], encoding="utf-8"))
m = json.load(open(sys.argv[2], encoding="utf-8"))
pick = None
for uid, rec in sorted(m["units"].items()):
    u = units.get(uid)
    if u and u["kind"] == "agent" and "mcp__serena__" in io.open(rec["dest"], encoding="utf-8").read():
        pick = (uid, rec["dest"])
        break
assert pick, "no recorded agent carries mcp__serena__"
json.dump([pick[1]], open(os.path.join(sys.argv[3], "paths.json"), "w"))
io.open(os.path.join(sys.argv[3], "uid.txt"), "w", encoding="utf-8", newline="\n").write(pick[0] + "\t" + pick[1])
PYST2A
chk $? "picked a recorded agent that names mcp__serena__"
ST2UID="$(cut -f1 "$SANDBOX/st2/uid.txt" 2>/dev/null)"
ST2DEST="$(cut -f2 "$SANDBOX/st2/uid.txt" 2>/dev/null)"
"$PY" "$REPO/install-lib.py" serena-rewrite "$SANDBOX/st2/paths.json" mcp__plugin_serena_serena__ >/dev/null
chk $? "rewrote its Serena prefix by hand"
yn "$(grep -qF 'mcp__serena__' "$ST2DEST" 2>/dev/null && echo 1 || echo 0)" "the rewrite really changed the file"
"$PY" - "$CH/.playbook-install.json" <<'PYST2B'
import json, sys
p = sys.argv[1]
m = json.load(open(p, encoding="utf-8"))
m.setdefault("config", {})["serena_prefix"] = "mcp__plugin_serena_serena__"
json.dump(m, open(p, "w", encoding="utf-8"), indent=2)
PYST2B
chk $? "recorded the same prefix in the manifest"
nokeys st2l; run list st2l
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 (rc=$RC)"
yn "$(grep -qE "current +$ST2UID\$" "$LOGS/st2l.out" && echo 0 || echo 1)" "list reports $ST2UID as current"
yn "$(grep -qE "edited +$ST2UID\$" "$LOGS/st2l.out" && echo 1 || echo 0)" "list does not call $ST2UID edited"
fi

# ---------------------------------------------------------------- ST3
# Catches: a tracker.md filled from the recorded tracker answers being called edited
# once its line endings changed, and then kept by remove as the user's work.
if want ST3; then
banner "ST3 · a tracker filled from its recorded answers that only changed line endings is current"
fresh_env st3; with_servers
# Not a path: MSYS would rewrite a /c/... argv for python and the compare would miss.
ST3M="st3-workspace-marker"
ST3K=( "${FULL[@]}" ); ST3K[15]="$ST3M"
keys st3 "${ST3K[@]}"; run install st3
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
inlog st3 "→ $ST3M" "the tracker stage filled a field with the marker answer"
yn "$([ "$(tr -cd '\r' < "$CH/tracker.md" | wc -c | tr -d ' ')" = "0" ] && echo 0 || echo 1)" \
   "the filled tracker.md has no CR bytes"
"$PY" - "$CH/.playbook-install.json" "$CH/tracker.md" "$ST3M" "$SANDBOX/st3/uid.txt" <<'PYST3'
import hashlib, io, json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
vals = ((m.get("config") or {}).get("tracker") or {}).get("values") or {}
assert sys.argv[3] in vals.values(), "the tracker answer is not recorded: %r" % vals
trk = sorted(k for k in m["units"] if k.startswith("tracker:"))
assert len(trk) == 1, "expected one recorded tracker, got %r" % trk
rec = m["units"][trk[0]]
data = open(sys.argv[2], "rb").read()
assert sys.argv[3].encode("utf-8") in data, "tracker.md does not carry the answer"
flip = data.replace(b"\r\n", b"\n") if b"\r\n" in data else data.replace(b"\n", b"\r\n")
open(sys.argv[2], "wb").write(flip)
assert hashlib.sha256(flip).hexdigest() != rec["hash"], "flipping endings did not change the hash"
io.open(sys.argv[4], "w", encoding="utf-8", newline="\n").write(trk[0])
PYST3
chk $? "flipped the line endings of the filled tracker.md (so its hash no longer matches)"
ST3UID="$(cat "$SANDBOX/st3/uid.txt" 2>/dev/null)"
nokeys st3l; run list st3l
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 (rc=$RC)"
yn "$([ -n "$ST3UID" ] && grep -qE "current +$ST3UID\$" "$LOGS/st3l.out" && echo 0 || echo 1)" "list reports $ST3UID as current"
yn "$(grep -qE "edited +$ST3UID\$" "$LOGS/st3l.out" && echo 1 || echo 0)" "list does not call $ST3UID edited"
keys st3r '' 'y'; run remove st3r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "remove exits 0 (rc=$RC)"
yn "$([ ! -e "$CH/tracker.md" ] && echo 0 || echo 1)" "remove deletes tracker.md rather than keeping it as edited"
fi

# ---------------------------------------------------------------- ST4
# Catches: a memory-schema skill swapped to the Forgetful variant and rewritten to a
# connector prefix being called edited once its line endings changed.
if want ST4; then
banner "ST4 · a memory-schema swapped to Forgetful under a connector prefix is current"
fresh_env st4; with_serena; with_memory_connector
keys st4 "${FULL[@]}"; run install st4
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
ST4D="$CH/skills/memory-schema"
yn "$(grep -qF 'mcp__claude_ai_forgetful__' "$ST4D/SKILL.md" 2>/dev/null && echo 0 || echo 1)" \
   "SKILL.md carries the connector prefix"
yn "$([ ! -e "$ST4D/forgetful.SKILL.md" ] && echo 0 || echo 1)" "the Forgetful variant was swapped in"
yn "$([ "$(tr -cd '\r' < "$ST4D/SKILL.md" | wc -c | tr -d ' ')" = "0" ] && echo 0 || echo 1)" \
   "the prefix-rewritten SKILL.md has no CR bytes"
"$PY" - "$CH/.playbook-install.json" <<'PYST4A'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
mem = (m.get("config") or {}).get("memory") or {}
sys.stdout.write("    (recorded memory: %r)\n" % mem)
sys.exit(0 if mem.get("server") == "forgetful" else 1)
PYST4A
chk $? "the manifest records the memory server as forgetful"
"$PY" - "$REPO/install-lib.py" "$CH/.playbook-install.json" "$ST4D" <<'PYST4B'
import importlib.util, json, os, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("pblib", sys.argv[1])
pblib = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pblib)
rec = json.load(open(sys.argv[2], encoding="utf-8"))["units"]["skill:memory-schema"]
p = os.path.join(sys.argv[3], "SKILL.md")
data = open(p, "rb").read()
flip = data.replace(b"\r\n", b"\n") if b"\r\n" in data else data.replace(b"\n", b"\r\n")
open(p, "wb").write(flip)
assert pblib.hash_path(sys.argv[3]) != rec["hash"], "flipping endings did not change the hash"
PYST4B
chk $? "flipped the line endings of the swapped SKILL.md (so the unit hash no longer matches)"
nokeys st4l; run list st4l
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 (rc=$RC)"
yn "$(grep -qE 'current +skill:memory-schema$' "$LOGS/st4l.out" && echo 0 || echo 1)" "list reports skill:memory-schema as current"
yn "$(grep -qE 'edited +skill:memory-schema$' "$LOGS/st4l.out" && echo 1 || echo 0)" "list does not call skill:memory-schema edited"
fi

# ---------------------------------------------------------------- ST5
# Catches: the stale check crashing on an older shipped version that the recorded
# answers leave unchanged (a memory-schema with no Forgetful variant), so list dies
# with a traceback instead of reporting the edited unit.
# The clone carries its own two-commit history, so the case does not depend on how
# deep the real repo was cloned; the history check fails if that setup did not land.
if want ST5; then
banner "ST5 · an edited memory-schema is edited when an older version has no Forgetful variant"
fresh_env st5; with_servers
ST5R="$SANDBOX/st5/repo"; ST5MS="$ST5R/templates/skills/memory-schema"
ST5GIT=(git -C "$ST5R" -c core.autocrlf=false -c user.name=st5 -c user.email=st5@example.invalid -c commit.gpgsign=false)
clone_repo "$ST5R" && mv "$ST5MS/forgetful.SKILL.md" "$SANDBOX/st5/forgetful.SKILL.md" \
  && "${ST5GIT[@]}" init -q && "${ST5GIT[@]}" add install.sh install-lib.py templates \
  && "${ST5GIT[@]}" commit -q -m older \
  && mv "$SANDBOX/st5/forgetful.SKILL.md" "$ST5MS/forgetful.SKILL.md" \
  && "${ST5GIT[@]}" add templates && "${ST5GIT[@]}" commit -q -m current \
  && echo "    (st5 clone history committed)"
chk $? "committed a clone history whose older memory-schema has no forgetful.SKILL.md"
"$PY" - "$ST5R/install-lib.py" "$ST5MS" <<'PYST5A'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("pblib", sys.argv[1])
pblib = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pblib)
versions = list(pblib._shipped_versions(sys.argv[2]))
sys.stdout.write("    (shipped memory-schema versions: %d)\n" % len(versions))
assert any("forgetful.SKILL.md" not in v for v in versions), "no version without the Forgetful variant"
assert any("forgetful.SKILL.md" in v for v in versions), "no version with the Forgetful variant"
PYST5A
chk $? "the stale check sees a shipped memory-schema without the Forgetful variant"
keys st5 "${FULL[@]}"; run_in "$ST5R" install st5
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
"$PY" - "$CH/.playbook-install.json" <<'PYST5B'
import json, sys
p = sys.argv[1]
m = json.load(open(p, encoding="utf-8"))
cfg = m.setdefault("config", {})
assert (cfg.get("memory") or {}).get("server") == "forgetful", "memory server: %r" % cfg.get("memory")
assert not cfg.get("serena_prefix"), "serena prefix: %r" % cfg.get("serena_prefix")
cfg["placeholders"] = {"values": {}, "delete": []}
json.dump(m, open(p, "w", encoding="utf-8"), indent=2)
PYST5B
chk $? "the manifest records Forgetful and no Serena prefix; its placeholder answers are cleared"
printf '\nst5 user edit\n' >> "$CH/skills/memory-schema/SKILL.md"
chk $? "edited the installed memory-schema SKILL.md"
nokeys st5l; run_in "$ST5R" list st5l
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 (rc=$RC)"
yn "$(grep -qF 'Traceback' "$LOGS/st5l.err" && echo 1 || echo 0)" "list prints no traceback"
yn "$(grep -qE 'edited +skill:memory-schema$' "$LOGS/st5l.out" && echo 0 || echo 1)" "list reports skill:memory-schema as edited"
fi

# ---------------------------------------------------------------- ST6
# Catches: a recorded tracker answer read back from the manifest carrying a CR into
# tracker.md, when update re-applies it to a refreshed template and when a re-run
# takes it as the Enter default. Only Windows python adds the CR.
if want ST6; then
banner "ST6 · a recorded tracker answer is re-applied to a refreshed tracker.md exactly"
fresh_env st6; with_servers
ST6R="$SANDBOX/st6/repo"; ST6T="$ST6R/templates/trackers/local-markdown.md"
# Not a path: MSYS would rewrite a /c/... argv for python and the compare would miss.
ST6M="st6-workspace-marker"
# tracker.md must equal the clone's template, LF, with <workspace> as the answer.
st6_exact() {
  "$PY" - "$ST6T" "$CH/tracker.md" "$ST6M" <<'PYST6'
import sys
exp = open(sys.argv[1], "rb").read().replace(b"\r\n", b"\n").replace(b"<workspace>", sys.argv[3].encode("utf-8"))
got = open(sys.argv[2], "rb").read()
sys.stdout.buffer.write(("    (tracker.md: %d bytes, %d CR; expected %d bytes)\n"
                         % (len(got), got.count(b"\r"), len(exp))).encode("utf-8"))
sys.exit(0 if got == exp else 1)
PYST6
}
clone_repo "$ST6R" && echo "    (st6 clone made)"
chk $? "made a clone to install from"
ST6K=( "${FULL[@]}" ); ST6K[15]="$ST6M"
keys st6 "${ST6K[@]}"; run_in "$ST6R" install st6
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
st6_exact; chk $? "setup: tracker.md carries the answer exactly"
printf '\nST6-TEMPLATE-MOVED-ONCE\n' >> "$ST6T"
chk $? "moved the clone's local-markdown template"
nokeys st6u; run_in "$ST6R" update st6u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the update exits 0 (rc=$RC)"
inlog st6u "re-applied 1 recorded tracker value" "update re-applied the recorded answer"
yn "$(grep -qF 'ST6-TEMPLATE-MOVED-ONCE' "$CH/tracker.md" && echo 0 || echo 1)" "update refreshed tracker.md from the moved template"
st6_exact; chk $? "after update, tracker.md is the template with the recorded answer, byte for byte"
printf '\nST6-TEMPLATE-MOVED-TWICE\n' >> "$ST6T"
chk $? "moved the clone's local-markdown template again"
#       banner discover seeded-pause i · serena x2 · models x2 · memory x2 · pause x2
#       y · <workspace> (Enter keeps the recorded answer) · tracker pause
keys st6r '' '' '' 'i' '' '' '' '' '' '' '' '' 'y' '' ''
run_in "$ST6R" install st6r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the re-run exits 0 (rc=$RC)"
inlog st6r "[Enter keeps $ST6M]" "the re-run offered the recorded answer"
yn "$(grep -qF 'ST6-TEMPLATE-MOVED-TWICE' "$CH/tracker.md" && echo 0 || echo 1)" "the re-run refreshed tracker.md from the moved template"
st6_exact; chk $? "after Enter kept the recorded answer, tracker.md is the template with it, byte for byte"
fi

# ---------------------------------------------------------------- LF1
# Catches: the placeholder fill and the Serena rewrite writing CRLF on Windows. Linux
# writes LF either way, so this can only go red on Windows. So can the CR-byte checks
# in ST3 (tracker answers) and ST4 (memory-schema prefix rewrite).
if want LF1; then
banner "LF1 · the placeholder fill and the Serena rewrite write LF"
LF1D="$SCRATCH/lf1"
rm -rf "$LF1D" && mkdir -p "$LF1D" && "$PY" - "$LF1D" <<'PYLF1'
import io, json, os, sys
d = sys.argv[1]
md = os.path.join(d, "agent.md")
sr = os.path.join(d, "serena.md")
io.open(md, "w", encoding="utf-8", newline="\n").write("---\nname: lf1\nmodel: <fast-model-id>\n---\nbody\n")
io.open(sr, "w", encoding="utf-8", newline="\n").write("tools: mcp__serena__find_symbol\nline two\n")
json.dump({"paths": [md], "values": {"<fast-model-id>": "lf1-model"}, "delete": []},
          open(os.path.join(d, "spec.json"), "w"))
json.dump([sr], open(os.path.join(d, "paths.json"), "w"))
PYLF1
chk $? "wrote LF fixtures"
"$PY" "$REPO/install-lib.py" apply-placeholders "$LF1D/spec.json" >/dev/null
chk $? "apply-placeholders ran"
yn "$(grep -qF 'model: lf1-model' "$LF1D/agent.md" && echo 0 || echo 1)" "the placeholder was filled"
yn "$([ "$(tr -cd '\r' < "$LF1D/agent.md" | wc -c | tr -d ' ')" = "0" ] && echo 0 || echo 1)" \
   "the filled file has no CR bytes"
"$PY" "$REPO/install-lib.py" serena-rewrite "$LF1D/paths.json" mcp__plugin_serena_serena__ >/dev/null
chk $? "serena-rewrite ran"
yn "$(grep -qF 'mcp__plugin_serena_serena__find_symbol' "$LF1D/serena.md" && echo 0 || echo 1)" \
   "the prefix was rewritten"
yn "$([ "$(tr -cd '\r' < "$LF1D/serena.md" | wc -c | tr -d ' ')" = "0" ] && echo 0 || echo 1)" \
   "the rewritten file has no CR bytes"
fi

# ---------------------------------------------------------------- HL1
# Catches: a hook installed without _lib/common.sh beside it. The hook fails closed, so
# every Bash call is refused — after a fresh install, after an update from a manifest
# that has no record of the library, and after a selection of one hook.
if want HL1; then
banner "HL1 · the shared hook library ships with the hooks, is never a hook, and leaves with remove"
fresh_env hl1; with_servers
keys hl1 "${FULL[@]}"; run install hl1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "HL1 install exits 0 (rc=$RC)"
HL1L="$CH/hooks/_lib/common.sh"
yn "$([ -f "$HL1L" ] && echo 0 || echo 1)" "HL1 install wrote hooks/_lib/common.sh"
yn "$([ -f "$HL1L" ] && [ "$(tr -cd '\r' < "$HL1L" | wc -c | tr -d ' ')" = "0" ] && echo 0 || echo 1)" \
   "HL1 hooks/_lib/common.sh has no CR bytes"
yn "$(cmp -s "$HL1L" "$REPO/templates/hooks/_lib/common.sh" && echo 0 || echo 1)" \
   "HL1 hooks/_lib/common.sh is the shipped file"
"$PY" - "$CH/.playbook-install.json" "$CH/settings.json" <<'PY'
import json, sys
units = json.load(open(sys.argv[1], encoding="utf-8"))["units"]
settings = open(sys.argv[2], encoding="utf-8").read()
assert (units.get("support:hook-lib") or {}).get("kind") == "hook-lib", "no support:hook-lib record"
assert not [u for u in units if u.startswith("hook:") and ("_lib" in u or "common" in u)], "recorded as a hook"
assert "_lib" not in settings and "common.sh" not in settings, "settings.json names the library"
PY
chk $? "HL1 the manifest records support:hook-lib, no hook unit for it, and settings.json never names it"
"$PY" - "$REPO/install-lib.py" "$REPO/templates" "$SANDBOX/hl1/discover-dest" <<'PY'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("install_lib", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
units = mod.discover(sys.argv[2], sys.argv[3])
hooks = sorted(u for u in units if u.startswith("hook:"))
assert len(hooks) >= 5, "only %d hook units discovered" % len(hooks)
missing = [h for h in hooks if "support:hook-lib" not in mod.resolve_deps(units, [h])[0]]
assert not missing, "selecting these alone leaves the library out: %s" % missing
PY
chk $? "HL1 selecting any one hook pulls support:hook-lib"

# A CRLF copy of the library breaks every hook at once: outdated, never current.
if sed -i 's/$/\r/' "$HL1L" && [ "$(tr -cd '\r' < "$HL1L" | wc -c | tr -d ' ')" -gt 0 ]; then
  pass "HL1 setup: hooks/_lib/common.sh converted to CRLF"
else
  fail "HL1 setup: hooks/_lib/common.sh converted to CRLF"
fi
nokeys hl1l; run list hl1l
if grep -qE 'outdated +support:hook-lib' "$LOGS/hl1l.out"; then pass "HL1 list reports a CRLF library as outdated"; else fail "HL1 list reports a CRLF library as outdated"; fi
nokeys hl1c; run update hl1c
yn "$([ "$(tr -cd '\r' < "$HL1L" | wc -c | tr -d ' ')" = "0" ] && echo 0 || echo 1)" "HL1 update rewrote a CRLF library as LF"

# An install from before the library existed: no file, and no record of one.
if rm -rf "$CH/hooks/_lib" && "$PY" - "$CH/.playbook-install.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
m["units"].pop("support:hook-lib", None)
json.dump(m, open(sys.argv[1], "w", encoding="utf-8"), indent=2)
PY
then pass "HL1 setup: the library and its record removed"; else fail "HL1 setup: the library and its record removed"; fi
nokeys hl1u; run update hl1u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "HL1 update exits 0 (rc=$RC)"
yn "$([ -f "$HL1L" ] && echo 0 || echo 1)" "HL1 update from a manifest without the library installs it"

# Gone afterwards only counts if it was there before.
HL1PRE=no; [ -f "$HL1L" ] && HL1PRE=yes
keys hl1r '' 'y'; run remove hl1r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "HL1 remove exits 0 (rc=$RC)"
yn "$([ "$HL1PRE" = yes ] && [ ! -e "$CH/hooks/_lib" ] && echo 0 || echo 1)" \
   "HL1 remove deletes hooks/_lib (present before: $HL1PRE)"
fi

# ---------------------------------------------------------------- HO1
# Catches: an agent-scoped hook reported UNWIRED on every install, merged into
# settings.json (every session would get it), or left behind when an agent that wires
# it in its frontmatter is installed alone — the agent then calls a missing file, a
# non-blocking error, and the write it exists to stop goes through.
if want HO1; then
banner "HO1 · an agent-scoped hook installs with its agents, and stays out of settings.json"
fresh_env ho1; with_servers
keys ho1 "${FULL[@]}"; run install ho1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "HO1 install exits 0 (rc=$RC)"
yn "$([ -f "$CH/hooks/handoffs-only.sh" ] && echo 0 || echo 1)" "HO1 install wrote hooks/handoffs-only.sh"
inlog ho1 "wired    block-dangerous-git" "HO1 control: the wiring readback ran"
notinlog ho1 "UNWIRED  handoffs-only" "HO1 the wiring readback does not call handoffs-only UNWIRED"
inlog ho1 "agent    handoffs-only — wired in agent frontmatter" "HO1 the readback names the agent-scoped hook"
yn "$([ -f "$CH/settings.json" ] && ! grep -qF "handoffs-only" "$CH/settings.json" && echo 0 || echo 1)" \
   "HO1 settings.json never names handoffs-only"
inlog ho1 "merged hook wiring" "HO1 control: a full install merges the hook wiring"

# Only aligner, so the only hook is the agent-scoped one: nothing goes into settings.json,
# and the closing screens must not talk about wiring that does not exist.
fresh_env ho1a; with_servers
keys ho1a '' '' '1' 'n' '' '2' 'n' '' '3' 'n' '1' '' '4' 'n' '' '6' 'n' '' '7' \
          'i' 'later' '' '' '' '' '' '' '' '' 'y' '' '' '' ''
run install ho1a
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "HO1 aligner-only install exits 0 (rc=$RC)"
inlog ho1a "1 [x] aligner" "HO1 setup: item 1 of the agent list is aligner"
yn "$([ -f "$CH/agents/aligner.md" ] && [ -f "$CH/hooks/handoffs-only.sh" ] && echo 0 || echo 1)" \
   "HO1 aligner-only install wrote aligner and handoffs-only"
notinlog ho1a "merged hook wiring" "HO1 aligner-only install merges no hook wiring"
notinlog ho1a "Are the guardrails switched on?" "HO1 aligner-only install prints no wiring readback"
notinlog ho1a "Claude cannot run 'git push'" "HO1 aligner-only install gives no push to-do"
notinlog ho1a "Check each guardrail really fires" "HO1 aligner-only install gives no guardrail to-do"

# The edge itself, on a tree whose only agents are fixtures: one wires a shipped hook in
# its frontmatter, one names a hook that does not exist.
HO1T="$SANDBOX/ho1/templates"
if mkdir -p "$HO1T/agents" && cp -R "$REPO/templates/hooks" "$HO1T/hooks" \
   && printf -- '---\nname: probe\nhooks:\n  PreToolUse:\n    - matcher: "Write|Edit"\n      hooks:\n        - type: command\n          command: "~/.claude/hooks/handoffs-only.sh"\n---\nbody\n' > "$HO1T/agents/probe.md" \
   && printf -- '---\nname: ghost\n---\nRuns ~/.claude/hooks/no-such-hook.sh.\n' > "$HO1T/agents/ghost.md"
then pass "HO1 setup: a fixture tree with two agents"; else fail "HO1 setup: a fixture tree with two agents"; fi
"$PY" - "$REPO/install-lib.py" "$HO1T" "$SANDBOX/ho1/discover-dest" <<'PY'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("install_lib", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
units = mod.discover(sys.argv[2], sys.argv[3])
full = mod.resolve_deps(units, ["agent:probe"])[0]
assert "hook:handoffs-only" in full and "support:hook-lib" in full, full
assert not [n for n in units["agent:ghost"]["needs"] if n.startswith("hook:")], units["agent:ghost"]["needs"]
PY
chk $? "HO1 an agent that wires a hook pulls it and the library; a hook that does not exist is no edge"

# The shipped agents that carry it.
"$PY" - "$REPO/install-lib.py" "$REPO/templates" "$SANDBOX/ho1/discover-dest" <<'PY'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("install_lib", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
units = mod.discover(sys.argv[2], sys.argv[3])
short = [a for a in ("agent:aligner", "agent:repo-reviewer", "agent:release-reviewer")
         if not {"hook:handoffs-only", "support:hook-lib"} <= set(mod.resolve_deps(units, [a])[0])]
assert not short, "installed alone, these leave handoffs-only or its library out: %s" % short
PY
chk $? "HO1 aligner, repo-reviewer and release-reviewer each pull hook:handoffs-only and support:hook-lib"

# The readback's error paths: an unreadable settings.json or snippet must not call the
# agent-scoped hook UNWIRED, which tells the user to put it into settings.json.
mkdir -p "$SANDBOX/ho1" && printf '{not json' > "$SANDBOX/ho1/bad.json"
HO1C=0
while IFS='|' read -r HO1V HO1N; do
  [ -n "$HO1N" ] || continue
  HO1C=$((HO1C + 1))
  if [ "$HO1V" = ok ]; then pass "HO1 $HO1N"; else fail "HO1 $HO1N"; fi
done < <("$PY" - "$REPO/install-lib.py" "$SANDBOX/ho1/bad.json" "$REPO/templates/hooks/settings-hooks.snippet.json" <<'PY'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("install_lib", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
bad, snippet = sys.argv[2], sys.argv[3]
hooks = ["block-dangerous-git", "handoffs-only"]
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("ok" if ok else "no", name)).encode("utf-8"))
d = mod.verify_wiring(bad, snippet, hooks)
say(d.get("error") and d["agent_scoped"] == ["handoffs-only"] and d["unwired"] == ["block-dangerous-git"],
    "settings.json unreadable: handoffs-only is agent-scoped, the rest unwired")
d = mod.verify_wiring(snippet, bad, hooks)
say(d.get("error") and "handoffs-only" not in d["unwired"],
    "snippet unreadable: handoffs-only is not called unwired")
PY
)
yn "$([ "$HO1C" = 2 ] && echo 0 || echo 1)" "HO1 the error-path check printed both verdicts (got $HO1C)"
fi

# ---------------------------------------------------------------- ML1
# Catches: memory-lint installed without lint.py beside it (the hook then refuses every
# memory write), wired under the registered tool name alone when Forgetful is reached as a
# connector (the hook never fires), or its python installed with CR bytes.
if want ML1; then
banner "ML1 · memory-lint installs with its skill, as LF, and is wired for the connector name too"
fresh_env ml1; with_serena; with_memory_connector
keys ml1 "${FULL[@]}"; run install ml1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "ML1 install exits 0 (rc=$RC)"
yn "$([ -f "$CH/hooks/memory-lint.sh" ] && echo 0 || echo 1)" "ML1 install wrote hooks/memory-lint.sh"
yn "$([ -f "$CH/skills/memory-lint/lint.py" ] && echo 0 || echo 1)" "ML1 install wrote skills/memory-lint/lint.py"
for ML1F in lint.py garden_check.py; do
  yn "$([ -f "$CH/skills/memory-lint/$ML1F" ] && [ "$(tr -cd '\r' < "$CH/skills/memory-lint/$ML1F" | wc -c | tr -d ' ')" = "0" ] && echo 0 || echo 1)" \
     "ML1 skills/memory-lint/$ML1F is installed with no CR bytes"
done
"$PY" - "$CH/settings.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
alts = set()
for b in (s.get("hooks") or {}).get("PreToolUse") or []:
    if any(h.get("command") == "~/.claude/hooks/memory-lint.sh" for h in b.get("hooks") or []):
        alts |= {a.strip() for a in (b.get("matcher") or "").split("|")}
print("    (memory-lint matcher alternatives: %s)" % sorted(alts))
want = {"mcp__forgetful__execute_forgetful_tool", "mcp__claude_ai_forgetful__execute_forgetful_tool"}
sys.exit(0 if want <= alts else 1)
PY
chk $? "ML1 the memory-lint matcher holds the registered and the connector tool name"
inlog ml1 "wired    memory-lint" "ML1 the readback says memory-lint is wired"
notinlog ml1 "MISWIRED memory-lint" "ML1 the readback does not call memory-lint MISWIRED"
notinlog ml1 "UNWIRED  memory-lint" "ML1 the readback does not call memory-lint UNWIRED"
"$PY" "$REPO/install-lib.py" discover "$REPO/templates" "$SANDBOX/ml1/discover-dest" > "$SANDBOX/ml1/units.json"
"$PY" - "$SANDBOX/ml1/units.json" <<'PY'
import json, sys
needs = json.load(open(sys.argv[1], encoding="utf-8"))["hook:memory-lint"]["needs"]
print("    (hook:memory-lint needs: %s)" % needs)
sys.exit(0 if "skill:memory-lint" in needs else 1)
PY
chk $? "ML1 hook:memory-lint needs skill:memory-lint"
# Registered Forgetful, and a memory server that is not Forgetful: the snippet's own
# matcher, unchanged.
for ML1P in mcp__forgetful__ ""; do
  printf '{"server": "forgetful", "prefix": "%s"}\n' "$ML1P" > "$SANDBOX/ml1/memory.json"
  "$PY" "$REPO/install-lib.py" hook-wiring "$REPO/templates/hooks/settings-hooks.snippet.json" \
        "$SANDBOX/ml1/memory.json" memory-lint > "$SANDBOX/ml1/wiring.json"
  "$PY" - "$SANDBOX/ml1/wiring.json" <<'PY'
import json, sys
blocks = json.load(open(sys.argv[1], encoding="utf-8"))["hooks"]["PreToolUse"]
sys.exit(0 if [b["matcher"] for b in blocks] == ["mcp__forgetful__execute_forgetful_tool"] else 1)
PY
  chk $? "ML1 prefix '${ML1P}' wires the snippet matcher unchanged"
done
fi

# ---------------------------------------------------------------- MJ1
# Catches: our matcherless hook block merged INTO a user's own matcherless block. The
# record then names a block that is not ours, so remove takes nothing back out.
if want MJ1; then
banner "MJ1 · a matcherless block of ours is added beside the user's, and remove takes it back"
mkdir -p "$SANDBOX/mj1"
MJ1C=0
while IFS='|' read -r MJ1V MJ1N; do
  [ -n "$MJ1N" ] || continue
  MJ1C=$((MJ1C + 1))
  if [ "$MJ1V" = ok ]; then pass "MJ1 $MJ1N"; else fail "MJ1 $MJ1N"; fi
done < <("$PY" - "$REPO/install-lib.py" "$SANDBOX/mj1/settings.json" <<'PY'
import copy, importlib.util, json, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("install_lib", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
path = sys.argv[2]
user = {"hooks": [{"type": "command", "command": "~/bin/my-stop.sh"}]}
ours = {"hooks": [{"type": "command", "command": "~/.claude/hooks/ours.sh"}]}
json.dump({"hooks": {"Stop": [copy.deepcopy(user)]}}, open(path, "w", encoding="utf-8"))
add = {"hooks": {"Stop": [copy.deepcopy(ours)]}}
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("ok" if ok else "no", name)).encode("utf-8"))
def stop():
    return json.load(open(path, encoding="utf-8"))["hooks"]["Stop"]
first = mod.merge_json(path, copy.deepcopy(add))
say(len(stop()) == 2, "after the merge there are two Stop blocks")
say(stop()[0] == user, "the user's Stop block is unchanged")
second = mod.merge_json(path, copy.deepcopy(add))
say(len(stop()) == 2 and not second["added"], "a second merge adds nothing and records nothing")
mod.unmerge_json(path, {"added": first["added"]})
say(stop() == [user], "remove takes our block out and leaves the user's intact")
PY
)
yn "$([ "$MJ1C" = 4 ] && echo 0 || echo 1)" "MJ1 the check printed all 4 verdicts (got $MJ1C)"
fi

# ---------------------------------------------------------------- RT1
# Catches: a retired hook left on disk and wired after update. cleanup-handoffs.sh deleted
# handoff folders at every session end; still wired, it keeps doing that with no template
# behind it. Its SessionEnd entry must go and every other hook entry must stay.
#
# rt1_seed MODE — the hook as an older install left it, wired under SessionEnd twice: in a
# block of its own, and inside a block that also holds a SessionEnd hook of the user's own.
#   recorded  on disk, recorded with its hash, its added paths recorded
#   edited    on disk, recorded, but changed since: its hash is not the recorded one
#   handcopy  on disk, no record (the manual install path), matching nothing ever shipped
rt1_seed() {
  "$PY" - "$CH/.playbook-install.json" "$CH/settings.json" "$1" "$SANDBOX/rt1/pre.json" <<'PY'
import hashlib, json, os, sys
mpath, spath, mode, snap = sys.argv[1:5]
m = json.load(open(mpath, encoding="utf-8"))
s = json.load(open(spath, encoding="utf-8"))
if not os.path.exists(snap):
    json.dump({k: v for k, v in s["hooks"].items() if k != "SessionEnd"}, open(snap, "w", encoding="utf-8"))
dest = os.path.join(os.path.dirname(m["units"]["hook:block-dangerous-git"]["dest"]), "cleanup-handoffs.sh")
body = {"recorded": b"#!/usr/bin/env bash\n# RT1 as installed\nexit 0\n",
        "edited": b"#!/usr/bin/env bash\n# RT1 changed by hand\nexit 0\n",
        "handcopy": b"#!/usr/bin/env bash\n# RT1 copied by hand\nexit 0\n"}[mode]
with open(dest, "wb") as fh:
    fh.write(body)
if mode != "handcopy":
    recorded = b"#!/usr/bin/env bash\n# RT1 as installed\nexit 0\n"
    m["units"]["hook:cleanup-handoffs"] = {"kind": "hook", "dest": dest,
                                          "hash": hashlib.sha256(recorded).hexdigest(),
                                          "source_hash": "0" * 64}
ours = {"type": "command", "command": "~/.claude/hooks/cleanup-handoffs.sh"}
own_block = {"hooks": [ours]}
shared = {"hooks": [{"type": "command", "command": "~/bin/my-session-end.sh"}, ours]}
s["hooks"]["SessionEnd"] = [own_block, shared]
if mode == "recorded":
    for j in m["json"]:
        if j["target"].replace("\\", "/").endswith("/settings.json"):
            j["added"] += [["hooks", "SessionEnd"],
                           ["hooks", "SessionEnd", json.dumps(own_block, sort_keys=True)]]
json.dump(m, open(mpath, "w", encoding="utf-8"), indent=2)
json.dump(s, open(spath, "w", encoding="utf-8"), indent=2)
print("seeded", mode, dest)
PY
}

# rt1_check PREFIX — one named case per line the python prints: "ok|name" or "no|name".
rt1_check() {
  local verdict name
  while IFS='|' read -r verdict name; do
    [ -n "$name" ] || continue
    if [ "$verdict" = ok ]; then pass "$1 $name"; else fail "$1 $name"; fi
  done < <("$PY" - "$CH/.playbook-install.json" "$CH/settings.json" "$SANDBOX/rt1/pre.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
s = json.load(open(sys.argv[2], encoding="utf-8"))
snap = json.load(open(sys.argv[3], encoding="utf-8"))
hooks = s.get("hooks") or {}
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("ok" if ok else "no", name)).encode("utf-8"))
say("cleanup-handoffs" not in json.dumps(s), "settings.json no longer names cleanup-handoffs")
own = [h for b in hooks.get("SessionEnd") or [] for h in b.get("hooks") or []
       if h.get("command") == "~/bin/my-session-end.sh"]
say(len(own) == 1, "the user's own SessionEnd hook is still wired, once")
say({k: v for k, v in hooks.items() if k != "SessionEnd"} == snap,
    "every other hook entry is unchanged")
say("hook:cleanup-handoffs" not in m["units"], "the manifest no longer records hook:cleanup-handoffs")
added = [p for j in m["json"] for p in j.get("added") or []]
say(not [p for p in added if "cleanup-handoffs" in json.dumps(p) or p == ["hooks", "SessionEnd"]],
    "the manifest records no added path for it")
PY
)
}

if want RT1; then
banner "RT1 · update retires cleanup-handoffs: its file, its settings entry and its record go"
fresh_env rt1; with_servers
# A hooks key of the user's own, so the install records its events one by one rather
# than the whole key, and remove below takes back only what was ours.
cat > "$CH/settings.json" <<'JSON'
{ "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "~/bin/my-stop.sh" } ] } ] } }
JSON
keys rt1 "${FULL[@]}"; run install rt1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RT1 install exits 0 (rc=$RC)"
RT1H="$CH/hooks/cleanup-handoffs.sh"
if rt1_seed recorded > "$LOGS/rt1-seed.out" && [ -f "$RT1H" ] && grep -qF 'cleanup-handoffs' "$CH/settings.json"
then pass "RT1 setup: a recorded, wired cleanup-handoffs beside a SessionEnd hook of the user's own"
else fail "RT1 setup: a recorded, wired cleanup-handoffs beside a SessionEnd hook of the user's own"; fi
nokeys rt1u; run update rt1u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RT1 update exits 0 (rc=$RC)"
yn "$([ ! -e "$RT1H" ] && echo 0 || echo 1)" "RT1 update deleted hooks/cleanup-handoffs.sh"
rt1_check "RT1 recorded:"
inlog rt1u "hook:cleanup-handoffs — retired" "RT1 the summary says it was retired"

# A second update has nothing left to do.
cp "$CH/settings.json" "$SANDBOX/rt1/settings.after1"
nokeys rt1u2; run update rt1u2
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RT1 second update exits 0 (rc=$RC)"
yn "$(cmp -s "$CH/settings.json" "$SANDBOX/rt1/settings.after1" && echo 0 || echo 1)" \
   "RT1 a second update leaves settings.json byte-identical"
notinlog rt1u2 "cleanup-handoffs" "RT1 a second update does not mention cleanup-handoffs"

# Changed since install: unwired and unrecorded, but the file is the user's and stays.
if rt1_seed edited > "$LOGS/rt1-seed2.out" && grep -qF 'changed by hand' "$RT1H"
then pass "RT1 setup: an edited copy, recorded and wired"; else fail "RT1 setup: an edited copy, recorded and wired"; fi
nokeys rt1e; run update rt1e
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RT1 update over an edited copy exits 0 (rc=$RC)"
yn "$(grep -qF 'changed by hand' "$RT1H" 2>/dev/null && echo 0 || echo 1)" "RT1 an edited copy is kept"
rt1_check "RT1 edited:"
inlog rt1e "cleanup-handoffs.sh is no longer wired" "RT1 an edited copy is named in a to-do"

# Copied by hand and never recorded: unwired, kept, and named.
if rt1_seed handcopy > "$LOGS/rt1-seed3.out" && grep -qF 'copied by hand' "$RT1H"
then pass "RT1 setup: a hand copy, unrecorded and wired"; else fail "RT1 setup: a hand copy, unrecorded and wired"; fi
nokeys rt1h; run update rt1h
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RT1 update over a hand copy exits 0 (rc=$RC)"
yn "$(grep -qF 'copied by hand' "$RT1H" 2>/dev/null && echo 0 || echo 1)" "RT1 a hand copy that matches nothing shipped is kept"
rt1_check "RT1 hand copy:"
inlog rt1h "cleanup-handoffs.sh is no longer wired" "RT1 a hand copy is named in a to-do"

# remove after a retirement: the recorded paths that are gone are skipped, not tripped over.
keys rt1r '' 'y'; run remove rt1r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RT1 remove after a retirement exits 0 (rc=$RC)"
"$PY" - "$CH/settings.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
own = [h for b in (s.get("hooks") or {}).get("SessionEnd") or [] for h in b.get("hooks") or []
       if h.get("command") == "~/bin/my-session-end.sh"]
assert len(own) == 1, own
PY
chk $? "RT1 remove leaves the user's own SessionEnd hook wired"

# A copy matching a committed version of the retired template is ours, recorded or not.
# Built on a scratch git repo, because CI checks this repo out one commit deep.
RT1G="$SANDBOX/rt1/git"
if mkdir -p "$RT1G/templates/hooks" "$RT1G/claude/hooks" \
   && printf '#!/usr/bin/env bash\nexit 0\n' > "$RT1G/templates/hooks/keep.sh" \
   && printf '#!/usr/bin/env bash\n# shipped once\nexit 0\n' > "$RT1G/templates/hooks/cleanup-handoffs.sh" \
   && git -C "$RT1G" init -q && git -C "$RT1G" add templates \
   && git -C "$RT1G" -c user.name=t -c user.email=t@t commit -qm one \
   && git -C "$RT1G" rm -q templates/hooks/cleanup-handoffs.sh \
   && git -C "$RT1G" -c user.name=t -c user.email=t@t commit -qm two \
   && printf '#!/usr/bin/env bash\r\n# shipped once\r\nexit 0\r\n' > "$RT1G/claude/hooks/cleanup-handoffs.sh"
then pass "RT1 setup: a scratch repo whose history ships cleanup-handoffs.sh, and a CRLF copy of it"
else fail "RT1 setup: a scratch repo whose history ships cleanup-handoffs.sh, and a CRLF copy of it"; fi
"$PY" - "$REPO/install-lib.py" "$RT1G" <<'PY'
import importlib.util, os, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("install_lib", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
g = sys.argv[2]
units = {"hook:keep": {"id": "hook:keep", "kind": "hook", "needs": [],
                       "src": os.path.join(g, "templates", "hooks", "keep.sh"),
                       "dest": os.path.join(g, "claude", "hooks", "keep.sh"),
                       "source_hash": "0" * 64}}
rows = mod.plan_install(units, {}, [])
retire = [r for r in rows if r[1] == "hook:cleanup-handoffs"]
assert [r[0] for r in retire] == ["retire"], rows
PY
chk $? "RT1 an unrecorded copy equal to a shipped version, CRLF aside, is planned for deletion"
fi

# ══════════════════════════════════════════════════════════════════════════
# FX1-FX3 · a tracker this clone stopped shipping, and to-dos already done
# ══════════════════════════════════════════════════════════════════════════

# ---------------------------------------------------------------- FX1
# Catches: a switch away from a recorded tracker this clone no longer ships planned
# as skip-foreign, because a record with no unit behind it carries no exclusive tag.
if want FX1; then
banner "FX1 · a switch away from a tracker this clone no longer ships replaces tracker.md"
fresh_env fx1; with_servers
sw_markers "$SANDBOX/fx1/markers.txt"; chk $? "found a marker line unique to each adapter"
FX1J="$(sed -n 1p "$SANDBOX/fx1/markers.txt" 2>/dev/null)"
keys fx1 "${FULL[@]}"; run install fx1
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
"$PY" - "$CH/.playbook-install.json" <<'PYFX1'
import json, sys
p = sys.argv[1]
m = json.load(open(p, encoding="utf-8"))
m["units"]["tracker:gone"] = m["units"].pop("tracker:local-markdown")
m.setdefault("config", {}).setdefault("tracker", {})["adapter"] = "gone"
json.dump(m, open(p, "w", encoding="utf-8"), indent=2, sort_keys=True)
PYFX1
chk $? "renamed the tracker record to tracker:gone, an adapter this clone does not ship"
FX1S="$(sw_state)"
yn "$([ "$FX1S" = "tracker:gone|gone" ] && echo 0 || echo 1)" \
   "setup: the manifest records only tracker:gone ($FX1S)"
#       banner discover seeded-pause menu:5 tracker:3(jira) back i · serena x2 · models x2
#       memory x2 · pause x2 · y · jira fields x3 · tracker pause
keys fx1j '' '' '' '5' '3' '' 'i' '' '' '' '' '' '' '' '' 'y' '' '' '' ''
run install fx1j
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the switch exits 0 (rc=$RC)"
notinlog fx1j "Files already here that this script did not install" "tracker.md is not offered for adoption"
notinlog fx1j "this clone no longer ships tracker:gone" \
         "no to-do tells the user to delete the tracker.md the switch just wrote"
yn "$(grep -qF -- "$FX1J" "$CH/tracker.md" 2>/dev/null && echo 0 || echo 1)" \
   "tracker.md now carries the jira adapter"
FX1S="$(sw_state)"
yn "$([ "${FX1S%%|*}" = "tracker:jira" ] && echo 0 || echo 1)" \
   "the manifest records tracker:jira and no other tracker ($FX1S)"
fi

# ---------------------------------------------------------------- FX2
# Catches: closing to-dos for work already done (an allowlist with an entry, the
# shared-place question answered in prose, a CLAUDE.md that already names
# tracker.md), and a left-alone diff path with mixed separators. The separator case
# is red only on Windows, where python joins paths with a backslash.
if want FX2; then
banner "FX2 · the closing to-dos name only what is still to do"
fresh_env fx2; with_servers
#       banner discover menu:5 tracker:1(github) back i · serena x2 · models x2
#       memory x2 · pause x2 · y · owner · repo · tracker pause
keys fx2 '' '' '5' '1' '' 'i' '' '' '' '' '' '' '' '' 'y' 'octo' 'weekend-project' ''
run install fx2
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
# shellcheck disable=SC2088  # the literal ~ is the text being looked for
yn "$(grep -qF '~/.claude/tracker.md' "$CH/CLAUDE.md" 2>/dev/null && echo 0 || echo 1)" \
   "setup: the installed global CLAUDE.md names ~/.claude/tracker.md"
inlog fx2 "Claude cannot run 'git push' in any repo" "an allowlist with no entry keeps the push to-do"
inlog fx2 "Answer 'Is this a shared place?'" "an unanswered github tracker keeps the shared-place to-do"
notinlog fx2 "Add a line to your global CLAUDE.md pointing at" \
         "a CLAUDE.md naming ~/.claude/tracker.md gets no pointer to-do"
printf '# a comment\ngithub.com/octo/weekend-project    yes    yes\n' >> "$CH/repo-allowlist"
"$PY" - "$CH/tracker.md" <<'PYFX2'
import io, re, sys
p = sys.argv[1]
t = io.open(p, encoding="utf-8", newline="").read()
n = len(re.findall("<yes[^>]*>", t))
assert n == 1, "expected one unanswered shared-place token, found %d" % n
io.open(p, "w", encoding="utf-8", newline="").write(
    re.sub("<yes[^>]*>", "Per repo: yes for anything public", t))
PYFX2
chk $? "answered the shared-place question in prose"
printf '# my own global rules, and no tracker pointer\n' > "$CH/CLAUDE.md"
nokeys fx2u; run update fx2u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the update exits 0 (rc=$RC)"
notinlog fx2u "Claude cannot run 'git push' in any repo" "an allowlist with an entry gets no push to-do"
notinlog fx2u "Answer 'Is this a shared place?'" "a shared-place answer in prose gets no to-do"
inlog fx2u "Add a line to your global CLAUDE.md pointing at" \
      "a CLAUDE.md that does not name tracker.md keeps the pointer to-do"
FX2D="$(grep -F 'you edited it since install; diff against' "$LOGS/fx2u.out")"
printf '    (%s)\n' "$FX2D"
yn "$("$PY" -c 'import sys; s = sys.stdin.read(); print(0 if "diff against" in s and chr(92) not in s else 1)' <<< "$FX2D")" \
   "every left-alone diff path uses one separator"
fi

# ---------------------------------------------------------------- FX3
# Catches: "Fill in <repo>" demanded of a tracker.md this run did not write. A
# hand-written one may use <repo> on purpose, as a per-call placeholder.
if want FX3; then
banner "FX3 · the tracker blanks are checked only in a tracker.md this run wrote"
fresh_env fx3; with_servers
keys fx3 "${FULL[@]}"; run install fx3
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the local-markdown install exits 0 (rc=$RC)"
inlog fx3 "Fill in <repo>" "an installed tracker.md with a blank keeps its fill-in to-do"
fresh_env fx3f; with_servers
printf '# my tracker\n\nRead an issue: gh issue view N --repo <repo>\n' > "$CH/tracker.md"
#       banner discover menu:5 tracker:4(local-markdown) back i · serena x2 · models x2
#       memory x2 · pause x2 · adopt n · adopt pause · y · <workspace> · tracker pause
keys fx3f '' '' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'n' '' 'y' "$SANDBOX/ws" ''
run install fx3f
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install beside a hand-written tracker.md exits 0 (rc=$RC)"
inlog fx3f "Left alone. They stay yours" "setup: adopting the hand-written tracker.md was declined"
notinlog fx3f "Fill in <repo>" "a hand-written tracker.md gets no fill-in to-do"
inlog fx3f "this run did not write it, so its blanks were not checked" \
      "check 3 says it left the hand-written tracker.md alone"
yn "$(grep -qF -- '--repo <repo>' "$CH/tracker.md" 2>/dev/null && echo 0 || echo 1)" \
   "the hand-written tracker.md still says <repo>"
fi

# ══════════════════════════════════════════════════════════════════════════
# RC8 · the route C kit (templates/serena/), run against tests/fake_serena.py
# ══════════════════════════════════════════════════════════════════════════

# ---------------------------------------------------------------- RC8
# Catches: a repo map with a placeholder path, a missing path, a bad key or a port+10
# clash accepted (a); a context file whose excluded_tools is not all_tools minus its
# profile, or an edit profile that drifts from the agents' Serena tools (b); a second
# serena-up starting a second server, or --edit not on port+10 (c); a server listing
# a tool outside its profile left running (d); serena-down trusting the PID instead of
# a process listing (e); a .ps1 wrapper with no BOM, or one that cannot start and stop
# a server under PowerShell 5.1 and 7 (f); warm-up skipping the source file or asking
# about an empty one (g); a repo with no source file failing instead of saying so (h).
# Every server here is the fake, on ports found free at run time, and every one is
# stopped at the end, pass or fail.
if want RC8; then
banner "RC8 · the route C kit starts, checks, reuses and stops per-repo servers"
fresh_env rc8
rc8_w() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
RC8K="$REPO/templates/serena"
RC8KW="$(rc8_w "$RC8K")"
RC8HW="$(rc8_w "$CH")"
RC8R="$SANDBOX/rc8/repos"
RC8LOG="$SANDBOX/rc8/fake.log"
RC8D="$SANDBOX/rc8/decoy"
RC8M="rc8mark$$x$RANDOM"
mkdir -p "$RC8R/alpha/src" "$RC8R/alpha/pkg" "$RC8R/beta" "$RC8R/gamma" \
  && printf 'def a():\n    return 1\n' > "$RC8R/alpha/src/a.py" \
  && : > "$RC8R/alpha/pkg/__init__.py" \
  && printf '# beta\n' > "$RC8R/beta/README.md" \
  && printf 'def g():\n    return 1\n' > "$RC8R/gamma/g.py" \
  && : > "$RC8LOG"
chk $? "setup: repos alpha (src/a.py, empty pkg/__init__.py), beta (README.md only), gamma"
RC8P="$("$PY" -c '
import socket, sys
def free(p):
    s = socket.socket()
    try:
        s.bind(("127.0.0.1", p))
        return True
    except OSError:
        return False
    finally:
        s.close()
for b in range(19121, 19921, 20):
    if all(free(b + d) for d in (0, 1, 2, 10, 11, 12)):
        sys.stdout.write(str(b))
        break
')"
yn "$([ -n "$RC8P" ] && echo 0 || echo 1)" "setup: alpha, beta, gamma get the free ports ${RC8P:-NONE}+0/1/2, edit +10"
"$PY" - "$RC8HW/serena-repos.json" "$(rc8_w "$RC8R")" "${RC8P:-0}" "$(rc8_w "$REPO/tests/fake_serena.py")" "$RC8M" <<'PYRC8'
import json, os, sys
out, root, port, fake, mark = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]
cmd = [sys.executable, fake, "--marker", mark]
def write(path, repos):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"repos": repos, "serena_cmd": cmd}, f, indent=2)
good = {k: {"path": root + "/" + k, "port": port + i} for i, k in enumerate(("alpha", "beta", "gamma"))}
write(out, good)
d = os.path.dirname(out)
write(os.path.join(d, "bad-placeholder.json"), dict(good, alpha={"path": "<absolute path to the repo>", "port": port}))
write(os.path.join(d, "bad-missing.json"), dict(good, alpha={"path": root + "/no-such-repo", "port": port}))
write(os.path.join(d, "bad-clash.json"), {"alpha": good["alpha"], "beta": {"path": root + "/beta", "port": port + 10}})
write(os.path.join(d, "bad-key.json"), {"Bad_Key": good["alpha"]})
PYRC8
chk $? "setup: the repo map, and four broken copies of it"

# rc8_py LOG args... - serena_route.py itself, the way the installer runs validate.
rc8_py() {
  local log="$1"; shift
  # shellcheck disable=SC2086
  $TIMEOUT "$PY" "$RC8KW/serena_route.py" "$@" > "$LOGS/$log.out" 2> "$LOGS/$log.err" < /dev/null
  RC=$?
}
# rc8_sh LOG up|down args... - through the bash wrapper, the way a user runs it.
rc8_sh() {
  local log="$1" verb="$2"; shift 2
  # shellcheck disable=SC2086
  FAKE_SERENA_LOG="$(rc8_w "$RC8LOG")" $TIMEOUT bash "$RC8K/serena-$verb.sh" --home "$RC8HW" "$@" \
    > "$LOGS/$log.out" 2> "$LOGS/$log.err" < /dev/null
  RC=$?
}
# rc8_ps EXE LOG WRAPPER args... - through a .ps1 wrapper under one PowerShell.
rc8_ps() {
  local exe="$1" log="$2" w="$3" pol=()
  shift 3
  command -v cygpath >/dev/null 2>&1 && pol=(-ExecutionPolicy Bypass)
  # shellcheck disable=SC2086
  PATH="$RC8D:$PATH" FAKE_SERENA_LOG="$(rc8_w "$RC8LOG")" $TIMEOUT "$exe" -NoProfile ${pol[@]+"${pol[@]}"} \
    -File "$(rc8_w "$RC8K/$w")" --home "$RC8HW" "$@" > "$LOGS/$log.out" 2> "$LOGS/$log.err" < /dev/null
  RC=$?
}
# rc8_said EXE LOG - after a failed wrapper check: what the run printed, and the pythons
# that PowerShell finds on the same PATH, so a CI log carries its own diagnosis.
rc8_said() {
  local f
  for f in "$LOGS/$2.out" "$LOGS/$2.err"; do
    printf '          %s, last lines:\n' "${f##*/}"
    tail -n 5 "$f" 2>/dev/null | sed 's/^/            /'
  done
  printf '          python candidates %s finds:\n' "$1"
  # shellcheck disable=SC2016  # PowerShell source: $_ is PowerShell's
  PATH="$RC8D:$PATH" $TIMEOUT "$1" -NoProfile -NonInteractive -Command \
    'Get-Command python3, python -CommandType Application -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source }' \
    < /dev/null 2>&1 | sed 's/^/            /'
}
# rc8_procs PORT - how many processes carry this run's marker and --port PORT. The
# suite's own listing, so it does not share a bug with the kit's.
# shellcheck disable=SC2016  # PowerShell source: $_ is PowerShell's
RC8PS='
import base64, os, re, subprocess, sys
mark, port = sys.argv[1], sys.argv[2]
if os.name == "nt":
    ps = "[Console]::OutputEncoding=[Text.Encoding]::UTF8; Get-CimInstance Win32_Process | ForEach-Object { [string]$_.CommandLine }"
    argv = ["powershell.exe", "-NoProfile", "-NonInteractive", "-EncodedCommand",
            base64.b64encode(ps.encode("utf-16-le")).decode("ascii")]
else:
    argv = ["ps", "-eo", "args="]
out = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.decode("utf-8", "replace")
pat = re.compile(r"--port\s+" + port + r"(\s|$)")
sys.stdout.write(str(sum(1 for l in out.splitlines() if mark in l and pat.search(l))))
'
rc8_procs() { "$PY" -c "$RC8PS" "$RC8M" "$1"; }
rc8_pid() { "$PY" -c 'import json, sys; sys.stdout.write(str(json.load(open(sys.argv[1]))["pid"]))' "$1" 2>/dev/null; }

# --- a: validate
rc8_py rc8a-ok validate --map "$RC8HW/serena-repos.json"
yn "$([ "$RC" = 0 ] && echo 0 || echo 1)" "RC8a the filled-in map validates (rc=$RC)"
rc8_py rc8a-ex validate --map "$RC8KW/serena-repos.example.json"
yn "$([ "$RC" = 1 ] && bothgrep rc8a-ex "placeholder" && echo 0 || echo 1)" \
   "RC8a the shipped example map is refused, and the refusal says placeholder (rc=$RC)"
rc8_py rc8a-lt validate --map "$RC8HW/bad-placeholder.json"
yn "$([ "$RC" = 1 ] && bothgrep rc8a-lt "repo 'alpha'" && bothgrep rc8a-lt "placeholder" && echo 0 || echo 1)" \
   "RC8a a path holding '<' is refused, naming the repo (rc=$RC)"
rc8_py rc8a-miss validate --map "$RC8HW/bad-missing.json"
yn "$([ "$RC" = 1 ] && bothgrep rc8a-miss "repo 'alpha'" && bothgrep rc8a-miss "not a folder" && echo 0 || echo 1)" \
   "RC8a a path that is not a folder is refused, naming the repo (rc=$RC)"
rc8_py rc8a-clash validate --map "$RC8HW/bad-clash.json"
yn "$([ "$RC" = 1 ] && bothgrep rc8a-clash "port $((RC8P + 10))" && bothgrep rc8a-clash "'beta'" && echo 0 || echo 1)" \
   "RC8a beta on alpha's edit port $((RC8P + 10)) is refused, naming port and repo (rc=$RC)"
rc8_py rc8a-key validate --map "$RC8HW/bad-key.json"
yn "$([ "$RC" = 1 ] && bothgrep rc8a-key "Bad_Key" && echo 0 || echo 1)" \
   "RC8a a repo key with capitals and an underscore is refused (rc=$RC)"

# --- b: profiles
"$PY" - "$RC8KW" "$(rc8_w "$REPO/templates/agents")" > "$LOGS/rc8b.out" 2>&1 <<'PYRC8B'
import glob, json, os, re, sys
kit, agents = sys.argv[1], sys.argv[2]
prof = json.load(open(os.path.join(kit, "profiles.json"), encoding="utf-8"))
every, read, edit = prof["all_tools"], prof["read"], prof["edit"]
bad = []
def context(name):
    out, inside, single = [], False, False
    for line in open(os.path.join(kit, name + ".context.yml"), encoding="utf-8").read().splitlines():
        if line.strip() == "single_project: true":
            single = True
        if line.startswith("excluded_tools:"):
            inside = True
            continue
        if inside:
            if line.startswith("  - "):
                out.append(line[4:].strip())
            elif line.strip():
                inside = False
    return out, single
for name, tools in (("read", read), ("edit", edit)):
    ex, single = context(name)
    expect = set(every) - set(tools)
    if set(ex) != expect or len(ex) != len(set(ex)):
        bad.append("%s.context.yml excluded_tools is not all_tools minus %s: extra %s, missing %s, %d listed"
                   % (name, name, sorted(set(ex) - expect), sorted(expect - set(ex)), len(ex)))
    if not single:
        bad.append("%s.context.yml does not say single_project: true" % name)
    if "activate_project" in tools:
        bad.append("the %s profile holds activate_project" % name)
    if set(tools) - set(every):
        bad.append("the %s profile holds tools outside all_tools: %s" % (name, sorted(set(tools) - set(every))))
if set(read) - set(edit):
    bad.append("read holds tools edit does not: %s" % sorted(set(read) - set(edit)))
used = set()
for p in sorted(glob.glob(os.path.join(agents, "*.md"))):
    for line in open(p, encoding="utf-8"):
        if line.startswith("tools:"):
            used |= set(re.findall(r"mcp__serena__([a-z_]+)", line))
used.discard("activate_project")
if used != set(edit):
    bad.append("edit is not the agents' Serena tools: agents only %s, edit only %s"
               % (sorted(used - set(edit)), sorted(set(edit) - used)))
if len(every) < 30 or len(read) < 8 or len(used) < 10:
    bad.append("a set is implausibly small: all_tools %d, read %d, agents' Serena tools %d" % (len(every), len(read), len(used)))
print("all_tools %d, read %d, edit %d, agents' Serena tools %d" % (len(every), len(read), len(edit), len(used)))
for b in bad:
    print("BAD " + b)
sys.exit(1 if bad else 0)
PYRC8B
chk $? "RC8b each context file excludes all_tools minus its profile, and edit is every Serena tool an agent declares (log: $LOGS/rc8b.out)"

# --- g, h: one serena-up for two repos, in parallel
rc8_sh rc8gh up alpha beta --timeout 60
RC8GH=$RC
yn "$([ "$RC8GH" = 0 ] && echo 0 || echo 1)" "RC8g serena-up alpha beta exits 0 (rc=$RC8GH)"
yn "$(bothgrep rc8gh "warm-up ok: alpha src/a.py" && ! bothgrep rc8gh "symbols not verified: alpha" && echo 0 || echo 1)" \
   "RC8g alpha's warm-up names src/a.py, and says nothing of symbols not verified"
yn "$(grep -qF "$RC8P call get_symbols_overview {\"relative_path\": \"src/a.py\"}" "$RC8LOG" \
      && ! grep -qF '__init__.py' "$RC8LOG" && echo 0 || echo 1)" \
   "RC8g the server was asked for the symbols of src/a.py, and never of the empty pkg/__init__.py"
yn "$(grep -qF "$((RC8P + 1)) call list_dir" "$RC8LOG" && bothgrep rc8gh "symbols not verified: beta" && echo 0 || echo 1)" \
   "RC8h beta, with no source file, is checked with list_dir and reported as symbols not verified"
yn "$([ -f "$CH/serena-state/alpha-read.json" ] && [ -f "$CH/serena-state/beta-read.json" ] && echo 0 || echo 1)" \
   "RC8g serena-up wrote a state file for alpha and for beta under serena-state/"

# --- c: reuse, and --edit
RC8PID="$(rc8_pid "$RC8HW/serena-state/alpha-read.json")"
rc8_sh rc8c up alpha --timeout 60
yn "$([ "$RC" = 0 ] && bothgrep rc8c "already running: alpha" && echo 0 || echo 1)" \
   "RC8c a second serena-up alpha exits 0 and says alpha is already running (rc=$RC)"
RC8N="$(grep -cF "$RC8P serve read.context.yml" "$RC8LOG")"
RC8PID2="$(rc8_pid "$RC8HW/serena-state/alpha-read.json")"
yn "$([ "$RC8N" = 1 ] && [ -n "$RC8PID" ] && [ "$RC8PID" = "$RC8PID2" ] && echo 0 || echo 1)" \
   "RC8c alpha's read server was started once, and its pid kept (starts=$RC8N, pid $RC8PID then $RC8PID2)"
rc8_sh rc8ce up alpha --edit --timeout 60
yn "$([ "$RC" = 0 ] && grep -qF "$((RC8P + 10)) serve edit.context.yml" "$RC8LOG" \
      && [ -f "$CH/serena-state/alpha-edit.json" ] && echo 0 || echo 1)" \
   "RC8c serena-up alpha --edit starts the edit profile on port $((RC8P + 10)) (rc=$RC)"

# --- d: a server that lists more than its profile
FAKE_SERENA_EXTRA_TOOLS=execute_shell_command rc8_sh rc8d up gamma --timeout 60
yn "$([ "$RC" != 0 ] && bothgrep rc8d "execute_shell_command" && echo 0 || echo 1)" \
   "RC8d gamma, listing execute_shell_command, is refused and the tool is named (rc=$RC)"
RC8DN="$(rc8_procs $((RC8P + 2)))"
yn "$(grep -qF "$((RC8P + 2)) serve " "$RC8LOG" && [ "$RC8DN" = 0 ] \
      && [ ! -e "$CH/serena-state/gamma-read.json" ] && echo 0 || echo 1)" \
   "RC8d the refused server was started and then stopped: ${RC8DN:-?} processes left, no state file"

# --- s: status, which the leftover-notice hook prints at session start
rc8_py rc8s-live status --notice --home "$RC8HW"
yn "$([ "$RC" = 0 ] && bothgrep rc8s-live "running: alpha (read, port $RC8P" && bothgrep rc8s-live "serena-down.sh" && echo 0 || echo 1)" \
   "RC8s status --notice lists alpha's running read server and the serena-down command (rc=$RC)"

# --- e: down
# An orphan: beta's recorded process is gone and the server it started still runs, so
# no tree kill from the recorded pid can reach it. Only the process listing finds it.
RC8BPID="$(rc8_pid "$RC8HW/serena-state/beta-read.json")"
case "$RC8BPID" in
  ''|*[!0-9]*|0) RC8OR=none ;;
  *) "$PY" -c 'import os, signal, sys, time
os.kill(int(sys.argv[1]), signal.SIGTERM)
time.sleep(1)' "$RC8BPID"
     RC8OR="$(rc8_procs $((RC8P + 1)))" ;;
esac
yn "$([ "$RC8OR" = 1 ] && echo 0 || echo 1)" \
   "setup: beta's recorded process ${RC8BPID:-?} killed alone, its server left running ($RC8OR process)"
RC8B4="$(rc8_procs "$RC8P")"
rc8_sh rc8e down
RC8E=$RC
RC8AF=$(( $(rc8_procs "$RC8P") + $(rc8_procs $((RC8P + 1))) + $(rc8_procs $((RC8P + 10))) ))
yn "$([ "$RC8E" = 0 ] && [ "${RC8B4:-0}" -ge 2 ] && [ "$RC8AF" = 0 ] && echo 0 || echo 1)" \
   "RC8e serena-down exits 0 and no fake server is left in the process list, beta's orphan included (rc=$RC8E; alpha had ${RC8B4:-?} processes, $RC8AF left in all)"
yn "$([ "$RC8E" = 0 ] && ! ls "$CH/serena-state"/*.json >/dev/null 2>&1 && echo 0 || echo 1)" \
   "RC8e serena-down removed every state file"
rc8_py rc8s-none status --notice --home "$RC8HW"
yn "$([ "$RC" = 0 ] && [ "$(bytes rc8s-none)" = 0 ] && echo 0 || echo 1)" \
   "RC8s with nothing recorded, status --notice prints nothing (rc=$RC, $(bytes rc8s-none) bytes)"
printf '{"key": "beta", "profile": "edit", "port": %s, "pid": 999999}\n' "$((RC8P + 11))" \
  > "$CH/serena-state/beta-edit.json"
rc8_py rc8s-stale status --notice --home "$RC8HW"
yn "$([ "$RC" = 0 ] && bothgrep rc8s-stale "stale:   beta (edit, port $((RC8P + 11)))" && bothgrep rc8s-stale "serena-down.sh" && echo 0 || echo 1)" \
   "RC8s a state file whose process is gone is reported stale, with the serena-down command (rc=$RC)"
rc8_sh rc8s-down down
yn "$([ "$RC" = 0 ] && [ ! -e "$CH/serena-state/beta-edit.json" ] && echo 0 || echo 1)" \
   "RC8s serena-down clears the stale state file (rc=$RC)"

# --- f: the PowerShell wrappers
"$PY" - "$RC8KW" <<'PYRC8F'
import os, sys
for w in ("serena-up.ps1", "serena-down.ps1"):
    if open(os.path.join(sys.argv[1], w), "rb").read(3) != b"\xef\xbb\xbf":
        sys.exit(1)
PYRC8F
chk $? "RC8f both .ps1 wrappers start with a UTF-8 BOM"
# Every wrapper run has this folder first on PATH. On Windows, PowerShell hands a
# python3.vbs to the shell rather than running it, and never waits for it - like the
# extensionless python3 script on CI's PATH, which brings up the Open-with handler. The
# probe must skip it; if it runs it, wscript leaves python3.vbs.ran.
mkdir -p "$RC8D" \
  && printf 'CreateObject("Scripting.FileSystemObject").CreateTextFile(WScript.ScriptFullName & ".ran", True).Close\r\n' \
       > "$RC8D/python3.vbs"
chk $? "setup: a python3.vbs decoy first on the wrappers' PATH"
if command -v cygpath >/dev/null 2>&1; then RC8PSH="powershell.exe pwsh.exe"; else RC8PSH="pwsh"; fi
RC8RAN=0
for RC8X in $RC8PSH; do
  command -v "$RC8X" >/dev/null 2>&1 || continue
  RC8RAN=1
  rm -f "$RC8D/python3.vbs.ran"
  rc8_ps "$RC8X" "rc8f-up-$RC8X" serena-up.ps1 beta --edit --timeout 60
  RC8V="$([ "$RC" = 0 ] && grep -qF "$((RC8P + 11)) serve edit.context.yml" "$RC8LOG" && echo 0 || echo 1)"
  yn "$RC8V" "RC8f $RC8X: serena-up.ps1 beta --edit starts beta's edit server (rc=$RC)"
  [ "$RC8V" = 0 ] || rc8_said "$RC8X" "rc8f-up-$RC8X"
  rc8_ps "$RC8X" "rc8f-down-$RC8X" serena-down.ps1 beta
  RC8FN="$(rc8_procs $((RC8P + 11)))"
  RC8V="$([ "$RC" = 0 ] && [ "$RC8FN" = 0 ] && echo 0 || echo 1)"
  yn "$RC8V" "RC8f $RC8X: serena-down.ps1 beta stops it ($RC8FN left, rc=$RC)"
  [ "$RC8V" = 0 ] || rc8_said "$RC8X" "rc8f-down-$RC8X"
  rc8_ps "$RC8X" "rc8f-bad-$RC8X" serena-up.ps1 no-such-repo
  RC8V="$([ "$RC" != 0 ] && bothgrep "rc8f-bad-$RC8X" "no-such-repo" && echo 0 || echo 1)"
  yn "$RC8V" "RC8f $RC8X: serena-up.ps1 refuses a key the map does not hold, naming it (rc=$RC)"
  [ "$RC8V" = 0 ] || rc8_said "$RC8X" "rc8f-bad-$RC8X"
  yn "$([ ! -e "$RC8D/python3.vbs.ran" ] && echo 0 || echo 1)" \
     "RC8f $RC8X: the wrappers' python probe never ran the python3.vbs decoy ahead of python on PATH"
done
[ "$RC8RAN" = 1 ] || printf '    SKIP  RC8f wrapper runs — no PowerShell on this machine, so NOT run\n'

rc8_sh rc8z down
fi

# ══════════════════════════════════════════════════════════════════════════
# RC1-RC7, RC9 · route C in the installer: detection, the repo map, agent wiring
# ══════════════════════════════════════════════════════════════════════════
# Every install that can reach route C runs from a clone INSIDE a fixture folder, with
# SERENA_REPOS_DIR pointed at that folder. Discovery's default folder is the clone's
# parent, so a case that lost the variable would still scan the fixture and never this
# machine's real repos.

# A fresh install that answers C at the Serena step: FULL with C as the route.
CFULL=( '' '' '5' '4' '' 'i' 'C' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" '' )
# A seeded re-run (the SW6 shape): banner discover seeded-pause i · serena C, pause ·
# models x2 · memory x2 · pause x2 · y · tracker pause
CRERUN=( '' '' '' 'i' 'C' '' '' '' '' '' '' '' 'y' '' )

# rc_env NAME [REPO...] — fresh_env with both pillars, plus a fixture folder holding a
# clone of the installer (with a .git, so discovery must skip it by path) and one git
# repo per REPO argument.
rc_env() {
  local name="$1" r
  shift
  fresh_env "$name"
  with_servers
  RCDIR="$SANDBOX/$name/repos"
  mkdir -p "$RCDIR" && clone_repo "$RCDIR/playbook" && mkdir -p "$RCDIR/playbook/.git" || return 1
  for r in "$@"; do mkdir -p "$RCDIR/$r/.git" || return 1; done
}

# run_c MODE LOG — run_in from the fixture's clone, with discovery pointed at the fixture.
run_c() {
  local mode="$1" log="$2"
  [ -f "$LOGS/$log.in" ] || : > "$LOGS/$log.in"
  ( cd "$RCDIR/playbook" && HOME="$HOME_DIR" CLAUDE_HOME="$CH" PLAYBOOK_SCRIPTED_INPUT=1 \
    SERENA_REPOS_DIR="$RCDIR" bash ./install.sh "$mode" ) \
    < "$LOGS/$log.in" > "$LOGS/$log.out" 2> "$LOGS/$log.err"
  RC=$?
  return 0
}

# run_c_raw LOG MODE [ARG...] — run_c with stdin closed, no scripted-input flag, and the
# run_raw timeout, for the modes that must work with nobody at the keyboard.
run_c_raw() {
  local log="$1"
  shift
  # shellcheck disable=SC2086
  ( cd "$RCDIR/playbook" && HOME="$HOME_DIR" CLAUDE_HOME="$CH" SERENA_REPOS_DIR="$RCDIR" \
    $TIMEOUT bash ./install.sh "$@" ) \
    < /dev/null > "$LOGS/$log.out" 2> "$LOGS/$log.err"
  RC=$?
  return 0
}

# verdicts — feed "PASS|name" / "FAIL|name" lines from a python check into pass/fail.
# Read through process substitution, never a pipe: a pipe's right side is a subshell
# and the counts would never make it back out.
verdicts() {
  local v n
  while IFS='|' read -r v n; do
    if [ "$v" = PASS ]; then pass "$n"; else fail "$n"; fi
  done
}

# rc_recorded UID — does the manifest in $CH record UID as an installed unit? Its
# "known" inventory names every unit the clone ships, so a plain grep cannot tell.
rc_recorded() {
  "$PY" -c 'import json,sys;sys.exit(0 if sys.argv[2] in (json.load(open(sys.argv[1])).get("units") or {}) else 1)' \
    "$CH/.playbook-install.json" "$1" 2>/dev/null
}

# rc_w PATH — the C:/... form a Windows python prints, or PATH unchanged elsewhere.
rc_w() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

# rc_free_port — the lowest p from 9121 where p and p+10 both bind on 127.0.0.1: the
# port discovery hands the first repo it finds.
rc_free_port() {
  "$PY" - <<'PY'
import socket, sys
def free(p):
    s = socket.socket()
    try:
        s.bind(("127.0.0.1", p))
        return True
    except OSError:
        return False
    finally:
        s.close()
for p in range(9121, 9621):
    if free(p) and free(p + 10):
        sys.stdout.buffer.write(b"%d" % p)
        break
PY
}

# rc_wire_fixture DIR — every agent template copied into DIR/agents, repo folders alpha,
# beta and gamma, maps naming them (alpha 9301, beta 9302, gamma 9303), and paths.json.
rc_wire_fixture() {
  local d="$1"
  rm -rf "$d" && mkdir -p "$d/agents" "$d/alpha" "$d/beta" "$d/gamma" \
    && cp "$REPO"/templates/agents/*.md "$d/agents/" && rm -f "$d/agents/README.md" \
    && "$PY" - "$d" <<'PY'
import json, os, sys
d = sys.argv[1]
ports = {"alpha": 9301, "beta": 9302, "gamma": 9303}
def write(name, keys):
    repos = {k: {"path": os.path.join(d, k).replace("\\", "/"), "port": ports[k]} for k in keys}
    with open(os.path.join(d, name), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"repos": repos}, f, indent=2)
write("map-ab.json", ["alpha", "beta"])
write("map-abg.json", ["alpha", "beta", "gamma"])
write("map-bg.json", ["beta", "gamma"])
json.dump([os.path.join(d, "agents")], open(os.path.join(d, "paths.json"), "w"))
PY
}

# rc_wire DIR MAP — install-lib.py serena-wire over DIR's agents with one of its maps.
rc_wire() {
  "$PY" "$REPO/install-lib.py" serena-wire "$1/paths.json" "$1/$2" \
    "$REPO/templates/serena/profiles.json" > "$1/wire-$2.out" 2>&1
}

# ---------------------------------------------------------------- RC1
# Catches: route C never suggested on a machine that has a repo map, and the third
# argument changing what an A or B machine is told.
if want RC1; then
banner "RC1 · serena-detect says C only when the repo map exists"
fresh_env rc1; with_serena
RC1L="$REPO/install-lib.py"
"$PY" "$RC1L" serena-detect "$HOME_DIR" "$SANDBOX/rc1" > "$SANDBOX/rc1/b2.json" \
  && "$PY" "$RC1L" serena-detect "$HOME_DIR" "$SANDBOX/rc1" "$CH" > "$SANDBOX/rc1/b3.json"
chk $? "setup: detect without a map, with and without the claude-home argument"
yn "$(cmp -s "$SANDBOX/rc1/b2.json" "$SANDBOX/rc1/b3.json" && echo 0 || echo 1)" \
   "RC1 control: without a map the claude-home argument changes nothing"
printf '{"repos": {}}\n' > "$CH/serena-repos.json" \
  && "$PY" "$RC1L" serena-detect "$HOME_DIR" "$SANDBOX/rc1" "$CH" > "$SANDBOX/rc1/c.json" \
  && mkdir -p "$HOME_DIR/.claude/plugins/cache/serena" \
  && "$PY" "$RC1L" serena-detect "$HOME_DIR" "$SANDBOX/rc1" "$CH" > "$SANDBOX/rc1/ca.json" \
  && rm -f "$CH/serena-repos.json" \
  && "$PY" "$RC1L" serena-detect "$HOME_DIR" "$SANDBOX/rc1" "$CH" > "$SANDBOX/rc1/a.json"
chk $? "setup: detect with a map, with a map and the plugin, with the plugin alone"
verdicts < <("$PY" - "$SANDBOX/rc1" "$(rc_w "$CH")" <<'PY'
import json, os, sys
d, ch = sys.argv[1], sys.argv[2]
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("PASS" if ok else "FAIL", name)).encode("utf-8"))
def get(n):
    try:
        return json.load(open(os.path.join(d, n), encoding="utf-8"))
    except Exception:
        return {}
say(get("b3.json").get("route") == "B", "RC1 control: a registered server with no map is route B")
c = get("c.json")
say(c.get("route") == "C", "RC1 a repo map in the claude home makes the route C (got %r)" % c.get("route"))
say(any("serena-repos.json" in (e.get("where") or "").replace("\\", "/")
        for e in c.get("evidence") or []), "RC1 the evidence names the repo map")
say(get("ca.json").get("route") == "C", "RC1 the map wins over plugin files (got %r)" % get("ca.json").get("route"))
say(get("a.json").get("route") == "A", "RC1 control: plugin files and no map is still route A")
PY
)
fi

# ---------------------------------------------------------------- RC2
# Catches: a wired agent keeping a tool its profile does not have, holding the wrong
# port for its role, keeping activate_project, an mcpServers block in a shape Claude
# Code does not read, a body still naming mcp__serena__, and a CRLF write.
if want RC2; then
banner "RC2 · serena-wire gives each Serena agent per-repo servers, tools and disallowedTools"
fresh_env rc2
RC2D="$SANDBOX/rc2/w"
rc_wire_fixture "$RC2D"
chk $? "setup: every agent template, and a two-repo map"
rc_wire "$RC2D" map-ab.json
chk $? "install-lib.py serena-wire exits 0 (see $RC2D/wire-map-ab.json.out)"
verdicts < <("$PY" - "$REPO" "$RC2D" <<'PY'
import importlib.util, json, os, re, sys
sys.dont_write_bytecode = True
repo, d = sys.argv[1], sys.argv[2]
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("PASS" if ok else "FAIL", name)).encode("utf-8"))
prof = json.load(open(os.path.join(repo, "templates", "serena", "profiles.json"), encoding="utf-8"))
edit_only = set(prof["edit"]) - set(prof["read"])
keys, ports = ["alpha", "beta"], {"alpha": 9301, "beta": 9302}
bad = {k: [] for k in ("cr", "tools", "others", "disallowed", "servers", "body", "fm", "untouched")}
n = 0
tdir = os.path.join(repo, "templates", "agents")
for fn in sorted(os.listdir(tdir)):
    if not fn.endswith(".md") or fn == "README.md":
        continue
    raw_tpl = open(os.path.join(tdir, fn), "rb").read()
    raw = open(os.path.join(d, "agents", fn), "rb").read()
    tpl = raw_tpl.decode("utf-8").replace("\r\n", "\n")
    tfm, tbody = tpl.split("\n---\n", 1)
    tline = re.search(r"^tools:(.*)$", tfm, re.M)
    entries = [t.strip() for t in tline.group(1).split(",") if t.strip()] if tline else []
    verbs = [t[len("mcp__serena__"):] for t in entries if t.startswith("mcp__serena__")]
    if not verbs:
        if raw != raw_tpl:
            bad["untouched"].append(fn)
        continue
    n += 1
    if b"\r" in raw:
        bad["cr"].append(fn)
    text = raw.decode("utf-8").replace("\r\n", "\n")
    fm, body = text.split("\n---\n", 1)
    base = [v for v in verbs if v != "activate_project"]
    role = "edit" if set(base) & edit_only else "read"
    line = re.search(r"^tools:(.*)$", fm, re.M)
    got = [t.strip() for t in line.group(1).split(",") if t.strip()] if line else []
    if [t for t in got if t.startswith("mcp__serena")] != ["mcp__serena-%s__%s" % (k, v) for k in keys for v in base]:
        bad["tools"].append(fn)
    wired = "\nmcpServers:\n" in fm + "\n"
    if not wired or [t for t in got if not t.startswith("mcp__serena")] != [t for t in entries if not t.startswith("mcp__serena")]:
        bad["others"].append(fn)
    dis = re.search(r"^disallowedTools:(.*)$", fm, re.M)
    want_dis = {"mcp__serena-%s__%s" % (k, t) for k in keys for t in prof["all_tools"] if t not in base}
    got_dis = [t.strip() for t in dis.group(1).split(",") if t.strip()] if dis else []
    if set(got_dis) != want_dis or len(got_dis) != len(want_dis):
        bad["disallowed"].append(fn)
    block = ["mcpServers:"]
    for k in keys:
        block += ["  - serena-%s:" % k, "      type: http",
                  "      url: http://127.0.0.1:%d/mcp" % (ports[k] + (10 if role == "edit" else 0))]
    if "\n" + "\n".join(block) + "\n" not in fm + "\n":
        bad["servers"].append("%s(%s)" % (fn, role))
    if "mcp__serena__" in text or ("mcp__serena__" in tbody and "mcp__serena-<key>__" not in body):
        bad["body"].append(fn)
    owned = re.compile(r"^(tools|disallowedTools|mcpServers):|^\s+(- serena-|type: http|url: http)")
    if not wired or [l for l in tfm.split("\n") if not owned.match(l)] != [l for l in fm.split("\n") if not owned.match(l)]:
        bad["fm"].append(fn)
say(n > 0, "RC2 the fixture holds Serena agents at all (%d)" % n)
say(not bad["cr"], "RC2 every wired agent is written LF, 0 CR %s" % bad["cr"])
say(not bad["tools"], "RC2 tools: holds mcp__serena-<key>__<verb> for each repo x the verbs it had, minus activate_project %s" % bad["tools"])
say(not bad["others"], "RC2 tools: keeps every non-Serena tool, in order %s" % bad["others"])
say(not bad["disallowed"], "RC2 disallowedTools is each repo x every other Serena tool %s" % bad["disallowed"])
say(not bad["servers"], "RC2 mcpServers lists one http serena-<key> per repo, on the edit port for an edit agent %s" % bad["servers"])
say(not bad["body"], "RC2 no body names mcp__serena__; it says mcp__serena-<key>__ instead %s" % bad["body"])
say(not bad["fm"], "RC2 every other frontmatter line is unchanged %s" % bad["fm"])
say(not bad["untouched"], "RC2 control: an agent with no Serena tools is not touched %s" % bad["untouched"])
def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
try:
    lib = load(os.path.join(repo, "install-lib.py"), "install_lib")
    kit = load(os.path.join(repo, "templates", "serena", "serena_route.py"), "serena_route")
    same = getattr(lib, "SERENA_EDIT_OFFSET", None) == kit.EDIT_OFFSET
except Exception:
    same = False
say(same, "RC2 install-lib.py's edit-port offset is the kit's EDIT_OFFSET")
PY
)
fi

# ---------------------------------------------------------------- RC3
# Catches: a re-run that duplicates entries or drifts, and a repo removed from the map
# that stays wired.
if want RC3; then
banner "RC3 · serena-wire is idempotent, and follows the map when a repo is added or removed"
fresh_env rc3
RC3D="$SANDBOX/rc3/w"
rc_wire_fixture "$RC3D" && mkdir -p "$SANDBOX/rc3/once" "$SANDBOX/rc3/gone"
chk $? "setup: every agent template, and maps with two, three and a different two repos"
rc_wire "$RC3D" map-ab.json && cp "$RC3D"/agents/*.md "$SANDBOX/rc3/once/" && rc_wire "$RC3D" map-ab.json
chk $? "wired twice with the same map"
yn "$(diff -r -q "$SANDBOX/rc3/once" "$RC3D/agents" >/dev/null 2>&1 && echo 0 || echo 1)" \
   "RC3 a second run with the same map changes no byte"
rc_wire "$RC3D" map-abg.json
chk $? "wired again with gamma added"
verdicts < <("$PY" - "$RC3D/agents" <<'PY'
import os, re, sys
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("PASS" if ok else "FAIL", name)).encode("utf-8"))
bad_keys, dupes, servers, n = [], [], [], 0
for fn in sorted(os.listdir(sys.argv[1])):
    text = open(os.path.join(sys.argv[1], fn), encoding="utf-8").read()
    fm = text.split("\n---\n", 1)[0]
    line = re.search(r"^tools:(.*)$", fm, re.M)
    tools = [t.strip() for t in line.group(1).split(",") if t.strip()] if line else []
    serena = [t for t in tools if t.startswith("mcp__serena")]
    if not serena:
        continue
    n += 1
    if {mm.group(1) for mm in (re.match(r"mcp__serena-([a-z0-9-]+)__", t) for t in serena) if mm} != {"alpha", "beta", "gamma"}:
        bad_keys.append(fn)
    dis = re.search(r"^disallowedTools:(.*)$", fm, re.M)
    dl = [t.strip() for t in dis.group(1).split(",") if t.strip()] if dis else []
    if len(set(tools)) != len(tools) or len(set(dl)) != len(dl):
        dupes.append(fn)
    if len(re.findall(r"^  - serena-", fm, re.M)) != 3 or fm.count("mcpServers:") != 1:
        servers.append(fn)
say(n > 0, "RC3 the three-repo run wired Serena agents at all (%d)" % n)
say(not bad_keys, "RC3 every Serena agent now holds tools for alpha, beta and gamma %s" % bad_keys)
say(not dupes, "RC3 no tool appears twice in tools: or disallowedTools %s" % dupes)
say(not servers, "RC3 one mcpServers key with exactly three servers %s" % servers)
PY
)
rc_wire "$RC3D" map-bg.json && cp "$RC3D"/agents/*.md "$SANDBOX/rc3/gone/" && rc_wire "$RC3D" map-bg.json
chk $? "wired twice with alpha removed"
yn "$(! grep -lF 'serena-alpha' "$RC3D"/agents/*.md >/dev/null 2>&1 \
       && grep -lF 'serena-beta' "$RC3D"/agents/*.md >/dev/null 2>&1 && echo 0 || echo 1)" \
   "RC3 alpha removed from the map leaves no serena-alpha in any agent, and beta still wired"
yn "$(diff -r -q "$SANDBOX/rc3/gone" "$RC3D/agents" >/dev/null 2>&1 && echo 0 || echo 1)" \
   "RC3 a second run after the removal changes no byte"
fi

# ---------------------------------------------------------------- RC4
# Catches: every wired agent reading "edited" once its wiring no longer matches the
# hash on record — update would then never refresh it and remove never delete it — and
# a serena-wire run that needs a keyboard.
if want RC4; then
banner "RC4 · serena-wire adds a repo with nobody at the keyboard, and rewired agents stay current"
rc_env rc4 alpha beta
chk $? "setup: a fixture folder with git repos alpha and beta, and a clone of the installer"
keys rc4 "${CFULL[@]}"; run_c install rc4
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the route C install exits 0 (rc=$RC)"
mkdir -p "$RCDIR/gamma/.git" && run_c_raw rc4w serena-wire
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RC4 serena-wire exits 0 with stdin closed (rc=$RC)"
yn "$([ "$(bytes rc4w)" -lt 20000 ] && echo 0 || echo 1)" "RC4 serena-wire's output is bounded ($(bytes rc4w) bytes)"
verdicts < <("$PY" - "$CH" <<'PY'
import json, os, re, sys
ch = sys.argv[1]
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("PASS" if ok else "FAIL", name)).encode("utf-8"))
try:
    m = json.load(open(os.path.join(ch, ".playbook-install.json"), encoding="utf-8"))
    repos = json.load(open(os.path.join(ch, "serena-repos.json"), encoding="utf-8"))["repos"]
except Exception as e:
    say(False, "RC4 read the manifest and the map (%s)" % e)
    sys.exit(0)
cfg = m.get("config") or {}
say(list(repos) == ["alpha", "beta", "gamma"], "RC4 the map gained gamma after alpha and beta (%s)" % list(repos))
say(cfg.get("serena_route") == "C", "RC4 the manifest records route C")
wired = [r.get("key") for r in (cfg.get("serena_wiring") or {}).get("repos") or []]
say(wired == ["alpha", "beta", "gamma"], "RC4 the recorded wiring names alpha, beta, gamma (%s)" % wired)
agents = [(u, r["dest"]) for u, r in m.get("units", {}).items() if u.startswith("agent:")]
serena = [u for u, p in agents if re.search(r"^tools:.*mcp__serena-", open(p, encoding="utf-8").read(), re.M)]
gamma = [u for u, p in agents if "mcp__serena-gamma__" in open(p, encoding="utf-8").read()]
say(bool(serena) and sorted(serena) == sorted(gamma), "RC4 every wired agent now holds gamma's tools (%d of %d)" % (len(gamma), len(serena)))
with open(os.path.join(os.path.dirname(ch), "wired.txt"), "wb") as f:
    f.write("".join(u + "\n" for u in sorted(serena)).encode("utf-8"))
PY
)
nokeys rc4l; run_c list rc4l
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "list exits 0 (rc=$RC)"
RC4N=0; RC4BAD=""
while IFS= read -r RC4U; do
  [ -n "$RC4U" ] || continue
  RC4N=$((RC4N + 1))
  grep -qE "current +$RC4U\$" "$LOGS/rc4l.out" || RC4BAD="$RC4BAD $RC4U"
done < "$SANDBOX/rc4/wired.txt"
yn "$([ "$RC4N" -gt 0 ] && [ -z "$RC4BAD" ] && echo 0 || echo 1)" \
   "RC4 list calls all $RC4N rewired agents current${RC4BAD:+ — not:$RC4BAD}"
yn "$(grep -qE 'edited +agent:' "$LOGS/rc4l.out" && echo 1 || echo 0)" "RC4 list calls no agent edited"
mkdir -p "$SANDBOX/rc4/before" && cp "$CH"/agents/*.md "$SANDBOX/rc4/before/"
nokeys rc4u; run_c update rc4u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RC4 update exits 0 (rc=$RC)"
yn "$(diff -r -q "$SANDBOX/rc4/before" "$CH/agents" >/dev/null 2>&1 && echo 0 || echo 1)" \
   "RC4 update rewires from the record and leaves every agent byte-identical"
yn "$("$PY" -c 'import json,sys;c=json.load(open(sys.argv[1])).get("config") or {};sys.exit(0 if c.get("serena_route")=="C" and [r["key"] for r in c["serena_wiring"]["repos"]]==["alpha","beta","gamma"] else 1)' "$CH/.playbook-install.json" 2>/dev/null && echo 0 || echo 1)" \
   "RC4 update keeps route C and the recorded wiring in the manifest"
fi

# ---------------------------------------------------------------- RC5
# Catches: remove keeping wired agents as "edited", leaving the kit behind, or deleting
# the user's own repo map and server state.
if want RC5; then
banner "RC5 · remove takes out the kit and the wired agents, and keeps the map and the state"
rc_env rc5 alpha
chk $? "setup: a fixture folder with git repo alpha, and a clone of the installer"
keys rc5 "${CFULL[@]}"; run_c install rc5
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the route C install exits 0 (rc=$RC)"
mkdir -p "$CH/serena-state" && printf '{}\n' > "$CH/serena-state/alpha-read.json" \
  && "$PY" - "$CH/.playbook-install.json" "$SANDBOX/rc5/agents.txt" <<'PY'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
wired = [r["dest"] for u, r in sorted(m["units"].items())
         if u.startswith("agent:") and "mcp__serena-" in open(r["dest"], encoding="utf-8").read()]
with open(sys.argv[2], "wb") as f:
    f.write("".join(d.replace("\\", "/") + "\n" for d in wired).encode("utf-8"))
sys.exit(0 if wired and "support:serena-kit" in m["units"] else 1)
PY
chk $? "setup: a state file, and the list of wired agents the manifest records beside the kit"
keys rc5r '' 'y'; run_c remove rc5r
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "remove exits 0 (rc=$RC)"
yn "$([ ! -e "$CH/serena" ] && echo 0 || echo 1)" "RC5 the route C kit is removed"
RC5LEFT=0
while IFS= read -r RC5A; do
  RC5A="${RC5A%$'\r'}"
  [ -n "$RC5A" ] && [ -e "$RC5A" ] && RC5LEFT=$((RC5LEFT + 1))
done < "$SANDBOX/rc5/agents.txt"
yn "$([ -s "$SANDBOX/rc5/agents.txt" ] && [ "$RC5LEFT" = 0 ] && echo 0 || echo 1)" \
   "RC5 every wired agent is removed, none kept as edited ($RC5LEFT left)"
yn "$([ -f "$CH/serena-repos.json" ] && echo 0 || echo 1)" "RC5 the repo map is kept"
yn "$([ -f "$CH/serena-state/alpha-read.json" ] && echo 0 || echo 1)" "RC5 the server state is kept"
inboth rc5r "serena-repos.json" "RC5 remove says it kept the repo map"
fi

# ---------------------------------------------------------------- RC6
# Catches: route A or B installing the route C kit or its SessionStart notice — the
# recommended preset ticks every hook and everything ticks every unit — and route C
# not installing them. Also a re-install that switches route (C to A, C to B, A to B)
# leaving unedited agents on the old route's tool names or route C servers, and one
# that overwrites an agent the user edited.
if want RC6; then
banner "RC6 · only route C installs the route C units"
"$PY" "$REPO/install-lib.py" discover "$REPO/templates" "$SANDBOX/rc6-units" > "$SANDBOX/rc6-units.json"
chk $? "discovered the units"
RC6IDS="$("$PY" - "$SANDBOX/rc6-units.json" <<'PY'
import json, sys
u = json.load(open(sys.argv[1], encoding="utf-8"))
sys.stdout.buffer.write(" ".join(sorted(k for k, v in u.items() if v.get("route_c_only"))).encode())
PY
)"
yn "$([ -n "$RC6IDS" ] && echo 0 || echo 1)" "RC6 discovery tags route C units at all (${RC6IDS:-none})"
case " $RC6IDS " in *" support:serena-kit "*) RC6K=0 ;; *) RC6K=1 ;; esac
yn "$RC6K" "RC6 the kit is a route C unit"
case " $RC6IDS " in *" hook:serena-leftover-notice "*) RC6K=0 ;; *) RC6K=1 ;; esac
yn "$RC6K" "RC6 the leftover-notice hook is a route C unit"
yn "$("$PY" -c 'import json,sys;u=json.load(open(sys.argv[1]));sys.exit(0 if "support:hook-lib" in u.get("support:serena-kit",{}).get("needs",[]) else 1)' "$SANDBOX/rc6-units.json" && echo 0 || echo 1)" \
   "RC6 the kit pulls in the hook library its .sh wrappers source"
# rc6_check LOG ROUTE — what the manifest, settings.json and the disk say for one route.
rc6_check() {
  local log="$1" route="$2" id rec=0
  yn "$([ -f "$CH/.playbook-install.json" ] && echo 0 || echo 1)" "RC6 $log: the install wrote its manifest"
  for id in $RC6IDS; do
    rc_recorded "$id" && rec=$((rec + 1))
  done
  if [ "$route" = C ]; then
    yn "$([ -n "$RC6IDS" ] && [ "$rec" = "$(echo "$RC6IDS" | wc -w | tr -d ' ')" ] && echo 0 || echo 1)" \
       "RC6 $log: route C records every route C unit ($rec)"
    yn "$([ -f "$CH/serena/serena_route.py" ] && echo 0 || echo 1)" "RC6 $log: the kit is on disk"
    yn "$(grep -qF '"SessionStart"' "$CH/settings.json" 2>/dev/null && echo 0 || echo 1)" \
       "RC6 $log: settings.json wires SessionStart"
  else
    yn "$([ "$rec" = 0 ] && echo 0 || echo 1)" "RC6 $log: route $route records no route C unit ($rec)"
    yn "$([ ! -e "$CH/serena" ] && [ ! -e "$CH/serena-repos.json" ] && echo 0 || echo 1)" \
       "RC6 $log: no kit and no repo map on disk"
    yn "$(grep -qF '"SessionStart"' "$CH/settings.json" 2>/dev/null && echo 1 || echo 0)" \
       "RC6 $log: settings.json has no SessionStart"
  fi
}
# rc6_route_scan ROUTE SKIP LABEL — "PASS|…"/"FAIL|…" lines for verdicts, over every
# .md the manifest records except the route C kit and the file SKIP. ROUTE C only
# counts the files that carry route C wiring: the control that the scan reads them.
rc6_route_scan() {
  "$PY" - "$CH/.playbook-install.json" "$1" "$2" "$3" <<'PY'
import json, os, re, sys
manifest, route, skip, label = sys.argv[1:5]
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("PASS" if ok else "FAIL", name)).encode("utf-8"))
def norm(p):
    return os.path.normcase(os.path.normpath(p))
m = json.load(open(manifest, encoding="utf-8"))
files = []
for uid, rec in sorted((m.get("units") or {}).items()):
    d = rec.get("dest") or ""
    if rec.get("kind") == "serena-kit" or not d:
        continue
    if os.path.isdir(d):
        files += [os.path.join(r, f) for r, _, fs in os.walk(d) for f in fs]
    elif os.path.isfile(d):
        files.append(d)
files = [f for f in files if f.endswith(".md") and (not skip or norm(f) != norm(skip))]
texts = {f: open(f, encoding="utf-8").read() for f in files}
def holding(test):
    return [os.path.basename(f) for f, t in sorted(texts.items()) if test(t)]
wired = holding(lambda t: re.search(r"mcp__serena-[a-z0-9]", t) or re.search(r"^mcpServers:", t, re.M))
plugin = holding(lambda t: "mcp__plugin_serena_serena__" in t)
plain = holding(lambda t: "mcp__serena__" in t)
cfg = m.get("config") or {}
if route == "C":
    say(wired, "RC6 %s: control, the scan finds route C wiring in %d recorded file(s)" % (label, len(wired)))
    sys.exit(0)
say(not wired, "RC6 %s: no unedited file carries route C wiring (%s)" % (label, ", ".join(wired[:5]) or "none"))
if route == "A":
    say(plugin and not plain, "RC6 %s: every Serena file names the plugin tools (%d do; mcp__serena__ in: %s)"
        % (label, len(plugin), ", ".join(plain[:5]) or "none"))
else:
    say(plain and not plugin, "RC6 %s: every Serena file names mcp__serena__ (%d do; the plugin form in: %s)"
        % (label, len(plain), ", ".join(plugin[:5]) or "none"))
say("serena_route" not in cfg and "serena_wiring" not in cfg, "RC6 %s: the manifest records no route C wiring" % label)
PY
}
# rc6_edit_agent NEEDLE LOG — append a line to the first recorded agent holding NEEDLE,
# keep a copy at $SANDBOX/LOG-edited.md, and print the agent's path.
rc6_edit_agent() {
  "$PY" - "$CH/.playbook-install.json" "$1" "$SANDBOX/$2-edited.md" <<'PY'
import json, shutil, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
for uid, rec in sorted(m["units"].items()):
    if uid.startswith("agent:") and sys.argv[2] in open(rec["dest"], encoding="utf-8").read():
        with open(rec["dest"], "ab") as f:
            f.write(b"\nmy own note\n")
        shutil.copyfile(rec["dest"], sys.argv[3])
        sys.stdout.buffer.write(rec["dest"].replace("\\", "/").encode("utf-8"))
        break
PY
}
rc_env rc6a alpha
keys rc6a '' '' '5' '4' '' 'i' 'A' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''; run_c install rc6a
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the route A recommended install exits 0 (rc=$RC)"
rc6_check "A recommended" A
verdicts < <(rc6_route_scan A "" "A recommended")
RC6ED="$(rc6_edit_agent mcp__plugin_serena_serena__ rc6ab)"
yn "$([ -n "$RC6ED" ] && echo 0 || echo 1)" "setup: an agent naming the plugin tools is edited by hand (${RC6ED:-none})"
RC6SW=( "${CRERUN[@]}" ); RC6SW[4]=B
keys rc6ab "${RC6SW[@]}"; run_c install rc6ab
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the A -> B re-install exits 0 (rc=$RC)"
verdicts < <(rc6_route_scan B "$RC6ED" "A -> B")
yn "$([ -n "$RC6ED" ] && cmp -s "$RC6ED" "$SANDBOX/rc6ab-edited.md" && echo 0 || echo 1)" \
   "RC6 A -> B: the agent edited by hand keeps the edit"
rc_env rc6e alpha
keys rc6e '' '' 'e' '5' '4' '' 'i' 'A' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''; run_c install rc6e
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the route A everything install exits 0 (rc=$RC)"
rc6_check "A everything" A
rc_env rc6c alpha
keys rc6c "${CFULL[@]}"; run_c install rc6c
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the route C install exits 0 (rc=$RC)"
rc6_check "C recommended" C
verdicts < <(rc6_route_scan C "" "C recommended")
RC6ED="$(rc6_edit_agent mcp__serena- rc6ca)"
yn "$([ -n "$RC6ED" ] && echo 0 || echo 1)" "setup: an agent wired for route C is edited by hand (${RC6ED:-none})"
RC6SW=( "${CRERUN[@]}" ); RC6SW[4]=A
keys rc6ca "${RC6SW[@]}"; run_c install rc6ca
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the C -> A re-install exits 0 (rc=$RC)"
verdicts < <(rc6_route_scan A "$RC6ED" "C -> A")
yn "$([ -n "$RC6ED" ] && cmp -s "$RC6ED" "$SANDBOX/rc6ca-edited.md" && echo 0 || echo 1)" \
   "RC6 C -> A: the agent edited by hand keeps the edit"
rc_env rc6cb alpha
keys rc6cb "${CFULL[@]}"; run_c install rc6cb
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the route C install exits 0 (rc=$RC)"
RC6SW=( "${CRERUN[@]}" ); RC6SW[4]=B
keys rc6cb2 "${RC6SW[@]}"; run_c install rc6cb2
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the C -> B re-install exits 0 (rc=$RC)"
verdicts < <(rc6_route_scan B "" "C -> B")
fi

# ---------------------------------------------------------------- RC7
# Catches: a broken repo map being used or overwritten — a placeholder path, a folder
# that is not there, or two repos on one port — when the run should stop first.
if want RC7; then
banner "RC7 · an invalid repo map stops the run before anything is written"
rc_env rc7 alpha
chk $? "setup: a fixture folder with git repo alpha, and a clone of the installer"
RC7A="$(rc_w "$RCDIR/alpha")"
for RC7V in placeholder missing clash; do
  rm -rf "$CH" && mkdir -p "$CH"
  case "$RC7V" in
    placeholder) RC7J="{\"repos\": {\"alpha\": {\"path\": \"<absolute path to the repo>\", \"port\": 9121}}}"
                 RC7T="is still the placeholder" ;;
    missing)     RC7J="{\"repos\": {\"alpha\": {\"path\": \"$RC7A/no-such-folder\", \"port\": 9121}}}"
                 RC7T="is not a folder on this machine" ;;
    clash)       RC7J="{\"repos\": {\"alpha\": {\"path\": \"$RC7A\", \"port\": 9121}, \"beta\": {\"path\": \"$RC7A\", \"port\": 9131}}}"
                 RC7T="both use port 9131" ;;
  esac
  printf '%s\n' "$RC7J" > "$CH/serena-repos.json"
  cp "$CH/serena-repos.json" "$SANDBOX/rc7/map-before.json"
  keys "rc7-$RC7V" "${CFULL[@]}"; run_c install "rc7-$RC7V"
  yn "$([ "$RC" != "0" ] && echo 0 || echo 1)" "RC7 $RC7V: the install stops (rc=$RC)"
  inboth "rc7-$RC7V" "$RC7T" "RC7 $RC7V: it prints the validator's line ($RC7T)"
  yn "$([ "$(n_files)" = 1 ] && cmp -s "$CH/serena-repos.json" "$SANDBOX/rc7/map-before.json" && echo 0 || echo 1)" \
     "RC7 $RC7V: nothing is written — the map alone is in the claude home, unchanged ($(n_files) files)"
done
run_c_raw rc7w serena-wire
yn "$([ "$RC" != "0" ] && bothgrep rc7w "both use port 9131" && echo 0 || echo 1)" \
   "RC7 serena-wire with stdin closed stops on the clashing map, printing the validator's line (rc=$RC)"
yn "$([ "$(n_files)" = 1 ] && cmp -s "$CH/serena-repos.json" "$SANDBOX/rc7/map-before.json" && echo 0 || echo 1)" \
   "RC7 serena-wire writes nothing ($(n_files) files)"
yn "$([ "$(bytes rc7w)" -lt 20000 ] && echo 0 || echo 1)" "RC7 serena-wire's output is bounded ($(bytes rc7w) bytes)"
fi

# ---------------------------------------------------------------- RC9
# Catches: discovery listing a folder that is not a git repo, the playbook clone itself,
# a key the kit refuses, two repos on one key or port, a port another program holds,
# a CRLF map; a run with no repos that crashes or half-installs route C; and an
# existing map that is rewritten instead of appended to.
if want RC9; then
banner "RC9 · the repo map is filled in from the git repos next to the clone"

# RC9a — discovery on a fresh machine.
rc_env rc9a My_Repo plain
rm -rf "$RCDIR/plain/.git" && mkdir -p "$RCDIR/my-repo" && printf 'gitdir: ../elsewhere\n' > "$RCDIR/my-repo/.git"
chk $? "RC9a setup: My_Repo (.git folder), my-repo (.git file), plain (no .git), and the clone"
RC9H="$(rc_free_port)"
"$PY" - "${RC9H:-0}" "$SANDBOX/rc9a/held" <<'PY' &
import os, socket, sys, time
s = socket.socket()
s.bind(("127.0.0.1", int(sys.argv[1])))
s.listen(1)
open(sys.argv[2], "w").close()
end = time.time() + 300
while time.time() < end and not os.path.exists(sys.argv[2] + ".stop"):
    time.sleep(0.2)
PY
RC9HPID=$!
for _i in $(seq 1 50); do [ -f "$SANDBOX/rc9a/held" ] && break; sleep 0.2; done
yn "$([ -n "$RC9H" ] && [ -f "$SANDBOX/rc9a/held" ] && echo 0 || echo 1)" \
   "RC9a setup: port ${RC9H:-NONE}, the one discovery would pick first, is held open"
keys rc9a "${CFULL[@]}"; run_c install rc9a
touch "$SANDBOX/rc9a/held.stop"; wait "$RC9HPID" 2>/dev/null
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RC9a the route C install exits 0 (rc=$RC)"
inboth rc9a "my-repo-2" "RC9a the output names the second repo's key"
inboth rc9a "$(rc_w "$RCDIR/My_Repo")" "RC9a the output names the first repo's folder"
"$PY" "$REPO/templates/serena/serena_route.py" validate --map "$CH/serena-repos.json" > "$SANDBOX/rc9a/validate.out" 2>&1
yn "$?" "RC9a the written map passes the kit's own validator ($(tr -d '\r' < "$SANDBOX/rc9a/validate.out" | head -1))"
yn "$([ -f "$CH/serena-repos.json" ] && [ "$(tr -cd '\r' < "$CH/serena-repos.json" | wc -c)" = 0 ] && echo 0 || echo 1)" \
   "RC9a the map is written LF, 0 CR"
verdicts < <("$PY" - "$CH" "$RCDIR" "${RC9H:-0}" <<'PY'
import json, os, re, sys
ch, fix, held = sys.argv[1], sys.argv[2], int(sys.argv[3])
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("PASS" if ok else "FAIL", name)).encode("utf-8"))
def norm(p):
    return os.path.normcase(os.path.realpath(p))
try:
    repos = json.load(open(os.path.join(ch, "serena-repos.json"), encoding="utf-8"))["repos"]
    m = json.load(open(os.path.join(ch, ".playbook-install.json"), encoding="utf-8"))
except Exception as e:
    say(False, "RC9a read the map and the manifest (%s)" % e)
    sys.exit(0)
say(list(repos) == ["my-repo", "my-repo-2"], "RC9a the map lists exactly the two git repos, the clash as -2 (%s)" % list(repos))
say(all(re.match(r"^[a-z0-9][a-z0-9-]*$", k) for k in repos), "RC9a every key is one the kit accepts")
paths = {k: norm(r.get("path", "")) for k, r in repos.items()}
say(paths.get("my-repo") == norm(os.path.join(fix, "My_Repo")) and paths.get("my-repo-2") == norm(os.path.join(fix, "my-repo")),
    "RC9a each key points at its own folder")
ports = [p for r in repos.values() for p in (r.get("port"), (r.get("port") or 0) + 10)]
say(len(set(ports)) == len(ports), "RC9a every port and port + 10 is unique (%s)" % ports)
say(held not in ports, "RC9a the held port %d is skipped (%s)" % (held, ports))
say(all("/" in r.get("path", "") and "\\" not in r.get("path", "") for r in repos.values()), "RC9a paths are stored with forward slashes")
say((m.get("config") or {}).get("serena_route") == "C", "RC9a the manifest records route C")
PY
)

# RC9b — no repos next to the clone.
rc_env rc9b
chk $? "RC9b setup: a fixture folder holding only the clone"
keys rc9b "${CFULL[@]}"; run_c install rc9b
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RC9b the install still exits 0 (rc=$RC)"
inboth rc9b "$(rc_w "$RCDIR")" "RC9b the message names the folder it searched"
inboth rc9b "nothing is set up for route C" "RC9b it says route C was not set up"
yn "$([ ! -e "$CH/serena-repos.json" ] && [ ! -e "$CH/serena" ] && echo 0 || echo 1)" "RC9b no map and no kit are written"
yn "$(! grep -qF '"serena_route"' "$CH/.playbook-install.json" 2>/dev/null \
       && [ -f "$CH/.playbook-install.json" ] && ! rc_recorded support:serena-kit \
       && ! rc_recorded hook:serena-leftover-notice && echo 0 || echo 1)" \
   "RC9b the manifest records no route C and no route C unit"
run_c_raw rc9bw serena-wire
yn "$([ "$RC" != "0" ] && bothgrep rc9bw "$(rc_w "$RCDIR")" && echo 0 || echo 1)" \
   "RC9b serena-wire with stdin closed stops with nothing to wire, naming the folder it searched (rc=$RC)"
yn "$([ ! -e "$CH/serena-repos.json" ] && echo 0 || echo 1)" "RC9b serena-wire writes no map"
yn "$([ "$(bytes rc9bw)" -lt 20000 ] && echo 0 || echo 1)" "RC9b serena-wire's output is bounded ($(bytes rc9bw) bytes)"

# RC9c — a map that already exists.
rc_env rc9c alpha
RC9P="$(rc_free_port)"
mkdir -p "$CH" && printf '{\n   "repos": {\n      "alpha": {"path": "%s", "port": %s}\n   },\n   "note": "kept as written"\n}\n' \
  "$(rc_w "$RCDIR/alpha")" "${RC9P:-9121}" > "$CH/serena-repos.json" && cp "$CH/serena-repos.json" "$SANDBOX/rc9c/map-0.json"
chk $? "RC9c setup: a hand-formatted map naming alpha on port ${RC9P:-NONE}"
keys rc9c "${CFULL[@]}"; run_c install rc9c
yn "$([ "$RC" = "0" ] && rc_recorded support:serena-kit && echo 0 || echo 1)" \
   "RC9c the install over an existing map exits 0 and installs route C (rc=$RC)"
yn "$(cmp -s "$CH/serena-repos.json" "$SANDBOX/rc9c/map-0.json" && echo 0 || echo 1)" \
   "RC9c with no new repo the map is byte-identical"
mkdir -p "$RCDIR/gamma/.git"
keys rc9c2 "${CRERUN[@]}"; run_c install rc9c2
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RC9c the re-run with gamma added exits 0 (rc=$RC)"
inboth rc9c2 "gamma" "RC9c the re-run names the repo it added"
cp "$CH/serena-repos.json" "$SANDBOX/rc9c/map-1.json" 2>/dev/null
verdicts < <("$PY" - "$SANDBOX/rc9c/map-0.json" "$SANDBOX/rc9c/map-1.json" "$CH" <<'PY'
import json, os, sys
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("PASS" if ok else "FAIL", name)).encode("utf-8"))
old = open(sys.argv[1], encoding="utf-8").read()
try:
    new = open(sys.argv[2], encoding="utf-8").read()
    o, n = json.loads(old), json.loads(new)
    m = json.load(open(os.path.join(sys.argv[3], ".playbook-install.json"), encoding="utf-8"))
except Exception as e:
    say(False, "RC9c read the maps and the manifest (%s)" % e)
    sys.exit(0)
k = 0
while k < min(len(old), len(new)) and old[k] == new[k]:
    k += 1
say(len(new) > len(old) and new.endswith(old[k:]), "RC9c the old map survives whole around one appended stretch")
say(list(n["repos"]) == ["alpha", "gamma"], "RC9c gamma is appended after alpha (%s)" % list(n["repos"]))
say(n["repos"]["alpha"] == o["repos"]["alpha"] and n.get("note") == o.get("note"), "RC9c alpha's entry and the user's own key are unchanged")
p0, g = o["repos"]["alpha"]["port"], (n["repos"].get("gamma") or {}).get("port", 0)
say(bool(g) and {g, g + 10}.isdisjoint({p0, p0 + 10}), "RC9c gamma's ports %d/%d avoid alpha's %d/%d" % (g, g + 10, p0, p0 + 10))
wired = [r.get("key") for r in ((m.get("config") or {}).get("serena_wiring") or {}).get("repos") or []]
say(wired == ["alpha", "gamma"], "RC9c the recorded wiring follows the map (%s)" % wired)
PY
)
run_c_raw rc9cw serena-wire
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "RC9c serena-wire with nothing new exits 0 (rc=$RC)"
yn "$(cmp -s "$CH/serena-repos.json" "$SANDBOX/rc9c/map-1.json" && echo 0 || echo 1)" \
   "RC9c serena-wire with nothing new leaves the map byte-identical"
fi

close_section
printf '\n--- time per section (whole seconds, run order)\n'
for _row in ${SECTION_ROWS[@]+"${SECTION_ROWS[@]}"}; do printf '  %s\n' "$_row"; done
printf '  %s sections   %ss total\n' "${#SECTION_ROWS[@]}" "$SECONDS"

printf '\n================================\n'
printf '  passed %s   failed %s\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failures:\n'
  for f in "${FAILED_NAMES[@]}"; do printf '    - %s\n' "$f"; done
  exit 1
fi
exit 0
