#!/usr/bin/env bash
# Wiring scrub. Two wirings live here, both the same shape — one definition, many
# call sites — and both failing OPEN when a call site drifts:
#
#   A1-A9  the per-dispatch model weight (issue #92)
#   N1-N4  the end-of-flow next-steps block (issue #104)
#
#   bash tests/test-wiring.sh            # all sections
#   bash tests/test-wiring.sh A1 N2      # only these
#
# Deterministic and offline: no network, no model, no install. It reads the
# templates and the docs and asserts both wirings are still wired.
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
NEXT="$REPO/templates/skills/next-steps/SKILL.md"
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

# ---------------------------------------------------------------- A8
# An agent that says "load the `x` skill" must DECLARE skill:x, so that ticking
# the agent installs the skill. Until #97 the installer read command and skill
# bodies only, so thirteen agents said it and declared nothing: a selection of
# agents without their commands installed instructions that could not be
# followed.
#
# Catches: the exclusion coming back, and a new agent that names a skill nobody
# wired. Both fail the same silent way — the agent loads a skill that is not on
# disk, finds nothing, and carries on with the step undone.
#
# The edges are read from `install-lib.py discover`, not from a list here: a list
# would need a line per agent and would go stale the day someone adds one.
if want A8; then
banner "A8 · every agent declares the skills it loads"
if command -v python3 >/dev/null 2>&1; then
  mkdir -p "$SCRATCH"
  ( cd "$REPO" && python3 install-lib.py discover templates "$SCRATCH/fakehome" ) \
    > "$SCRATCH/discover-a8.json" 2> "$SCRATCH/discover-a8.err"
  chk $? "install-lib.py discover runs (errors in $SCRATCH/discover-a8.err)"

  # python reports what it found; the verdicts stay in the harness so they tally
  # with every other line here. A backtick reference that is not a shipped skill
  # is not an edge — the installer intersects with what exists on disk, and so
  # does this.
  # The backticks in the regex below are python's, not command substitution.
  # SC2016 sees a single-quoted string with backticks in it and cannot tell.
  # shellcheck disable=SC2016
  A8="$(cd "$REPO" && python3 -c '
import json, re, sys
units = json.load(open(sys.argv[1]))
skills = {u.split(":", 1)[1] for u in units if u.startswith("skill:")}
found = missing = 0
for uid in sorted(units):
    if not uid.startswith("agent:"):
        continue
    body = open(units[uid]["src"], encoding="utf-8", errors="replace").read()
    for ref in sorted(set(re.findall(r"`([a-z][a-z0-9-]+)`", body))):
        if ref not in skills:
            continue
        found += 1
        if ("skill:" + ref) not in units[uid]["needs"]:
            missing += 1
            print("MISSING " + uid + " names `" + ref + "` and does not need skill:" + ref)
print("found %d" % found)
print("missing %d" % missing)
' "$SCRATCH/discover-a8.json" 2>/dev/null)"

  # A count of zero would pass the assertion below while testing nothing at all,
  # which is the failure mode this line exists to close.
  case "$A8" in *"found 0"*|"")
    fail "no agent names any shipped skill — A8 asserted nothing, so it proves nothing" ;;
  *) pass "$(printf '%s\n' "$A8" | sed -n 's/^found /agent-to-skill references checked: /p')" ;; esac

  case "$A8" in *"missing 0"*)
    pass "every agent declares the skills it names, so ticking one installs them" ;;
  *)
    printf '%s\n' "$A8" | sed -n 's/^MISSING /          /p'
    fail "an agent names a skill it does not declare — tick that agent alone and the skill is absent, silently" ;;
  esac
else
  printf '    SKIP  python3 — NOT INSTALLED on this machine, so A8 NOT run\n'
fi
fi

# ---------------------------------------------------------------- A9
# Three files under templates/ are GENERATION TEMPLATES, not installables:
# layer-specialist, slice-layer-specialist and engineering-standards. Each carries
# a <layer> placeholder in its `name:`, and /adapt-to-stack writes a filled copy
# per layer into the REPO's .claude/ — never into $CLAUDE_HOME. Stage 2 of the
# installer prints that promise in its own words; install-lib.py keeps it with
# NEVER_INSTALL.
#
# Catches: the guard going vacuous. It did, on Windows — under Git Bash the lib
# runs on a windows python, os.path.relpath came back with backslashes, no entry
# matched, and all three became ordinary units. skill:adapt-to-stack then gained a
# skill:engineering-standards edge, `recommended` dragged it in, and the install
# ended red on its own placeholder gate for a unit nobody ticked. (#99)
#
# It catches the quieter ways too: a renamed template leaves an entry matching
# nothing, and an entry whose file no longer holds a placeholder is a template
# that has stopped being one.
if want A9; then
banner "A9 · the three generation templates are not installable units"
if command -v python3 >/dev/null 2>&1; then
  mkdir -p "$SCRATCH"

  # python reports what it found; the verdicts stay in the harness, as in A8.
  A9="$(cd "$REPO" && python3 -c '
import importlib.util, os, sys

spec = importlib.util.spec_from_file_location("pblib", "install-lib.py")
lib = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lib)

templates = "templates"
units = lib.discover(templates, sys.argv[1])

print("units %d" % len(units))
print("entries %d" % len(lib.NEVER_INSTALL))

def unit_name(rel):
    base = os.path.basename(rel)
    return base[:-3] if base.endswith(".md") else base

for rel in sorted(lib.NEVER_INSTALL):
    print("NAME " + unit_name(rel))
    src = os.path.join(templates, *rel.split("/"))
    if not os.path.exists(src):
        print("MISSINGSRC " + rel)
        continue
    # A template with nothing left to fill is not a generation template any more,
    # and excluding it would need a different reason than this one.
    if not lib.scan_placeholders([src]):
        print("NOPLACEHOLDER " + rel)

# The exclusion itself: not a unit, and therefore not reachable as a dependency
# either — an edge is only ever drawn to something discovery kept, so no preset
# and no hand-ticked selection can close over one of these.
excluded = {unit_name(r) for r in lib.NEVER_INSTALL}
for uid in sorted(units):
    if uid.split(":", 1)[1] in excluded:
        print("UNIT " + uid)
    for need in units[uid]["needs"]:
        if need.split(":", 1)[1] in excluded:
            print("EDGE " + uid + " -> " + need)

# Separator-proofing, asserted on every platform rather than only where it broke:
# feed the guard the shape a windows python hands it and it must still match.
win = lib._unit_rel(os.path.join(templates, "skills\\engineering-standards"), templates)
print("SEP " + ("ok" if win in lib.NEVER_INSTALL else "broken(" + win + ")"))
' "$SCRATCH/fakehome-a9" 2>"$SCRATCH/discover-a9.err")"

  if [ -n "$A9" ]; then
    pass "install-lib.py discover runs (errors in $SCRATCH/discover-a9.err)"
  else
    fail "install-lib.py discover produced nothing — see $SCRATCH/discover-a9.err"
  fi

  # An empty NEVER_INSTALL would pass every assertion below while excluding
  # nothing, which is the failure mode this line closes.
  case "$A9" in *"entries 3"*)
    pass "NEVER_INSTALL still names three templates" ;;
  *)
    fail "NEVER_INSTALL no longer names three templates — reclassify, or fix the guard" ;;
  esac

  if printf '%s\n' "$A9" | grep -q '^MISSINGSRC '; then
    printf '%s\n' "$A9" | sed -n 's/^MISSINGSRC /          no such template: /p'
    fail "a NEVER_INSTALL entry matches no file — the guard excludes nothing, silently"
  else
    pass "every NEVER_INSTALL entry names a template that exists"
  fi

  if printf '%s\n' "$A9" | grep -q '^NOPLACEHOLDER '; then
    printf '%s\n' "$A9" | sed -n 's/^NOPLACEHOLDER /          nothing left to fill: /p'
    fail "an excluded template holds no blocking placeholder — it is no longer a generation template"
  else
    pass "each one still carries the <layer> placeholder that makes it ungeneric"
  fi

  if printf '%s\n' "$A9" | grep -q '^UNIT '; then
    printf '%s\n' "$A9" | sed -n 's/^UNIT /          discovered: /p'
    fail "a generation template is an installable unit — tick it and the placeholder gate goes red"
  else
    pass "none of the three is discovered as a unit"
  fi

  if printf '%s\n' "$A9" | grep -q '^EDGE '; then
    printf '%s\n' "$A9" | sed -n 's/^EDGE /          /p'
    fail "a unit depends on a generation template — a preset installs it without anyone choosing it"
  else
    pass "no unit depends on one, so no preset can drag one in"
  fi

  case "$A9" in *"SEP ok"*)
    pass "the guard matches a windows-shaped relative path too" ;;
  *)
    printf '%s\n' "$A9" | sed -n 's/^SEP /          /p'
    fail "the guard is separator-dependent — under Git Bash all three become units again (#99)" ;;
  esac

  # The promise and the behaviour are two different files. Stage 2 of install.sh
  # names the three in prose; NEVER_INSTALL is what actually excludes them. Drift
  # between them is exactly how #99 read as a broken installer.
  NOTE="$(grep -n 'deliberately NOT installed' -A1 "$REPO/install.sh" \
          | sed -n 's/.*note "  *\(.*\)"$/\1/p' | tail -1)"
  NOTED="$(setlike "$(printf '%s\n' "$NOTE" | tr '·' ' ')")"
  GUARDED="$(setlike "$(printf '%s\n' "$A9" | sed -n 's/^NAME //p' | tr '\n' ' ')")"
  if [ -n "$NOTED" ] && [ "$NOTED" = "$GUARDED" ]; then
    pass "stage 2 names exactly what NEVER_INSTALL excludes: $GUARDED"
  else
    fail "stage 2 promises [$NOTED] but NEVER_INSTALL excludes [$GUARDED]"
  fi
else
  printf '    SKIP  python3 — NOT INSTALLED on this machine, so A9 NOT run\n'
fi
fi

# ================================================================== N — next-steps
#
# The end-of-flow hand-back (#104). A flow that finishes and says nothing leaves
# the user holding a finished stage with no next move, and NOTHING in the output
# says so — a report reads as complete either way. That is the same silent shape
# the A sections guard, so it is guarded the same way.

# ---------------------------------------------------------------- N readers
#
# Every installable command and skill is classified here, by hand, into one of two
# buckets. The list IS the tripwire: a new command, or a new skill with an ending,
# lands in neither and fails N1 until somebody decides which it is.
#
# terminal      — a flow the user is left standing at the end of; must invoke the
#                 skill, whatever the ending is (including a stop-with-a-question)
# not-terminal  — runs INSIDE another flow's ending and has no ending of its own,
#                 or is the block's own definition, or is a generation template
terminal_class() {
  case "$1" in
    # every command template ships a flow, and every flow has an ending
    build-chart-ticket|encode-codebase|end-of-day|feeling-lucky|feeling-very-lucky) printf 'terminal' ;;
    fix-ticket|garden-memory|resume-massive|resume-ticket|start-massive)            printf 'terminal' ;;
    start-ticket|test-ticket)                                                       printf 'terminal' ;;
    # the skills a human is left standing at the end of
    adapt-to-stack|bootstrap|charting|cut-backlog|grilling|handoff)                 printf 'terminal' ;;
    pitch|prototype|research|to-questionnaire|to-tickets|wizard)                    printf 'terminal' ;;
    # always-loaded skills, the block's own definition, and a generation template
    commit-conventions|diagnose|dispatch-weight|memory-schema|memory-tag-lint)      printf 'not-terminal' ;;
    tdd|to-spec|wait-what|next-steps|engineering-standards)                         printf 'not-terminal' ;;
    *)                                                                              printf 'UNCLASSIFIED' ;;
  esac
}

# skill_dirs — the skill stems, read off disk the way stems() reads the flat dirs
skill_dirs() {
  local d
  for d in "$TEMPLATES"/skills/*/; do
    [ -d "$d" ] || continue
    basename "$d"
  done
}

# invokes_next FILE — does this file send the reader to the one definition?
# The backticks are the pattern, not a substitution: the installer's skill-edge
# regex only matches a backticked reference, so this asks for the same thing.
# shellcheck disable=SC2016
invokes_next() { grep -qF '`next-steps`' "$1"; }

# terminal_file STEM — the template a stem's ending lives in
terminal_file() {
  if [ -f "$COMMANDS/$1.md" ]; then printf '%s' "$COMMANDS/$1.md"
  else printf '%s' "$TEMPLATES/skills/$1/SKILL.md"; fi
}

# terminal_uid STEM — the unit id discovery will have given it
terminal_uid() {
  if [ -f "$COMMANDS/$1.md" ]; then printf 'command:%s' "$1"
  else printf 'skill:%s' "$1"; fi
}

# ---------------------------------------------------------------- N1
# Every terminal template invokes the skill, and every template is classified.
#
# Catches: a new flow that ends in silence, and an existing one whose hand-back
# was reworded until the reference stopped matching.
if want N1; then
banner "N1 · every terminal template invokes next-steps"
if [ -f "$NEXT" ]; then pass "templates/skills/next-steps/SKILL.md exists"
else fail "templates/skills/next-steps/SKILL.md is MISSING"; fi

n_terminal=0
for stem in $(stems "$COMMANDS") $(skill_dirs); do
  f="$(terminal_file "$stem")"
  case "$(terminal_class "$stem")" in
    terminal)
      n_terminal=$((n_terminal+1))
      if [ ! -f "$f" ]; then
        fail "$stem is classified terminal but has no template file"
      elif invokes_next "$f"; then
        pass "$stem ends by invoking next-steps"
      else
        fail "$stem is a terminal point and never invokes next-steps — it finishes and says nothing"
      fi
      ;;
    not-terminal)
      # Exempt because it runs inside another flow's ending. Nothing to assert
      # about its body: a not-terminal template that DOES invoke the skill is not
      # an error, it is somebody having found an ending in it.
      pass "$stem is not a terminal point (exempt)"
      ;;
    *)
      fail "$stem is UNCLASSIFIED — classify it terminal or not-terminal in terminal_class()"
      ;;
  esac
done

# A classification list that had drifted to zero terminals would pass every line
# above while asserting nothing at all.
if [ "$n_terminal" = "24" ]; then
  pass "24 terminal points, which is the inventory this landed against"
else
  fail "$n_terminal terminal points, not 24 — the inventory moved; change it here deliberately"
fi
fi

# ---------------------------------------------------------------- N2
# The format lives in the skill and nowhere else under templates/. Call sites
# reference it; they never restate the four fields.
#
# Catches: the drift that had ALREADY happened — three hand-written hand-back
# blocks in three different shapes, in three of twenty-four terminal points.
FIELDS='**Landed**
**Yours now**
**Next command**
**This session or a fresh one**'

if want N2; then
banner "N2 · the four fields live in the skill and nowhere else under templates/"

# Anchor first: if the fields have left the skill, the guard below would pass
# while guarding nothing.
missing=""
while IFS= read -r m; do
  grep -qF "$m" "$NEXT" 2>/dev/null || missing="$missing [$m]"
done <<FIELDEOF
$FIELDS
FIELDEOF
if [ -z "$missing" ]; then pass "the skill states all four field names"
else fail "field names left the skill:$missing — the guard below is guarding nothing"; fi

# One field name in passing is prose; two is the format restated. Same rule as A4.
clean=yes
while IFS= read -r f; do
  [ "$f" = "$NEXT" ] && continue
  n=0; found=""
  while IFS= read -r m; do
    if grep -qF "$m" "$f"; then n=$((n+1)); found="$found [$m]"; fi
  done <<FIELDEOF
$FIELDS
FIELDEOF
  rel="${f#"$REPO"/}"
  if [ "$n" -ge 2 ]; then
    fail "$rel restates the block's fields:$found — reference the skill instead"
    clean=no
  fi
done <<FILEEOF
$(find "$TEMPLATES" -name '*.md' -type f | sort)
FILEEOF
[ "$clean" = "yes" ] && pass "no template outside the skill restates the four fields"
fi

# ---------------------------------------------------------------- N3
# Every command a next step names actually ships. Two halves: the skill's own
# examples resolve to template units, and no command or skill sends the user to
# one of the two commands the flow catalogue lists but templates/commands/ does
# not carry.
#
# Catches: the /close-ticket class of error — a next step pointing at something
# the install does not have, which sends the user looking for a file. An AGENT may
# still say which command owns what; a command or skill saying it is a step
# somebody is being told to take.
CATALOGUE_ONLY='close-ticket confirm-deployment'

if want N3; then
banner "N3 · every command a next step names actually ships"
if command -v python3 >/dev/null 2>&1; then
  mkdir -p "$SCRATCH"
  ( cd "$REPO" && python3 install-lib.py discover templates "$SCRATCH/fakehome" ) \
    > "$SCRATCH/discover-n3.json" 2> "$SCRATCH/discover-n3.err"
  chk $? "install-lib.py discover runs (errors in $SCRATCH/discover-n3.err)"

  # The same /command regex install-lib.py links edges with, so this asks the
  # question the installer will answer rather than a lookalike of it.
  N3="$(cd "$REPO" && python3 -c '
import json, re, sys
units = json.load(open(sys.argv[1]))
names = {u.split(":", 1)[1] for u in units if u.split(":", 1)[0] in ("command", "skill")}
body = open("templates/skills/next-steps/SKILL.md", encoding="utf-8").read()
refs = sorted(set(re.findall(r"(?<![\w./-])/([a-z][a-z0-9-]+)", body)))
print("refs %d" % len(refs))
for r in refs:
    if r not in names:
        print("GHOST /" + r)
' "$SCRATCH/discover-n3.json" 2>/dev/null)"

  case "$N3" in *"refs 0"*|"")
    fail "the skill names no command at all — N3 asserted nothing, so it proves nothing" ;;
  *) pass "$(printf '%s\n' "$N3" | sed -n 's/^refs /commands named in the skill: /p')" ;; esac

  if printf '%s\n' "$N3" | grep -q '^GHOST '; then
    printf '%s\n' "$N3" | sed -n 's/^GHOST /          not a template unit: /p'
    fail "the skill names a command that does not ship — the user goes looking for it"
  else
    pass "every command the skill names is a template unit"
  fi
else
  printf '    SKIP  python3 — NOT INSTALLED on this machine, so half of N3 NOT run\n'
fi

clean=yes
for stem in $(stems "$COMMANDS") $(skill_dirs); do
  f="$(terminal_file "$stem")"
  [ -f "$f" ] || continue
  for c in $CATALOGUE_ONLY; do
    if grep -qF "/$c" "$f"; then
      fail "$stem names /$c, which the catalogue lists and templates/commands/ does not ship"
      clean=no
    fi
  done
done
[ "$clean" = "yes" ] && pass "no command or skill sends the user to a catalogue-only command"
fi

# ---------------------------------------------------------------- N4
# The installer edge resolves. Assert the EDGE, not the install: every terminal
# unit carries skill:next-steps in its needs, which is what pulls the skill in
# behind any selection holding one of them — preset_minimal included, through
# command:start-ticket.
#
# Catches: a reword that breaks the backtick match, leaving 24 call sites pointing
# at a skill that was never installed. That fails silently: a missing skill is not
# an error, it is an absence.
if want N4; then
banner "N4 · discover puts skill:next-steps in every terminal unit's needs"
if command -v python3 >/dev/null 2>&1; then
  mkdir -p "$SCRATCH"
  ( cd "$REPO" && python3 install-lib.py discover templates "$SCRATCH/fakehome" ) \
    > "$SCRATCH/discover-n4.json" 2> "$SCRATCH/discover-n4.err"
  chk $? "install-lib.py discover runs (errors in $SCRATCH/discover-n4.err)"

  EDGES="$(python3 -c '
import json, sys
u = json.load(open(sys.argv[1]))
print("theunit" if "skill:next-steps" in u else "nounit")
for uid in sorted(u):
    if "skill:next-steps" in u[uid]["needs"]:
        print("edge " + uid)
' "$SCRATCH/discover-n4.json" 2>/dev/null)"

  case "$EDGES" in *theunit*)
    pass "skill:next-steps is a discovered unit" ;;
  *) fail "skill:next-steps is NOT a discovered unit" ;; esac

  for stem in $(stems "$COMMANDS") $(skill_dirs); do
    [ "$(terminal_class "$stem")" = "terminal" ] || continue
    uid="$(terminal_uid "$stem")"
    case "$EDGES" in *"edge $uid"*)
      pass "$uid needs skill:next-steps" ;;
    *)
      fail "$uid does NOT need skill:next-steps — install it alone and its hand-back points at nothing" ;;
    esac
  done
else
  printf '    SKIP  python3 — NOT INSTALLED on this machine, so N4 NOT run\n'
fi
fi

# ---------------------------------------------------------------- tally
printf '\n=== %s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" != "0" ]; then
  printf '\nfailed:\n'
  for n in "${FAILED_NAMES[@]}"; do printf '  - %s\n' "$n"; done
  exit 1
fi
exit 0
