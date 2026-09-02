#!/usr/bin/env bash
#
# install.sh — select, install and remove the claude-code-playbook templates.
#
# Run it from a clone:   ./install.sh            interactive install / change what you have
#                        ./install.sh update     non-interactive: refresh what you have
#                        ./install.sh remove     take back what it installed
#                        ./install.sh list       show state, change nothing
#
# The correctness half of this installer lives in install-lib.py, beside this file:
# discovery, hashing, the additive JSON merge, and the wiring check. This file owns
# the UX and the orchestration.
#
# ONE INVARIANT RUNS THROUGH ALL OF IT:
#   the installer never overwrites or deletes something you changed.
# That is why an upgrade skips edited files, why a merge leaves a differing value
# alone and reports it, and why remove keeps anything whose hash has moved.
#
# Prior art: the wizard library below is included verbatim from Matt Pocock's
# `wizard` skill, licensed under the MIT License by its original author, by way of
# templates/skills/wizard/template.sh.
#
# Everything from here to the "STAGES" marker is that library: do not hand-edit it.
# The installer is authored below the marker.
#
# shellcheck disable=SC2329  # pause() and confirm() in that library are never called:
# both are superseded by the definitions beside _read() below, which end the run at EOF
# instead of treating a closed stdin as an answer. The library stays byte-identical, so
# the directive lives out here rather than inside it. File-scoped for that reason.
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# Wizard library — delightful, consistent UX. Identical across every wizard.
# ──────────────────────────────────────────────────────────────────────────

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
  BLUE=$(tput setaf 4); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1)
else
  BOLD=""; DIM=""; RESET=""; BLUE=""; GREEN=""; YELLOW=""; RED=""
fi

# Author sets this at the top of the stages section.
TOTAL_STAGES=0

_STAGE_INDEX=0
ENV_FILE="${ENV_FILE:-.env}"
WRITTEN_ENV=()    # KEYs written to ENV_FILE this run
WRITTEN_SECRET=() # secret NAMEs set this run
SKIPPED=()        # things we couldn't do (e.g. gh missing)

# _clear — wipe the terminal so only the current step is on screen. No-op when
# output isn't a terminal, so piped logs stay readable.
_clear() {
  [[ -t 1 ]] || return 0
  if command -v tput >/dev/null 2>&1; then tput clear; else printf '\033[2J\033[3J\033[H'; fi
}

# banner "Title" — opening frame: what this wizard does.
banner() {
  _clear
  printf '\n%s%s  %s%s\n' "$BOLD" "$BLUE" "$1" "$RESET"
  printf '%s  %s stages%s\n\n' "$DIM" "$TOTAL_STAGES" "$RESET"
  printf '%s  You drive the browser; this wizard tells you exactly what to do and\n' "$DIM"
  printf '  captures the values you copy back. Stop any time with Ctrl-C and re-run\n'
  printf '  later — it remembers values already saved.%s\n' "$RESET"
  pause "Ready to start?"
}

# stage "Name" — clear the screen, then announce a stage and show progress.
# Clearing keeps only the current step on screen.
stage() {
  _clear
  _STAGE_INDEX=$((_STAGE_INDEX + 1))
  printf '\n%s%s▸ Stage %s/%s · %s%s\n' \
    "$BOLD" "$BLUE" "$_STAGE_INDEX" "$TOTAL_STAGES" "$1" "$RESET"
}

# say "..." — a plain instruction line.
say()  { printf '  %s\n' "$1"; }
# step "..." — a numbered-feeling action the human takes in the browser.
step() { printf '  %s•%s %s\n' "$BLUE" "$RESET" "$1"; }
note() { printf '  %s%s%s\n' "$DIM" "$1" "$RESET"; }
warn() { printf '  %s⚠ %s%s\n' "$YELLOW" "$1" "$RESET"; }

# open_url URL — open in the human's browser, cross-platform incl. WSL.
open_url() {
  local url="$1"
  printf '  %s↗ opening%s %s\n' "$GREEN" "$RESET" "$url"
  { if   command -v wslview     >/dev/null 2>&1; then wslview "$url"
    elif command -v explorer.exe >/dev/null 2>&1; then explorer.exe "$url"
    elif command -v xdg-open    >/dev/null 2>&1; then xdg-open "$url"
    elif command -v open        >/dev/null 2>&1; then open "$url"
    else warn "couldn't open a browser — visit it manually: $url"; fi
  } >/dev/null 2>&1 || warn "couldn't open a browser — visit it manually: $url"
}

# pause "msg" — wait for the human to confirm they've done the manual part.
#
# DEAD ON PURPOSE. This is the verbatim library copy; the definition that runs is
# the one near require_tty below, which stops on EOF instead of answering for you.
# The library stays unedited (see banner_pb), so this body is shadowed, not fixed.
# shellcheck disable=SC2317  # shadowed by the re-definition below — see there
pause() {
  printf '  %s%s%s ' "$DIM" "${1:-Press Enter to continue}" "$RESET"
  read -r _ || true
}

# confirm "question" — y/N gate; returns success on yes.
#
# DEAD ON PURPOSE, for the same reason as pause above.
# shellcheck disable=SC2317  # shadowed by the re-definition below — see there
confirm() {
  local reply=""
  printf '  %s? %s [y/N] ' "$YELLOW" "$1"
  read -r reply || true
  [[ "$reply" =~ ^[Yy] ]]
}

# _existing KEY — current value of KEY in ENV_FILE, if any.
_existing() {
  [[ -f "$ENV_FILE" ]] || return 1
  local line; line=$(grep -E "^${1}=" "$ENV_FILE" | tail -n1) || return 1
  printf '%s' "${line#*=}"
}

# ask KEY "Prompt" — read a value into $KEY. Offers the existing .env value as
# a default on re-runs (Enter keeps it). Visible input (non-secret).
ask() {
  local key="$1" prompt="$2" current input
  current=$(_existing "$key" || true)
  if [[ -n "$current" ]]; then
    printf '  %s%s%s %s[Enter keeps current]%s ' "$BOLD" "$prompt" "$RESET" "$DIM" "$RESET"
  else
    printf '  %s%s%s ' "$BOLD" "$prompt" "$RESET"
  fi
  read -r input || true
  [[ -z "$input" && -n "$current" ]] && input="$current"
  printf -v "$key" '%s' "$input"
}

# ask_secret KEY "Prompt" — like ask, but input is hidden.
ask_secret() {
  local key="$1" prompt="$2" current input
  current=$(_existing "$key" || true)
  if [[ -n "$current" ]]; then
    printf '  %s%s%s %s[Enter keeps current]%s ' "$BOLD" "$prompt" "$RESET" "$DIM" "$RESET"
  else
    printf '  %s%s%s ' "$BOLD" "$prompt" "$RESET"
  fi
  read -rs input || true
  printf '\n'
  [[ -z "$input" && -n "$current" ]] && input="$current"
  printf -v "$key" '%s' "$input"
}

# write_env KEY VALUE — upsert KEY=VALUE into ENV_FILE (creates it; replaces
# any existing line). Idempotent.
write_env() {
  local key="$1" value="$2" tmp
  touch "$ENV_FILE"
  tmp=$(mktemp)
  grep -vE "^${key}=" "$ENV_FILE" > "$tmp" || true
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$ENV_FILE"
  WRITTEN_ENV+=("$key")
  printf '  %s✓ wrote%s %s → %s\n' "$GREEN" "$RESET" "$key" "$ENV_FILE"
}

# set_secret NAME VALUE — set a GitHub Actions repo secret via gh. Falls back
# to a warning (and records it) if gh is unavailable or unauthenticated.
set_secret() {
  local name="$1" value="$2"
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if printf '%s' "$value" | gh secret set "$name" >/dev/null 2>&1; then
      WRITTEN_SECRET+=("$name")
      printf '  %s✓ set%s GitHub secret %s\n' "$GREEN" "$RESET" "$name"
      return
    fi
  fi
  SKIPPED+=("GitHub secret $name (set it manually: gh secret set $name)")
  warn "skipped GitHub secret $name — gh not ready; set it later"
}

# set_var NAME VALUE — set a GitHub Actions repo variable (non-secret).
set_var() {
  local name="$1" value="$2"
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if gh variable set "$name" --body "$value" >/dev/null 2>&1; then
      printf '  %s✓ set%s GitHub variable %s\n' "$GREEN" "$RESET" "$name"
      return
    fi
  fi
  SKIPPED+=("GitHub variable $name")
  warn "skipped GitHub variable $name — gh not ready; set it later"
}

# finish — clear, then a closing summary of everything configured.
finish() {
  _clear
  printf '\n%s%s  ✓ Setup complete%s\n' "$BOLD" "$GREEN" "$RESET"
  (( ${#WRITTEN_ENV[@]} ))    && note "wrote ${#WRITTEN_ENV[@]} value(s) to $ENV_FILE: ${WRITTEN_ENV[*]}"
  (( ${#WRITTEN_SECRET[@]} )) && note "set ${#WRITTEN_SECRET[@]} GitHub secret(s): ${WRITTEN_SECRET[*]}"
  if (( ${#SKIPPED[@]} )); then
    printf '\n'; warn "still to do by hand:"
    for s in "${SKIPPED[@]}"; do note "  - $s"; done
  fi
  printf '\n'
}

# ──────────────────────────────────────────────────────────────────────────
# STAGES — the playbook installer.
# The wizard library above is verbatim and not edited. Everything below is the
# installer: preflight, discovery, selection, install/upgrade, remove, verify.
# ──────────────────────────────────────────────────────────────────────────

TOTAL_STAGES=9

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$HERE/templates"
LIB="$HERE/install-lib.py"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
MANIFEST="$CLAUDE_HOME/.playbook-install.json"
BACKUPS="$CLAUDE_HOME/.playbook-backups"
SETTINGS="$CLAUDE_HOME/settings.json"
HOOK_SNIPPET="$TEMPLATES/hooks/settings-hooks.snippet.json"

MODE="${1:-install}"
PY=""

# Git Bash hands arguments to a WINDOWS python, and msys rewrites /c/... into C:/...
# on the way there — for every argument EXCEPT one containing an apostrophe, which it
# leaves alone. A clone or a CLAUDE_HOME under C:\Users\O'Brien therefore arrives as
# /c/Users/O'Brien/..., which python reads as C:\c\Users\O'Brien\... and cannot open:
# the installer dies at discovery, several stages after preflight said everything was
# fine. So do that one rewrite by hand, with the flag that produces the same C:/...
# shape msys produces, and an apostrophe path behaves like every other path already
# does. cygpath exists only under msys, so this is a no-op on Linux and macOS — where
# an apostrophe in a path was never a problem in the first place.
#
# Every python call in this file goes through here. Only /-rooted arguments carrying
# an apostrophe are touched; a -c script or a plain value is passed straight on.
CYGPATH="$(command -v cygpath 2>/dev/null || true)"
py() {
  local a
  local args=()
  for a in "$@"; do
    case "$a" in
      /*\'*) if [ -n "$CYGPATH" ]; then a="$("$CYGPATH" -m "$a")"; fi ;;
    esac
    args+=("$a")
  done
  "$PY" "${args[@]}"
}

# Windows Python picks the ANSI code page for stdout (cp1252 on a UK/US box), and the
# first python block below that prints a "←" or an em dash then dies with a
# UnicodeEncodeError — which, under `set -e`, takes the whole installer down mid-stage.
# The bash printfs are fine either way: they pass bytes straight through. This is the
# one line that keeps the python halves honest, and it is a no-op everywhere else.
export PYTHONIOENCODING=utf-8

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
UNITS="$WORK/units.json"
TSV="$WORK/units.tsv"
SELECTED="$WORK/selected"
: > "$SELECTED"

# Closing-summary accumulators. The library's finish() reports .env values and
# GitHub secrets, neither of which this installer writes, so it has its own.
INSTALLED=()
UPGRADED=()
REMOVED=()
ADOPTED=()
LEFT_ALONE=()
CONFLICTS=()
TODO=()

# Set to yes only when the user has explicitly chosen to go on without a tracker
# adapter, having been shown what that costs.
TRACKER_DEFERRED="no"

pb() { py "$LIB" "$@"; }

# screen "Title" — a sub-screen WITHIN a stage. Clears and titles like stage(),
# but does not advance the counter: stages are milestones, and paging around the
# selection lists is navigation. Without this the header climbs past the total.
screen() {
  _clear
  printf '\n%s%s▸ Stage %s/%s · %s%s\n' \
    "$BOLD" "$BLUE" "$_STAGE_INDEX" "$TOTAL_STAGES" "$1" "$RESET"
}

# banner_pb TITLE [pause] — this installer's own opening screen.
#
# The wizard library's banner() is verbatim and not hand-edited, so the fix for it
# is not to call it. Two things made it wrong here:
#   * it says "You drive the browser", which belongs to the wizard the library was
#     written for. This installer never opens a browser, and it is the first
#     sentence a stranger reads.
#   * it always ends in pause "Ready to start?". `update` documents itself as
#     asking nothing, and `list` changes nothing — neither should stop for a key.
# install and remove still pause: both are about to change the machine.
banner_pb() {
  _clear
  printf '
%s%s  %s%s
' "$BOLD" "$BLUE" "$1" "$RESET"
  printf '%s  %s stages%s

' "$DIM" "$TOTAL_STAGES" "$RESET"
  printf '%s' "$DIM"
  case "$MODE" in
    remove|uninstall)
      printf '  This takes the playbook files back out of:\n'
      printf '    %s\n\n' "$CLAUDE_HOME"
      printf '  You are shown exactly what would go before anything is deleted, and\n'
      printf '  anything you edited yourself is kept.\n'
      ;;
    update|upgrade)
      printf '  This brings what you already have in:\n'
      printf '    %s\n' "$CLAUDE_HOME"
      printf '  up to date with this clone. It asks you nothing.\n'
      printf '  Files you edited yourself are left exactly as they are.\n'
      ;;
    list|status)
      printf '  This shows what is currently installed in:\n'
      printf '    %s\n\n' "$CLAUDE_HOME"
      printf '  It only reads. Nothing is written, changed or deleted.\n'
      ;;
    *)
      printf '  This installs ready-made commands, agents and guardrails for Claude\n'
      printf '  Code into this folder:\n'
      printf '    %s\n\n' "$CLAUDE_HOME"
      printf '  How it goes: you pick what you want, you are shown the exact list of\n'
      printf '  files first, and NOTHING is written until you answer yes.\n'
      printf '  A file you have edited yourself is never overwritten.\n'
      ;;
  esac
  printf '  Ctrl-C stops it at any point, safely.%s\n' "$RESET"
  [[ "${2:-}" == "pause" ]] && pause "Ready to start?"
  return 0
}

heading() { printf '\n  %s%s%s\n' "$BOLD" "$1" "$RESET"; }
ok()      { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
bad()     { printf '  %s✗%s %s\n' "$RED" "$RESET" "$1"; }
die()     { printf '\n  %s✗ %s%s\n\n' "$RED" "$1" "$RESET" >&2; exit 1; }

# ── prompts: a closed stdin is not an answer ──────────────────────────────
# The library's read helpers all end `|| true`, so at EOF the variable comes back
# empty — and an empty answer is a legal one at every menu here (Enter = back, or
# = keep the default). `./install.sh < /dev/null`, a pipe, or CI therefore does
# not stop at the first question: it falls through the Stage 3 menu, which loops,
# re-rendering and re-running resolve-deps until something kills it.
#
# require_tty catches that at the door. _read catches a terminal that closes
# mid-run, which the door check cannot see coming. The library itself is verbatim
# and not hand-edited (see banner_pb), so pause and confirm are re-defined here
# rather than corrected up there — these definitions are the ones that run.

# require_tty — refuse an interactive mode that has no one to talk to.
#
# PLAYBOOK_SCRIPTED_INPUT is the one deliberate exception: tests/test-installer.sh
# drives the real prompts from a file of keystrokes, and means it. It buys past
# this door check only — if that answer list runs short, _read below still stops
# the run rather than letting EOF answer the rest.
require_tty() {
  [[ -t 0 || -n "${PLAYBOOK_SCRIPTED_INPUT:-}" ]] && return 0
  printf '\n'
  note "./install.sh update  refreshes what you already have, asking nothing."
  note "./install.sh list    shows what you have and changes nothing."
  die "this mode ($MODE) needs to ask you questions, but stdin is not a terminal — there is nobody to answer them"
}

# _read VAR — one line into VAR. EOF ends the run instead of answering for you.
# `update` reaches this too: on a manifest that predates recorded config it asks
# one question, and no tty means it stops there rather than picking for you.
_read() {
  read -r "$1" && return 0
  printf '\n'
  die "no answer came back — stopping here rather than picking an answer for you"
}

pause() {
  printf '  %s%s%s ' "$DIM" "${1:-Press Enter to continue}" "$RESET"
  _read _
}

confirm() {
  local reply=""
  printf '  %s? %s [y/N] ' "$YELLOW" "$1"
  _read reply
  [[ "$reply" =~ ^[Yy] ]]
}

# ── selection state ───────────────────────────────────────────────────────
# Held in a file rather than an associative array, so this runs on the bash 3.2
# that still ships as /bin/bash on macOS.
sel_has()    { grep -Fxq "$1" "$SELECTED" 2>/dev/null; }
sel_add()    { sel_has "$1" || printf '%s\n' "$1" >> "$SELECTED"; }
sel_del()    { grep -Fxv "$1" "$SELECTED" > "$SELECTED.tmp" 2>/dev/null || : ; mv "$SELECTED.tmp" "$SELECTED"; }
sel_toggle() { if sel_has "$1"; then sel_del "$1"; else sel_add "$1"; fi; }
sel_count()  { grep -c "^$1:" "$SELECTED" 2>/dev/null || true; }
sel_yn()     { if sel_has "$1"; then printf 'yes'; else printf 'no'; fi; }

# The unit table is read from a cached TSV, not by re-running python per row —
# the selection screen renders it on every keystroke.
ids_of()   { awk -F'\t' -v k="$1" '$1==k {print $3}' "$TSV"; }
count_of() { awk -F'\t' -v k="$1" '$1==k {n++} END {print n+0}' "$TSV"; }
deps_of()  { awk -F'\t' -v u="$1" '$3==u {print $4+0}' "$TSV"; }
exists()   { awk -F'\t' -v u="$1" '$3==u {f=1} END {exit !f}' "$TSV"; }

sel_json() {
  py - "$SELECTED" <<'PY'
import json, sys
print(json.dumps([l.strip() for l in open(sys.argv[1]) if l.strip()]))
PY
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 1 — preflight
# ══════════════════════════════════════════════════════════════════════════
preflight() {
  stage "Checking this machine"

  for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1 &&
       "$cand" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 7) else 1)' 2>/dev/null; then
      PY="$cand"; break
    fi
  done
  [[ -n "$PY" ]] || die "python 3.7 or newer is required, and none was found. This installer needs it, and so do all six guardrail hooks."

  [[ -f "$LIB" ]]       || die "install-lib.py is not next to this script. Run ./install.sh from inside the folder you cloned."
  [[ -d "$TEMPLATES" ]] || die "the templates/ folder is not next to this script. Run ./install.sh from inside the folder you cloned."

  ok "found $(py --version 2>&1)"
  ok "reading the templates from  $TEMPLATES"
  ok "your Claude Code folder     $CLAUDE_HOME"
  printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 2 — discovery
# ══════════════════════════════════════════════════════════════════════════
discover_units() {
  stage "What this clone can install"
  pb discover "$TEMPLATES" "$CLAUDE_HOME" > "$UNITS" || die "discovery failed"
  pb units-tsv "$UNITS" > "$TSV"

  heading "Everything this clone can install:"
  awk -F'\t' '{c[$1]++} END {for (k in c) printf "    %-11s %d\n", k, c[k]}' "$TSV" | sort

  printf '\n'
  note "  Three files are deliberately NOT installed:"
  note "    layer-specialist · slice-layer-specialist · engineering-standards"
  note "  They are half-written on purpose. The /adapt-to-stack command finishes"
  note "  them off for each project you use, to match that project's languages,"
  note "  and saves the result inside that project. Copied here unfinished they"
  note "  would not work at all, so the installer leaves them alone."
  printf '\n'
  pause "Press Enter to continue"
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 3 — selection
# ══════════════════════════════════════════════════════════════════════════
preset_minimal() {
  : > "$SELECTED"
  sel_add "command:start-ticket"
  sel_add "claude-md:global"
}

preset_recommended() {
  preset_minimal
  local id
  for id in $(ids_of hook) $(ids_of view); do sel_add "$id"; done
  # skill:adapt-to-stack generates the layer specialists and the standards skill this
  # installer deliberately never places, so without it `recommended` ships a pipeline
  # that dispatches specialists nothing has created. command:resume-ticket covers the
  # first interrupted ticket, which happens to almost everybody.
  for id in command:fix-ticket command:test-ticket command:end-of-day command:garden-memory \
            command:resume-ticket \
            skill:tdd skill:diagnose skill:commit-conventions skill:research skill:handoff \
            skill:adapt-to-stack; do
    exists "$id" && sel_add "$id"
  done
}

preset_everything() {
  : > "$SELECTED"
  local id
  # every kind except tracker — that one is exclusive and picked explicitly
  # Word-splitting is the point here: one id per field, and an id is a filename-derived
  # kind:name that never contains whitespace.
  # shellcheck disable=SC2013
  for id in $(awk -F'\t' '$1!="tracker" {print $3}' "$TSV"); do sel_add "$id"; done
}

# toggle_screen KIND TITLE — one category's checkbox list.
toggle_screen() {
  local kind="$1" title="$2" choice ids id i mark n suffix tok
  while :; do
    screen "Choose · $title"
    ids=$(ids_of "$kind")
    i=0
    for id in $ids; do
      i=$((i + 1))
      mark=" "; sel_has "$id" && mark="x"
      n=$(deps_of "$id"); suffix=""
      [[ "$n" != "0" ]] && suffix="  ${DIM}(+$n dependencies)${RESET}"
      printf '   %2d [%s] %s%s\n' "$i" "$mark" "${id#*:}" "$suffix"
    done
    printf '\n'
    note "type numbers to tick/untick (e.g. 1 4 5) · a=all · n=none · Enter=go back"
    printf '  %s>%s ' "$BOLD" "$RESET"
    _read choice
    [[ -z "$choice" ]] && return 0
    case "$choice" in
      a) for id in $ids; do sel_add "$id"; done; continue ;;
      n) for id in $ids; do sel_del "$id"; done; continue ;;
    esac
    for tok in $choice; do
      case "$tok" in ''|*[!0-9]*) continue ;; esac
      i=0
      for id in $ids; do
        i=$((i + 1))
        [[ "$i" == "$tok" ]] && sel_toggle "$id"
      done
    done
  done
}

# The tracker is exclusive: exactly one adapter, at the fixed path
# $CLAUDE_HOME/tracker.md. Picking a second replaces the first; it is never a merge.
tracker_screen() {
  local choice ids id i mark
  while :; do
    screen "Choose · where your tickets live"
    note "Pick exactly ONE of these."
    note "The commands here ask things like \"what should I work on next?\". This"
    note "file is what turns that into a real lookup against your tracker."
    note "It is installed as $CLAUDE_HOME/tracker.md."
    printf '\n'
    ids=$(ids_of tracker)
    i=0
    for id in $ids; do
      i=$((i + 1))
      mark=" "; sel_has "$id" && mark="•"
      printf '   %2d (%s) %s\n' "$i" "$mark" "${id#*:}"
    done
    printf '\n'
    note "type one number to choose it · 0=none · Enter=go back"
    printf '  %s>%s ' "$BOLD" "$RESET"
    _read choice
    [[ -z "$choice" ]] && return 0
    for id in $ids; do sel_del "$id"; done
    [[ "$choice" == "0" ]] && continue
    i=0
    for id in $ids; do
      i=$((i + 1))
      [[ "$i" == "$choice" ]] && sel_add "$id"
    done
  done
}

# tracker_required_screen — the gate on "install" while the tracker is `none`.
# Returns 0 only when the user has explicitly taken the "later" escape, having been
# told what it costs; 1 sends them back to the menu to pick one.
#
# Why forced rather than defaulted: /start-ticket's FIRST step is
# "@ticket-analyzer — tracker -> ticket-analyzer.md". github, jira and
# local-markdown are genuinely different answers, so guessing one is worse than
# asking. Today's alternative is pressing `r` and getting the flagship command with
# nothing to read a ticket from.
tracker_required_screen() {
  local reply
  screen "Choose · where your tickets live (required)"
  warn "No tracker is selected yet."
  printf '\n'
  say "A tracker is wherever your tickets live: GitHub Issues, Jira, or plain"
  say "markdown files on your own disk."
  printf '\n'
  say "Almost every command here begins by reading a ticket. The very first step"
  say "of /start-ticket, for example, is:"
  printf '      %s@ticket-analyzer — tracker -> ticket-analyzer.md%s\n' "$BOLD" "$RESET"
  say "With no tracker there is nothing for it to read, so the main command of"
  say "the whole playbook stops on its first line."
  printf '\n'
  say "GitHub, Jira and local-markdown work too differently for the installer to"
  say "guess which one you mean, so it asks."
  printf '\n'
  note "Enter  = go back and pick one (item 5 on the previous screen)"
  note "later  = carry on without one, and set it up yourself afterwards"
  printf '  %s>%s ' "$BOLD" "$RESET"
  _read reply
  case "$reply" in
    later|l|LATER)
      TRACKER_DEFERRED="yes"
      TODO+=("Install one tracker adapter: copy a file from templates/trackers/ to $CLAUDE_HOME/tracker.md and fill it in, or re-run ./install.sh and pick one at menu item 5. Until then /start-ticket has nothing to read a ticket from.")
      return 0
      ;;
    *) return 1 ;;
  esac
}

# seed_from_manifest — pre-tick exactly what is already installed.
# Returns 1 when there is no manifest to seed from (a fresh machine).
seed_from_manifest() {
  [[ -f "$MANIFEST" ]] || return 1
  py - "$MANIFEST" <<'PY' > "$SELECTED"
import json, sys
m = json.load(open(sys.argv[1]))
for uid in sorted(m.get("units") or {}):
    print(uid)
PY
  [[ -s "$SELECTED" ]]
}

selection_stage() {
  local choice total extra chosen_tracker seeded="no"

  # On a machine that already has an install, start from WHAT IS THERE, not from
  # a preset. Starting from the preset would pre-tick units the user never chose
  # and silently drop ones they did — an "upgrade" that installs 21 extra things
  # is not an upgrade.
  if seed_from_manifest; then
    seeded="yes"
  else
    preset_recommended
  fi

  stage "What to install"
  if [[ "$seeded" == "yes" ]]; then
    note "Already ticked below: the $(wc -l < "$SELECTED" | tr -d ' ') things you installed last time."
    note "Tick something to add it. Untick something to have it removed."
    note "(./install.sh update refreshes what you have without asking anything.)"
    pause "Press Enter to continue"
  fi
  while :; do
    pb resolve-deps "$UNITS" "$(sel_json)" > "$WORK/resolved.json"
    total=$(py -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["selected"]))' "$WORK/resolved.json")
    extra=$(py -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["pulled_in"]))' "$WORK/resolved.json")
    chosen_tracker=$(sed -n 's/^tracker://p' "$SELECTED" | tr '\n' ' ')
    [[ -z "${chosen_tracker// /}" ]] && chosen_tracker="none"

    screen "What to install"
    printf '   1  commands ......... %s of %s\n' "$(sel_count command)" "$(count_of command)"
    printf '   2  skills ........... %s of %s\n' "$(sel_count skill)"   "$(count_of skill)"
    printf '   3  agents ........... %s of %s   %s(you rarely pick these by hand)%s\n' \
           "$(sel_count agent)" "$(count_of agent)" "$DIM" "$RESET"
    printf '   4  guardrails ....... %s of %s\n' "$(sel_count hook)"    "$(count_of hook)"
    printf '   5  tracker .......... %s\n' "$chosen_tracker"
    printf '   6  views ............ %s of %s\n' "$(sel_count view)"    "$(count_of view)"
    printf '   7  global CLAUDE.md . %s\n' "$(sel_yn claude-md:global)"
    printf '\n'
    printf '   %s%s things will be installed — %s of them added for you,%s\n' "$DIM" "$total" "$extra" "$RESET"
    printf '   %sbecause something you picked cannot work without them.%s\n' "$DIM" "$RESET"
    printf '\n'
    note "1-7  open one of the lists above and tick things on or off"
    note "m    a bare minimum    r  recommended (a good starting point)"
    note "e    absolutely everything"
    note "v    show me the full list, and what was added for me"
    note "i    install it        q  quit without changing anything"
    printf '  %s>%s ' "$BOLD" "$RESET"
    _read choice
    case "$choice" in
      1) toggle_screen command "commands" ;;
      2) toggle_screen skill   "skills" ;;
      3) toggle_screen agent   "agents" ;;
      4) toggle_screen hook    "hooks" ;;
      5) tracker_screen ;;
      6) toggle_screen view    "views" ;;
      7) sel_toggle claude-md:global ;;
      m) preset_minimal ;;
      r) preset_recommended ;;
      e) preset_everything ;;
      v) review_screen ;;
      i)
        if [[ "$total" -le 0 ]]; then
          warn "nothing selected"; pause
        elif [[ "$chosen_tracker" == "none" && "$TRACKER_DEFERRED" != "yes" ]]; then
          # Decision 6: the tracker is a required CHOICE, not an unticked extra.
          if tracker_required_screen; then return 0; fi
        else
          return 0
        fi
        ;;
      q) printf '\n'; exit 0 ;;
    esac
  done
}

# Decision 5: dependencies are auto-ticked, but VISIBLY.
review_screen() {
  screen "Review · everything that will be installed"
  pb resolve-deps "$UNITS" "$(sel_json)" > "$WORK/resolved.json"
  py - "$WORK/resolved.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
pulled = set(d["pulled_in"])
print("\n  you picked these:")
for u in sorted(set(d["selected"]) - pulled):
    print("    " + u)
if pulled:
    print("\n  and these were added for you, because the ones above need them:")
    for u in sorted(pulled):
        print("    " + u)
else:
    print("\n  nothing extra was needed.")
PY
  printf '\n'
  note "Things are added for you rather than refused: a command with no agent to"
  note "call would fail the first time you used it, which is a worse surprise."
  note "If you disagree with one, untick it in its own list (1-7)."
  printf '\n'
  pause "Press Enter to go back"
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 4 — Serena route
# ══════════════════════════════════════════════════════════════════════════
SERENA_PREFIX=""

# serena_gate — Serena is MANDATORY, so no evidence means no install.
#
# 16 of the 20 agents declare Serena tools and every one of them carries a
# "## HALTED — no Serena tools" block telling it to produce nothing; the global
# CLAUDE.md says there is no Serena opt-out. So a no-Serena machine does not get
# degraded agents, it gets sixteen agents that refuse to run. An installer that
# reports success over that is the silent failure this whole issue is about.
#
# CRITICAL: this prints and then EXITS. It must not route through stage(), screen()
# or install_finish() on the way out — all three call _clear, which would wipe the
# instructions off the screen at the exact moment the user needs to read them.
serena_gate() {
  pb serena-detect "$HOME" "$PWD" > "$WORK/serena.json"
  # Gate on the FINDING, not on the length of the evidence list. _server_scan
  # appends an evidence row for an unparseable ~/.claude.json, and counting rows
  # read that row as a reason to continue — a corrupt config file let the gate
  # through on a machine with no Serena at all. `route` cannot lie that way: it is
  # only ever set by a real registration or a real plugin directory.
  local route
  route=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["route"] or "")' "$WORK/serena.json")
  [[ -n "$route" ]] && return 0

  printf '\n  %s%s✗ Serena is not set up on this machine.%s\n\n' "$BOLD" "$RED" "$RESET"
  printf '  %sNothing has been installed and nothing has been changed.%s\n\n' "$BOLD" "$RESET"
  say "Serena is a separate tool that lets Claude find and edit code by symbol"
  say "name instead of re-reading whole files. This playbook does not merely"
  say "prefer it — 16 of its 20 agents refuse to run at all without it."
  printf '\n'
  say "Installing now would leave you with something that reports success and"
  say "then does nothing, so the installer stops here instead."
  printf '\n'
  printf '  %sDo this first:%s\n\n' "$BOLD" "$RESET"
  printf '    1. Install Claude Code and sign in, if you have not already.\n\n'
  printf '    2. Install Serena. Two routes — pick ONE:\n\n'
  printf '       Route A (simplest): run /plugin inside Claude Code and install the\n'
  printf '                           serena plugin from the official marketplace.\n'
  printf '                           It runs Serena via uvx, so it needs uv on PATH.\n\n'
  printf '       Route B:            run Serena yourself and register it under\n'
  printf '                           mcpServers.serena in <workspace>/.mcp.json or\n'
  printf '                           in ~/.claude.json. See\n'
  printf '                           templates/mcp/project.mcp.json.snippet\n\n'
  printf '    3. Check it worked: run /mcp in Claude Code. You should see serena\n'
  printf '       listed, AND the tools that write code (replace_symbol_body,\n'
  printf '       rename_symbol, safe_delete_symbol). A Serena that can only read\n'
  printf '       is not enough for this playbook.\n\n'
  printf '    4. Run this installer again.\n\n'
  printf '  %sThe same steps in full, including why picking the wrong tool name fails\n' "$DIM"
  printf '  with no error message at all, are written up in:%s\n' "$RESET"
  printf '    docs/shared/02-prerequisites.md\n'
  printf '    docs/shared/03-setup.md   (step 2)\n\n'
  printf '  %sPlaces this installer looked: %s/.claude.json, %s/.mcp.json,\n' "$DIM" "$HOME" "$PWD"
  printf '  and %s/.claude/plugins%s\n\n' "$HOME" "$RESET"
  exit 1
}

# agents_declaring TOKEN — the agent names whose tools: line declares TOKEN.
# Derived from the template tree every time it is asked, never written down: the
# last two counts in this repo to be typed by hand were both wrong, and #109
# existed to remove exactly that habit.
agents_declaring() {
  grep -lE "^tools:.*$1" "$TEMPLATES"/agents/*.md 2>/dev/null \
    | sed 's#.*/##; s#\.md$##' | grep -v '^README$' || true
}

# memory_gate — memory is the SECOND pillar, and it is mandatory for the same
# reason Serena is. The difference is how it fails: an agent with no Serena tools
# halts and says so, while an agent with no memory tools runs to completion and
# produces nothing durable. /encode-codebase, /end-of-day, /garden-memory,
# /test-ticket's banked recipes, charting's one-memory-per-map close and
# /start-ticket's consolidation step all no-op in silence.
#
# Before this gate, no memory server meant the two memory blanks were DELETED from
# the agents and the installer printed "nothing left unfilled" over the result.
# That is the silent success the Serena gate exists to prevent, applied to the
# other required pillar — see docs/shared/02-prerequisites.md, which has listed
# both under Required all along.
#
# CRITICAL: this prints and then EXITS. Like serena_gate it must not route through
# stage(), screen() or install_finish() on the way out — all three call _clear,
# which would wipe the instructions off the screen at the exact moment they are
# needed.
memory_gate() {
  pb memory-detect "$HOME" "$PWD" > "$WORK/memory.json"
  # Gate on the server that was FOUND, not on the length of the evidence list —
  # see serena_gate for the same correction. Counting rows was worse here: an
  # unparseable ~/.claude.json produced one row and no server, so the gate passed,
  # placeholder_stage then announced "found a memory server ()" with an empty name
  # and no suggestion to offer, and the run died five unanswerable prompts later.
  # The gate exists to stop exactly that, on exactly that machine.
  local server
  server=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["server"] or "")' "$WORK/memory.json")
  [[ -n "$server" ]] && return 0

  local n_mem n_all=0 f
  n_mem=$(agents_declaring '<memory-(read|write)-tools>' | grep -c . || true)
  for f in "$TEMPLATES"/agents/*.md; do
    [[ -e "$f" ]] || continue
    [[ "${f##*/}" == "README.md" ]] && continue
    n_all=$((n_all + 1))
  done

  printf '\n  %s%s✗ No memory server is set up on this machine.%s\n\n' "$BOLD" "$RED" "$RESET"
  printf '  %sNothing has been installed and nothing has been changed.%s\n\n' "$BOLD" "$RESET"
  say "A semantic-memory MCP server is the second of this playbook's two pillars."
  say "It is what makes the work compound: what one session concluded, the next"
  say "session can look up. $n_mem of the $n_all agents declare memory tools."
  printf '\n'
  say "Without one, those agents do not stop and complain. They run, they look"
  say "right, and nothing they learn is ever written down. /end-of-day and"
  say "/garden-memory have nothing to garden, /test-ticket cannot bank a recipe,"
  say "and every ticket starts from zero."
  printf '\n'
  say "Installing now would leave you with something that reports success and"
  say "then quietly forgets everything, so the installer stops here instead."
  printf '\n'
  printf '  %sDo this first:%s\n\n' "$BOLD" "$RESET"
  printf '    1. Install a semantic-memory MCP server. Forgetful is the one this\n'
  printf '       playbook documents and fills in for, and it needs a PostgreSQL +\n'
  printf '       pgvector backend — Docker is the easy path.\n\n'
  printf '    2. Register it. Two routes — pick ONE:\n\n'
  printf '       Route A: register it under mcpServers.forgetful in ~/.claude.json,\n'
  printf '                which makes it available in every project.\n\n'
  printf '       Route B: register it under mcpServers.forgetful in the\n'
  printf '                workspace .mcp.json, next to Serena. See\n'
  printf '                templates/mcp/project.mcp.json.snippet\n\n'
  printf '       Route C: connect it as a claude.ai connector, if it offers one.\n'
  printf '                Nothing is written to mcpServers by this route, and the\n'
  printf '                tools are named mcp__claude_ai_<name>__* rather than\n'
  printf '                mcp__forgetful__* — this installer reads the connector\n'
  printf '                list and fills in the matching names.\n\n'
  printf '    3. Check it worked: run /mcp in Claude Code. You should see the server\n'
  printf '       listed, AND its tools. A server that is registered but not running\n'
  printf '       is not enough.\n\n'
  printf '    4. Run this installer again.\n\n'
  printf '  %sRunning a memory server other than Forgetful is fine — this installer\n' "$DIM"
  printf '  asks for your own tool names. What it will not do is continue with no\n'
  printf '  memory server at all. The full write-up is in:%s\n' "$RESET"
  printf '    docs/shared/02-prerequisites.md\n'
  printf '    docs/shared/03-setup.md   (step 3)\n\n'
  printf '  %sPlaces this installer looked: %s/.claude.json (both mcpServers and\n' "$DIM" "$HOME"
  printf '  the claude.ai connector list), %s/.mcp.json, and %s/.claude/plugins%s\n\n' "$PWD" "$HOME" "$RESET"
  exit 1
}

serena_stage() {
  stage "Serena — which tool names to use"
  serena_gate

  heading "What this installer found on your machine:"
  py - "$WORK/serena.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if not d["evidence"]:
    print("      nothing — no Serena registration or plugin files were found")
for e in d["evidence"]:
    print("      %-22s ← %s" % (e["found"], e["where"]))
PY
  printf '\n'
  say "Serena's tools are named differently depending on how you installed it,"
  say "and the agent files have to use the matching name. This one is worth"
  say "getting right: if the name is wrong, nothing complains. Claude Code drops"
  say "a tool it cannot find without a word, and the agent carries on without it."
  printf '\n'
  note "  A  you installed the Serena PLUGIN    ->  mcp__plugin_serena_serena__"
  note "  B  you registered it yourself, in"
  note "     .mcp.json or ~/.claude.json        ->  mcp__serena__   (the default)"
  printf '\n'
  say "Pressing Enter takes the suggestion, which is based on what was found above."
  printf '\n'

  local suggest ans
  suggest=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["route"] or "B")' "$WORK/serena.json")
  printf '  %sRoute [A/B, Enter = %s]%s ' "$BOLD" "$suggest" "$RESET"
  _read ans
  [[ -z "$ans" ]] && ans="$suggest"
  case "$ans" in
    a|A) SERENA_PREFIX="mcp__plugin_serena_serena__"; ok "will rename the Serena tools to the plugin form" ;;
    *)   SERENA_PREFIX="";                            ok "keeping mcp__serena__, which is what the files already say" ;;
  esac
  TODO+=("Check the real Serena tool names with /mcp in Claude Code, then run one agent and confirm it actually got them.")
  printf '\n'
  pause "Press Enter to continue"
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 5 — placeholders
# ══════════════════════════════════════════════════════════════════════════
# Asked once per distinct token, then applied across every file installed.
PH_SPEC="$WORK/placeholders.json"

# show_evidence FILE — the "here is what I found" block, in the shape serena_stage
# already prints it. Detection that reports its evidence is the difference between
# a suggestion the user can check and a decision made quietly on their behalf.
show_evidence() {
  py - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if not d["evidence"]:
    print("      nothing — no registration or plugin files were found")
for e in d["evidence"]:
    print("      %-28s ← %s" % (e["found"], e["where"]))
PY
  printf '\n'
}

# ask_tools VAR PROMPT DEFAULT WHAT_IT_COSTS — one tool-name answer that cannot be
# thrown away by accident.
#
# This is the whole point of #105. The old prompt printed
# "[Enter = take the blank out instead]" under a stage whose opening line is
# "Press Enter at any question to take the suggested answer", so the key the stage
# told you to press deleted a tool grant from 13 agents and the install still
# reported success. Here Enter TAKES the suggestion; where there is no suggestion
# Enter re-asks; and removing the grant is an explicit '-' that says what it costs
# and then asks again. Deleting a tool grant is a decision, so it needs an answer.
ask_tools() {
  local __var="$1" __prompt="$2" __default="$3" __cost="$4" __ans __tries=0
  while :; do
    printf '  %s%s%s\n' "$BOLD" "$__prompt" "$RESET"
    if [[ -n "$__default" ]]; then
      printf '  %s[Enter = %s]%s ' "$DIM" "$__default" "$RESET"
    else
      printf '  %s[type the names, comma-separated, or - to remove the grant]%s ' "$DIM" "$RESET"
    fi
    _read __ans
    case "$__ans" in
      "")
        if [[ -n "$__default" ]]; then
          printf -v "$__var" '%s' "$__default"
          return 0
        fi
        printf '\n'
        warn "There is no suggested answer to this one, so Enter cannot take it."
        note "Run /mcp in Claude Code to see the exact tool names, then type them."
        note "If you really do want the grant removed, type a single -"
        ;;
      "-")
        printf '\n'
        warn "Removing that grant means: $__cost"
        note "They will not fail or complain. They will run and do that part badly."
        if confirm "Remove it anyway?"; then
          printf -v "$__var" '%s' ""
          return 0
        fi
        ;;
      *)
        printf -v "$__var" '%s' "$__ans"
        return 0
        ;;
    esac
    __tries=$((__tries + 1))
    # _read already ends the run at EOF, so this cannot spin on a closed stdin.
    # The cap is for the other shape: a scripted answer list that keeps feeding
    # an answer this prompt cannot use.
    [[ "$__tries" -ge 5 ]] && die "five unusable answers in a row — stopping rather than picking one for you"
    printf '\n'
  done
}

placeholder_stage() {
  stage "Filling in the blanks"

  # The second pillar's gate. It lives here rather than beside serena_gate because
  # this is the stage that needs the answer — and like that one it runs before a
  # single byte is written.
  memory_gate

  say "Some of these files ship with blanks in them, written like <strong-model-id>."
  say "Each one has to be filled in before Claude Code can use the file. A blank"
  say "left behind is either ignored without a word, or fails the first time you"
  say "use that file."
  printf '\n'
  say "Press Enter at any question that has a suggested answer, to take it."
  # NOT "every question below has one": two of them may not. A server this repo
  # ships no tool names for, and the tracker question, are both asked with an
  # empty suggestion, and ask_tools then says so and re-asks. Claiming otherwise
  # here contradicts the installer's own next screen.
  note "Enter never removes a tool grant — that is an explicit  -  and it tells"
  note "you what it costs first. Where a question has no suggestion, it says so"
  note "and asks again rather than taking silence for an answer."
  printf '\n'

  local strong fast mem_read="" mem_write="" trk_read=""
  printf '  %sWhich model for the heavy work — planning and code review?%s\n' "$BOLD" "$RESET"
  printf '  %s[Enter = claude-opus-5]%s ' "$DIM" "$RESET"
  _read strong; [[ -z "$strong" ]] && strong="claude-opus-5"
  printf '  %sWhich model for the quick, cheap lookups?%s\n' "$BOLD" "$RESET"
  printf '  %s[Enter = claude-haiku-4-5-20251001]%s ' "$DIM" "$RESET"
  _read fast; [[ -z "$fast" ]] && fast="claude-haiku-4-5-20251001"
  printf '\n'

  # ── memory ───────────────────────────────────────────────────────────────
  # memory_gate has already proved a server is here and left the evidence in
  # $WORK/memory.json, so this never has to ask "do you have one".
  local mem_server mem_suggest mem_both mem_conn mem_short mem_cost_r mem_cost_w
  mem_server=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["server"] or "")' "$WORK/memory.json")
  mem_suggest=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["suggest"])' "$WORK/memory.json")
  mem_conn=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["connector"])' "$WORK/memory.json")
  # The whole-server short form is the prefix with the trailing __ taken off, so it
  # has to be derived from the SAME prefix as the trio. Printing mcp__forgetful at
  # a connector user would be the wrong-name failure this gate exists to remove,
  # just moved from the default answer into the advice next to it.
  mem_short=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["prefix"].rstrip("_"))' "$WORK/memory.json")
  mem_both=$(py -c 'import json,sys;print("yes" if json.load(open(sys.argv[1]))["one_tool_does_both"] else "no")' "$WORK/memory.json")
  mem_cost_r="these agents lose their memory sweep and start every ticket from zero — $(agents_declaring '<memory-read-tools>' | tr '\n' ' ')"
  mem_cost_w="these agents can no longer bank what they learned — $(agents_declaring '<memory-write-tools>' | tr '\n' ' ')"

  ok "found a memory server ($mem_server)"
  heading "What this installer found on your machine:"
  show_evidence "$WORK/memory.json"

  # A connector was found in a list that records what has EVER been connected, so
  # unlike a registered server its presence is not proof it is live. Say so here
  # rather than letting the tick above imply more than was checked.
  if [[ -n "$mem_conn" ]]; then
    warn "Found via the claude.ai connector list, which records what has ever been"
    note "connected — not what is connected now. The tool names below are built"
    note "from the connector's name ($mem_conn), which is where the"
    note "mcp__claude_ai_ prefix comes from."
    TODO+=("Your memory server was found in the claude.ai connector list, which is a history rather than a live roster. Run /mcp in Claude Code and confirm $mem_conn is connected AND that its tools are listed.")
    printf '\n'
  fi

  if [[ -n "$mem_suggest" ]]; then
    say "Forgetful has no per-operation tools. Every read and every write dispatches"
    say "through the same wrapper trio, so the same three names are the right answer"
    say "to both questions below, and Enter takes them."
    printf '\n'
    note "A shorter answer is also accepted:  $mem_short  on its own grants"
    note "every tool the server exposes. Verified against Claude Code v2.1.251;"
    note "the docs do not say which version introduced it, so the three explicit"
    note "names are the default here because they work on any version."
  else
    say "This installer does not ship the tool names for $mem_server, so it cannot"
    say "suggest them. Run /mcp in Claude Code to see the exact names, then type"
    say "them below. Enter will not answer this one for you."
  fi
  printf '\n'

  # §4 of #105. Several agents state their read-only-on-memory scope as being
  # enforced "by charter and by tool grant". Against a wrapper-trio server only
  # the charter is real, and saying so is better than shipping a split the
  # recommended server cannot honour.
  if [[ "$mem_both" == "yes" ]]; then
    warn "Worth knowing before you answer: Forgetful dispatches reads AND writes"
    note "through one tool, so granting an agent memory read also grants it write."
    note "The read/write split in the agent files is a charter, not a tool grant."
    TODO+=("Forgetful runs every memory operation through one tool, so the read/write split in the agent files is enforced by their instructions, not by the tool grant. Do not rely on the grant to keep an agent read-only on memory.")
    printf '\n'
  fi

  ask_tools mem_read  "Memory tools that READ"  "$mem_suggest" "$mem_cost_r"
  ask_tools mem_write "Memory tools that WRITE" "$mem_suggest" "$mem_cost_w"
  [[ -z "$mem_read" ]]  && TODO+=("You removed <memory-read-tools>. These agents have no memory sweep: $(agents_declaring '<memory-read-tools>' | tr '\n' ' ')")
  [[ -z "$mem_write" ]] && TODO+=("You removed <memory-write-tools>. These agents cannot bank what they learn: $(agents_declaring '<memory-write-tools>' | tr '\n' ' ')")
  printf '\n'

  # ── tracker ──────────────────────────────────────────────────────────────
  # The adapter was chosen back in the selection stage, so this no longer has to
  # ask for tracker tool names before knowing whether a tracker MCP is even
  # wanted. The GitHub adapter drives the gh CLI and needs none: for that one
  # deletion is the RIGHT answer, not a loss, and the installer can now say so.
  #
  # Two blanks, two different questions. <tracker-read-tools> is MCP tool names,
  # which only a registered server can supply. <tracker-shell-tools> is the shell
  # @ticket-analyzer needs when the adapter is a CLI instead — it is the ONLY agent
  # declaring the read token that grants no Bash of its own, so it is the only one
  # the delete actually disables, and it is the FIRST agent /start-ticket runs.
  # Neither is a question here: both follow from the adapter picked back in the
  # selection stage. install-lib.py owns that table, so there is one copy of it.
  local chosen_tracker trk_server trk_cost trk_shell trk_mcp
  chosen_tracker=$(sed -n 's/^tracker://p' "$SELECTED" | head -1)
  trk_cost="these agents can no longer read a ticket from the tracker — $(agents_declaring '<tracker-read-tools>' | tr '\n' ' ')"
  pb tracker-route "$chosen_tracker" > "$WORK/tracker-route.json"
  trk_shell=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["shell"])' \
              "$WORK/tracker-route.json")
  trk_mcp=$(py -c 'import json,sys;print("yes" if json.load(open(sys.argv[1]))["mcp"] else "")' \
            "$WORK/tracker-route.json")

  # Branch on the ROUTE, not on the adapter name. Naming github here was a second
  # copy of the table the comment above says lives in install-lib.py, and it sent
  # gitlab-shape — which drives glab and registers no server either — down the MCP
  # path, where it drew a pointless probe and a TODO telling the user to register
  # a server their adapter never reads.
  if [[ -z "$trk_mcp" ]]; then
    ok "your tracker adapter is $chosen_tracker, which does not read through an MCP server"
    note "It needs no tracker MCP server, so the tracker blank is taken out of the"
    note "files. For this adapter that is the correct answer rather than a loss."
  else
    pb tracker-detect "$HOME" "$PWD" > "$WORK/tracker-mcp.json"
    trk_server=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["server"] or "")' "$WORK/tracker-mcp.json")
    if [[ -n "$trk_server" ]]; then
      ok "found a tracker server ($trk_server)"
      show_evidence "$WORK/tracker-mcp.json"
      say "Run /mcp in Claude Code to see its exact tool names, then type them."
      ask_tools trk_read "Tracker tools that READ" "" "$trk_cost"
      [[ -z "$trk_read" ]] && TODO+=("You removed <tracker-read-tools>. These agents cannot read a ticket: $(agents_declaring '<tracker-read-tools>' | tr '\n' ' ')")
    else
      note "No tracker MCP server is registered, so the tracker blank is taken out"
      note "of the files rather than left in. Your tracker adapter may not need one."
      TODO+=("No tracker MCP was found, so <tracker-read-tools> was removed from: $(agents_declaring '<tracker-read-tools>' | tr '\n' ' ') — if your adapter needs one, register it and re-run the installer.")
    fi
  fi

  if [[ -n "$trk_shell" ]]; then
    ok "$chosen_tracker is driven from the command line, so @ticket-analyzer gets $trk_shell"
    note "It is the one agent whose whole job is reading the tracker and which holds"
    note "no shell of its own. Without this it cannot run a single adapter command,"
    note "and it is the first thing /start-ticket dispatches."
  fi

  # Stamp the answers with the contract they were given under, so a later `update`
  # can tell "still your answer" from "given under rules that no longer hold".
  # Read from install-lib.py rather than hardcoded here: two copies of one constant
  # is the anti-pattern already called out for the tracker token list below.
  local ph_contract
  ph_contract=$(pb contract-version)
  py - "$PH_SPEC" "$strong" "$fast" "$mem_read" "$mem_write" "$trk_read" \
       "$trk_shell" "$ph_contract" <<'PY'
import json, sys
out = sys.argv[1]
values = {"<strong-model-id>": sys.argv[2], "<fast-model-id>": sys.argv[3]}
delete = []
for tok, val in (("<memory-read-tools>",   sys.argv[4]),
                 ("<memory-write-tools>",  sys.argv[5]),
                 ("<tracker-read-tools>",  sys.argv[6]),
                 ("<tracker-shell-tools>", sys.argv[7])):
    if val.strip():
        values[tok] = val.strip()
    else:
        delete.append(tok)
json.dump({"paths": [], "values": values, "delete": delete,
           "contract": int(sys.argv[8])}, open(out, "w"), indent=2)
PY
  printf '\n'
  pause "Press Enter to continue"
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 6 — confirm, in the only place a confirmation is worth anything:
#            after the plan is known and before a single byte is written.
# ══════════════════════════════════════════════════════════════════════════
# A flag would only have reached people who read the README, which is the same
# problem $CLAUDE_HOME has today. This screen answers "what is this about to do to
# my computer" for everybody, including the person who ran it on a hunch.

# hooks_warning_screen HOOKS — decision 1, in plain language, BEFORE any hook is
# written or wired. The word "allowlist" used to appear exactly once in this
# installer, inside a code comment, and the first a stranger heard about it was
# their next `git push` being refused.
hooks_warning_screen() {
  screen "Before the guardrail hooks go in — please read this"
  printf '\n'
  say "You picked some guardrails. In Claude Code these are called \"hooks\":"
  say "small scripts that sit between Claude and your computer, and refuse a"
  say "few commands that are hard to undo."
  printf '\n'
  printf '  %sWhat changes for you, straight away:%s\n\n' "$BOLD" "$RESET"
  say "  Claude will no longer be able to run  git push  for you, in any repo,"
  say "  until you say that repo is allowed. If it tries, it is refused and you"
  say "  see a message saying the repo is not in your allowlist."
  printf '\n'
  printf '  %sWhat does NOT change:%s\n\n' "$BOLD" "$RESET"
  say "  Your own  git push , typed by you in your own terminal, is untouched."
  say "  These hooks only ever see commands that Claude runs. They cannot see,"
  say "  and cannot stop, anything you type yourself. Your git still works."
  printf '\n'
  printf '  %sHow to allow a repo — one line in %s:%s\n\n' "$BOLD" "$CLAUDE_HOME/repo-allowlist" "$RESET"
  printf '      %sgithub.com/you/weekend-project    yes    yes%s\n\n' "$BOLD" "$RESET"
  say "  Three things on one line, separated by spaces:"
  say "    1  any recognisable piece of that repo's address. To see yours, run"
  say "         git config --get remote.origin.url"
  say "       inside the repo, and copy enough of it that no other repo of"
  say "       yours would match. It only has to appear somewhere in the"
  say "       address, so one line covers the https:// and the git@ form both."
  say "    2  may Claude run git push in this repo?               yes or no"
  say "    3  does this repo's CLAUDE.md belong to the repo — would"
  say "       someone cloning it fresh on a new laptop need it?   yes or no"
  say "  Anything that is not exactly 'yes' is treated as no."
  printf '\n'
  note "That file is installed EMPTY on purpose. Any repo you have not thought"
  note "about yet answers no to both questions, which is the safe answer. You"
  note "add a line the first time a project actually needs one."
  printf '\n'
  note "Two things stay blocked everywhere, and no line in that file turns them"
  note "back on: 'git add -A' / 'git add .', and writing into .claude/, .serena,"
  note ".forgetful or MEMORY.md."
  printf '\n'
  pause "Press Enter when you have read this"
}

# adopt_screen — decision 3. Files that are already there but were not put there by
# this script are `skip-foreign`: today the installer sees them, refuses to touch
# them, and does nothing useful — so it is least useful to exactly the people who
# followed docs/shared/03-setup.md by hand. Offer to adopt them, with consent.
adopt_screen() {
  local action uid kind src dest n=0
  : > "$WORK/foreign.txt"
  while IFS=$'\t' read -r action uid kind src dest; do
    [[ "$action" == "skip-foreign" ]] || continue
    printf '%s\t%s\n' "$uid" "$dest" >> "$WORK/foreign.txt"
    n=$((n + 1))
  done < "$WORK/plan-preview.tsv"
  [[ "$n" -gt 0 ]] || return 0

  screen "Files already here that this script did not install"
  printf '\n'
  say "These files are already on your disk, and this installer has no record of"
  say "putting them there — so they are almost certainly yours, copied in by hand"
  say "at some point."
  printf '\n'
  while IFS=$'\t' read -r uid dest; do
    printf '    %-34s %s\n' "$uid" "$dest"
  done < "$WORK/foreign.txt"
  printf '\n'
  say "Unless you say otherwise, the installer leaves them alone for good — which"
  say "also means it can never bring you a newer version of them."
  printf '\n'
  printf '  %sIf you say yes ("adopt" them):%s\n\n' "$BOLD" "$RESET"
  say "  · nothing changes on disk right now. Your files stay exactly as they are."
  say "  · from now on they count as managed, so a later ./install.sh update WILL"
  say "    replace them when the playbook's version of that file changes."
  say "  · ./install.sh remove will still NEVER delete them, whatever they contain,"
  say "    because this installer did not put them there in the first place."
  printf '\n'
  if confirm "Adopt the $n file(s)/dir(s) above?"; then
    cut -f1 "$WORK/foreign.txt" > "$WORK/adopt.txt"
    ok "$n file(s) will be kept up to date from now on"
    pause "Press Enter to continue"
  else
    rm -f "$WORK/adopt.txt"
    note "Left alone. They stay yours, and this installer will not touch them."
    pause "Press Enter to continue"
  fi
}

confirm_stage() {
  stage "What this will write"

  # Close the selection over its dependency edges and plan against THAT, without
  # touching $SELECTED — install_stage_body closes it again from the same inputs,
  # so the plan shown here is the plan that runs.
  pb resolve-deps "$UNITS" "$(sel_json)" > "$WORK/resolved.json"
  py -c 'import json,sys
for u in json.load(open(sys.argv[1]))["selected"]: print(u)' "$WORK/resolved.json" > "$WORK/closed.txt"
  pb plan-install "$UNITS" "$MANIFEST" "$WORK/closed.txt" > "$WORK/plan-preview.tsv"

  local hooks_selected
  hooks_selected=$(sed -n 's/^hook://p' "$WORK/closed.txt" | tr '\n' ' ')

  # Decision 1: the guardrail explanation comes before any hook is written or wired.
  if [[ -n "${hooks_selected// /}" ]]; then
    hooks_warning_screen
  fi

  # Decision 3: adopting a hand-install is a consented act, and this is the last
  # moment before anything is recorded.
  adopt_screen

  if [[ -n "${hooks_selected// /}" ]]; then
    # shellcheck disable=SC2086
    pb hook-wiring "$HOOK_SNIPPET" $hooks_selected > "$WORK/wiring-preview.json"
  else
    printf '{"hooks":{}}\n' > "$WORK/wiring-preview.json"
  fi

  screen "What this will write"
  printf '\n'
  py - "$WORK/plan-preview.tsv" "$WORK/wiring-preview.json" "$SETTINGS" <<'PY'
import json, sys

plan_path, wiring_path, settings = sys.argv[1], sys.argv[2], sys.argv[3]

groups = {}
for line in open(plan_path, encoding="utf-8"):
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 5:
        continue
    action, uid, kind, _src, dest = parts[:5]
    groups.setdefault(action, []).append((kind, uid, dest))

TITLES = [
    ("install",      "NEW — do not exist yet, will be created"),
    ("upgrade",      "UPDATED — this installer wrote these before, and will replace them"),
    ("current",      "UNCHANGED — already exactly this version"),
    ("skip-edited",  "LEFT ALONE — you edited these yourself since installing them"),
    ("skip-foreign", "LEFT ALONE — already here, and this installer did not put them there"),
    ("orphan",       "LEFT ALONE — installed once, and this clone no longer ships them"),
]

wrote_any = False
for action, title in TITLES:
    rows = sorted(groups.get(action) or [])
    if not rows:
        continue
    wrote_any = True
    print("  %s (%d):" % (title, len(rows)))
    last_kind = None
    for kind, uid, dest in rows:
        if kind != last_kind:
            print("      %s" % kind)
            last_kind = kind
        print("        %s" % dest)
    print("")

if not wrote_any:
    print("  nothing to write.\n")

wiring = json.load(open(wiring_path)).get("hooks") or {}
if wiring:
    print("  keys added to %s:" % settings)
    for event in sorted(wiring):
        for block in wiring[event]:
            matcher = block.get("matcher", "*")
            for h in block.get("hooks") or []:
                print("      hooks / %s / matcher=%s" % (event, matcher))
                print("          %s" % h.get("command", ""))
    print("")
    print("  If one of those settings already exists with a different value, your")
    print("  value is kept. The installer never overwrites it, and it tells you")
    print("  at the end that it left it alone.")
    print("")
else:
    print("  no changes to %s.\n" % settings)
PY
  note "This is the last question before anything is written. Not one file"
  note "outside $CLAUDE_HOME is touched, and answering no writes nothing at all."
  printf '\n'
  if ! confirm "Write the files listed above?"; then
    printf '\n  %sNothing was written. Nothing on your machine changed.%s\n\n' "$BOLD" "$RESET"
    printf '  Run ./install.sh again whenever you like.\n\n'
    exit 0
  fi
  printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 7 — install
# ══════════════════════════════════════════════════════════════════════════
# Keep the newest BACKUP_KEEP copies of each backed-up file and prune the rest.
# Unbounded growth was the old behaviour: settings.json is copied on every run that
# wires a hook, for ever. Nothing here is pruned by `remove` — see remove_mode.
BACKUP_KEEP=10

backup_file() {
  [[ -e "$1" ]] || return 0
  mkdir -p "$BACKUPS"
  local base dest old
  base="$(basename "$1")"
  dest="$BACKUPS/$base.$(date +%Y%m%d-%H%M%S)"
  cp -R "$1" "$dest" 2>/dev/null || return 0
  note "backed up $base → $dest"

  # Newest first, drop everything past the cap. Keyed on "$base." so one file's
  # history never prunes another's.
  # ls, not find: this needs newest-first ordering, the names are timestamps we wrote,
  # and read -r takes a whole line, so a space in $BACKUPS is handled. The directive
  # must sit in front of the whole loop - between done and its redirect it is SC1123.
  # shellcheck disable=SC2012
  while IFS= read -r old; do
    [[ -n "$old" ]] && rm -rf "$old"
  done < <(ls -1dt "$BACKUPS/$base."* 2>/dev/null | tail -n "+$((BACKUP_KEEP + 1))")
  return 0
}

install_stage() {
  stage "Writing the files"
  install_stage_body
  write_manifest
  printf '\n'
}

# install_stage_body — the actual work, shared by `install` and `update`.
# Kept separate from the stage banner and the manifest write so `update` can run
# exactly the same copy / rewrite / fill / wire path without a second stage.
install_stage_body() {
  # close the selection over its dependency edges, then write the closed set back
  pb resolve-deps "$UNITS" "$(sel_json)" > "$WORK/resolved.json"
  py -c 'import json,sys
for u in json.load(open(sys.argv[1]))["selected"]: print(u)' "$WORK/resolved.json" > "$SELECTED"

  pb plan-install "$UNITS" "$MANIFEST" "$SELECTED" > "$WORK/plan.tsv"

  local action uid kind src dest
  : > "$WORK/written.txt"

  while IFS=$'\t' read -r action uid kind src dest; do
    [[ -z "$action" ]] && continue
    case "$action" in
      install|upgrade)
        mkdir -p "$(dirname "$dest")"
        if [[ "$kind" == "allowlist" ]]; then
          # comments only, ZERO entries. Not listed means no to both questions,
          # which is the safe default for a repo you have not thought about yet.
          grep -E '^[[:space:]]*#|^[[:space:]]*$' "$src" > "$dest"
        elif [[ -d "$src" ]]; then
          rm -rf "$dest"; cp -R "$src" "$dest"
        else
          cp "$src" "$dest"
        fi
        [[ "$kind" == "hook" ]] && chmod +x "$dest"
        printf '%s\n' "$dest" >> "$WORK/written.txt"
        if [[ "$action" == "install" ]]; then INSTALLED+=("$uid"); else UPGRADED+=("$uid"); fi
        ;;
      current)
        printf '%s\n' "$dest" >> "$WORK/written.txt"
        ;;
      skip-edited)
        LEFT_ALONE+=("$uid — you edited it since install; diff against $src")
        # The summary line above says it once, in a class that scrolls past. An
        # edited file is frozen until somebody does something about it, which makes
        # it a to-do, not a footnote — and the to-do has to carry the actual command.
        # Separators normalised because this one is meant to be COPIED AND RUN:
        # python builds these paths with os.path.join, so on Windows they come back
        # as C:/...\commands\x.md, and backslashes in a shell command are escapes.
        TODO+=("${dest//\\//} was kept, so this update did not refresh it — you changed it after it was installed. See what this clone would have written: diff ${dest//\\//} ${src//\\//} — then either keep yours, or copy the new one over it by hand.")
        ;;
      orphan)
        # Recorded, still on disk, and this clone no longer ships it: renamed or
        # removed upstream. Say so and name the file. Deleting it without being
        # asked is not this script's call.
        TODO+=("${dest//\\//} is still installed, but this clone no longer ships $uid — it was renamed or removed since you installed it. Nothing was changed. Delete the file by hand if you do not want it any more.")
        ;;
      skip-foreign)
        # Decision 3: adopted only when the user said yes on the confirm stage.
        # The file itself is NOT rewritten — adoption records what is already there
        # as ours to manage, it does not replace the user's content with ours.
        if [[ -f "$WORK/adopt.txt" ]] && grep -Fxq "$uid" "$WORK/adopt.txt"; then
          ADOPTED+=("$uid — adopted; recorded as managed, and remove will never delete it")
        else
          LEFT_ALONE+=("$uid — present but not installed by this script; left untouched")
        fi
        ;;
    esac
  done < "$WORK/plan.tsv"

  ok "$(wc -l < "$WORK/written.txt" | tr -d ' ') file(s)/dir(s) written"

  # ── Serena prefix, then placeholders, across what we just wrote ────────
  py -c 'import json,sys
json.dump([l.strip() for l in open(sys.argv[1]) if l.strip()], open(sys.argv[2],"w"))' \
    "$WORK/written.txt" "$WORK/paths.json"

  if [[ -n "$SERENA_PREFIX" ]]; then
    pb serena-rewrite "$WORK/paths.json" "$SERENA_PREFIX" > "$WORK/serena-rw.json"
    ok "rewrote the Serena prefix in $(py -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["changed"]))' "$WORK/serena-rw.json") file(s)"
  fi

  py - "$PH_SPEC" "$WORK/paths.json" <<'PY'
import json, sys
spec = json.load(open(sys.argv[1]))
spec["paths"] = json.load(open(sys.argv[2]))
json.dump(spec, open(sys.argv[1], "w"), indent=2)
PY
  pb apply-placeholders "$PH_SPEC" > "$WORK/ph-applied.json"
  ok "filled placeholders in $(py -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["changed"]))' "$WORK/ph-applied.json") file(s)"

  memory_schema_swap

  # ── hook wiring, filtered to the hooks actually installed ─────────────
  local hooks_installed
  hooks_installed=$(sed -n 's/^hook://p' "$SELECTED" | tr '\n' ' ')
  if [[ -n "${hooks_installed// /}" ]]; then
    backup_file "$SETTINGS"
    # shellcheck disable=SC2086
    pb hook-wiring "$HOOK_SNIPPET" $hooks_installed > "$WORK/wiring.json"
    pb merge-json "$SETTINGS" "$WORK/wiring.json" > "$WORK/merge.json"
    ok "merged hook wiring into $SETTINGS"
    # Decision 1: the same line the pre-install screen taught, repeated where the
    # user is standing when they next try to push.
    TODO+=("Claude cannot run 'git push' in any repo until you allow that repo. Your OWN git push is unaffected. To allow one, add a line to $CLAUDE_HOME/repo-allowlist, like:   github.com/you/weekend-project    yes    yes   — that is (part of your remote URL from 'git config --get remote.origin.url') (may Claude push here? yes/no) (is this repo's CLAUDE.md its own? yes/no).")
    while IFS= read -r line; do
      [[ -n "$line" ]] && CONFLICTS+=("$line")
    done < <(py -c 'import json,sys
for c in json.load(open(sys.argv[1]))["conflicts"]:
    print("%s — kept yours (%r); ours would have been %r" % (c["path"], c["yours"], c["ours"]))' "$WORK/merge.json")
  fi
}

# memory_schema_swap — load the filled-in memory-schema, not the placeholder one.
#
# skill:memory-schema installs as a whole DIRECTORY, so a Forgetful user ends up
# with the unfilled placeholder SKILL.md loaded and the filled-in, already-verified
# forgetful.SKILL.md sitting unused beside it. The variant's own header says to run
# `mv forgetful.SKILL.md SKILL.md`, and nothing ever did it.
#
# verify_stage's blank-grep cannot catch this either: it reads only name:, model:
# and tools: lines, and memory-schema's placeholders (<create-memory-tool> and the
# rest) are all in the body.
#
# Runs inside install_stage_body, so it covers `install` and `update` both, and
# write_manifest runs after it — the manifest therefore records the swapped
# directory and the next run does not mistake this for a user edit.
memory_schema_swap() {
  local dir="$CLAUDE_HOME/skills/memory-schema"
  local variant="$dir/forgetful.SKILL.md"
  [[ -f "$variant" ]] || return 0
  [[ -f "$WORK/memory.json" ]] || return 0

  local server
  server=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["server"] or "")' "$WORK/memory.json")
  if [[ "$server" != "forgetful" ]]; then
    note "memory-schema installed with its placeholder SKILL.md — fill it in for"
    note "$server. The Forgetful variant beside it is a worked example."
    TODO+=("Fill in $dir/SKILL.md with your memory server's real call shape. It ships as a placeholder, and its blanks are in the body where the installer's blank-check cannot see them. $variant is the same skill filled in for Forgetful, as a worked example.")
    return 0
  fi

  backup_file "$dir/SKILL.md"
  mv -f "$variant" "$dir/SKILL.md"

  # The variant hardcodes mcp__forgetful__, which is the REGISTERED form. Reached
  # as a connector the same server's tools carry the connector prefix, and the
  # agents were just filled in with that form — so shipping the file unrewritten
  # would hand the model a call shape that does not resolve while the tools: line
  # beside it is correct. That is the same silent failure the tool-name prompt was
  # fixed to remove, one file further down; detection and prefix travel together.
  local prefix
  prefix=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["prefix"])' "$WORK/memory.json")
  if [[ -n "$prefix" && "$prefix" != "mcp__forgetful__" ]]; then
    py - "$dir/SKILL.md" "$prefix" <<'PY'
import io, sys
path, prefix = sys.argv[1], sys.argv[2]
text = io.open(path, encoding="utf-8").read()
io.open(path, "w", encoding="utf-8").write(text.replace("mcp__forgetful__", prefix))
PY
    ok "memory-schema: loaded the Forgetful variant, renamed to ${prefix}*"
  else
    ok "memory-schema: loaded the Forgetful variant as SKILL.md"
  fi
}

write_manifest() {
  py - "$MANIFEST" "$UNITS" "$SELECTED" "$WORK/merge.json" "$HERE" "$LIB" "$WORK/plan.tsv" \
         "$PH_SPEC" "$SERENA_PREFIX" "$WORK/tracker.json" "$WORK/adopt.txt" <<'PY'
import sys
sys.dont_write_bytecode = True   # don't leave a __pycache__ in the user's clone

import json, os, time, importlib.util

(manifest_path, units_path, sel_path, merge_path, repo, lib_path, plan_path,
 ph_path, serena_prefix, tracker_path, adopt_path) = sys.argv[1:12]

# reuse the library's hashing so the manifest and the planner agree exactly
spec = importlib.util.spec_from_file_location("pblib", lib_path)
pblib = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pblib)

units = json.load(open(units_path))
selected = [l.strip() for l in open(sel_path) if l.strip()]

manifest = {}
if os.path.exists(manifest_path):
    try:
        manifest = json.load(open(manifest_path))
    except ValueError:
        manifest = {}
manifest.setdefault("version", 1)
manifest.setdefault("units", {})
manifest.setdefault("json", [])
manifest["installed_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
manifest["repo"] = repo

# Remember the answers, so `update` can apply the SAME ones without asking. An
# update that quietly swapped your model id or your Serena prefix would be a
# different install wearing an upgrade's clothes.
config = manifest.get("config") or {}
if os.path.exists(ph_path):
    spec = json.load(open(ph_path))
    # This REPLACES config["placeholders"] wholesale on every run, so the contract
    # stamp has to be carried through here too. Absent in the spec means the answers
    # predate stamping, which is 0, not "current".
    config["placeholders"] = {"values": spec.get("values", {}),
                              "delete": spec.get("delete", []),
                              "contract": spec.get("contract", 0)}
    config["serena_prefix"] = serena_prefix
if os.path.exists(tracker_path):
    # Merge rather than replace: a run where the user pressed Enter past a field
    # records nothing for it, and must not erase the answer they gave last time.
    new = json.load(open(tracker_path))
    prior = (config.get("tracker") or {}).get("values", {})
    merged = dict(prior)
    merged.update(new.get("values", {}))
    config["tracker"] = {"adapter": new.get("adapter"), "values": merged}
if config:
    manifest["config"] = config

# The whole unit inventory this clone shipped at write time. `update` diffs the
# current inventory against this to answer the only question that matters after a
# git pull: WHAT IS NEW. Without it, "available but not installed" lists every unit
# you have ever declined, which is noise rather than a signal.
manifest["known"] = sorted(units)

# Units this run refused to touch. Re-hashing one of these would ADOPT the user's
# edit as our own recorded content, and the next remove would then delete their
# work as if we had written it. The old record (or no record) stands instead.
untouched = set()
if os.path.exists(plan_path):
    with open(plan_path) as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2 and parts[0].startswith("skip-"):
                untouched.add(parts[1])

# Decision 3: adoption is a CONSENTED path through that same guard, and the only
# one. The list is written by the confirm stage after the user says yes, and it can
# only ever contain skip-foreign units — a skip-edited file is still never adopted,
# because the user did not ask for that and we would be claiming their edit as ours.
adopted = set()
if os.path.exists(adopt_path):
    with open(adopt_path) as fh:
        adopted = {l.strip() for l in fh if l.strip()}
untouched -= adopted

for uid in selected:
    u = units.get(uid)
    if not u or uid in untouched:
        continue
    # The hash recorded is of the file AS INSTALLED — after the Serena rewrite and
    # the placeholder fill. Recording the template's hash would make every file we
    # just wrote look user-edited on the very next run.
    h = pblib.hash_path(u["dest"])
    if h is None:
        continue
    rec = {
        "kind": u["kind"], "dest": u["dest"],
        "hash": h, "source_hash": u["source_hash"],
    }
    # Sticky: once adopted, always adopted. This script did not write the file, so
    # remove must never delete it — not on this run and not on any later one.
    if uid in adopted or (manifest["units"].get(uid) or {}).get("adopted"):
        rec["adopted"] = True
    manifest["units"][uid] = rec

if os.path.exists(merge_path):
    rec = json.load(open(merge_path))
    # ACCUMULATE, never replace. A second run merges the same wiring, finds it
    # already present and so reports no additions — replacing the record with that
    # empty list would erase the memory of what run 1 added, and remove would then
    # leave our hook entries wired in settings.json forever.
    prior = []
    for entry in manifest["json"]:
        if entry.get("target") == rec["target"]:
            prior = entry.get("added", [])
    combined = list(prior)
    for path in rec["added"]:
        if path not in combined:
            combined.append(path)
    manifest["json"] = [j for j in manifest["json"] if j.get("target") != rec["target"]]
    manifest["json"].append({"target": rec["target"], "added": combined})

os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
with open(manifest_path, "w") as fh:
    json.dump(manifest, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
  ok "manifest written → $MANIFEST"
}

# ══════════════════════════════════════════════════════════════════════════
# The tracker fill — the ONE hardcoded block in this installer.
# ══════════════════════════════════════════════════════════════════════════
# Everything else is discovered by walking templates/. This list is not, and that
# is a deliberate, priced exception: it covers four adapters that change rarely,
# and the cost of it going stale is a MISSED PROMPT, not a broken install.
# Per-token prompting was rejected because the tracker files mix real config with
# tokens inside worked example payloads that are meant to survive.
# Edit HERE when an adapter gains a field.
tracker_fields() {
  case "$1" in
    github)
      printf '%s\n' \
        '<owner>|GitHub owner — the user or org that owns your repo' \
        '<repo>|Repository name'
      ;;
    jira)
      printf '%s\n' \
        '<MAP-KEY>|Jira key of the parent your maps hang under, e.g. ABC-1' \
        '<LABEL-PREFIX>|Label prefix this playbook may use, e.g. cc' \
        '<YOUR-DONE-STATUS>|The done status in your workflow, e.g. Done'
      ;;
    local-markdown)
      printf '%s\n' \
        '<workspace>|Absolute path to your workspace root'
      ;;
    gitlab-shape)
      # Ships as a shape, not an adapter: its commands are explicitly unverified
      # against a live instance, so there is nothing safe to prefill.
      ;;
  esac
}

# tracker_recorded TOKEN — the answer given for TOKEN on a previous run, if any.
tracker_recorded() {
  [[ -f "$MANIFEST" ]] || return 0
  py - "$MANIFEST" "$1" <<'PY'
import json, sys
try:
    m = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
print(((m.get("config") or {}).get("tracker") or {}).get("values", {}).get(sys.argv[2], ""))
PY
}

# tracker_apply TOKEN VALUE — substitute one token throughout tracker.md.
tracker_apply() {
  py - "$CLAUDE_HOME/tracker.md" "$1" "$2" <<'PY'
import sys
path, token, value = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as fh:
    text = fh.read()
with open(path, "w", encoding="utf-8") as fh:
    fh.write(text.replace(token, value))
PY
}

# tracker_replay — re-apply every recorded answer, without asking.
# An upgrade overwrites tracker.md with the fresh template, which puts the tokens
# back. Without this replay a non-interactive `update` would leave the adapter
# unfilled, and an unfilled tracker passes every gate here and fails at first use.
tracker_replay() {
  [[ -f "$CLAUDE_HOME/tracker.md" ]] || return 0
  [[ -f "$MANIFEST" ]] || return 0
  local n=0 line token value
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    token="${line%%|*}"; value="${line#*|}"
    grep -qF -- "$token" "$CLAUDE_HOME/tracker.md" || continue
    tracker_apply "$token" "$value"
    n=$((n + 1))
  done < <(py - "$MANIFEST" <<'PY'
import json, sys
try:
    m = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for k, v in (((m.get("config") or {}).get("tracker") or {}).get("values") or {}).items():
    print("%s|%s" % (k, v))
PY
)
  [[ "$n" -gt 0 ]] && ok "re-applied $n recorded tracker value(s)"
  return 0
}

tracker_stage() {
  local chosen fields line token prompt answer prior
  chosen=$(sed -n 's/^tracker://p' "$SELECTED" | head -1)

  # Always a stage, so the counter matches the total whether or not a tracker was
  # picked — and so "you have no tracker" is stated rather than silently skipped.
  stage "Setting up your tracker"
  if [[ -z "$chosen" || ! -f "$CLAUDE_HOME/tracker.md" ]]; then
    warn "no tracker selected"
    say "Nothing is set up to read your tickets, so the commands that start from a"
    say "ticket have nowhere to look. Everything else still works."
    TODO+=("Set up a tracker: re-run ./install.sh and pick one at item 5, or copy a file from templates/trackers/ to $CLAUDE_HOME/tracker.md and fill it in.")
    printf '\n'
    pause "Press Enter to continue"
    return 0
  fi
  printf '  %s%s%s\n\n' "$BOLD" "$chosen" "$RESET"
  fields=$(tracker_fields "$chosen")
  if [[ -z "$fields" ]]; then
    warn "$chosen is an outline, not a finished tracker."
    say "The published API docs for it are wrong about how blocking works, so none"
    say "of its commands have been verified against a real instance. Treat the file"
    say "as a starting point: fill it in against your own server and check each"
    say "command by hand before you rely on it."
    TODO+=("Write and verify the GitLab adapter commands in $CLAUDE_HOME/tracker.md.")
    printf '\n'; pause "Press Enter to continue"; return 0
  fi

  # The field list is fed on fd 3, not stdin. On stdin the `read answer` below
  # would consume the next field line instead of the human's reply, and every
  # second prompt would silently answer itself with the following token.
  : > "$WORK/tracker-values.txt"
  while IFS= read -r line <&3; do
    [[ -z "$line" ]] && continue
    token="${line%%|*}"; prompt="${line#*|}"
    grep -qF -- "$token" "$CLAUDE_HOME/tracker.md" || continue
    prior=$(tracker_recorded "$token")
    if [[ -n "$prior" ]]; then
      printf '  %s%s%s  %s[Enter keeps %s]%s ' "$BOLD" "$prompt" "$RESET" "$DIM" "$prior" "$RESET"
    else
      printf '  %s%s%s  %s[Enter skips this one]%s ' "$BOLD" "$prompt" "$RESET" "$DIM" "$RESET"
    fi
    _read answer
    [[ -z "$answer" ]] && answer="$prior"
    [[ -z "$answer" ]] && continue
    tracker_apply "$token" "$answer"
    printf '%s|%s\n' "$token" "$answer" >> "$WORK/tracker-values.txt"
    ok "$token → $answer"
  done 3<<< "$fields"

  # Persist the answers so a later upgrade can replay them onto a fresh template.
  py - "$WORK/tracker.json" "$chosen" "$WORK/tracker-values.txt" <<'PY'
import json, sys
values = {}
for line in open(sys.argv[3], encoding="utf-8"):
    line = line.rstrip("\n")
    if "|" in line:
        k, v = line.split("|", 1)
        values[k] = v
json.dump({"adapter": sys.argv[2], "values": values}, open(sys.argv[1], "w"), indent=2)
PY

  # The tracker's hash moved, so re-record it or the next run calls it user-edited.
  write_manifest
  printf '\n'
  pause "Press Enter to continue"
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 9 — verify
# ══════════════════════════════════════════════════════════════════════════
verify_stage() {
  stage "Checking it worked"

  # 1 — the acceptance grep from 03-setup.md step 8
  heading "1. Are all the blanks filled in?"
  local hits
  hits=$(grep -rnE '^(name|model|tools):.*<[a-z][a-z-]*>' \
           "$CLAUDE_HOME/agents" "$CLAUDE_HOME/skills" 2>/dev/null || true)
  if [[ -z "$hits" ]]; then
    ok "yes — nothing left unfilled in any name:, model: or tools: line"
  else
    bad "no — these blanks were not filled in:"
    printf '%s\n' "$hits" | sed 's/^/        /'
    say "      Each one has to be filled in or deleted before the file works."
    TODO+=("Fill in or delete the blanks listed under 'Are all the blanks filled in?' above, or re-run ./install.sh, which asks for it.")
  fi

  # 1b — the other half of the same question. Check 1 above greps for blanks that
  #      are STILL THERE, and a DELETED token is not a remaining token: it printed
  #      "nothing left unfilled" over an install where the whole pipeline had lost
  #      memory access. "Nothing is unfilled" and "the tools are there" are two
  #      different claims and only the first was ever checked.
  if [[ -d "$CLAUDE_HOME/agents" ]]; then
    heading "1b. Did the tools actually make it into the agents?"
    # A deleted token is not always a LOST one. Two of the tracker routes have
    # nothing to fill <tracker-read-tools> in with — the github adapter drives `gh`
    # and registers no server, local-markdown reads files off the disk — so counting
    # the delete as a loss painted a correct install red. A check that is red when
    # nothing is wrong teaches the reader to ignore it, which is #105's silent
    # failure inverted. The chosen adapter and the registered server are what tell
    # the two apart, so both are passed in.
    local trk_adapter trk_mcp
    trk_adapter=$(sed -n 's/^tracker://p' "$SELECTED" | head -1)
    pb tracker-detect "$HOME" "$PWD" > "$WORK/tracker-mcp-verify.json"
    trk_mcp=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["server"] or "")' \
              "$WORK/tracker-mcp-verify.json")
    pb audit-grants "$PH_SPEC" "$TEMPLATES/agents" "$CLAUDE_HOME/agents" \
       "$trk_adapter" "$trk_mcp" > "$WORK/grants.json"
    py - "$WORK/grants.json" "$CLAUDE_HOME/agents" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
rows = d["agents"]
if not rows:
    print("      yes — every installed agent carries the tools its template declared")
else:
    for kind in ("memory", "tracker", "serena"):
        names = d["missing"].get(kind) or []
        if names:
            print("      NO %-8s tools in %d agent(s): %s" % (kind, len(names), ", ".join(names)))
    # Which FILE lost WHICH tools. These rows were computed on every run and then
    # thrown away: the summary above names a capability and a count, and leaves you
    # to work out which file to open.
    print("")
    # Joined by hand, not with os.path.join: on Windows that returns a backslash
    # and the directory arrives with forward slashes, so the path printed back to
    # the user came out mixed. Every other path this installer prints is /-joined.
    base = sys.argv[2].rstrip("/\\")
    for row in rows:
        print("      %s/%s.md — lost: %s"
              % (base, row["agent"], ", ".join(row["missing"])))
PY
    if py -c 'import json,sys;sys.exit(0 if json.load(open(sys.argv[1]))["agents"] else 1)' "$WORK/grants.json"; then
      bad "some agents are installed without a capability their template declared"
      # Same finding, different cause, so different advice. On an update nobody was
      # asked anything: the missing grant was REPLAYED from the answers recorded at
      # install time, and saying "re-run and answer those prompts" without saying so
      # reads as if the user had just chosen it.
      if [[ "$MODE" == "update" || "$MODE" == "upgrade" ]]; then
        TODO+=("Some agents were installed with no memory, tracker or Serena tools — the files are named under 'Did the tools actually make it into the agents?' above. This update did not choose that: it replayed the answers recorded when you first installed. Run ./install.sh to answer those questions again.")
      else
        TODO+=("Some agents were installed with no memory, tracker or Serena tools — see 'Did the tools actually make it into the agents?' above. They will not complain; they will run and do that part badly. Re-run ./install.sh to answer those prompts again.")
      fi
    else
      ok "yes — nothing was silently dropped"
    fi
  else
    note "  no agents directory to check"
  fi

  # 2 — wiring. Installing a hook is NOT wiring a hook, so this re-reads
  #     settings.json rather than trusting that the merge did what it said.
  local hooks_installed
  hooks_installed=$(sed -n 's/^hook://p' "$SELECTED" | tr '\n' ' ')
  if [[ -n "${hooks_installed// /}" ]]; then
    heading "2. Are the guardrails switched on? (read back from settings.json)"
    # shellcheck disable=SC2086
    pb verify-wiring "$SETTINGS" $hooks_installed > "$WORK/wiring-check.json"
    py - "$WORK/wiring-check.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for h in d.get("wired", []):
    print("      wired    %s" % h)
for h in d.get("unwired", []):
    print("      UNWIRED  %s" % h)
if d.get("error"):
    print("      %s" % d["error"])
PY
    TODO+=("Check each guardrail really fires: in a throwaway repo, ask Claude to do something it should refuse. (test-hooks.sh cannot tell you this - it runs the scripts directly and never reads settings.json.)")
  fi

  # 3 — the tracker. The step-8 grep reads only agents/ and skills/, so an
  #     unfilled tracker passes every other gate here and fails at first use.
  if [[ -f "$CLAUDE_HOME/tracker.md" ]]; then
    heading "3. Is the tracker filled in?"
    local left
    left=$(grep -oE '<(owner|repo|MAP-KEY|LABEL-PREFIX|YOUR-DONE-STATUS|workspace)>' \
             "$CLAUDE_HOME/tracker.md" 2>/dev/null | sort -u | tr '\n' ' ' || true)
    if [[ -n "${left// /}" ]]; then
      bad "no — still to fill in: $left"
      TODO+=("Fill in ${left% } in $CLAUDE_HOME/tracker.md.")
    else
      ok "yes — the settings it asks for are all filled in"
    fi
    TODO+=("Answer 'Is this a shared place?' in $CLAUDE_HOME/tracker.md. It decides whether Claude needs your approval before writing to the tracker.")
    TODO+=("Add a line to your global CLAUDE.md pointing at $CLAUDE_HOME/tracker.md, so it is loaded in every session.")
  fi

  # 4 — the two CLAUDE.md layers this installer deliberately does not place
  heading "4. Two files you copy into your own projects, by hand"
  note "  templates/claude-md/repo.CLAUDE.md      → <your repo>/CLAUDE.md"
  note "  templates/claude-md/workspace.CLAUDE.md → <your workspace>/CLAUDE.md"
  note "                                            (only if you keep sibling repos)"
  note "  The installer cannot know which project you mean, so it will not guess."
  printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════
# update — the "I added a feature to the playbook" path
# ══════════════════════════════════════════════════════════════════════════
# Non-interactive on purpose. It upgrades what you already have to the current
# templates and pulls in anything newly REQUIRED by it. It does not install new
# optional units: a new skill nobody depends on is a choice, not an upgrade, so
# it is reported and left for you to tick in the interactive run.
load_recorded_config() {
  [[ -f "$MANIFEST" ]] || return 1
  py - "$MANIFEST" "$PH_SPEC" <<'PY'
import json, sys
try:
    m = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
cfg = m.get("config") or {}
ph = cfg.get("placeholders")
if not ph:
    sys.exit(1)
# Carry the contract stamp through with the answers. Without it, this run's own
# write_manifest re-records contract 0 from the replayed spec and DOWNGRADES the
# stamp. That does not SILENCE the stop — a stopped run dies before write_manifest
# and writes nothing at all. It arms a FALSE one: an answer the user has since
# given deliberately, under today's rules, gets re-tested against an older bump's
# suspect list and stops an update that should have run. And it cannot be cleared,
# because the refusal writes nothing and the next successful update downgrades the
# stamp again.
json.dump({"paths": [], "values": ph.get("values", {}), "delete": ph.get("delete", []),
           "contract": ph.get("contract", 0)},
          open(sys.argv[2], "w"), indent=2)
print(cfg.get("serena_prefix") or "")
PY
}

# backfill_tracker_shell — answer a token that did not exist when these answers
# were recorded.
#
# `update` replays what was recorded, and an install predating <tracker-shell-tools>
# recorded neither a value nor a delete for it. The upgrade rewrites
# @ticket-analyzer from the current template, which puts the token back, and a token
# with no recorded answer survives apply-placeholders and lands in the installed
# file as a literal blank — the silent-strip failure the grant audit exists to
# remove.
#
# It is not asked, because it was never a question: it follows from the adapter,
# which the manifest already records. Same table and same rule as a fresh install.
backfill_tracker_shell() {
  local adapter shell
  # The adapter comes from $SELECTED, NOT from config.tracker.adapter in the
  # manifest, and the difference is not cosmetic. tracker_stage returns early for
  # any adapter with no fields to ask about — gitlab-shape is one — so it never
  # writes tracker.json, and write_manifest's os.path.exists guard then leaves
  # config.tracker unset. Reading it there yields "", which routes to
  # TRACKER_ROUTE_UNKNOWN, whose shell is "" — so the backfill would DELETE the
  # shell grant on an adapter whose route says Bash, and only ever adds, so the
  # wrong answer would stick forever. $SELECTED is seeded from the manifest's unit
  # ids by seed_from_manifest, which runs above this, and is what the other three
  # call sites read.
  adapter=$(sed -n 's/^tracker://p' "$SELECTED" | head -1)
  pb tracker-route "$adapter" > "$WORK/tracker-route.json"
  shell=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["shell"])' \
          "$WORK/tracker-route.json")
  py - "$PH_SPEC" "$shell" <<'PY'
import json, sys
path, val = sys.argv[1], sys.argv[2].strip()
try:
    spec = json.load(open(path))
except Exception:
    sys.exit(0)
tok = "<tracker-shell-tools>"
# Only ever ADDS a missing answer. A recorded one is the user's, whichever way it
# went, and overwriting it here would be the replay-what-was-never-decided bug.
if tok in (spec.get("values") or {}) or tok in (spec.get("delete") or []):
    sys.exit(0)
if val:
    spec.setdefault("values", {})[tok] = val
else:
    spec.setdefault("delete", []).append(tok)
json.dump(spec, open(path, "w"), indent=2)
PY
}


# contract_gate — refuse to replay an answer whose MEANING has since changed.
#
# `update` replays the recorded answers without asking, and that is correct for
# exactly as long as those answers still mean what they meant when they were
# given. When a contract bump has invalidated one, there is no safe thing to
# replay: filling the token in needs an answer only the user can give, and
# leaving it blank writes a broken `tools:` line, which is worse than the delete
# it would replace. So this stops — it does not warn and carry on — and it stops
# BEFORE anything is written, so a refused update changes nothing at all.
#
# The gate is "a recorded delete that a bump invalidated", never "the recorded
# number is lower". See CONTRACT_SUSPECT in install-lib.py for why: a blanket
# compare would condemn every pre-#105 install including the ones whose
# <tracker-read-tools> delete was right, and that stop could never be cleared.
contract_gate() {
  local report="$WORK/contract.json"
  pb contract-check "$MANIFEST" > "$report" 2>/dev/null || return 0
  py -c 'import json,sys
sys.exit(0 if json.load(open(sys.argv[1]))["stale"] else 1)' "$report" || return 0

  # To stderr, alongside die's own line, so the whole explanation arrives together
  # and survives however the run was invoked.
  {
    printf '\n  %sSome of your recorded answers are no longer valid.%s\n\n' "$BOLD" "$RESET"
    py - "$report" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for tok in d["stale"]:
    print("      your recorded answer for %s was given under older rules" % tok)
    print("      it was recorded as: %s — the token was taken out of your files"
          % d["answers"][tok])
    print("")
why = d.get("why") or []
if why:
    for line in why:
        print("      %s" % line)
    print("")
print("      This update will not replay that answer onto your files, and it has")
print("      written nothing.")
print("")
print("      Run ./install.sh — it asks the question again.")
print("")
print("      That one needs a terminal. This update normally runs fine unattended;")
print("      ./install.sh never can — it refuses to start where there is nobody to")
print("      answer it. So if this run came from a script, an ssh command or a CI")
print("      job, clear this from a real shell rather than from there.")
PY
  } >&2
  die "update stopped — nothing was written."
}

update_mode() {
  TOTAL_STAGES=4
  preflight
  [[ -f "$MANIFEST" ]] || die "no manifest at $MANIFEST — run ./install.sh first."

  discover_units_quiet

  # The same two hard gates as the install path, and for the same reason:
  # refreshing agents that will halt on dispatch is not an upgrade, and neither is
  # refreshing agents that will run and quietly remember nothing. Both run here,
  # before anything is written, and both exit without routing through a
  # screen-clearing helper so their instructions survive the exit.
  serena_gate
  memory_gate

  seed_from_manifest || die "the manifest records no units — run ./install.sh instead."
  local had
  had=$(wc -l < "$SELECTED" | tr -d ' ')

  # Reuse the answers from the original install. An update that silently changed
  # your model id or Serena prefix is a reinstall, not an update.
  local prefix
  if prefix=$(load_recorded_config); then
    SERENA_PREFIX="$prefix"
    # Before reusing them, check they are still answers to the questions that were
    # actually asked. This is a hard stop and it must stay ABOVE `stage "Update"`
    # and install_stage_body: a refused update writes nothing.
    contract_gate
    backfill_tracker_shell
    ok "reusing the recorded placeholder values and Serena prefix"
  else
    # The legacy path asks one question, and that question is a whole extra stage.
    warn "this install predates recorded config — asking once"
    TOTAL_STAGES=5
    placeholder_stage
  fi

  stage "Update"

  # Snapshot the PREVIOUS inventory before install_stage_body -> write_manifest
  # overwrites it. Reading manifest["known"] after the write would compare this
  # clone against itself and always report "nothing new".
  py - "$MANIFEST" "$WORK/known-before.json" <<'PY'
import json, sys
try:
    known = json.load(open(sys.argv[1])).get("known") or []
except Exception:
    known = []
json.dump(known, open(sys.argv[2], "w"))
PY

  install_stage_body
  tracker_replay
  write_manifest

  # The signal after a git pull: what is NEW in this clone, as opposed to
  # everything you have ever declined. Those are different questions, and only the
  # first one is news.
  heading "New in this clone since your last run"
  py - "$UNITS" "$SELECTED" "$WORK/known-before.json" <<'PY'
import json, sys
units = json.load(open(sys.argv[1]))
have = {l.strip() for l in open(sys.argv[2]) if l.strip()}
try:
    known_before = set(json.load(open(sys.argv[3])))
except Exception:
    known_before = set()

brand_new = sorted(u for u in units if u not in known_before)
if not known_before:
    print("      (this install predates inventory tracking — nothing to compare yet)")
elif not brand_new:
    print("      nothing new")
else:
    for u in brand_new:
        print("      %-34s %s" % (u, "installed" if u in have else "not installed"))
    if any(u not in have for u in brand_new):
        print("")
        print("      Run ./install.sh to tick on the ones you want.")

declined = sorted(u for u in units
                  if u not in have and u in known_before and not u.startswith("tracker:"))
if declined:
    print("")
    print("      %d other unit(s) available and not installed — ./install.sh list shows them."
          % len(declined))
PY
  printf '\n'

  verify_stage
  install_finish "Update complete"
  note "was: $had units"
  exit 0
}

# discover_units_quiet — same discovery, no explanatory screen or pause.
discover_units_quiet() {
  stage "Reading this clone"
  pb discover "$TEMPLATES" "$CLAUDE_HOME" > "$UNITS" || die "discovery failed"
  pb units-tsv "$UNITS" > "$TSV"
  ok "$(wc -l < "$TSV" | tr -d ' ') things this clone can install"
  printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════
# remove
# ══════════════════════════════════════════════════════════════════════════
remove_mode() {
  preflight

  stage "What removing would do"
  [[ -f "$MANIFEST" ]] || die "no manifest at $MANIFEST — this script has not installed anything."

  pb plan-remove "$MANIFEST" > "$WORK/rplan.tsv"
  local action uid kind dest n_rm=0 n_keep=0 n_adopt=0
  while IFS=$'\t' read -r action uid kind dest; do
    [[ -z "$action" ]] && continue
    case "$action" in
      remove)       printf '   %sremove%s  %s\n' "$RED" "$RESET" "$uid"; n_rm=$((n_rm + 1)) ;;
      keep-edited)  printf '   %skeep%s    %s  %s(you changed it)%s\n' "$GREEN" "$RESET" "$uid" "$DIM" "$RESET"; n_keep=$((n_keep + 1)) ;;
      keep-adopted) printf '   %skeep%s    %s  %s(adopted — this script never wrote it)%s\n' "$GREEN" "$RESET" "$uid" "$DIM" "$RESET"; n_adopt=$((n_adopt + 1)) ;;
    esac
  done < "$WORK/rplan.tsv"
  printf '\n'
  note "$n_rm will be deleted · $n_keep kept, because you edited them yourself"
  [[ "$n_adopt" -gt 0 ]] && note "$n_adopt kept because they were adopted, not installed by this script"
  note "Settings this installer added are taken back out; anything you added"
  note "yourself stays exactly where it is."
  note "Your backups in $BACKUPS are NOT deleted — this is when they matter most."
  printf '\n'
  confirm "Delete the files marked 'remove' above?" || { printf '\n  Nothing changed.\n\n'; exit 0; }

  stage "Removing"
  while IFS=$'\t' read -r action uid kind dest; do
    case "$action" in
      remove)       rm -rf "$dest"; REMOVED+=("$uid") ;;
      keep-edited)  LEFT_ALONE+=("$uid — kept, you changed it since install") ;;
      keep-adopted) LEFT_ALONE+=("$uid — kept, adopted rather than installed; this script never wrote it") ;;
    esac
  done < "$WORK/rplan.tsv"

  # revert exactly the JSON additions we recorded, and nothing else
  py - "$MANIFEST" "$WORK" <<'PY'
import json, os, sys
manifest = json.load(open(sys.argv[1]))
for i, rec in enumerate(manifest.get("json", [])):
    with open(os.path.join(sys.argv[2], "unmerge-%d.json" % i), "w") as fh:
        json.dump(rec, fh)
PY
  local i=0 target
  while [[ -f "$WORK/unmerge-$i.json" ]]; do
    target=$(py -c 'import json,sys;print(json.load(open(sys.argv[1]))["target"])' "$WORK/unmerge-$i.json")
    backup_file "$target"
    pb unmerge-json "$target" "$WORK/unmerge-$i.json" > /dev/null
    ok "reverted our additions in $target"
    i=$((i + 1))
  done

  # tidy up directories we created and then emptied — never one with anything left
  local d
  for d in agents skills commands hooks; do
    # rmdir only ever removes an EMPTY directory, so a dir the user still has
    # things in survives by refusing — the `|| true` is about not failing the
    # run, not about ignoring a real error.
    if [[ -d "$CLAUDE_HOME/$d" ]]; then rmdir "$CLAUDE_HOME/$d" 2>/dev/null || true; fi
  done

  rm -f "$MANIFEST"
  ok "manifest removed"
  TODO+=("Backups of every shared file this script touched are under $BACKUPS.")
  install_finish "Removed"
  exit 0
}

# ══════════════════════════════════════════════════════════════════════════
# list
# ══════════════════════════════════════════════════════════════════════════
list_mode() {
  preflight
  discover_units_quiet
  stage "What you have installed"
  if [[ -f "$MANIFEST" ]]; then
    local state uid kind n_out=0 n_new=0
    while IFS=$'\t' read -r state uid kind; do
      case "$state" in
        current)   printf '   %s%-10s%s %s\n' "$GREEN" "current"  "$RESET" "$uid" ;;
        outdated)  printf '   %s%-10s%s %s\n' "$YELLOW" "outdated" "$RESET" "$uid"; n_out=$((n_out + 1)) ;;
        edited)    printf '   %s%-10s%s %s\n' "$BOLD" "edited"   "$RESET" "$uid" ;;
        missing)   printf '   %-10s %s\n' "missing"   "$uid" ;;
        orphaned)  printf '   %s%-10s%s %s\n' "$YELLOW" "orphaned" "$RESET" "$uid" ;;
        available) printf '   %s%-10s%s %s\n' "$DIM" "available" "$RESET" "$uid"; n_new=$((n_new + 1)) ;;
      esac
    done < <(pb plan-state "$MANIFEST" "$UNITS")
    printf '\n'
    note "current   = you have the same version this clone ships"
    note "outdated  = this clone has a newer version than the one you installed"
    note "edited    = you changed it yourself; update and remove both leave it be"
    note "missing   = installed once, but the file is gone from disk now"
    note "orphaned  = you installed it, but this clone no longer ships it (renamed or removed)"
    note "available = this clone ships it and you have not installed it"
    printf '\n'
    [[ "$n_out" -gt 0 ]] && say "$n_out would be brought up to date by:  ./install.sh update"
    [[ "$n_new" -gt 0 ]] && say "$n_new more could be added by:            ./install.sh"
  else
    note "nothing installed by this script yet (there is no $MANIFEST)"
  fi
  printf '\n'
  exit 0
}

# ══════════════════════════════════════════════════════════════════════════
# closing summary
# ══════════════════════════════════════════════════════════════════════════
# The library's finish() summarises .env values and CI secrets, neither of which
# this installer writes. Same shape, reporting what it actually did.
_summarise() {
  local title="$1"; shift
  [[ $# -eq 0 ]] && return 0
  printf '  %s%s (%s):%s\n' "$BOLD" "$title" "$#" "$RESET"
  local x
  for x in "$@"; do printf '    %s\n' "$x"; done
  printf '\n'
}

install_finish() {
  _clear
  printf '\n%s%s  ✓ %s%s\n\n' "$BOLD" "$GREEN" "${1:-Install complete}" "$RESET"

  _summarise "installed"                   ${INSTALLED[@]+"${INSTALLED[@]}"}
  _summarise "upgraded"                    ${UPGRADED[@]+"${UPGRADED[@]}"}
  _summarise "adopted"                     ${ADOPTED[@]+"${ADOPTED[@]}"}
  _summarise "removed"                     ${REMOVED[@]+"${REMOVED[@]}"}
  _summarise "left alone"                  ${LEFT_ALONE[@]+"${LEFT_ALONE[@]}"}
  _summarise "conflicts — your value kept" ${CONFLICTS[@]+"${CONFLICTS[@]}"}

  if [[ ${#TODO[@]} -gt 0 ]]; then
    printf '  %s%sStill to do, by hand:%s\n' "$BOLD" "$YELLOW" "$RESET"
    local t
    for t in "${TODO[@]}"; do printf '    %s-%s %s\n' "$YELLOW" "$RESET" "$t"; done
    printf '\n'
  fi

  note "docs/shared/03-setup.md walks through these same steps by hand, in full."
  note "./install.sh list    see what you have now"
  note "./install.sh update  bring it up to date with this clone"
  note "./install.sh remove  take it all back out again"
  printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════
# main
# ══════════════════════════════════════════════════════════════════════════
case "$MODE" in
  remove|uninstall)
    require_tty
    TOTAL_STAGES=3
    banner_pb "claude-code-playbook · remove" pause
    remove_mode
    ;;
  update|upgrade)
    TOTAL_STAGES=4
    banner_pb "claude-code-playbook · update"
    update_mode
    ;;
  list|status)
    # preflight · discover · current state
    TOTAL_STAGES=3
    banner_pb "claude-code-playbook · state"
    list_mode
    ;;
  install|"")
    require_tty
    banner_pb "claude-code-playbook · install" pause
    preflight
    discover_units
    selection_stage
    serena_stage
    placeholder_stage
    confirm_stage
    install_stage
    tracker_stage
    verify_stage
    install_finish "Install complete"
    ;;
  *)
    die "unknown mode: $MODE (expected install, update, remove or list)"
    ;;
esac
