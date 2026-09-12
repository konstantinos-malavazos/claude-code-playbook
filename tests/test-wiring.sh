#!/usr/bin/env bash
# Wiring scrub. Two wirings live here, both the same shape — one definition, many
# call sites — and both failing OPEN when a call site drifts:
#
#   A1-A9  the per-dispatch model weight (issue #92)
#   A10    the Serena halt block every navigating agent needs (issue #109)
#   A11    the two model-id tokens are lowercase and reach a live install (issue #135)
#   A12    the flow guardrails are stated where the dispatcher reads them (issue #148)
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
# rule. The threshold clause carries the one concrete number in the whole design
# and is fatal on its own — it exists only for the skill, so a second copy is a
# second threshold, and it going missing means the number was silently re-blanked.
#
# The last two markers are #135's addition. The skill gained a SECOND body of
# content — the id-to-tier alias table — and the original four markers are the
# CLASSIFICATION criteria only, so A4 was guarding half the file it guards. Both
# strings come from the table's header row, so a template that copies the header
# scores 2 and is caught on its own. The row regex below covers the other half:
# copying the ROWS without the header. That is the real freeze risk here — the
# alias set is a fact about the harness, not about this playbook, and a second
# copy of it rots silently, which is exactly what A4 exists to stop.
MARKERS='placeholder seam
multiple callers
more than one repo
several findings against one track
the model id contains
dispatch alias'
FATAL_MARKER='touches **more than 3 files**'
# An id-to-alias row: first two cells carrying the same family word. Prose that
# merely mentions sonnet cannot match it; a copied table row cannot avoid it.
FATAL_ROW_RE='^\|[^|]*sonnet[^|]*\|[^|]*sonnet[^|]*\|'

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
grep -qE "$FATAL_ROW_RE" "$SKILL" 2>/dev/null || missing="$missing [id-to-alias row]"
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
  if grep -qE "$FATAL_ROW_RE" "$f"; then
    fail "$rel carries an id-to-alias table row — a second copy of the alias set"
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

# ---------------------------------------------------------------- A11
# Catches: issue #135. The two model-id placeholders shipped UPPERCASE, which
# is this repo's reserved namespace for prose the installer must never fill —
# so even a working fill mechanism could never reach them. And a filled-in id
# is not itself usable: the dispatch `model:` field takes a tier alias, never
# a full id (docs/shared/07-the-flows.md), so a table has to map one to the
# other, and the three commands have to point at it.
if want A11; then
banner "A11 · the model-id tokens are lowercase and a live install can act on them"

# A11a — Catches: the tokens still living in the UPPERCASE, never-fill
# namespace anywhere under templates/.
if grep -rlE '<MODEL-(CHEAP|STRONG)-ID>' "$TEMPLATES" >/dev/null 2>&1; then
  fail "A11a: <MODEL-CHEAP-ID> / <MODEL-STRONG-ID> appear nowhere under templates/"
else
  pass "A11a: <MODEL-CHEAP-ID> / <MODEL-STRONG-ID> appear nowhere under templates/"
fi

# A11b — Catches: a command that drops one of the two ids while rewriting the
# light/heavy arms. Each of the three dispatch sites must reference BOTH
# backticked tokens, exactly once each.
A11B_MISSING=""
for c in start-ticket fix-ticket build-chart-ticket; do
  f="$COMMANDS/$c.md"
  if [ ! -f "$f" ]; then A11B_MISSING="$A11B_MISSING $c(missing-file)"; continue; fi
  # shellcheck disable=SC2016
  n_strong=$(grep -oF -- '`<strong-model-id>`' "$f" 2>/dev/null | wc -l | tr -d ' ')
  # shellcheck disable=SC2016
  n_fast=$(grep -oF -- '`<fast-model-id>`' "$f" 2>/dev/null | wc -l | tr -d ' ')
  [ "$n_strong" = "1" ] || A11B_MISSING="$A11B_MISSING $c(strong=$n_strong)"
  [ "$n_fast" = "1" ] || A11B_MISSING="$A11B_MISSING $c(fast=$n_fast)"
done
chk "$([ -z "$A11B_MISSING" ] && echo 0 || echo 1)" \
   "A11b: all three commands reference \`<strong-model-id>\` and \`<fast-model-id>\` exactly once (missing:${A11B_MISSING:- none})"

# A11c — Anchor first (the A4 shape): assert the id-to-tier table lives in
# SKILL.md BEFORE asserting the three commands reference it, so the guard
# below can never pass while guarding nothing. The ORDER is the important half
# and does not change: the anchor is checked first, and both assertions fail in
# the else arm, so the guard can never pass over a missing table.
#
# The anchor is the MAPPING, not the word. `\|.*sonnet.*\|` matched any table row
# anywhere in the skill that happened to name sonnet — the table could have been
# replaced wholesale by an unrelated row and the anchor would still have held.
# Assert the two things that make it a mapping: the header cell that names what
# the left column is, and a row whose FIRST TWO cells both carry the same family
# word, which is what an id-to-alias row looks like and what a prose mention
# never does.
A11C_ANCHOR=0
grep -qF 'the model id contains' "$SKILL" 2>/dev/null || A11C_ANCHOR=1
grep -qE '^\|[^|]*sonnet[^|]*\|[^|]*sonnet[^|]*\|' "$SKILL" 2>/dev/null || A11C_ANCHOR=1
if [ "$A11C_ANCHOR" = "0" ]; then
  pass "A11c: an id-to-tier mapping row (not just the word sonnet) exists in SKILL.md"
  A11C_MISSING=""
  for c in start-ticket fix-ticket build-chart-ticket; do
    f="$COMMANDS/$c.md"
    # The two words must be in the SAME pointer sentence, not merely both
    # present somewhere in the file — `dispatch-weight` is named several times
    # for unrelated reasons, so a bare co-occurrence test guards nothing.
    # Newlines are flattened first: the sentence wraps in two of the three. CRs are
    # stripped BEFORE the flatten — on Windows the wrap is "\r\n", so flattening
    # newlines alone leaves a stray \r inside the span this pattern has to cross.
    if [ -f "$f" ] && tr -d '\r' <"$f" | tr '\n' ' ' \
         | grep -qE 'id-to-tier mapping[^.]*dispatch-weight'; then
      :
    else
      A11C_MISSING="$A11C_MISSING $c"
    fi
  done
  chk "$([ -z "$A11C_MISSING" ] && echo 0 || echo 1)" \
     "A11c: all three commands point at the SKILL.md mapping (missing:${A11C_MISSING:- none})"
else
  fail "A11c: an id-to-tier mapping row (not just the word sonnet) exists in SKILL.md — the guard below would be guarding nothing"
  fail "A11c: all three commands point at the SKILL.md mapping (skipped — anchor missing)"
fi
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

# ---------------------------------------------------------------- A10
# The halt block is the only defence that survives a renamed `mcp__` prefix. An
# agent whose Serena names do not resolve is not told so: they are stripped at
# launch with no error, and it runs on Read and Grep and produces an answer of
# exactly the normal SHAPE. templates/agents/README.md records @repo-reviewer
# doing that before the halt blocks existed, and issue #109 found that
# @fixer-planner had never been given one.
#
# Derived, not listed: the set is every agent whose `tools:` names a Serena
# navigation verb, so the next Serena-using agent is covered the day it lands.
# Probed by VERB rather than by the `mcp__serena__` prefix, for the same reason
# EDIT_VERBS is — an install that rewrites the prefix must not blind the check.
#
# Catches: a Serena-declaring agent with no halt instruction.
serena_agents() {
  local stem
  stems "$AGENTS" | while read -r stem; do
    fm_field "$AGENTS/$stem.md" tools | grep -qF 'find_symbol' && printf '%s
' "$stem"
  done
}
SERENA_AGENTS="$(serena_agents)"

if want A10; then
banner "A10 · every Serena-declaring agent carries a halt block"
# Same positive control as A1: a probe that matches nothing would pass this
# section by finding no agents to fail.
if [ -n "$SERENA_AGENTS" ]; then
  pass "the Serena-verb probe matches something at all"
else
  fail "the Serena-verb probe matched NOTHING — the probe is broken, not the tree"
fi
for stem in $SERENA_AGENTS; do
  if grep -qF 'HALTED' "$AGENTS/$stem.md"; then
    pass "$stem halts when Serena is missing"
  else
    fail "$stem declares Serena verbs and never says HALTED — strip the prefix and it greps instead"
  fi
done
fi

# ---------------------------------------------------------------- A12
# The flow guardrails (#148). Five rules — a stated persona on every dispatch, an
# explicit timeout with a per-call expectation, a concrete overrun trigger whose
# answer is report-and-stop, delta-scoped and risk-proportional review, and the
# duty to check on work you spawned — all of them prose, in the template the
# dispatcher actually reads. Prose is what a shortening edit removes first, and
# nothing else in this repo reads these sentences: a rule that quietly leaves is
# a rule that was never there, and the session that dispatches without it
# produces a result of exactly the normal SHAPE.
#
# WHAT THESE CASES PROVE, PRECISELY, because the difference is the whole
# disclosure this ticket owes its reader:
#   A12.1-A12.7  prove A RULE IS WRITTEN, at the site the dispatcher reads. They
#                cannot prove any agent obeyed it. In particular A12.5 proves the
#                check-back duty is STATED at every site that spawns background
#                work — never that anybody checked. There is no elapsed-time
#                event for a hook to fire on, so that half is prose by design.
#   A12.8        proves BEHAVIOUR, and it is the only case here that does: it
#                reads the shipped wiring and asserts that every installable hook
#                is named in both settings files AND sits under the event and the
#                matcher its own header declares it needs. A hook nobody names is
#                wired into nothing; a hook named under the wrong matcher is ALSO
#                wired into nothing, and the second one is the quieter of the two.
#                Both are facts about the tree, not about anyone's wording.
#
#                THE BOUNDARY, because this case is the one that could overclaim:
#                A12.8 judges the SHIPPED SNIPPETS, which are the expectation the
#                installer merges from. It says nothing about any particular
#                user's settings.json — comparing a real install against the
#                snippet is verify_wiring's job at install time
#                (install-lib.py:1131-1203), and duplicating it here would assert
#                a machine this suite cannot see. What this guards is the other
#                half: that the expectation ITSELF cannot rot.
#
# Catches: a reword or a trim that drops the persona rule, the timeout duty, the
# overrun trigger, one of the three review-scoping rules or the check-back
# clause; a new hook file that ships wired into neither settings snippet; and a
# matcher narrowed back to one shell, which leaves every suite green while the
# guard stops covering the tool the user actually types into.

# joined FILE — the whole file as ONE line, with markdown emphasis removed.
# Both halves are load-bearing and both were bitten while this section was
# written. Several of the anchors below WRAP across a line break in the shipped
# text, so a line-oriented grep -qF for the sentence finds nothing and the case
# goes red for a reason that has nothing to do with the rule; and every .md in
# this repo is CRLF, so an unstripped carriage return lands in the middle of a
# joined anchor and does the same thing more quietly. The emphasis strip is what
# lets the anchors below be written as the prose a reader would quote, rather
# than as a copy of somebody's asterisks. (\140 is the backtick, spelled in
# octal on purpose: a literal one inside a quoted string reads to shellcheck as
# a command substitution — SC2016 — and this repo has already lost an hour to
# that once.)
joined() { tr -d '\r*\140' < "$1" | tr '\n' ' ' | tr -s ' \t'; }

# a12 NAME FILE ANCHOR — one anchor, one PASS/FAIL line. Every case gets its own
# name, because a combined case cannot say WHICH rule was deleted.
a12() {
  if joined "$2" | grep -qF "$3"; then pass "$1"
  else fail "$1 — GONE from ${2#"$REPO"/}: [$3]"; fi
}

A12_AGENTS_README="$AGENTS/README.md"
A12_REVIEWER="$AGENTS/repo-reviewer.md"
A12_HOOKS_README="$TEMPLATES/hooks/README.md"
A12_SHIM='usr/bin/bash.exe'
A12_SHIM_ANCHOR='hooks/README.md#do-not-kill-a-slow-run-on-windows'

# Every template that fires background work, DERIVED rather than listed. The
# three commands are the obvious members and they are half the set: the
# definition the commands wrap lives in a skill, and a commands-only predicate
# guards half the ticket. Matched on the dispatch itself — a research subagent
# being fired — so the next flow that fires one is covered the day it lands.
a12_bg_sites() {
  local f
  while IFS= read -r f; do
    joined "$f" | grep -qE '/research subagent|research skill.s discipline|research subagents' \
      && printf '%s\n' "$f"
  done <<EOF
$(find "$COMMANDS" "$TEMPLATES/skills" -name '*.md' -type f | sort)
EOF
}

# Every .md under templates/ and docs/ that talks about a slow run, minus the one
# file that owns the mechanism. These are the files that must LINK rather than
# re-explain.
a12_shim_namers() {
  local f
  while IFS= read -r f; do
    [ "$f" = "$A12_HOOKS_README" ] && continue
    joined "$f" | grep -qF 'slow run' && printf '%s\n' "$f"
  done <<EOF
$(find "$TEMPLATES" "$REPO/docs" -name '*.md' -type f | sort)
EOF
}

if want A12; then
banner "A12 · flow guardrails are stated where the dispatcher reads them"

# --- A12.1 · AC1, the persona rule and its third answer
a12 "A12.1 · the persona rule is stated in templates/agents/README.md" \
    "$A12_AGENTS_README" 'Every dispatch states a persona'
# The third answer is what keeps an untyped dispatch legitimate and is the reason
# no research agent template exists to be preferred over the skill. Lose it and
# the rule reads as "always use a typed template", which no flow here obeys.
a12 "A12.1 · the persona rule keeps its third answer — a role line AND a named skill" \
    "$A12_AGENTS_README" 'state the role in one line AND name the skill that supplies its discipline'

# --- A12.2 · AC5, the timeout duty
a12 "A12.2 · a long call carries an explicit timeout and a stated expectation" \
    "$A12_AGENTS_README" 'A call you expect to run long carries an explicit timeout'
a12 "A12.2 · work past the tool's maximum goes to the background by design" \
    "$A12_AGENTS_README" 'goes to the background by design'

# --- A12.3 · AC6, the overrun trigger, stated ONCE
# A census rather than a presence check, and for the reason A4 is a census: two
# copies of a threshold are two thresholds the day one of them is edited.
A12_TRIGGER='three times the stated expectation, or ten minutes, whichever comes first'
n=0; where=""
while IFS= read -r f; do
  joined "$f" | grep -qF "$A12_TRIGGER" || continue
  n=$((n+1)); where="$where ${f#"$REPO"/}"
done <<EOF
$(find "$TEMPLATES" -name '*.md' -type f | sort)
EOF
if [ "$n" = "1" ]; then
  pass "A12.3 · the overrun trigger is stated exactly once under templates/ —$where"
elif [ "$n" = "0" ]; then
  fail "A12.3 · the overrun trigger is stated NOWHERE under templates/ — nothing says when a wait has gone wrong"
else
  fail "A12.3 · the overrun trigger is stated $n times under templates/ —$where — a second copy is a second threshold"
fi
a12 "A12.3 · the required response to an overrun is report-and-stop" \
    "$A12_AGENTS_README" 'The required response is report-and-stop'

# --- A12.4 · AC3, the three review-scoping rules
# Three anchors, three PASS/FAIL lines, deliberately. One combined case goes red
# without saying which of the three was deleted, and the three fail for entirely
# different reasons.
a12 "A12.4 · repo-reviewer scopes the review to the delta" \
    "$A12_REVIEWER" 'Scope to the delta.'
a12 "A12.4 · repo-reviewer takes its depth from the weight the work already carries" \
    "$A12_REVIEWER" 'Depth is proportional to the weight the work already carries'
a12 "A12.4 · repo-reviewer prefers running a check to reasoning about one" \
    "$A12_REVIEWER" 'Prefer running a check to reasoning about one.'

# --- A12.5 · AC2 + AC7, every site that spawns background work
A12_SITES="$(a12_bg_sites)"
# The INVENTORY is the tripwire, the way A1's EXPECTED_EDITORS is. A floor is not
# enough here and the first version of this case had one: a site that rewords the
# dispatch phrase drops out of the derived set AND TAKES ITS TWO ASSERTIONS WITH
# IT, so the section quietly shrinks from six sites to five and still reports
# green. Nothing fails, and the whole premise of A12.5 is that nobody re-reads
# these files. Comparing the derived set against the expected one by NAME means
# losing one site fails, and gaining one fails too until somebody adds it here —
# which is the point: a new flow that fires background work is a new place the
# persona and check-back rules have to be stated.
A12_EXPECTED_SITES="templates/commands/feeling-lucky.md
templates/commands/resume-massive.md
templates/commands/start-massive.md
templates/skills/charting/SKILL.md
templates/skills/grilling/SKILL.md
templates/skills/pitch/SKILL.md"
A12_SITE_N="$(printf '%s\n' "$A12_SITES" | sed '/^$/d' | wc -l | tr -d ' ')"
A12_SITES_REL=""
for f in $A12_SITES; do A12_SITES_REL="$A12_SITES_REL ${f#"$REPO"/}"; done
if [ "$(setlike "$A12_SITES_REL")" = "$(setlike "$A12_EXPECTED_SITES")" ]; then
  pass "A12.5 · the background-dispatch probe found exactly the $A12_SITE_N sites this section expects"
else
  fail "A12.5 · the background-dispatch set has MOVED — derived [$(setlike "$A12_SITES_REL")] against expected [$(setlike "$A12_EXPECTED_SITES")]. A site that leaves the set takes its two assertions with it and nothing else notices"
fi
for f in $A12_SITES; do
  rel="${f#"$REPO"/}"
  # AC2 — this dispatch says who the agent is. Matched on the WORD, not the
  # substring: the red run for this case found "persona" matching "personal
  # data" in pitch/SKILL.md, so one of the six passed on the pre-change tree for
  # a reason with nothing to do with the rule. A case that green for the wrong
  # reason is indistinguishable from a case that is pointed at nothing.
  if joined "$f" | grep -qE '\bpersona\b'; then
    pass "A12.5 · $rel states a persona for the work it spawns"
  else
    fail "A12.5 · $rel spawns background work and names no persona — a bare dispatch, and the handoff will not say which one you got"
  fi
  # AC7 — and somebody owns looking at it. PROVES THE RULE IS WRITTEN, never
  # that anyone looked; there is no elapsed-time event to hang a hook on.
  if joined "$f" | grep -qF 'at each multiple of'; then
    pass "A12.5 · $rel states the check-back duty on the work it spawns"
  else
    fail "A12.5 · $rel spawns background work and never says to check on it — the harness reports completion and never silence, so a dead agent and a working one read the same"
  fi
done

# --- A12.6 · AC4, the skill this ticket deliberately does not create
if [ -d "$TEMPLATES/skills/review-guidelines" ]; then
  fail "A12.6 · templates/skills/review-guidelines/ EXISTS — #139 owns that name, and repo-reviewer.md's dangling reference to it is deliberate until then"
else
  pass "A12.6 · no templates/skills/review-guidelines/ — #139 still owns the name"
fi

# --- A12.7 · AC8, the shim rule: stated once, linked from everywhere else
a12 "A12.7 · templates/hooks/README.md still states the shim mechanism" \
    "$A12_HOOKS_README" "$A12_SHIM"
a12 "A12.7 · the shim rule has a heading to link to" \
    "$A12_HOOKS_README" '### Do not kill a slow run on Windows'
n=0; where=""
while IFS= read -r f; do
  joined "$f" | grep -qF "$A12_SHIM" || continue
  n=$((n+1)); where="$where ${f#"$REPO"/}"
done <<EOF
$(find "$TEMPLATES" "$REPO/docs" -name '*.md' -type f | sort)
EOF
if [ "$n" = "1" ]; then
  pass "A12.7 · the shim mechanism is explained in exactly one file —$where"
else
  fail "A12.7 · the shim mechanism is explained in $n files —$where — the one place #146 put it was the point"
fi
A12_NAMERS="$(a12_shim_namers)"
A12_NAMER_N="$(printf '%s\n' "$A12_NAMERS" | sed '/^$/d' | wc -l | tr -d ' ')"
# The control that makes the loop below mean anything. Before this ticket NOTHING
# in the repo linked to that file by anchor, so the set was empty and "every
# other file links to it" was true of nobody.
#
# SAID PLAINLY, BECAUSE A SET OF ONE IS WORTH DISCLOSING: today this binds exactly
# ONE file. That is not a weak predicate hiding members — it is the tree. The shim
# is discussed in two places in the whole repo, the owner and the one file that
# links to it, and every wider predicate available was measured and rejected:
# `stuck` pulls in five files about stuck tickets and stuck decisions, none of
# which is about this subject or should be made to link here. So the set cannot be
# made real by rewording the probe; it becomes real when a third file discusses
# the subject, and the control above is what stops it silently returning to zero
# in the meantime. The failure that actually matters — a second COPY of the
# mechanism rather than a link to it — is caught by the census above, which does
# not depend on this predicate at all.
if [ "${A12_NAMER_N:-0}" -ge 1 ]; then
  pass "A12.7 · $A12_NAMER_N file(s) other than the owner talk about a slow run, so the link rule has somebody to bind"
else
  fail "A12.7 · no file outside the owner mentions a slow run — the link rule below is guarding an empty set"
fi
for f in $A12_NAMERS; do
  rel="${f#"$REPO"/}"
  if joined "$f" | grep -qF "$A12_SHIM_ANCHOR"; then
    pass "A12.7 · $rel links to the shim rule instead of restating it"
  else
    fail "A12.7 · $rel talks about a slow run and does not link to $A12_SHIM_ANCHOR — the second copy starts here"
  fi
done

# --- A12.8 · AC5's mechanism is actually wired, in BOTH settings files
# The only case in this section that proves behaviour rather than wording. A hook
# is a file plus an entry; a file with no entry is never invoked and reports
# nothing, which is the failure shape templates/hooks/README.md calls the worst
# one a guardrail has. SKIP_HOOKS is read out of the installer itself, the way
# tests/test-docs.sh derives the same set, so a hook the installer stops wiring
# stops being asserted here without anyone editing this file. Pure bash on
# purpose: tests/test-docs.sh exits early with a SKIP when there is no python,
# and this check has to run on the machine that has none.
A12_WIRINGS="$TEMPLATES/hooks/settings-hooks.snippet.json $TEMPLATES/mcp/settings.json.snippet"
A12_SKIP="$(sed -n 's/^SKIP_HOOKS[[:space:]]*=[[:space:]]*{\(.*\)}.*/\1/p' "$REPO/install-lib.py" \
            | tr -d '" ' | tr ',' ' ')"
if [ -n "$A12_SKIP" ]; then
  pass "A12.8 · SKIP_HOOKS parsed out of install-lib.py: $A12_SKIP"
else
  fail "A12.8 · SKIP_HOOKS did not parse out of install-lib.py — the set below is being derived from nothing"
fi
A12_WIRED=""
for f in "$TEMPLATES"/hooks/*.sh; do
  b="$(basename "$f")"
  case " $A12_SKIP " in *" $b "*) continue ;; esac
  A12_WIRED="$A12_WIRED $b"
done
A12_WIRED_N="$(printf '%s' "$A12_WIRED" | wc -w | tr -d ' ')"
# Second control: an empty or one-member set would pass the loop by having
# nothing to check, which is how this assertion would rot into a no-op.
if [ "${A12_WIRED_N:-0}" -ge 2 ]; then
  pass "A12.8 · $A12_WIRED_N installable hook scripts to check against both settings files"
else
  fail "A12.8 · only ${A12_WIRED_N:-0} installable hook script(s) found — the derivation is broken, not the wiring"
fi
for b in $A12_WIRED; do
  for w in $A12_WIRINGS; do
    wrel="${w#"$REPO"/}"
    if grep -qF "$b" "$w"; then
      pass "A12.8 · $b is wired in $wrel"
    else
      fail "A12.8 · $b is in templates/hooks/ and appears nowhere in $wrel — it installs, it never runs, and nothing says so"
    fi
  done
done

# --- A12.8, second half · and under the matcher the hook itself asks for
#
# Being NAMED in the wiring is not being wired. Wiring is the triple (event,
# matcher, command), and a hook whose command sits under the wrong matcher is
# installed, listed, reported present, and never invoked by the tool it exists to
# guard. That is the failure shape templates/hooks/README.md calls the worst one a
# guardrail has, because it keeps reporting success — and it is reachable by an
# edit as small as deleting one alternative from one string.
#
# THE EXPECTATION IS THE HOOK'S OWN HEADER, and that is deliberate. Nothing here
# hardcodes a matcher, so a hook added tomorrow is covered the day it lands with
# no edit to this file — the same property install-lib.py's verify_wiring gets by
# treating the shipped snippet as the expectation. What this adds is the layer
# underneath it: verify_wiring asks whether a machine matches the snippet, and
# nothing until now asked whether the SNIPPET matches what the hooks say they need.
#
# Matchers compare as SETS of alternatives, never as strings, for the same reason
# verify_wiring does: widening Bash|PowerShell to Bash|PowerShell|Foo still covers
# every hook that asked for the two shells and must not be flagged. Only a MISSING
# alternative is a finding.
a12_placements() { # FILE -> "event<TAB>matcher<TAB>hookfile" per wired command
  awk '
    {
      if (match($0, /"[A-Za-z]+"[[:space:]]*:[[:space:]]*\[/)) {
        k = substr($0, RSTART + 1); sub(/".*/, "", k)
        if (k != "hooks") { ev = k; matcher = "" }
      }
      if (match($0, /"matcher"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
        m = substr($0, RSTART, RLENGTH)
        sub(/^"matcher"[[:space:]]*:[[:space:]]*"/, "", m); sub(/"$/, "", m)
        matcher = m
      }
      if (match($0, /hooks\/[A-Za-z0-9_-]+\.sh/)) {
        h = substr($0, RSTART, RLENGTH); sub(/^hooks\//, "", h)
        printf "%s\t%s\t%s\n", ev, matcher, h
      }
    }' "$1"
}

# a12_declares HOOKFILE -> "EVENT<TAB>alt alt …", read off the header line every
# hook in this directory already carries: `# <Event> hook (matcher: A / B).`
a12_declares() {
  # Two forms, in this order. A hook with no matcher at all (SessionEnd) is legal
  # and gets its event checked and nothing else; the second expression is what
  # reads it, and it must not also swallow the first form — it cannot, because
  # sed applies them in sequence to a line the first one has already rewritten.
  sed -n '1,4p' "$1" | sed -n \
    's/^#[[:space:]]*\([A-Za-z]*\)[[:space:]]hook[[:space:]]*(matcher:[[:space:]]*\([^)]*\)).*/\1\t\2/p;
     s/^#[[:space:]]*\([A-Za-z]*\)[[:space:]]hook[.,[:space:]].*/\1\t/p' | head -1
}

A12_CHECKABLE=0
A12_PROSE=""
for b in $A12_WIRED; do
  decl="$(a12_declares "$TEMPLATES/hooks/$b")"
  want_ev="${decl%%	*}"
  want_alts="$(printf '%s' "${decl#*	}" | tr '/' ' ' | tr -s ' ')"
  if [ -z "$want_ev" ]; then
    fail "A12.8 · $b declares no event in its header — nothing states what this hook needs to be wired to, so nothing can check it"
    continue
  fi
  # A matcher written as prose rather than as tool names cannot be compared to a
  # matcher string. Named out loud rather than skipped in silence: a check that
  # quietly drops its awkward members is how a gate ends up guarding the easy half.
  plain=yes
  for alt in $want_alts; do
    case "$alt" in *[!A-Za-z0-9_]*|"") plain=no ;; esac
  done
  if [ -n "$want_alts" ] && [ "$plain" = "no" ]; then
    A12_PROSE="$A12_PROSE $b"
  fi
  [ "$plain" = "yes" ] && [ -n "$want_alts" ] && A12_CHECKABLE=$((A12_CHECKABLE+1))
  for w in $A12_WIRINGS; do
    wrel="${w#"$REPO"/}"
    got="$(a12_placements "$w" | awk -F'\t' -v h="$b" '$3 == h {print $1 "\t" $2; exit}')"
    [ -n "$got" ] || continue     # not named at all — the loop above already failed it
    got_ev="${got%%	*}"
    got_matcher="${got#*	}"
    if [ "$got_ev" != "$want_ev" ]; then
      fail "A12.8 · $b asks for $want_ev and $wrel wires it under $got_ev — it will fire on the wrong event, or never"
      continue
    fi
    if [ -z "$want_alts" ] || [ "$plain" = "no" ]; then
      # Reported rather than passed over in silence: its event WAS checked, and
      # saying which half ran is the difference between a gap and a blind spot.
      pass "A12.8 · $b is wired under $got_ev in $wrel, the event it declares (no comparable matcher declared)"
      continue
    fi
    missing=""
    for alt in $want_alts; do
      case "|$got_matcher|" in
        *"|$alt|"*) ;;
        *) missing="$missing $alt" ;;
      esac
    done
    if [ -z "$missing" ]; then
      pass "A12.8 · $b is wired under $got_ev/$got_matcher in $wrel, covering the matcher it declares"
    else
      fail "A12.8 · $b declares it guards [$want_alts] and $wrel wires it under $got_ev/$got_matcher — missing:$missing. It installs, it is listed as present, and it never sees the tool it exists to guard"
    fi
  done
done
# Positive control, and it is the one that matters most here: if the header
# parser stops matching, every hook falls into the un-checkable bucket and this
# whole half passes by having found nothing to compare.
if [ "$A12_CHECKABLE" -ge 2 ]; then
  pass "A12.8 · $A12_CHECKABLE hook header(s) declare a matcher this can check against the wiring"
else
  fail "A12.8 · only $A12_CHECKABLE hook header(s) parsed into a checkable matcher — the header parser is broken, not the wiring"
fi
[ -n "$A12_PROSE" ] && pass "A12.8 · matcher declared as prose, event checked but alternatives not comparable:$A12_PROSE"
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
