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
pause() {
  printf '  %s%s%s ' "$DIM" "${1:-Press Enter to continue}" "$RESET"
  read -r _ || true
}

# confirm "question" — y/N gate; returns success on yes.
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

TOTAL_STAGES=8

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
LEFT_ALONE=()
CONFLICTS=()
TODO=()

pb() { "$PY" "$LIB" "$@"; }

# screen "Title" — a sub-screen WITHIN a stage. Clears and titles like stage(),
# but does not advance the counter: stages are milestones, and paging around the
# selection lists is navigation. Without this the header climbs past the total.
screen() {
  _clear
  printf '\n%s%s▸ Stage %s/%s · %s%s\n' \
    "$BOLD" "$BLUE" "$_STAGE_INDEX" "$TOTAL_STAGES" "$1" "$RESET"
}

heading() { printf '\n  %s%s%s\n' "$BOLD" "$1" "$RESET"; }
ok()      { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
bad()     { printf '  %s✗%s %s\n' "$RED" "$RESET" "$1"; }
die()     { printf '\n  %s✗ %s%s\n\n' "$RED" "$1" "$RESET" >&2; exit 1; }

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
  "$PY" - "$SELECTED" <<'PY'
import json, sys
print(json.dumps([l.strip() for l in open(sys.argv[1]) if l.strip()]))
PY
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 1 — preflight
# ══════════════════════════════════════════════════════════════════════════
preflight() {
  stage "Preflight"

  for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1 &&
       "$cand" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 7) else 1)' 2>/dev/null; then
      PY="$cand"; break
    fi
  done
  [[ -n "$PY" ]] || die "python3 (3.7+) is required — install-lib.py needs it, and so do six of the seven hooks, which parse their payload with it."

  [[ -f "$LIB" ]]       || die "install-lib.py not found beside this script. Run it from the clone."
  [[ -d "$TEMPLATES" ]] || die "templates/ not found beside this script. Run it from the clone."

  ok "$("$PY" --version 2>&1)"
  ok "templates  $TEMPLATES"
  ok "target     $CLAUDE_HOME"
  printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 2 — discovery
# ══════════════════════════════════════════════════════════════════════════
discover_units() {
  stage "Discover what is installable"
  pb discover "$TEMPLATES" "$CLAUDE_HOME" > "$UNITS" || die "discovery failed"
  pb units-tsv "$UNITS" > "$TSV"

  heading "Found by walking templates/ — nothing below is a hardcoded list:"
  awk -F'\t' '{c[$1]++} END {for (k in c) printf "    %-11s %d\n", k, c[k]}' "$TSV" | sort

  printf '\n'
  note "  never installed here, deliberately:"
  note "    layer-specialist · slice-layer-specialist · engineering-standards"
  note "  /adapt-to-stack generates those per layer, per repo, into that repo's own"
  note "  .claude/. A <layer> left in name: registers an agent that cannot be"
  note "  dispatched, so they must not land in $CLAUDE_HOME."
  printf '\n'
  pause "Continue?"
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
  for id in command:fix-ticket command:test-ticket command:end-of-day command:garden-memory \
            skill:tdd skill:diagnose skill:commit-conventions skill:research skill:handoff; do
    exists "$id" && sel_add "$id"
  done
}

preset_everything() {
  : > "$SELECTED"
  local id
  # every kind except tracker — that one is exclusive and picked explicitly
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
    note "numbers toggle (space-separated) · a=all · n=none · Enter=back"
    printf '  %s>%s ' "$BOLD" "$RESET"
    read -r choice || true
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
    screen "Choose · tracker adapter"
    note "Exactly one, installed at $CLAUDE_HOME/tracker.md."
    note "Flows state their intent in abstract verbs; one adapter answers them."
    printf '\n'
    ids=$(ids_of tracker)
    i=0
    for id in $ids; do
      i=$((i + 1))
      mark=" "; sel_has "$id" && mark="•"
      printf '   %2d (%s) %s\n' "$i" "$mark" "${id#*:}"
    done
    printf '\n'
    note "one number selects · 0=none · Enter=back"
    printf '  %s>%s ' "$BOLD" "$RESET"
    read -r choice || true
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

# seed_from_manifest — pre-tick exactly what is already installed.
# Returns 1 when there is no manifest to seed from (a fresh machine).
seed_from_manifest() {
  [[ -f "$MANIFEST" ]] || return 1
  "$PY" - "$MANIFEST" <<'PY' > "$SELECTED"
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
    note "Pre-ticked from your existing install ($(wc -l < "$SELECTED" | tr -d ' ') units)."
    note "Untick to remove on the next run; tick to add. ./install.sh update skips this screen."
    pause "Continue?"
  fi
  while :; do
    pb resolve-deps "$UNITS" "$(sel_json)" > "$WORK/resolved.json"
    total=$("$PY" -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["selected"]))' "$WORK/resolved.json")
    extra=$("$PY" -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["pulled_in"]))' "$WORK/resolved.json")
    chosen_tracker=$(sed -n 's/^tracker://p' "$SELECTED" | tr '\n' ' ')
    [[ -z "${chosen_tracker// /}" ]] && chosen_tracker="none"

    screen "What to install"
    printf '   1  commands ......... %s of %s\n' "$(sel_count command)" "$(count_of command)"
    printf '   2  skills ........... %s of %s\n' "$(sel_count skill)"   "$(count_of skill)"
    printf '   3  agents ........... %s of %s   %s(normally left to dependencies)%s\n' \
           "$(sel_count agent)" "$(count_of agent)" "$DIM" "$RESET"
    printf '   4  hooks ............ %s of %s\n' "$(sel_count hook)"    "$(count_of hook)"
    printf '   5  tracker .......... %s\n' "$chosen_tracker"
    printf '   6  views ............ %s of %s\n' "$(sel_count view)"    "$(count_of view)"
    printf '   7  global CLAUDE.md . %s\n' "$(sel_yn claude-md:global)"
    printf '\n'
    printf '   %s%s units once dependencies are pulled in (+%s of them)%s\n' "$DIM" "$total" "$extra" "$RESET"
    printf '\n'
    note "1-7 opens a list · m=minimal · r=recommended · e=everything"
    note "v=review what gets pulled in · i=install · q=quit"
    printf '  %s>%s ' "$BOLD" "$RESET"
    read -r choice || true
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
      i) if [[ "$total" -gt 0 ]]; then return 0; else warn "nothing selected"; pause; fi ;;
      q) printf '\n'; exit 0 ;;
    esac
  done
}

# Decision 5: dependencies are auto-ticked, but VISIBLY.
review_screen() {
  screen "Review · what your selection pulls in"
  pb resolve-deps "$UNITS" "$(sel_json)" > "$WORK/resolved.json"
  "$PY" - "$WORK/resolved.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
pulled = set(d["pulled_in"])
print("\n  you picked:")
for u in sorted(set(d["selected"]) - pulled):
    print("    " + u)
if pulled:
    print("\n  pulled in for you:")
    for u in sorted(pulled):
        print("    " + u)
else:
    print("\n  nothing extra was needed.")
PY
  printf '\n'
  note "A command without its agents fails on first dispatch, so these are added"
  note "rather than refused. Untick one in its own list if you disagree."
  printf '\n'
  pause "Back"
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 4 — Serena route
# ══════════════════════════════════════════════════════════════════════════
SERENA_PREFIX=""
serena_stage() {
  stage "Serena — which tool prefix"
  pb serena-detect "$HOME" "$PWD" > "$WORK/serena.json"

  heading "Evidence on this machine:"
  "$PY" - "$WORK/serena.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if not d["evidence"]:
    print("      none — no Serena registration or plugin files found")
for e in d["evidence"]:
    print("      %-22s ← %s" % (e["found"], e["where"]))
PY
  printf '\n'
  say "A wrong prefix fails SILENTLY: an unresolvable name in a tools: list is"
  say "stripped at launch and the agent quietly reads whole files instead."
  printf '\n'
  note "  A  plugin route       mcp__plugin_serena_serena__"
  note "  B  .mcp.json route    mcp__serena__   (what the templates ship with)"
  printf '\n'

  local suggest ans
  suggest=$("$PY" -c 'import json,sys;print(json.load(open(sys.argv[1]))["route"] or "B")' "$WORK/serena.json")
  printf '  %sRoute [A/B, Enter = %s]%s ' "$BOLD" "$suggest" "$RESET"
  read -r ans || true
  [[ -z "$ans" ]] && ans="$suggest"
  case "$ans" in
    a|A) SERENA_PREFIX="mcp__plugin_serena_serena__"; ok "will rewrite to the plugin prefix" ;;
    *)   SERENA_PREFIX="";                            ok "leaving mcp__serena__ as shipped" ;;
  esac
  TODO+=("Confirm the real Serena tool names with /mcp, and check a dispatched agent actually got them.")
  printf '\n'
  pause "Continue?"
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 5 — placeholders
# ══════════════════════════════════════════════════════════════════════════
# Asked once per distinct token, then applied across every file installed.
PH_SPEC="$WORK/placeholders.json"

# server_registered NAME — is there an mcpServers.NAME in ~/.claude.json?
server_registered() {
  "$PY" - "$HOME/.claude.json" "$1" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        raw = fh.read().strip()
    data = json.loads(raw) if raw else {}
    print("yes" if sys.argv[2] in (data.get("mcpServers") or {}) else "no")
except Exception:
    print("no")
PY
}

placeholder_stage() {
  stage "Fill the placeholders"
  say "These sit in name:, model: and tools: — the three keys the harness resolves."
  say "One left unfilled is stripped in silence, or dies on first dispatch."
  printf '\n'

  local strong fast mem_read="" mem_write="" trk_read=""
  printf '  %sStrong model id — planning, review  [Enter = claude-opus-5]%s ' "$BOLD" "$RESET"
  read -r strong || true; [[ -z "$strong" ]] && strong="claude-opus-5"
  printf '  %sFast model id — cheap lookups       [Enter = claude-haiku-4-5-20251001]%s ' "$BOLD" "$RESET"
  read -r fast || true; [[ -z "$fast" ]] && fast="claude-haiku-4-5-20251001"
  printf '\n'

  # The MCP tool tokens: fill only when the server is actually registered,
  # otherwise DELETE. Deleting is the documented right move for a server you do
  # not run — a token left in a tools: list is stripped at launch, silently.
  if [[ "$(server_registered forgetful)" == "yes" ]]; then
    ok "found mcpServers.forgetful in ~/.claude.json"
    printf '  %sMemory READ tool names, comma-separated  [Enter deletes the token]%s ' "$BOLD" "$RESET"
    read -r mem_read || true
    printf '  %sMemory WRITE tool names, comma-separated [Enter deletes the token]%s ' "$BOLD" "$RESET"
    read -r mem_write || true
  else
    note "no mcpServers.forgetful — deleting <memory-read-tools> and <memory-write-tools>"
  fi
  if [[ "$(server_registered tracker)" == "yes" ]]; then
    ok "found mcpServers.tracker in ~/.claude.json"
    printf '  %sTracker READ tool names, comma-separated [Enter deletes the token]%s ' "$BOLD" "$RESET"
    read -r trk_read || true
  else
    note "no mcpServers.tracker — deleting <tracker-read-tools>"
  fi

  "$PY" - "$PH_SPEC" "$strong" "$fast" "$mem_read" "$mem_write" "$trk_read" <<'PY'
import json, sys
out = sys.argv[1]
values = {"<strong-model-id>": sys.argv[2], "<fast-model-id>": sys.argv[3]}
delete = []
for tok, val in (("<memory-read-tools>",  sys.argv[4]),
                 ("<memory-write-tools>", sys.argv[5]),
                 ("<tracker-read-tools>", sys.argv[6])):
    if val.strip():
        values[tok] = val.strip()
    else:
        delete.append(tok)
json.dump({"paths": [], "values": values, "delete": delete}, open(out, "w"), indent=2)
PY
  printf '\n'
  pause "Continue?"
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 6 — install
# ══════════════════════════════════════════════════════════════════════════
backup_file() {
  [[ -e "$1" ]] || return 0
  mkdir -p "$BACKUPS"
  local dest="$BACKUPS/$(basename "$1").$(date +%Y%m%d-%H%M%S)"
  cp -R "$1" "$dest" 2>/dev/null || return 0
  note "backed up $(basename "$1") → $dest"
}

install_stage() {
  stage "Install"
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
  "$PY" -c 'import json,sys
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
        ;;
      skip-foreign)
        LEFT_ALONE+=("$uid — present but not installed by this script; left untouched")
        ;;
    esac
  done < "$WORK/plan.tsv"

  ok "$(wc -l < "$WORK/written.txt" | tr -d ' ') file(s)/dir(s) written"

  # ── Serena prefix, then placeholders, across what we just wrote ────────
  "$PY" -c 'import json,sys
json.dump([l.strip() for l in open(sys.argv[1]) if l.strip()], open(sys.argv[2],"w"))' \
    "$WORK/written.txt" "$WORK/paths.json"

  if [[ -n "$SERENA_PREFIX" ]]; then
    pb serena-rewrite "$WORK/paths.json" "$SERENA_PREFIX" > "$WORK/serena-rw.json"
    ok "rewrote the Serena prefix in $("$PY" -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["changed"]))' "$WORK/serena-rw.json") file(s)"
  fi

  "$PY" - "$PH_SPEC" "$WORK/paths.json" <<'PY'
import json, sys
spec = json.load(open(sys.argv[1]))
spec["paths"] = json.load(open(sys.argv[2]))
json.dump(spec, open(sys.argv[1], "w"), indent=2)
PY
  pb apply-placeholders "$PH_SPEC" > "$WORK/ph-applied.json"
  ok "filled placeholders in $("$PY" -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["changed"]))' "$WORK/ph-applied.json") file(s)"

  # ── hook wiring, filtered to the hooks actually installed ─────────────
  local hooks_installed
  hooks_installed=$(sed -n 's/^hook://p' "$SELECTED" | tr '\n' ' ')
  if [[ -n "${hooks_installed// /}" ]]; then
    backup_file "$SETTINGS"
    # shellcheck disable=SC2086
    pb hook-wiring "$HOOK_SNIPPET" $hooks_installed > "$WORK/wiring.json"
    pb merge-json "$SETTINGS" "$WORK/wiring.json" > "$WORK/merge.json"
    ok "merged hook wiring into $SETTINGS"
    while IFS= read -r line; do
      [[ -n "$line" ]] && CONFLICTS+=("$line")
    done < <("$PY" -c 'import json,sys
for c in json.load(open(sys.argv[1]))["conflicts"]:
    print("%s — kept yours (%r); ours would have been %r" % (c["path"], c["yours"], c["ours"]))' "$WORK/merge.json")
  fi
}

write_manifest() {
  "$PY" - "$MANIFEST" "$UNITS" "$SELECTED" "$WORK/merge.json" "$HERE" "$LIB" "$WORK/plan.tsv" \
         "$PH_SPEC" "$SERENA_PREFIX" "$WORK/tracker.json" <<'PY'
import sys
sys.dont_write_bytecode = True   # don't leave a __pycache__ in the user's clone

import json, os, time, importlib.util

(manifest_path, units_path, sel_path, merge_path, repo, lib_path, plan_path,
 ph_path, serena_prefix, tracker_path) = sys.argv[1:11]

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
    config["placeholders"] = {"values": spec.get("values", {}),
                              "delete": spec.get("delete", [])}
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
    manifest["units"][uid] = {
        "kind": u["kind"], "dest": u["dest"],
        "hash": h, "source_hash": u["source_hash"],
    }

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
  "$PY" - "$MANIFEST" "$1" <<'PY'
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
  "$PY" - "$CLAUDE_HOME/tracker.md" "$1" "$2" <<'PY'
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
  done < <("$PY" - "$MANIFEST" <<'PY'
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
  stage "Tracker"
  if [[ -z "$chosen" || ! -f "$CLAUDE_HOME/tracker.md" ]]; then
    warn "no tracker adapter selected"
    say "Every flow that touches a ticket states its intent in abstract verbs, and"
    say "exactly one adapter answers them. Without it those flows have nothing to ask."
    TODO+=("Install one tracker adapter — re-run and pick one at menu item 5, or copy one from templates/trackers/ to $CLAUDE_HOME/tracker.md by hand.")
    printf '\n'
    pause "Continue?"
    return 0
  fi
  printf '  %s%s%s\n\n' "$BOLD" "$chosen" "$RESET"
  fields=$(tracker_fields "$chosen")
  if [[ -z "$fields" ]]; then
    warn "$chosen ships as a shape, not a working adapter."
    say "Its API documentation is wrong about blocking, so no command in it has been"
    say "verified. Fill it in against your own instance and check every line."
    TODO+=("Write and verify the GitLab adapter commands in $CLAUDE_HOME/tracker.md.")
    printf '\n'; pause "Continue?"; return 0
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
      printf '  %s%s  [Enter keeps %s]%s ' "$BOLD" "$prompt" "$prior" "$RESET"
    else
      printf '  %s%s  [Enter skips]%s ' "$BOLD" "$prompt" "$RESET"
    fi
    read -r answer || true
    [[ -z "$answer" ]] && answer="$prior"
    [[ -z "$answer" ]] && continue
    tracker_apply "$token" "$answer"
    printf '%s|%s\n' "$token" "$answer" >> "$WORK/tracker-values.txt"
    ok "$token → $answer"
  done 3<<< "$fields"

  # Persist the answers so a later upgrade can replay them onto a fresh template.
  "$PY" - "$WORK/tracker.json" "$chosen" "$WORK/tracker-values.txt" <<'PY'
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
  pause "Continue?"
}

# ══════════════════════════════════════════════════════════════════════════
# Stage 7 — verify
# ══════════════════════════════════════════════════════════════════════════
verify_stage() {
  stage "Verify"

  # 1 — the acceptance grep from 03-setup.md step 8
  heading "Placeholder gate (03-setup.md step 8)"
  local hits
  hits=$(grep -rnE '^(name|model|tools):.*<[a-z][a-z-]*>' \
           "$CLAUDE_HOME/agents" "$CLAUDE_HOME/skills" 2>/dev/null || true)
  if [[ -z "$hits" ]]; then
    ok "no unfilled placeholder in any name:, model: or tools:"
  else
    bad "unfilled placeholders remain:"
    printf '%s\n' "$hits" | sed 's/^/        /'
    TODO+=("Fill or delete the placeholders listed in the verify stage.")
  fi

  # 2 — wiring. Installing a hook is NOT wiring a hook, so this re-reads
  #     settings.json rather than trusting that the merge did what it said.
  local hooks_installed
  hooks_installed=$(sed -n 's/^hook://p' "$SELECTED" | tr '\n' ' ')
  if [[ -n "${hooks_installed// /}" ]]; then
    heading "Hook wiring (re-read from settings.json, not assumed)"
    # shellcheck disable=SC2086
    pb verify-wiring "$SETTINGS" $hooks_installed > "$WORK/wiring-check.json"
    "$PY" - "$WORK/wiring-check.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for h in d.get("wired", []):
    print("      wired    %s" % h)
for h in d.get("unwired", []):
    print("      UNWIRED  %s" % h)
if d.get("error"):
    print("      %s" % d["error"])
PY
    TODO+=("Prove each hook FIRES: in a scratch repo, feed it a command it must refuse. test-hooks.sh runs hooks standalone and never sees settings.json, so it cannot tell you this.")
  fi

  # 3 — the tracker. The step-8 grep reads only agents/ and skills/, so an
  #     unfilled tracker passes every other gate here and fails at first use.
  if [[ -f "$CLAUDE_HOME/tracker.md" ]]; then
    heading "Tracker"
    local left
    left=$(grep -oE '<(owner|repo|MAP-KEY|LABEL-PREFIX|YOUR-DONE-STATUS|workspace)>' \
             "$CLAUDE_HOME/tracker.md" 2>/dev/null | sort -u | tr '\n' ' ' || true)
    if [[ -n "${left// /}" ]]; then
      bad "still unfilled: $left"
      TODO+=("Fill $left in $CLAUDE_HOME/tracker.md.")
    else
      ok "the curated config fields are filled"
    fi
    TODO+=("Answer 'Is this a shared place?' in $CLAUDE_HOME/tracker.md — it decides whether writes need your approval.")
    TODO+=("Point your global CLAUDE.md at $CLAUDE_HOME/tracker.md so it loads every session.")
  fi

  # 4 — the two CLAUDE.md layers this installer deliberately does not place
  heading "Per-repo files this script does not place"
  note "  templates/claude-md/repo.CLAUDE.md      → <repo>/CLAUDE.md"
  note "  templates/claude-md/workspace.CLAUDE.md → <workspace>/CLAUDE.md (sibling repos only)"
  note "  The installer does not know which repo you mean, so it will not guess a path."
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
  "$PY" - "$MANIFEST" "$PH_SPEC" <<'PY'
import json, sys
try:
    m = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
cfg = m.get("config") or {}
ph = cfg.get("placeholders")
if not ph:
    sys.exit(1)
json.dump({"paths": [], "values": ph.get("values", {}), "delete": ph.get("delete", [])},
          open(sys.argv[2], "w"), indent=2)
print(cfg.get("serena_prefix") or "")
PY
}

update_mode() {
  TOTAL_STAGES=4
  preflight
  [[ -f "$MANIFEST" ]] || die "no manifest at $MANIFEST — run ./install.sh first."

  discover_units_quiet

  seed_from_manifest || die "the manifest records no units — run ./install.sh instead."
  local had=$(wc -l < "$SELECTED" | tr -d ' ')

  # Reuse the answers from the original install. An update that silently changed
  # your model id or Serena prefix is a reinstall, not an update.
  local prefix
  if prefix=$(load_recorded_config); then
    SERENA_PREFIX="$prefix"
    ok "reusing the recorded placeholder values and Serena prefix"
  else
    warn "this install predates recorded config — asking once"
    placeholder_stage
  fi

  stage "Update"

  # Snapshot the PREVIOUS inventory before install_stage_body -> write_manifest
  # overwrites it. Reading manifest["known"] after the write would compare this
  # clone against itself and always report "nothing new".
  "$PY" - "$MANIFEST" "$WORK/known-before.json" <<'PY'
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
  "$PY" - "$UNITS" "$SELECTED" "$WORK/known-before.json" <<'PY'
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
  stage "Discover"
  pb discover "$TEMPLATES" "$CLAUDE_HOME" > "$UNITS" || die "discovery failed"
  pb units-tsv "$UNITS" > "$TSV"
  ok "$(wc -l < "$TSV" | tr -d ' ') installable units in this clone"
  printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════
# remove
# ══════════════════════════════════════════════════════════════════════════
remove_mode() {
  preflight

  stage "What remove would do"
  [[ -f "$MANIFEST" ]] || die "no manifest at $MANIFEST — this script has not installed anything."

  pb plan-remove "$MANIFEST" > "$WORK/rplan.tsv"
  local action uid kind dest n_rm=0 n_keep=0
  while IFS=$'\t' read -r action uid kind dest; do
    [[ -z "$action" ]] && continue
    case "$action" in
      remove)      printf '   %sremove%s  %s\n' "$RED" "$RESET" "$uid"; n_rm=$((n_rm + 1)) ;;
      keep-edited) printf '   %skeep%s    %s  %s(you changed it)%s\n' "$GREEN" "$RESET" "$uid" "$DIM" "$RESET"; n_keep=$((n_keep + 1)) ;;
    esac
  done < "$WORK/rplan.tsv"
  printf '\n'
  note "$n_rm to remove · $n_keep kept because you changed them since install"
  note "JSON keys and hook entries this script added are reverted; yours stay."
  printf '\n'
  confirm "Remove them?" || { printf '\n  nothing changed.\n\n'; exit 0; }

  stage "Removing"
  while IFS=$'\t' read -r action uid kind dest; do
    case "$action" in
      remove)      rm -rf "$dest"; REMOVED+=("$uid") ;;
      keep-edited) LEFT_ALONE+=("$uid — kept, you changed it since install") ;;
    esac
  done < "$WORK/rplan.tsv"

  # revert exactly the JSON additions we recorded, and nothing else
  "$PY" - "$MANIFEST" "$WORK" <<'PY'
import json, os, sys
manifest = json.load(open(sys.argv[1]))
for i, rec in enumerate(manifest.get("json", [])):
    with open(os.path.join(sys.argv[2], "unmerge-%d.json" % i), "w") as fh:
        json.dump(rec, fh)
PY
  local i=0 target
  while [[ -f "$WORK/unmerge-$i.json" ]]; do
    target=$("$PY" -c 'import json,sys;print(json.load(open(sys.argv[1]))["target"])' "$WORK/unmerge-$i.json")
    backup_file "$target"
    pb unmerge-json "$target" "$WORK/unmerge-$i.json" > /dev/null
    ok "reverted our additions in $target"
    i=$((i + 1))
  done

  # tidy up directories we created and then emptied — never one with anything left
  local d
  for d in agents skills commands hooks; do
    [[ -d "$CLAUDE_HOME/$d" ]] && rmdir "$CLAUDE_HOME/$d" 2>/dev/null || true
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
  stage "Current state"
  if [[ -f "$MANIFEST" ]]; then
    local state uid kind n_out=0 n_new=0
    while IFS=$'\t' read -r state uid kind; do
      case "$state" in
        current)   printf '   %s%-10s%s %s\n' "$GREEN" "current"  "$RESET" "$uid" ;;
        outdated)  printf '   %s%-10s%s %s\n' "$YELLOW" "outdated" "$RESET" "$uid"; n_out=$((n_out + 1)) ;;
        edited)    printf '   %s%-10s%s %s\n' "$BOLD" "edited"   "$RESET" "$uid" ;;
        missing)   printf '   %-10s %s\n' "missing"   "$uid" ;;
        available) printf '   %s%-10s%s %s\n' "$DIM" "available" "$RESET" "$uid"; n_new=$((n_new + 1)) ;;
      esac
    done < <(pb plan-state "$MANIFEST" "$UNITS")
    printf '\n'
    note "outdated  = the template moved since you installed it"
    note "edited    = you changed it; update and remove both leave it alone"
    note "available = this clone ships it and you have not installed it"
    printf '\n'
    [[ "$n_out" -gt 0 ]] && say "$n_out unit(s) would be refreshed by ./install.sh update"
    [[ "$n_new" -gt 0 ]] && say "$n_new unit(s) can be added with ./install.sh"
  else
    note "nothing installed by this script (no $MANIFEST)"
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
  _summarise "removed"                     ${REMOVED[@]+"${REMOVED[@]}"}
  _summarise "left alone"                  ${LEFT_ALONE[@]+"${LEFT_ALONE[@]}"}
  _summarise "conflicts — your value kept" ${CONFLICTS[@]+"${CONFLICTS[@]}"}

  if [[ ${#TODO[@]} -gt 0 ]]; then
    printf '  %s%sstill yours to do:%s\n' "$BOLD" "$YELLOW" "$RESET"
    local t
    for t in "${TODO[@]}"; do printf '    %s-%s %s\n' "$YELLOW" "$RESET" "$t"; done
    printf '\n'
  fi

  note "The manual path is documented in full in docs/shared/03-setup.md."
  note "./install.sh update refreshes what you have; remove takes it back out."
  printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════
# main
# ══════════════════════════════════════════════════════════════════════════
case "$MODE" in
  remove|uninstall)
    TOTAL_STAGES=3
    banner "claude-code-playbook · remove"
    remove_mode
    ;;
  update|upgrade)
    TOTAL_STAGES=4
    banner "claude-code-playbook · update"
    update_mode
    ;;
  list|status)
    TOTAL_STAGES=2
    banner "claude-code-playbook · state"
    list_mode
    ;;
  install|"")
    banner "claude-code-playbook · install"
    preflight
    discover_units
    selection_stage
    serena_stage
    placeholder_stage
    install_stage
    tracker_stage
    verify_stage
    install_finish "Install complete"
    ;;
  *)
    die "unknown mode: $MODE (expected install, update, remove or list)"
    ;;
esac
