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
#   strong · fast · placeholder pause
#   hooks-warning pause · "Write these?" y
#   <workspace> · tracker pause
FULL=( '' '' '5' '4' '' 'i' '' '' '' '' '' '' 'y' "$SANDBOX/ws" '' )

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
fresh_env t3; with_serena; keys t3 "${FULL[@]}"; run install t3
notinlog t3 "Serena is not set up" "gate does not fire"
inlog t3 "which tool names" "reaches the Serena route stage"
inlog t3 "mcpServers.serena" "shows the evidence it found"
inlog t3 "Install complete" "runs to completion"
fi

# ---------------------------------------------------------------- 4 tracker gate
if want 4; then
banner "4 · tracker is a required choice"
fresh_env t4; with_serena
keys t4 '' '' 'i' '' 'q'
run install t4
inlog t4 "No tracker is selected" "refuses i while tracker is none"
inlog t4 "ticket-analyzer" "states the cost (start-ticket's first step)"
notinlog t4 "which tool names" "did NOT proceed past selection"
yn "$([ "$(n_files)" = "0" ] && echo 0 || echo 1)" "nothing written"

banner "4b · the explicit 'later' escape"
fresh_env t4b; with_serena
keys t4b '' '' 'i' 'later' '' '' '' '' '' '' 'y' ''
run install t4b
inlog t4b "which tool names" "'later' lets the install proceed"
inlog t4b "no tracker selected" "tracker stage still warns"
inlog t4b "Install complete" "completes"
fi

# ---------------------------------------------------------------- 5 confirm NO
if want 5; then
banner "5 · confirm stage — answering no"
fresh_env t5; with_serena
keys t5 '' '' '5' '4' '' 'i' '' '' '' '' '' '' 'n'
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
fresh_env t6; with_serena
keys t6 '' '' 'r' '5' '4' '' 'i' '' '' '' '' '' '' 'y' "$SANDBOX/ws" ''
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
fresh_env t11; with_serena
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
fresh_env t8; with_serena
mkdir -p "$CH/commands"
cp "$REPO/templates/commands/end-of-day.md" "$CH/commands/end-of-day.md"
BYHAND=$(python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$CH/commands/end-of-day.md")
# adopt_screen inserts: confirm(y) + pause, between the hooks pause and "Write these?"
keys t8 '' '' '5' '4' '' 'i' '' '' '' '' '' '' 'y' '' 'y' "$SANDBOX/ws" ''
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
fresh_env t8b; with_serena
mkdir -p "$CH/commands"
cp "$REPO/templates/commands/end-of-day.md" "$CH/commands/end-of-day.md"
keys t8b '' '' '5' '4' '' 'i' '' '' '' '' '' '' 'n' '' 'y' "$SANDBOX/ws" ''
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
fresh_env t14; with_serena
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
fresh_env t15; with_serena
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
fresh_env t16; with_serena
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

printf '\n================================\n'
printf '  passed %s   failed %s\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failures:\n'
  for f in "${FAILED_NAMES[@]}"; do printf '    - %s\n' "$f"; done
  exit 1
fi
exit 0
