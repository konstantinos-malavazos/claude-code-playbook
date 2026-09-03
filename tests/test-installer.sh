#!/usr/bin/env bash
# Test driver for issue #85. Drives install.sh with redirected HOME / CLAUDE_HOME
# so nothing touches the real ~/.claude. Run from anywhere.
#
#   bash tests/test-installer.sh            # all tests
#   bash tests/test-installer.sh 5 8        # only these

# The repo is the parent of tests/. The sandbox and the logs go to a temp dir, never
# into the repo: every run redirects HOME and CLAUDE_HOME into it, so a stray path
# here would be the one thing this suite must never do — touch the real ~/.claude.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SCRATCH="${PLAYBOOK_TEST_DIR:-${TMPDIR:-/tmp}/playbook-install-tests}"
SANDBOX="$SCRATCH/sandbox"
LOGS="$SCRATCH/logs"

PASS=0; FAIL=0
FAILED_NAMES=()

pass() { PASS=$((PASS+1)); printf '    PASS  %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); printf '    FAIL  %s\n' "$1"; }
chk()  { if [ "$1" = "0" ]; then pass "$2"; else fail "$2"; fi; }
yn()   { if [ "$1" = "0" ]; then pass "$2"; else fail "$2"; fi; }

banner() { printf '\n=== %s\n' "$1"; }

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
  python3 - "$HOME_DIR/.claude.json" <<'PY'
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
# mcpServers is empty and every server is a connector - the gate refused it.
# The name is lower-case on purpose: the tool prefix keeps the case of whatever
# is recorded here, so "claude.ai forgetful" is mcp__claude_ai_forgetful__.
with_memory_connector() {
  mkdir -p "$HOME_DIR"
  python3 - "$HOME_DIR/.claude.json" <<'PY'
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
( cd "$REPO" && python3 -m py_compile install-lib.py && rm -rf __pycache__ ) >/dev/null 2>&1
chk $? "python3 -m py_compile install-lib.py"
if command -v shellcheck >/dev/null 2>&1; then
  ( cd "$REPO" && shellcheck install.sh ) ; chk $? "shellcheck install.sh"
  ( cd "$REPO" && shellcheck templates/hooks/*.sh ) ; chk $? "shellcheck the hooks"
  ( cd "$REPO" && shellcheck tests/test-installer.sh ) ; chk $? "shellcheck this suite"
  ( cd "$REPO" && shellcheck tests/test-wiring.sh ) ; chk $? "shellcheck the wiring scrub"
  ( cd "$REPO" && shellcheck tests/test-docs.sh ) ; chk $? "shellcheck the docs scrub"
else
  printf '    SKIP  shellcheck — NOT INSTALLED on this machine, so NOT run\n'
fi
fi

# ------------------------------------------------- 17 the documented Windows command
# Windows PowerShell ships set to `Restricted`, so a bare `.\install.ps1` dies with
# "running scripts is disabled on this system" before the script's first line runs.
# The README told people to type exactly that.
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

DOCFAIL=$(cd "$REPO" && python3 - <<'PY'
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

# ---------------------------------------------------------------- 12 hooks
if want 12; then
banner "12 · templates/hooks/test-hooks.sh"
( cd "$REPO" && bash templates/hooks/test-hooks.sh ) > "$LOGS/hooks.out" 2>&1
chk $? "test-hooks.sh passes (see logs/hooks.out)"
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
awk '/This installer looked in:/{seen=1} seen' "$LOGS/t2.out" > "$LOGS/t2.tail"
if grep -qE $'\033\\[[23]J' "$LOGS/t2.tail"; then fail "no clear escape after the steps"
else pass "no clear escape after the steps"; fi
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
python3 - "$CH/settings.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert d.get("hooks"), "no hooks block"
PY
chk $? "settings.json has a hooks block"
inlog t6 "github.com/you/weekend-project    yes    yes" "closing summary repeats the allowlist line"
# #122's own reproduction: this is the run whose log said "NO tracker tools in 6
# agent(s)" on a correct install. local-markdown reads files off the disk, so the
# deleted tracker token was never a lost grant.
inlog t6 "every installed agent carries the tools its template declared"          "check 1b is GREEN on a clean local-markdown install"
fi

if want 7; then
banner "7 · recommended includes the two new units"
python3 - "$CH/.playbook-install.json" <<'PY'
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
python3 - "$CH/settings.json" <<'PY'
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
BYHAND=$(python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/commands/end-of-day.md")
# adopt_screen inserts: confirm(y) + pause, between the hooks pause and "Write these?"
keys t8 '' '' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' '' 'y' "$SANDBOX/ws" ''
run install t8
inlog t8 "Files already here that this script did not install" "offers adoption"
inlog t8 "command:end-of-day" "names the foreign unit"
python3 - "$CH/.playbook-install.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
rec=m["units"].get("command:end-of-day")
assert rec, "not recorded in manifest"
assert rec.get("adopted") is True, 'no "adopted": true -- %r' % rec
PY
chk $? 'manifest records "adopted": true'
NOW=$(python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/commands/end-of-day.md")
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
python3 - "$CH/.playbook-install.json" <<'PY'
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
# this repo and was wrong both times.
agents_with_memory() {
  ( cd "$REPO" && grep -lE '^tools:.*<memory-(read|write)-tools>' templates/agents/*.md ) \
    | sed 's#.*/##'
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
# installer can place, not just the handful in the default selection. #105's "done
# when" asks for the tools present in all 13 that declare them; two of those 13,
# layer-specialist and slice-layer-specialist, are in NEVER_INSTALL because they are
# generated per repo, so 11 is the whole of what any install can produce.
fresh_env m3; with_servers
keys m3 '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run install m3
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "exits 0"
M3_MISSING=""; M3_N=0
while IFS= read -r a; do
  [ -n "$a" ] || continue
  [ -f "$CH/agents/$a" ] || continue
  M3_N=$((M3_N + 1))
  grep -qF 'mcp__forgetful__execute_forgetful_tool' "$CH/agents/$a" \
    || M3_MISSING="$M3_MISSING $a"
done < <(agents_with_memory)
yn "$([ "$M3_N" -ge 11 ] && echo 0 || echo 1)" "$M3_N memory-declaring agents installed (every one that is installable)"
yn "$([ -z "$M3_MISSING" ] && echo 0 || echo 1)" "every one of them carries the tools (missing:${M3_MISSING:- none})"
notinlog m3 "take the blank out instead" "the old delete-by-default prompt is gone"
# Only the tools: line. A `<memory-read-tools>` in a BODY is prose that is meant to
# survive — apply_placeholders rewrites name:/model:/tools: and nothing else.
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

# ══════════════════════════════════════════════════════════════════════════
# U1-U6 · issue #106 — what an `update` may and may not carry forward
# ══════════════════════════════════════════════════════════════════════════
# `update` is non-interactive: it replays the answers recorded at install time.
# These six ask what that replay is allowed to do. U1/U2 lock in behaviour that
# already worked; U3-U6 are the new behaviour this branch adds.
#
# A case that has to MUTATE a template does it in a throwaway clone_repo, never in
# $REPO: the mutation IS the case, and the real tree must not move underneath the
# rest of the suite.
#
# What may NOT be asserted here. Check 3 ("Fill in <repo>") is ALREADY RED on a clean
# sandbox install, so a case keying on the generic tick, on the ✗ line, or on "verify
# is clean" is born green and proves nothing. Every string below is either absent from
# the tree before this branch, or specific to that case's own planted mutation.
# Check 1b used to be listed here too — it went red on every sandbox install because a
# deleted <tracker-read-tools> counted as a lost grant whatever the route. That was the
# bug, not the baseline; T1-T3 below are what hold it green now.

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
python3 - "$CH/.playbook-install.json" <<'PY'
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
WANT_CONTRACT="$(python3 "$REPO/install-lib.py" contract-version)"
chk $? "read the current contract from install-lib.py"
keys u7 "${FULL[@]}"; run install u7
stamp_is() {
  python3 - "$CH/.playbook-install.json" "$WANT_CONTRACT" <<'PYSTAMP'
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
# #122, on the same run.
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
  python3 "$REPO/install-lib.py" audit-grants \
    "$T2SPEC" "$REPO/templates/agents" "$CH/agents" "$1" "$2" \
  | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["agents"]))'
}
# T1's OWN recorded answers, read back out of its manifest, so this is the real spec
# rather than a hand-written stand-in that could drift from what install.sh writes.
python3 - "$CH/.playbook-install.json" "$T2SPEC" <<'PYT2'
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
python3 - "$CH/agents/ticket-analyzer.md" <<'PYT2B'
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
python3 - "$T3TPL" <<'PYT3A'
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
python3 - "$CH/.playbook-install.json" <<'PYT3'
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
python3 - "$T4TPL" <<'PYT4'
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
python3 - "$CH/.playbook-install.json" <<'PYT4M'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
rec = ((m.get("config") or {}).get("tracker") or {}).get("adapter") or ""
print("recorded adapter: %r" % rec)
sys.exit(1 if rec else 0)
PYT4M
chk $? "gitlab-shape records no config.tracker.adapter (the trap the bug fell into)"
# Rewind the recording, exactly as T3 does — a pre-#123 install wrote no answer.
python3 - "$CH/.playbook-install.json" <<'PYT4'
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
T5TPL="$SANDBOX/t5/repo/templates/agents/encoder.md"
T5AGENT="$CH/agents/encoder.md"
# The `e` preset, as M3 uses it: @encoder is not in the recommended selection, and
# it is one of the three agents this actually happened to.
keys t5 '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run_in "$SANDBOX/t5/repo" install t5
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
yn "$([ -f "$T5AGENT" ] && echo 0 || echo 1)" "@encoder is installed"
# The healthy file, kept byte for byte. The repair must restore the lost fill and
# change NOTHING ELSE, so the repaired file has to come back identical to this.
cp "$T5AGENT" "$SANDBOX/t5/encoder.healthy"
# The damage: the memory tool names deleted from the installed tools: line, which
# is exactly what the pre-#105 run left behind. Only that line, and only within it,
# so the file's line endings and everything else survive untouched.
python3 - "$T5AGENT" <<'PYT5D'
import io, re, sys
p = sys.argv[1]
t = io.open(p, encoding="utf-8", newline="").read()
m = re.search(r"(?m)^tools:.*$", t)
assert m, "no tools: line in the installed @encoder"
old = m.group(0).rstrip("\r")
names = [x.strip() for x in old.split(":", 1)[1].split(",") if x.strip()]
mem = [x for x in names if x.startswith("mcp__forgetful__")]
assert mem, "the installed tools: line carries no memory tools to strip"
new = "tools: " + ", ".join(x for x in names if x not in mem)
io.open(p, "w", encoding="utf-8", newline="").write(t.replace(old, new, 1))
PYT5D
chk $? "stripped the memory tools out of the installed @encoder"
# Control. A blanking step that silently no-ops is a fourth wrong-green.
yn "$(grep -qE '^tools:.*mcp__forgetful__' "$T5AGENT" && echo 1 || echo 0)" \
   "the damaged tools: line really has lost the memory tools"
# Record the damaged file's OWN hash, so it plans `current` and not `skip-edited`.
# source_hash is deliberately left alone: the template did not move.
python3 - "$SANDBOX/t5/repo" "$CH/.playbook-install.json" "$T5AGENT" <<'PYT5H'
import json, subprocess, sys
repo, manifest_path, dest = sys.argv[1], sys.argv[2], sys.argv[3]
h = json.loads(subprocess.check_output(
    [sys.executable, repo + "/install-lib.py", "hash", dest]))["hash"]
m = json.load(open(manifest_path, encoding="utf-8"))
units = m["units"]
uids = [u for u, r in units.items()
        if (r.get("dest") or "").replace("\\", "/").endswith("/agents/encoder.md")]
assert len(uids) == 1, "expected exactly one recorded unit for @encoder: %r" % uids
assert units[uids[0]]["hash"] != h, "the damage did not change the file's hash"
units[uids[0]]["hash"] = h
json.dump(m, open(manifest_path, "w", encoding="utf-8"), indent=2)
sys.stdout.write("    (damaged unit: %s)\n" % uids[0])
PYT5H
chk $? "recorded the damaged file's own hash (so it plans \`current\`, not \`skip-edited\`)"
# A2 — the guard on wrong-green 1. If the template had moved, source_hash would
# differ, the unit would plan `upgrade`, and the ordinary path would repair it.
yn "$(cmp -s "$REPO/templates/agents/encoder.md" "$T5TPL" && echo 0 || echo 1)" \
   "the clone's @encoder template never moved (so the unit really is \`current\`)"
nokeys t5u; run_in "$SANDBOX/t5/repo" update t5u
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the update completes (rc=$RC)"
T5TOOLS="$(sed -n '/^tools:/p' "$T5AGENT" 2>/dev/null)"
printf '    (%s)\n' "$T5TOOLS"
# A1 — THE assertion. Check 1b is not proof: audit_grants matches the first name
# only, so this greps for the tool name itself.
case "$T5TOOLS" in
  *mcp__forgetful__execute_forgetful_tool*)
    pass "A1 the update puts the lost memory grant back into @encoder" ;;
  *)
    fail "A1 the update puts the lost memory grant back into @encoder ($T5TOOLS)" ;;
esac
# A3 — only ADDS. The repair re-copies from the template and replays the whole
# answer set, so this is where a replayed delete would show up.
case "$T5TOOLS" in
  *mcp__serena__find_symbol*) pass "A3 the repaired @encoder kept its non-memory tools" ;;
  *) fail "A3 the repaired @encoder kept its non-memory tools ($T5TOOLS)" ;;
esac
case "$(sed -n '/^tools:/p' "$CH/agents/context-gatherer.md" 2>/dev/null)" in
  *mcp__forgetful__execute_forgetful_tool*)
    pass "A3 an undamaged memory agent still carries its memory tools" ;;
  *)
    fail "A3 an undamaged memory agent still carries its memory tools" ;;
esac
# The re-copy is a whole-file rewrite, so "it only added the grant back" has to be
# proved on the whole file, not on the tools: line.
yn "$(cmp -s "$SANDBOX/t5/encoder.healthy" "$T5AGENT" && echo 0 || echo 1)" \
   "the repair restored the lost fill and changed nothing else in the file"
# A4
notinlog t5u "some agents are installed without a capability" "check 1b is green on the update"
fi

# ------------------------------------------- T6 the confirm screen tells the truth
# The repair in #127 is computed by install_stage_body. But confirm_stage does NOT
# reuse that plan — it runs the SAME subcommand a second time, from its own inputs,
# to show the user what is about to happen. The two calls drifted: only one of them
# was handed the recorded answers, so a damaged agent was listed on the consent
# screen under "UNCHANGED — already exactly this version" and was then rewritten by
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
T6TPL="$SANDBOX/t6p/repo/templates/agents/encoder.md"
T6AGENT="$CH/agents/encoder.md"
keys t6p '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run_in "$SANDBOX/t6p/repo" install t6p
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the first install exits 0 (rc=$RC)"
yn "$([ -f "$T6AGENT" ] && echo 0 || echo 1)" "@encoder is installed"
# The damage, exactly as T5 inflicts it: the memory tool names deleted from the
# installed tools: line and nothing else, which is what the pre-#105 run left.
python3 - "$T6AGENT" <<'PYT6D'
import io, re, sys
p = sys.argv[1]
t = io.open(p, encoding="utf-8", newline="").read()
m = re.search(r"(?m)^tools:.*$", t)
assert m, "no tools: line in the installed @encoder"
old = m.group(0).rstrip("\r")
names = [x.strip() for x in old.split(":", 1)[1].split(",") if x.strip()]
mem = [x for x in names if x.startswith("mcp__forgetful__")]
assert mem, "the installed tools: line carries no memory tools to strip"
new = "tools: " + ", ".join(x for x in names if x not in mem)
io.open(p, "w", encoding="utf-8", newline="").write(t.replace(old, new, 1))
PYT6D
chk $? "stripped the memory tools out of the installed @encoder"
yn "$(grep -qE '^tools:.*mcp__forgetful__' "$T6AGENT" && echo 1 || echo 0)" \
   "the damaged tools: line really has lost the memory tools"
python3 - "$SANDBOX/t6p/repo" "$CH/.playbook-install.json" "$T6AGENT" <<'PYT6H'
import json, subprocess, sys
repo, manifest_path, dest = sys.argv[1], sys.argv[2], sys.argv[3]
h = json.loads(subprocess.check_output(
    [sys.executable, repo + "/install-lib.py", "hash", dest]))["hash"]
m = json.load(open(manifest_path, encoding="utf-8"))
units = m["units"]
uids = [u for u, r in units.items()
        if (r.get("dest") or "").replace("\\", "/").endswith("/agents/encoder.md")]
assert len(uids) == 1, "expected exactly one recorded unit for @encoder: %r" % uids
assert units[uids[0]]["hash"] != h, "the damage did not change the file's hash"
units[uids[0]]["hash"] = h
json.dump(m, open(manifest_path, "w", encoding="utf-8"), indent=2)
PYT6H
chk $? "recorded the damaged file's own hash (so it plans \`current\`, not \`skip-edited\`)"
yn "$(cmp -s "$REPO/templates/agents/encoder.md" "$T6TPL" && echo 0 || echo 1)" \
   "the clone's @encoder template never moved (so the unit really is \`current\`)"
# The remedy #127 tells these users to run: a plain interactive re-install, and the
# consent screen is answered `y` so the preview can be held against what happened.
keys t6p2 '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run_in "$SANDBOX/t6p/repo" install t6p2
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the re-run exits 0 (rc=$RC)"
# THE assertion — which heading of the consent screen owns the damaged agent? The
# headings are matched on ASCII fragments, never on the em-dash, and the tally is
# reset at every "What this will write" so only the final screen is read.
python3 - "$LOGS/t6p2.out" <<'PYT6P'
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
    if cur is not None and s.replace("\\", "/").endswith("/agents/encoder.md"):
        hits.append(cur)
sys.stdout.write("    (previewed as: %s)\n" % (", ".join(hits) or "<not listed at all>"))
sys.exit(0 if hits == ["upgrade"] else 1)
PYT6P
chk $? "the confirm preview classifies the damaged @encoder as \`upgrade\`"
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
T7TPL="$SANDBOX/t7/repo/templates/agents/encoder.md"
T7AGENT="$CH/agents/encoder.md"
keys t7 '' '' 'e' '5' '4' '' 'i' '' '' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
run_in "$SANDBOX/t7/repo" install t7
yn "$([ "$RC" = "0" ] && echo 0 || echo 1)" "the install exits 0 (rc=$RC)"
yn "$([ -f "$T7AGENT" ] && echo 0 || echo 1)" "@encoder is installed"
# The damage, exactly as T5 and T6 inflict it: the memory tool names deleted from
# the installed tools: line and nothing else, which is what the pre-#105 run left.
python3 - "$T7AGENT" <<'PYT7D'
import io, re, sys
p = sys.argv[1]
t = io.open(p, encoding="utf-8", newline="").read()
m = re.search(r"(?m)^tools:.*$", t)
assert m, "no tools: line in the installed @encoder"
old = m.group(0).rstrip("\r")
names = [x.strip() for x in old.split(":", 1)[1].split(",") if x.strip()]
mem = [x for x in names if x.startswith("mcp__forgetful__")]
assert mem, "the installed tools: line carries no memory tools to strip"
new = "tools: " + ", ".join(x for x in names if x not in mem)
io.open(p, "w", encoding="utf-8", newline="").write(t.replace(old, new, 1))
PYT7D
chk $? "stripped the memory tools out of the installed @encoder"
yn "$(grep -qE '^tools:.*mcp__forgetful__' "$T7AGENT" && echo 1 || echo 0)" \
   "the damaged tools: line really has lost the memory tools"
# Record the damaged file's OWN hash, so it lists `current` and not `edited`, and
# hand the unit id back out: the row assertions must key on the state AND the uid
# on the same line, because list_mode prints every state word in its legend too.
python3 - "$SANDBOX/t7/repo" "$CH/.playbook-install.json" "$T7AGENT" "$SANDBOX/t7/uid.txt" <<'PYT7H'
import json, io, subprocess, sys
repo, manifest_path, dest, uid_out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
h = json.loads(subprocess.check_output(
    [sys.executable, repo + "/install-lib.py", "hash", dest]))["hash"]
m = json.load(open(manifest_path, encoding="utf-8"))
units = m["units"]
uids = [u for u, r in units.items()
        if (r.get("dest") or "").replace("\\", "/").endswith("/agents/encoder.md")]
assert len(uids) == 1, "expected exactly one recorded unit for @encoder: %r" % uids
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
yn "$(cmp -s "$REPO/templates/agents/encoder.md" "$T7TPL" && echo 0 || echo 1)" \
   "the clone's @encoder template never moved (so the unit really is version-current)"
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
python3 - "$LOGS/t7l.out" "$T7UID" <<'PYT7C'
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

printf '\n================================\n'
printf '  passed %s   failed %s\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failures:\n'
  for f in "${FAILED_NAMES[@]}"; do printf '    - %s\n' "$f"; done
  exit 1
fi
exit 0
