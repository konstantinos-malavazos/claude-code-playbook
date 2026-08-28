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
  rm -rf "$SANDBOX/$1"
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
  ( cd "$REPO" && HOME="$HOME_DIR" CLAUDE_HOME="$CH" bash ./install.sh $mode ) \
    < "$LOGS/$log.in" > "$LOGS/$log.out" 2> "$LOGS/$log.err"
  RC=$?
  return 0
}

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
else
  printf '    SKIP  shellcheck — NOT INSTALLED on this machine, so NOT run\n'
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
yn $([ "$RC" = "0" ] && echo 0 || echo 1) "exit 0"
inlog t1 "nothing installed by this script" "reports nothing installed"
yn $([ "$(n_files)" = "0" ] && echo 0 || echo 1) "wrote nothing"
fi

# ---------------------------------------------------------------- 2 serena gate fires
if want 2; then
banner "2 · Serena gate FIRES (no .claude.json anywhere)"
fresh_env t2; keys t2 "${FULL[@]}"; run install t2
yn $([ "$RC" != "0" ] && echo 0 || echo 1) "exits non-zero (rc=$RC)"
inlog t2 "Serena is not set up on this machine" "prints the refusal"
inlog t2 "serena plugin from the official marketplace" "prints route A"
inlog t2 "mcpServers.serena" "prints route B"
inlog t2 "docs/shared/03-setup.md" "points at the doc rather than copying it"
yn $([ "$(n_files)" = "0" ] && echo 0 || echo 1) "CLAUDE_HOME still empty ($(n_files) files)"
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
inlog t3 "which tool prefix" "reaches the Serena route stage"
inlog t3 "mcpServers.serena" "shows the evidence it found"
inlog t3 "Install complete" "runs to completion"
fi

# ---------------------------------------------------------------- 4 tracker gate
if want 4; then
banner "4 · tracker is a required choice"
fresh_env t4; with_serena
keys t4 '' '' 'i' '' 'q'
run install t4
inlog t4 "No tracker adapter is selected" "refuses i while tracker is none"
inlog t4 "ticket-analyzer" "states the cost (start-ticket's first step)"
notinlog t4 "which tool prefix" "did NOT proceed past selection"
yn $([ "$(n_files)" = "0" ] && echo 0 || echo 1) "nothing written"

banner "4b · the explicit 'later' escape"
fresh_env t4b; with_serena
keys t4b '' '' 'i' 'later' '' '' '' '' '' '' 'y' ''
run install t4b
inlog t4b "which tool prefix" "'later' lets the install proceed"
inlog t4b "no tracker adapter selected" "tracker stage still warns"
inlog t4b "Install complete" "completes"
fi

# ---------------------------------------------------------------- 5 confirm NO
if want 5; then
banner "5 · confirm stage — answering no"
fresh_env t5; with_serena
keys t5 '' '' '5' '4' '' 'i' '' '' '' '' '' '' 'n'
run install t5
yn $([ "$RC" = "0" ] && echo 0 || echo 1) "exits 0"
inlog t5 "Nothing was written" "says nothing was written"
yn $([ "$(n_files)" = "0" ] && echo 0 || echo 1) "CLAUDE_HOME has zero files ($(n_files))"
yn $([ ! -f "$CH/.playbook-install.json" ] && echo 0 || echo 1) "no manifest"
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
yn $([ "$RC" = "0" ] && echo 0 || echo 1) "exits 0"
for f in commands/start-ticket.md agents/ticket-analyzer.md hooks/block-dangerous-git.sh \
         repo-allowlist tracker.md CLAUDE.md settings.json .playbook-install.json; do
  yn $([ -e "$CH/$f" ] && echo 0 || echo 1) "wrote $f"
done
yn $([ -d "$CH/skills/adapt-to-stack" ] && echo 0 || echo 1) "wrote skills/adapt-to-stack"
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
BEFORE=$(ls -1 "$CH/.playbook-backups"/settings.json.* 2>/dev/null | wc -l | tr -d ' ')
nokeys bk1; run update bk1
AFTER=$(ls -1 "$CH/.playbook-backups"/settings.json.* 2>/dev/null | wc -l | tr -d ' ')
printf '    (before=%s after=%s)\n' "$BEFORE" "$AFTER"
yn $([ "$BEFORE" -gt 10 ] && echo 0 || echo 1) "primed with more than 10 backups ($BEFORE)"
yn $([ "$AFTER" -le 10 ] && echo 0 || echo 1) "at most 10 backups remain ($AFTER)"
yn $([ ! -e "$CH/.playbook-backups/settings.json.20000101-000000" ] && echo 0 || echo 1) "oldest pruned"
yn $([ -e "$CH/.playbook-backups/settings.json.20000114-000000" ] && echo 0 || echo 1) "newest kept"
fi

# ---------------------------------------------------------------- 10 update
if want 10; then
banner "10 · update is non-interactive"
nokeys up1; run update up1
yn $([ "$RC" = "0" ] && echo 0 || echo 1) "exit 0 with stdin closed"
inlog up1 "Update complete" "completes"
if grep -qE '\[y/N\]|Write these\?|Ready to start' "$LOGS/up1.out"; then
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
yn $([ -f "$CH/commands/start-ticket.md" ] && echo 0 || echo 1) "installed first"
keys rm1 '' 'y'; run remove rm1
yn $([ "$RC" = "0" ] && echo 0 || echo 1) "remove exits 0"
yn $([ ! -e "$CH/commands/start-ticket.md" ] && echo 0 || echo 1) "files gone"
yn $([ ! -e "$CH/.playbook-install.json" ] && echo 0 || echo 1) "manifest gone"
python3 - "$CH/settings.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert d.get("model")=="my-own-model", "user key lost: %r" % d
assert d.get("verbose") is True, "user key lost: %r" % d
assert "hooks" not in d, "hook entries left behind: %r" % d.get("hooks")
PY
chk $? "hook entries removed, user's own settings keys untouched"
yn $([ -d "$CH/.playbook-backups" ] && echo 0 || echo 1) "backups survive remove"
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
yn $([ "$BYHAND" = "$NOW" ] && echo 0 || echo 1) "the user's file was not rewritten"
keys rm8 '' 'y'; run remove rm8
inlog rm8 "adopted" "remove reports keep-adopted"
yn $([ -f "$CH/commands/end-of-day.md" ] && echo 0 || echo 1) "ADOPTED FILE SURVIVES remove"
yn $([ ! -f "$CH/commands/start-ticket.md" ] && echo 0 || echo 1) "non-adopted files still removed"

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

printf '\n================================\n'
printf '  passed %s   failed %s\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failures:\n'
  for f in "${FAILED_NAMES[@]}"; do printf '    - %s\n' "$f"; done
  exit 1
fi
exit 0
