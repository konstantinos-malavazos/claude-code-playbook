#!/usr/bin/env bash
# Wiring scrub for the per-dispatch model weight (issue #92).
#
#   bash tests/test-wiring.sh            # all sections
#   bash tests/test-wiring.sh A1 A4      # only these
#
# Deterministic and offline: no network, no model, no install. It reads the
# templates and the docs and asserts the weight wiring is still wired.
#
# WHY THIS EXISTS. The weight landed across six dispatch sites, one shared skill
# and four weighing agents, and was verified by hand. None of that survives the
# next change: the wiring fails OPEN. A new editing agent nobody wired, or a
# command that restates the criteria instead of loading the skill, produces the
# same SHAPE of result as a correct one — just slower and more expensive. There
# is nothing in the output to notice.
#
# Every assertion below names the failure it catches, because an assertion whose
# failure nobody can picture gets deleted the first time it goes red.
#
# What this does NOT do: prove an agent BEHAVES differently. That needs a live
# model, a tracker adapter, Serena and a real ticket, and the result is
# nondeterministic. See issue #92's Tier 2 — run by hand before a release, never
# in CI. Tier 1 is most of the value: every failure this design can realistically
# have is a wiring failure, not a reasoning failure.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

AGENTS="$REPO/templates/agents"
COMMANDS="$REPO/templates/commands"
TEMPLATES="$REPO/templates"
SKILL="$REPO/templates/skills/dispatch-weight/SKILL.md"
FLOWS="$REPO/docs/shared/07-the-flows.md"

SCRATCH="${PLAYBOOK_TEST_DIR:-${TMPDIR:-/tmp}/playbook-wiring-tests}"

PASS=0; FAIL=0
FAILED_NAMES=()

pass() { PASS=$((PASS+1)); printf '    PASS  %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); printf '    FAIL  %s\n' "$1"; }
chk()  { if [ "$1" = "0" ]; then pass "$2"; else fail "$2"; fi; }
banner() { printf '\n=== %s\n' "$1"; }

WANT="$*"
want() { [ -z "$WANT" ] && return 0; case " $WANT " in *" $1 "*) return 0;; esac; return 1; }

# ---------------------------------------------------------------- readers
#
# Everything below reads the SAME three things, so a change of format breaks one
# helper rather than seven assertions.

# frontmatter FILE — the YAML block between the first two `---` lines. An agent's
# capabilities live here and nowhere else, so a verb mentioned in the prose below
# is deliberately NOT a capability.
frontmatter() { awk '/^---$/{n++; next} n==1' "$1"; }

# fm_field FILE FIELD — one frontmatter field's value, empty if absent
fm_field() { frontmatter "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

# fenced FILE — the contents of every fenced code block. An agent's output-format
# template is written as one, which is what "somewhere to put the answer" means:
# a weight in the prose is an instruction, a weight in the template is a field.
fenced() { awk '/^```/{n++; next} n%2==1' "$1"; }

# stems DIR — installable template stems, minus the README index
stems() {
  local f stem
  for f in "$1"/*.md; do
    stem="$(basename "$f" .md)"
    [ "$stem" = "README" ] && continue
    printf '%s\n' "$stem"
  done
}

# Serena's edit verbs — the issue's list plus `insert_before_symbol`, which is the
# same verb family and does not change today's inventory. Matched WITHOUT the
# `mcp__serena__` prefix so the check survives an install that rewrites it.
EDIT_VERBS='(replace_symbol_body|insert_after_symbol|insert_before_symbol|create_text_file|rename_symbol|safe_delete_symbol|replace_content|replace_in_files)'

# can_edit FILE — does this agent hold a Serena edit verb in its `tools:` line?
# This is the test the doc's inventory rule names: run it off the TOOL LIST, not
# the job title. Reading the names instead misses the agents that quietly write
# and amend — which is the error this repo already made once, about
# @integration-tester.
can_edit() { fm_field "$1" tools | grep -qE "$EDIT_VERBS"; }

# has_weight_skill FILE — does this file send the reader to the one definition?
has_weight_skill() { grep -qF 'dispatch-weight' "$1"; }

# setlike LIST — normalise a list, newline- or space-separated, into one sorted
# space-separated line, so a comparison is about membership and not order.
setlike() { printf '%s\n' "$1" | tr ' ' '\n' | sed '/^$/d' | sort | tr '\n' ' ' | sed 's/ $//'; }

printf 'wiring scrub — %s\n' "$REPO"

# ---------------------------------------------------------------- A1
# The edit-capability inventory is a TRIPWIRE, not a description. A fourth agent
# holding edit verbs fails this until somebody classifies it as weight-eligible
# (A2) or floor-exempt (A7).
#
# Catches: a new editing agent nobody wired.
EXPECTED_EDITORS="integration-tester layer-specialist slice-layer-specialist"

editors_now() {
  local stem
  stems "$AGENTS" | while read -r stem; do
    can_edit "$AGENTS/$stem.md" && printf '%s\n' "$stem"
  done
}
EDITORS="$(editors_now)"

if want A1; then
banner "A1 · exactly three agents hold Serena edit verbs"
GOT="$(setlike "$EDITORS")"
EXP="$(setlike "$EXPECTED_EDITORS")"
if [ "$GOT" = "$EXP" ]; then
  pass "edit-capable agents are exactly: $EXP"
else
  fail "edit-capable agents drifted — expected [$EXP], found [$GOT]"
  printf '          a new editing agent must be classified weight-eligible (A2)\n'
  printf '          or floor-exempt (A7), then added to EXPECTED_EDITORS here\n'
fi
# The inventory is only a tripwire if the verb list itself is real. An empty or
# mistyped regex would make every agent look read-only and pass silently.
if [ -n "$EDITORS" ]; then pass "the edit-verb probe matches something at all"
else fail "the edit-verb probe matched NOTHING — EDIT_VERBS is broken, not the tree"; fi
fi

# ---------------------------------------------------------------- A2
# An agent that can edit code AND pins no `model:` is weight-eligible: the weight
# is the only thing that decides its tier. Every command that dispatches one must
# reference the skill.
#
# Every command that so much as says "specialist" must be classified here. That
# is the tripwire: a new dispatching command will say it, and will fail until
# somebody decides which of the three it is.
#
# Catches: a new command that dispatches a specialist on the cheap tier forever.
weight_eligible() {
  local stem
  printf '%s\n' "$EDITORS" | sed '/^$/d' | while read -r stem; do
    [ -z "$(fm_field "$AGENTS/$stem.md" model)" ] && printf '%s\n' "$stem"
  done
}
ELIGIBLE="$(weight_eligible)"

# The @-handles those agents are dispatched by — read from their `name:`, so a
# rename moves the check with them rather than leaving it matching a ghost.
eligible_handles() {
  local stem
  printf '%s\n' "$ELIGIBLE" | sed '/^$/d' | while read -r stem; do
    printf '@%s\n' "$(fm_field "$AGENTS/$stem.md" name)"
  done
}

# weighs         — dispatches a weight-eligible specialist itself
# delegates      — hands the dispatch to a weighing command; never dispatches one
# not-a-dispatch — says "specialist" about agents that are not weight-eligible
command_class() {
  case "$1" in
    start-ticket|fix-ticket|build-chart-ticket) printf 'weighs' ;;
    start-massive|resume-massive)               printf 'delegates' ;;
    encode-codebase|feeling-lucky)              printf 'not-a-dispatch' ;;
    *)                                          printf 'UNCLASSIFIED' ;;
  esac
}

if want A2; then
banner "A2 · weight-eligible agents are dispatched only from weight-aware commands"
if [ -n "$(setlike "$ELIGIBLE")" ]; then
  pass "weight-eligible agents: $(setlike "$ELIGIBLE")"
else
  fail "NO weight-eligible agents found — every editor pins a model, or A1's probe is broken"
fi

for stem in $(stems "$COMMANDS"); do
  grep -qF 'specialist' "$COMMANDS/$stem.md" || continue
  class="$(command_class "$stem")"
  case "$class" in
    weighs)
      if has_weight_skill "$COMMANDS/$stem.md"; then
        pass "/$stem dispatches a specialist and references dispatch-weight"
      else
        fail "/$stem dispatches a specialist but never references dispatch-weight"
      fi
      ;;
    delegates)
      # A delegating command is only exempt while it really delegates: it must
      # name a command that does the weighing. Lose that and it is dispatching
      # on its own, unweighed.
      named=""
      for w in $(stems "$COMMANDS"); do
        [ "$(command_class "$w")" = "weighs" ] || continue
        grep -qF "/$w" "$COMMANDS/$stem.md" && named="$named /$w"
      done
      if [ -n "$named" ]; then
        pass "/$stem delegates the dispatch to$named"
      else
        fail "/$stem names a specialist but delegates to no weighing command"
      fi
      ;;
    not-a-dispatch)
      # Exempt because the specialists it names pin their own tier. If a
      # weight-eligible handle turns up in it, that reason has expired.
      hit=""
      while read -r h; do
        [ -n "$h" ] || continue
        grep -qF "$h" "$COMMANDS/$stem.md" && hit="$hit $h"
      done <<EOF
$(eligible_handles)
EOF
      if [ -z "$hit" ]; then
        pass "/$stem names no weight-eligible specialist (exemption holds)"
      else
        fail "/$stem is marked not-a-dispatch but names$hit"
      fi
      ;;
    *)
      fail "/$stem mentions a specialist and is UNCLASSIFIED — classify it in command_class()"
      ;;
  esac
done
fi

# ---------------------------------------------------------------- A3
# Every weigher loads the skill AND has somewhere to put the answer.
#
# Catches: an agent told to classify with nowhere to write it, so the
# orchestrator reads nothing and silently defaults — the cheap direction, whose
# failures are invisible in the output.
WEIGHERS="planner repo-reviewer aligner fixer-planner"

if want A3; then
banner "A3 · the four weighers load the skill and carry a weight line"
for stem in $WEIGHERS; do
  f="$AGENTS/$stem.md"
  if [ ! -f "$f" ]; then fail "@$stem is missing from templates/agents/"; continue; fi
  if has_weight_skill "$f"; then pass "@$stem references dispatch-weight"
  else fail "@$stem does not reference dispatch-weight"; fi
  if fenced "$f" | grep -qF 'weight'; then
    pass "@$stem's output-format block has a weight line"
  else
    fail "@$stem classifies with nowhere to write the answer (no weight in its output block)"
  fi
done
fi

# ---------------------------------------------------------------- A4
# Criteria drift guard: the classification criteria live in the skill and nowhere
# else under templates/. Docs may reference them; templates must not restate them.
#
# Catches: the exact regression this design exists to prevent — six copies of a
# threshold that stop being six copies of the SAME threshold.
#
# Markers are the criteria's own wording. One in passing is fine (a tracker
# adapter may say "more than one repo" about something else); two is a restated
# rule. The threshold placeholder is fatal on its own — it exists only for the
# skill, so a second copy is a second threshold.
MARKERS='placeholder seam
multiple callers
more than one repo
several findings against one track'
FATAL_MARKER='<FILE-COUNT-THRESHOLD>'

if want A4; then
banner "A4 · the criteria live in the skill and nowhere else under templates/"
if [ -f "$SKILL" ]; then pass "templates/skills/dispatch-weight/SKILL.md exists"
else fail "templates/skills/dispatch-weight/SKILL.md is MISSING"; fi

# Anchor first: if the criteria have left the skill, the guard below would pass
# while guarding nothing.
missing=""
while IFS= read -r m; do
  grep -qF "$m" "$SKILL" 2>/dev/null || missing="$missing [$m]"
done <<EOF
$MARKERS
EOF
grep -qF "$FATAL_MARKER" "$SKILL" 2>/dev/null || missing="$missing [$FATAL_MARKER]"
if [ -z "$missing" ]; then pass "the skill still states every criterion the guard looks for"
else fail "criteria left the skill:$missing — the guard below is guarding nothing"; fi

clean=yes
while IFS= read -r f; do
  [ "$f" = "$SKILL" ] && continue
  n=0; found=""
  while IFS= read -r m; do
    if grep -qF "$m" "$f"; then n=$((n+1)); found="$found [$m]"; fi
  done <<EOF
$MARKERS
EOF
  rel="${f#"$REPO"/}"
  if grep -qF "$FATAL_MARKER" "$f"; then
    fail "$rel carries $FATAL_MARKER — a second copy of the threshold"
    clean=no
  fi
  if [ "$n" -ge 2 ]; then
    fail "$rel restates the criteria:$found — reference the skill instead"
    clean=no
  fi
done <<EOF
$(find "$TEMPLATES" -name '*.md' -type f | sort)
EOF
# The loop names offenders one by one, so it says nothing at all when there are
# none. Report the clean sweep, once.
[ "$clean" = "yes" ] && pass "no template outside the skill restates the criteria"
fi

# ---------------------------------------------------------------- A5
# The skill is reachable from a minimal install. Assert the EDGE, not the install:
# `install-lib.py discover` must report skill:dispatch-weight in the needs of
# command:start-ticket, which is what pulls it into preset_minimal.
#
# Catches: somebody rewording a command so the backtick reference stops matching,
# leaving every agent pointing at a skill that was never installed — which fails
# silently, because a missing skill is not an error, it is an absence.
if want A5; then
banner "A5 · discover puts skill:dispatch-weight in command:start-ticket's needs"
if command -v python3 >/dev/null 2>&1; then
  mkdir -p "$SCRATCH"
  ( cd "$REPO" && python3 install-lib.py discover templates "$SCRATCH/fakehome" ) \
    > "$SCRATCH/discover.json" 2> "$SCRATCH/discover.err"
  chk $? "install-lib.py discover runs (errors in $SCRATCH/discover.err)"

  # One reader, three assertions: the extraction is python's job because the
  # output is JSON, but the verdicts stay in the harness so they tally like
  # every other line here.
  UNITS="$(python3 -c '
import json, sys
u = json.load(open(sys.argv[1]))
for uid in sorted(u):
    print("unit " + uid)
for n in u.get("command:start-ticket", {}).get("needs", []):
    print("needs " + n)
' "$SCRATCH/discover.json" 2>/dev/null)"

  case "$UNITS" in *"unit skill:dispatch-weight"*)
    pass "skill:dispatch-weight is a discovered unit" ;;
  *) fail "skill:dispatch-weight is NOT a discovered unit" ;; esac

  case "$UNITS" in *"unit command:start-ticket"*)
    pass "command:start-ticket is a discovered unit" ;;
  *) fail "command:start-ticket is NOT a discovered unit" ;; esac

  case "$UNITS" in *"needs skill:dispatch-weight"*)
    pass "command:start-ticket needs skill:dispatch-weight, so preset_minimal pulls it in" ;;
  *) fail "command:start-ticket does NOT need skill:dispatch-weight — the backtick reference stopped matching, and a minimal install ships agents pointing at a skill that is not there" ;; esac
else
  printf '    SKIP  python3 — NOT INSTALLED on this machine, so A5 NOT run\n'
fi
fi

# ---------------------------------------------------------------- A6
# The doc's site table matches the templates. Six sites, each a real dispatch
# point, each weighed by an agent or command that actually loads the skill.
#
# Catches: the doc and the pipeline drifting apart — worse than either being
# wrong alone, because an agent reads both.
if want A6; then
banner "A6 · the six sites in 07-the-flows.md correspond to real dispatch points"
if [ ! -f "$FLOWS" ]; then
  fail "docs/shared/07-the-flows.md is missing"
else
  ROWS="$(awk '/^\| # \| Dispatch site \|/{f=1; next} f && !/^\|/{exit} f && /^\|[- |]*\|$/{next} f' "$FLOWS")"
  N="$(printf '%s\n' "$ROWS" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$N" = "6" ]; then pass "the table lists 6 dispatch sites"
  else fail "the table lists $N dispatch sites, not 6 — doc and pipeline have drifted"; fi

  # Every @handle the table names must be an agent that loads the skill. The
  # table is the doc's claim; templates/agents is the fact.
  HANDLES="$(printf '%s\n' "$ROWS" | grep -oE '@[a-z-]+' | sed 's/^@//' | sort -u)"
  if [ "$(setlike "$HANDLES")" = "$(setlike "$WEIGHERS")" ]; then
    pass "the table's weighers are exactly A3's four: $(setlike "$HANDLES")"
  else
    fail "table weighers [$(setlike "$HANDLES")] != A3's [$(setlike "$WEIGHERS")]"
  fi
  for h in $HANDLES; do
    if [ -f "$AGENTS/$h.md" ] && has_weight_skill "$AGENTS/$h.md"; then
      pass "site weigher @$h exists and loads the skill"
    else
      fail "site weigher @$h is missing or does not load the skill"
    fi
  done

  # Site 6 is the secondary-command site. Whatever /command the table names there
  # must exist and be weight-aware.
  CMDS="$(printf '%s\n' "$ROWS" | grep -oE '/[a-z-]+-ticket' | sed 's|^/||' | sort -u)"
  for c in $CMDS; do
    if [ ! -f "$COMMANDS/$c.md" ]; then
      fail "the table names /$c, which is not a command template"
    elif has_weight_skill "$COMMANDS/$c.md"; then
      pass "the table's /$c exists and is weight-aware"
    else
      fail "the table names /$c as a dispatch site, but it never references dispatch-weight"
    fi
  done

  # The doc points at the skill by relative path; a moved skill must break the
  # doc loudly rather than leave a link that 404s only for a reader.
  LINK="$(grep -oE '\.\./\.\./templates/skills/dispatch-weight/SKILL\.md' "$FLOWS" | head -1)"
  if [ -n "$LINK" ] && [ -f "$(cd "$(dirname "$FLOWS")" && pwd)/$LINK" ]; then
    pass "the doc's link to the skill resolves"
  else
    fail "the doc's link to templates/skills/dispatch-weight/SKILL.md does not resolve"
  fi
fi
fi

# ---------------------------------------------------------------- A7
# Floor-exempt agents really are at the floor. An editing agent excluded from
# weighting is only excluded because a weight could not raise it anyway — which
# is true ONLY if it already pins the strong tier.
#
# Catches: an agent exempted for the wrong reason. That mistake has already been
# made here once: @integration-tester holds edit verbs, so the claim that it "is
# not an implementation dispatch" was wrong. It is exempt because of its floor,
# and this asserts the floor rather than the claim.
if want A7; then
banner "A7 · every floor-exempt editing agent pins the strong tier"
for stem in $(printf '%s\n' "$EDITORS" | sed '/^$/d'); do
  m="$(fm_field "$AGENTS/$stem.md" model)"
  if [ -z "$m" ]; then
    pass "@$stem pins no model — weight-eligible, covered by A2"
  elif [ "$m" = "<strong-model-id>" ]; then
    pass "@$stem is floor-exempt and pinned to <strong-model-id>"
  else
    fail "@$stem edits code, is excluded from weighting, and pins '$m' instead of <strong-model-id>"
  fi
done
fi

# ---------------------------------------------------------------- tally
printf '\n=== %s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" != "0" ]; then
  printf '\nfailed:\n'
  for n in "${FAILED_NAMES[@]}"; do printf '  - %s\n' "$n"; done
  exit 1
fi
exit 0
