#!/usr/bin/env bash
# Wiring scrub. Several wirings live here, all the same shape — one definition, many
# call sites — and all failing OPEN when a call site drifts:
#
#   A1-A9  the per-dispatch model weight (issue #92)
#   A10    every navigating agent preloads the code-access skill, which holds the halt block
#   A11    the two model-id tokens are lowercase and reach a live install (issue #135)
#   A12    the flow guardrails are stated where the dispatcher reads them (issue #148)
#   A13    every Serena-declaring agent can activate its project, and code-access says
#          what to do on "No active project"; on route C a wired agent holds per-repo
#          tools and no activate_project, and code-access says so
#   A14    every agent that names a skill it does not preload grants Skill; the
#          TaskStop-only agents do not
#   A15    no slice template mentions a worktree
#   A16    implementation dispatch carries the code-access paragraph, and every editing
#          agent's handoff reports its Serena calls
#   A17    every "dispatch site N" mention agrees with start-ticket.md's numbering
#   A18    no agent template holds Agent in its tools: line, or has no tools: line
#   A19    the context checkpoint runs at every /start-ticket gate, /resume-ticket reads
#          its handoff, and the threshold lives in occupancy.py alone
#   A20    both layer specialists preload <layer>-write-core, and nothing switches it off
#   N1-N4  the end-of-flow next-steps block (issue #104)
#
#   bash tests/test-wiring.sh            # all sections
#   bash tests/test-wiring.sh A1 N2      # only these; an unknown id stops the run (exit 2)
#
# Deterministic and offline: no network, no model, no install. It reads the
# templates and the docs and asserts both wirings are still wired.
#
# WHY THIS EXISTS. The weight is wired across six dispatch sites, one shared skill
# and five weighing agents. None of that survives the
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

# The interpreter candidates are the hooks' own; the first that runs `-c pass` wins. No
# working python leaves $PY empty, and each python-backed section prints its own SKIP.
HOOK_LIB_LOADED=
# shellcheck source-path=SCRIPTDIR source=../templates/hooks/_lib/common.sh
if ! . "$REPO/templates/hooks/_lib/common.sh" || [ "${HOOK_LIB_LOADED-}" != 1 ]; then
    echo "FAIL: $REPO/templates/hooks/_lib/common.sh is missing or did not load — no interpreter list to run with." >&2
    exit 1
fi

PY=""
for _c in ${PY_LIST[@]+"${PY_LIST[@]}"}; do
    if "$_c" -c "pass" >/dev/null 2>&1; then
        PY="$_c"
        break
    fi
done

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

# Every argument must name a section, or it would match no `want` and run nothing,
# green.
if [ "$#" -gt 0 ]; then
    _ids=" $(grep -oE '^if want [[:alnum:]-]+;' "${BASH_SOURCE[0]}" \
             | sed -e 's/^if want //' -e 's/;$//' | sort -u | tr '\n' ' ')"
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

# fm_skills FILE — the skills an agent preloads, one per line, from the inline-list
# form `skills: [a, b]`. A block list reads as empty, so it fails the checks that
# want a name rather than passing them. CRs are stripped first: on Linux awk does
# not, and `---\r` is not a frontmatter fence.
fm_skills() {
  tr -d '\r' < "$1" | awk '/^---$/{n++; next} n==1' | sed -n 's/^skills:[[:space:]]*//p' | head -1 \
    | tr -d "[]\"'" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d'
}

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

# skill_dirs — the skill stems, read off disk the way stems() reads the flat dirs
skill_dirs() {
  local d
  for d in "$TEMPLATES"/skills/*/; do
    [ -d "$d" ] || continue
    basename "$d"
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
    feeling-lucky)                              printf 'not-a-dispatch' ;;
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
WEIGHERS="planner repo-reviewer release-reviewer aligner fixer-planner"

if want A3; then
banner "A3 · the five weighers load the skill and carry a weight line"
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
if [ -n "$PY" ]; then
  mkdir -p "$SCRATCH"
  ( cd "$REPO" && "$PY" install-lib.py discover templates "$SCRATCH/fakehome" ) \
    > "$SCRATCH/discover.json" 2> "$SCRATCH/discover.err"
  chk $? "install-lib.py discover runs (errors in $SCRATCH/discover.err)"

  # One reader, three assertions: the extraction is python's job because the
  # output is JSON, but the verdicts stay in the harness so they tally like
  # every other line here.
  UNITS="$("$PY" -c '
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
  printf '    SKIP  python — no working python3 or python, so A5 NOT run\n'
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
    pass "the table's weighers are exactly A3's: $(setlike "$HANDLES")"
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
if [ -n "$PY" ]; then
  mkdir -p "$SCRATCH"
  ( cd "$REPO" && "$PY" install-lib.py discover templates "$SCRATCH/fakehome" ) \
    > "$SCRATCH/discover-a8.json" 2> "$SCRATCH/discover-a8.err"
  chk $? "install-lib.py discover runs (errors in $SCRATCH/discover-a8.err)"

  # python reports what it found; the verdicts stay in the harness so they tally
  # with every other line here. A backtick reference that is not a shipped skill
  # is not an edge — the installer intersects with what exists on disk, and so
  # does this.
  # The backticks in the regex below are python's, not command substitution.
  # SC2016 sees a single-quoted string with backticks in it and cannot tell.
  # shellcheck disable=SC2016
  A8="$(cd "$REPO" && "$PY" -c '
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
  printf '    SKIP  python — no working python3 or python, so A8 NOT run\n'
fi
fi

# ---------------------------------------------------------------- A9
# Four files under templates/ are GENERATION TEMPLATES, not installables:
# layer-specialist, slice-layer-specialist, engineering-standards and write-core. Each carries
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
# that has stopped being one. And from the other side: a template whose `name:`
# carries <layer> but has no NEVER_INSTALL entry installs as an ordinary unit.
if want A9; then
banner "A9 · the generation templates are not installable units"
if [ -n "$PY" ]; then
  mkdir -p "$SCRATCH"

  rm -rf "$SCRATCH/a9-plant" && mkdir -p "$SCRATCH/a9-plant/skills/probe" \
    && printf -- '---\nname: <layer>-probe\n---\nbody\n' > "$SCRATCH/a9-plant/skills/probe/SKILL.md"

  # python reports what it found; the verdicts stay in the harness, as in A8.
  A9="$(cd "$REPO" && "$PY" -c '
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

# The other direction: a template whose name: carries <layer> and is NOT excluded
# ships as an ordinary unit with an unfilled name.
def fm_name(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    if not lines or lines[0].strip() != "---":
        return ""
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line.startswith("name:"):
            return line[5:].strip()
    return ""

def unguarded(root):
    out = []
    for dirpath, _dirs, files in os.walk(root):
        for f in files:
            path = os.path.join(dirpath, f)
            if not f.endswith(".md") or "<layer>" not in fm_name(path):
                continue
            rel = os.path.relpath(path, root).replace(os.sep, "/")
            if not any(rel == e or rel.startswith(e + "/") for e in lib.NEVER_INSTALL):
                out.append(rel)
    return sorted(out)

for rel in unguarded(templates):
    print("UNGUARDED " + rel)
print("CONTROL " + ("ok" if unguarded(sys.argv[2]) == ["skills/probe/SKILL.md"] else "broken"))
' "$SCRATCH/fakehome-a9" "$SCRATCH/a9-plant" 2>"$SCRATCH/discover-a9.err")"

  if [ -n "$A9" ]; then
    pass "install-lib.py discover runs (errors in $SCRATCH/discover-a9.err)"
  else
    fail "install-lib.py discover produced nothing — see $SCRATCH/discover-a9.err"
  fi

  # An empty NEVER_INSTALL would pass every assertion below while excluding
  # nothing, which is the failure mode this line closes.
  case "$A9" in *"entries 4"*)
    pass "NEVER_INSTALL still names four templates" ;;
  *)
    fail "NEVER_INSTALL no longer names four templates — reclassify, or fix the guard" ;;
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
    pass "none of them is discovered as a unit"
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
    fail "the guard is separator-dependent — under Git Bash every excluded template becomes a unit again" ;;
  esac

  case "$A9" in *"CONTROL ok"*)
    pass "control: a planted <layer> template missing from NEVER_INSTALL is flagged" ;;
  *)
    fail "control: a planted <layer> template missing from NEVER_INSTALL went unflagged — the check below guards nothing" ;;
  esac

  if printf '%s\n' "$A9" | grep -q '^UNGUARDED '; then
    printf '%s\n' "$A9" | sed -n 's/^UNGUARDED /          not in NEVER_INSTALL: /p'
    fail "a template whose name: carries <layer> is installable — it ships as a unit with an unfilled name"
  else
    pass "every template whose name: carries <layer> is in NEVER_INSTALL"
  fi

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
  printf '    SKIP  python — no working python3 or python, so A9 NOT run\n'
fi
fi

# ---------------------------------------------------------------- A10
# The halt block is the only defence that survives a renamed `mcp__` prefix. An
# agent whose Serena names do not resolve is not told so: they are stripped at
# launch with no error, and it runs on Read and Grep and produces an answer of
# exactly the normal SHAPE. The halt block lives in one skill, code-access, and
# every Serena agent preloads it through its `skills:` frontmatter.
#
# The preload and the install edge are separate wirings. `skills:` loads the skill
# at launch; the backticked `code-access` in the body is what gives
# `install-lib.py discover` its agent -> skill edge. Without the edge, an agent
# installed on its own ships with no protocol at all, halt rule included. The two
# generation templates are not units; their edge runs through skill:adapt-to-stack.
#
# A skill whose frontmatter sets disable-model-invocation is not preloaded, and
# nothing reports it: the protocol would vanish from every Serena agent at once.
#
# Derived, not listed: the set is every agent whose `tools:` names a Serena
# navigation verb, so the next Serena-using agent is covered the day it lands.
# Probed by VERB rather than by the `mcp__serena__` prefix, for the same reason
# EDIT_VERBS is — an install that rewrites the prefix must not blind the check.
#
# Catches: a Serena agent that does not preload code-access, a code-access skill
# with no halt block, a lost install edge, an inline protocol copy left in an agent
# to drift, and the flag that switches the preload off.
CODE_ACCESS="$TEMPLATES/skills/code-access/SKILL.md"

serena_agents() {
  local stem
  stems "$AGENTS" | while read -r stem; do
    fm_field "$AGENTS/$stem.md" tools | grep -qF 'find_symbol' && printf '%s\n' "$stem"
  done
}
SERENA_AGENTS="$(serena_agents)"

# a10_inline FILE — does this file carry its own copy of the protocol? The
# "No active project" paragraph is the part every copy had.
a10_inline() { grep -qF 'No active project' "$1"; }

if want A10; then
banner "A10 · every Serena-declaring agent preloads the code-access skill"
# Same positive control as A1: a probe that matches nothing would pass this
# section by finding no agents to fail.
if [ -n "$SERENA_AGENTS" ]; then
  pass "the Serena-verb probe matches something at all"
else
  fail "the Serena-verb probe matched NOTHING — the probe is broken, not the tree"
fi

# A10.a — the preload
for stem in $SERENA_AGENTS; do
  if fm_skills "$AGENTS/$stem.md" | grep -qx 'code-access'; then
    pass "A10.a $stem preloads code-access"
  else
    fail "A10.a $stem declares Serena verbs but its skills: does not list code-access — no halt rule reaches it"
  fi
done

# A10.b — the halt block, in the one place it lives
if [ ! -f "$CODE_ACCESS" ]; then
  fail "A10.b templates/skills/code-access/SKILL.md does not exist — no Serena agent has a halt rule"
elif grep -qF 'HALTED' "$CODE_ACCESS"; then
  pass "A10.b the code-access skill carries a HALTED block"
else
  fail "A10.b the code-access skill never says HALTED — strip the prefix and every Serena agent greps instead"
fi

# A10.c / A10.d — the install edges
if [ -n "$PY" ]; then
  mkdir -p "$SCRATCH"
  ( cd "$REPO" && "$PY" install-lib.py discover templates "$SCRATCH/fakehome-a10" ) \
    > "$SCRATCH/discover-a10.json" 2> "$SCRATCH/discover-a10.err"
  chk $? "A10 install-lib.py discover runs (errors in $SCRATCH/discover-a10.err)"

  # python reports what it found; the verdicts stay in the harness, as in A8.
  A10_EDGES="$(printf '%s\n' "$SERENA_AGENTS" | "$PY" -c '
import json, sys
units = json.load(open(sys.argv[1]))
out = []
for stem in sys.stdin.read().split():
    uid = "agent:" + stem
    if uid in units:
        out.append("EDGE %s %s" % (stem, "yes" if "skill:code-access" in units[uid]["needs"] else "no"))
adapt = units.get("skill:adapt-to-stack")
if adapt is None:
    out.append("ADAPT absent")
else:
    out.append("ADAPT " + ("yes" if "skill:code-access" in adapt["needs"] else "no"))
sys.stdout.buffer.write(("\n".join(out) + "\n").encode("utf-8"))
' "$SCRATCH/discover-a10.json" 2>>"$SCRATCH/discover-a10.err")"

  n=0
  while read -r tag stem verdict; do
    case "$tag" in
      EDGE)
        n=$((n+1))
        if [ "$verdict" = "yes" ]; then
          pass "A10.c installing $stem alone pulls in skill:code-access"
        else
          fail "A10.c $stem does not need skill:code-access — installed alone it ships with no protocol, halt rule included"
        fi
        ;;
      ADAPT)
        case "$stem" in
          yes) pass "A10.d skill:adapt-to-stack needs skill:code-access, so generated specialists get it" ;;
          absent) fail "A10.d skill:adapt-to-stack is not a discovered unit — the generated specialists' edge is gone" ;;
          *) fail "A10.d skill:adapt-to-stack does not need skill:code-access — a generated specialist installs without its protocol" ;;
        esac
        ;;
    esac
  done <<< "$A10_EDGES"
  if [ "$n" -gt 0 ]; then
    pass "A10.c Serena agents checked as installable units: $n"
  else
    fail "A10.c discover returned no Serena agent as a unit — A10.c checked nothing"
  fi
else
  printf '    SKIP  python — no working python3 or python, so A10.c and A10.d NOT run\n'
fi

# A10.e — no agent keeps its own copy of the protocol
mkdir -p "$SCRATCH/a10"
printf 'Serena answers "No active project": activate it and retry\r\n' > "$SCRATCH/a10/inline.md"
printf 'preload code-access and follow it\r\n' > "$SCRATCH/a10/clean.md"
if a10_inline "$SCRATCH/a10/inline.md" && ! a10_inline "$SCRATCH/a10/clean.md"; then
  pass "A10.e the inline-copy probe flags a copy and leaves a clean file alone"
else
  fail "A10.e the inline-copy probe is broken, not the tree"
fi
A10_INLINE=""
for stem in $(stems "$AGENTS"); do
  a10_inline "$AGENTS/$stem.md" && A10_INLINE="$A10_INLINE $stem"
done
if [ -z "$A10_INLINE" ]; then
  pass "A10.e no agent other than README.md carries an inline copy of the protocol"
else
  fail "A10.e inline protocol copies left in:$A10_INLINE — each one drifts from code-access"
fi

# A10.f — nothing switches the preload off
if [ ! -f "$CODE_ACCESS" ]; then
  fail "A10.f templates/skills/code-access/SKILL.md does not exist — a missing skill must not pass as an unflagged one"
elif frontmatter "$CODE_ACCESS" | tr -d '\r' | grep -q '^disable-model-invocation:'; then
  fail "A10.f the code-access skill sets disable-model-invocation — that blocks the skills: preload on every Serena agent, silently"
else
  pass "A10.f the code-access skill leaves disable-model-invocation unset, so the preload loads it"
fi
fi

# ---------------------------------------------------------------- A13
# An agent that declares Serena verbs but cannot call activate_project, or is never
# told what to do when Serena answers "No active project", halts on a state it
# could have recovered from. The instruction lives in the code-access skill. Probed
# by verb, not by the mcp__serena__ prefix, for the same reason as A10.
if want A13; then
banner "A13 · every Serena-declaring agent can activate its project"
if [ -n "$SERENA_AGENTS" ]; then
  pass "A13 the Serena-verb probe matches something at all"
else
  fail "A13 the Serena-verb probe matched NOTHING — the probe is broken, not the tree"
fi
for stem in $SERENA_AGENTS; do
  if fm_field "$AGENTS/$stem.md" tools | grep -qF 'activate_project'; then
    pass "A13.1 $stem declares activate_project"
  else
    fail "A13.1 $stem declares Serena verbs but not activate_project — \"No active project\" halts an agent that could have recovered"
  fi
done
if [ ! -f "$CODE_ACCESS" ]; then
  fail "A13.2 templates/skills/code-access/SKILL.md does not exist — no Serena agent is told what to do on \"No active project\""
elif grep -qF 'No active project' "$CODE_ACCESS" && grep -qF 'activate_project' "$CODE_ACCESS"; then
  pass "A13.2 the code-access skill says what to do on \"No active project\": activate_project, then retry"
else
  fail "A13.2 the code-access skill does not name both \"No active project\" and activate_project — every Serena agent halts instead of activating and retrying"
fi

# A13.3 — route C. Templates stay route A/B shaped, so the check runs on what the
# installer's serena-wire makes of them: one read agent and one edit agent, wired for a
# two-repo map. A route C server is single-project and has no activate_project.
A13W="$SCRATCH/a13"
if [ -z "$PY" ]; then
  printf '    SKIP  A13.3 no working python — route C wiring NOT checked\n'
else
  rm -rf "$A13W" && mkdir -p "$A13W/agents" "$A13W/alpha" "$A13W/beta" \
    && "$PY" - "$AGENTS" "$TEMPLATES/serena/profiles.json" "$A13W" <<'PYA13' > "$A13W/pick.txt"
import json, os, re, shutil, sys
agents, profiles, work = sys.argv[1:4]
prof = json.load(open(profiles, encoding="utf-8"))
edit_only = set(prof["edit"]) - set(prof["read"])
picked = {}
for fn in sorted(os.listdir(agents)):
    if not fn.endswith(".md") or fn == "README.md":
        continue
    text = open(os.path.join(agents, fn), encoding="utf-8").read().replace("\r\n", "\n")
    m = re.search(r"^tools:(.*)$", text.split("\n---\n", 1)[0], re.M)
    verbs = set(re.findall(r"mcp__serena__(\w+)", m.group(1))) if m else set()
    if not verbs:
        continue
    role = "edit" if verbs & edit_only else "read"
    if role not in picked:
        picked[role] = fn
        shutil.copy(os.path.join(agents, fn), os.path.join(work, "agents", role + ".md"))
repos = {k: {"path": os.path.join(work, k).replace("\\", "/"), "port": p}
         for k, p in (("alpha", 9301), ("beta", 9302))}
json.dump({"repos": repos}, open(os.path.join(work, "map.json"), "w", encoding="utf-8"))
json.dump([os.path.join(work, "agents")], open(os.path.join(work, "paths.json"), "w"))
sys.stdout.buffer.write((" ".join("%s=%s" % kv for kv in sorted(picked.items())) + "\n").encode())
PYA13
  chk $? "A13.3 setup: a read agent and an edit agent from the templates ($(tr -d '\r\n' < "$A13W/pick.txt" 2>/dev/null))"
  "$PY" "$REPO/install-lib.py" serena-wire "$A13W/paths.json" "$A13W/map.json" \
    "$TEMPLATES/serena/profiles.json" > "$A13W/wire.out" 2>&1
  chk $? "A13.3 install-lib.py serena-wire wires them for a two-repo map"
  while IFS='|' read -r verdict name; do
    if [ "$verdict" = PASS ]; then pass "A13.3 $name"; else fail "A13.3 $name"; fi
  done < <("$PY" - "$A13W/agents" <<'PYA13C'
import os, re, sys
def say(ok, name):
    sys.stdout.buffer.write(("%s|%s\n" % ("PASS" if ok else "FAIL", name)).encode("utf-8"))
for role, ports in (("read", {9301, 9302}), ("edit", {9311, 9312})):
    path = os.path.join(sys.argv[1], role + ".md")
    if not os.path.exists(path):
        say(False, "%s agent: no template holds this role" % role)
        continue
    text = open(path, encoding="utf-8").read()
    fm = text.split("\n---\n", 1)[0]
    m = re.search(r"^tools:(.*)$", fm, re.M)
    line = m.group(1) if m else ""
    tools = [t.strip() for t in line.split(",") if t.strip()]
    serena = [t for t in tools if t.startswith("mcp__serena")]
    keys = {k.group(1) for k in (re.match(r"^mcp__serena-([a-z0-9-]+)__", t) for t in serena) if k}
    say(bool(line) and "activate_project" not in line,
        "%s agent: no activate_project on its tools: line" % role)
    say(bool(serena) and all(re.match(r"^mcp__serena-(alpha|beta)__\w+$", t) for t in serena),
        "%s agent: every Serena tool is mcp__serena-<key>__" % role)
    say(keys == {"alpha", "beta"}, "%s agent: holds tools for both repos (got %s)" % (role, sorted(keys)))
    say("mcp__serena__" not in text, "%s agent: no mcp__serena__ left anywhere in the file" % role)
    got = {int(p) for p in re.findall(r"^\s+url: http://127\.0\.0\.1:(\d+)/mcp$", fm, re.M)}
    say(got == ports, "%s agent: its servers are on the %s ports %s (got %s)"
        % (role, role, sorted(ports), sorted(got)))
PYA13C
)
fi

# A13.4 — the code-access skill gives route C its own rule: no activate_project there,
# and a down server is started with serena-up.
if [ ! -f "$CODE_ACCESS" ]; then
  fail "A13.4 templates/skills/code-access/SKILL.md does not exist"
else
  if grep -qF 'serena-up' "$CODE_ACCESS"; then
    pass "A13.4 the code-access skill names serena-up, the route C start command"
  else
    fail "A13.4 the code-access skill never names serena-up — a route C agent that finds its server down cannot say how to start it"
  fi
  if tr -d '\r' < "$CODE_ACCESS" | grep -iE 'route c' | grep -qF 'activate_project'; then
    pass "A13.4 the code-access skill says on one line what route C does about activate_project"
  else
    fail "A13.4 no line of the code-access skill names both route C and activate_project — a route C agent retries a tool its server does not have"
  fi
fi
fi

# ---------------------------------------------------------------- A14
# An agent whose body names a skill but whose tools: line does not grant Skill
# cannot load it, and silently falls through to its fallback. A skill the agent
# lists in its own `skills:` frontmatter is preloaded at launch and needs no grant;
# any other skill it names still does.
if want A14; then
banner "A14 · every agent that names a skill it does not preload grants Skill"

a14_tools() {
  tr -d '\r' < "$1" | awk '/^---$/{n++; next} n==1' | sed -n 's/^tools:[[:space:]]*//p' | head -1
}

grants_skill() {
  a14_tools "$1" | tr ',' '\n' | tr -d ' \t\r' | grep -qx 'Skill'
}

# names_skill FILE [PRELOADED] — does FILE name a skill? PRELOADED, a newline list,
# takes those skills' own names out of the match; the standards arms always apply.
names_skill() {
  local skills
  skills="$(skill_dirs | paste -sd '|' -)"
  if [ -n "${2-}" ]; then
    skills="$(skill_dirs | grep -vxF -e "$2" | paste -sd '|' -)"
  fi
  # shellcheck disable=SC2016
  tr -d '\r' < "$1" | grep -qE '`('"$skills"')`|\b('"$skills"') skill\b|standards skill|`[^`]+-standards`'
}

# a14_needs_grant FILE — does this agent name a skill that only a Skill grant can load?
a14_needs_grant() { names_skill "$1" "$(fm_skills "$1")"; }

# These agents run tools: TaskStop with maxTurns: 1 as an evidence floor, and Skill reads content, so they must never grant it.
A14_FLOOR="decision-steward pitch-judge"

# A14.0 — probe is not pointed at nothing
a14_probe_ok=0
if [ -n "$(skill_dirs)" ]; then
  for stem in $(stems "$AGENTS"); do
    if names_skill "$AGENTS/$stem.md"; then
      a14_probe_ok=1
      break
    fi
  done
fi
if [ "$a14_probe_ok" -eq 1 ]; then
  pass "A14.0 the skill probe matches something at all"
else
  fail "A14.0 the skill probe matched NOTHING — the probe is broken, not the tree"
fi

# A14.1 — agents naming a skill they do not preload grant Skill
for stem in $(stems "$AGENTS"); do
  case " $A14_FLOOR " in
    *" $stem "*) continue ;;
  esac
  if a14_needs_grant "$AGENTS/$stem.md"; then
    if grants_skill "$AGENTS/$stem.md"; then
      pass "A14.1 $stem names a skill and grants Skill"
    else
      fail "A14.1 $stem names a skill but its tools: line does not grant Skill — grant Skill, or add it to A14_FLOOR with its reason"
    fi
  fi
done

# A14.2 — floor agents exist and do not grant Skill
for stem in $A14_FLOOR; do
  f="$AGENTS/$stem.md"
  if [ ! -f "$f" ]; then
    fail "A14.2 $stem in floor does not exist"
  elif grants_skill "$f"; then
    fail "A14.2 $stem in floor grants Skill — floor agents must never grant Skill"
  else
    pass "A14.2 $stem in floor does not grant Skill"
  fi
done

# A14.3 — controls on synthetic fixtures
mkdir -p "$SCRATCH/a14"

# shellcheck disable=SC2016
printf -- '---\r\ntools: Read, Bash\r\n---\r\nload `dispatch-weight` first\r\n' > "$SCRATCH/a14/arm1.md"
if names_skill "$SCRATCH/a14/arm1.md"; then
  pass "A14.3 arm 1 (backticked name) is flagged"
else
  fail "A14.3 arm 1 (backticked name) was not flagged"
fi
if ! grants_skill "$SCRATCH/a14/arm1.md"; then
  pass "A14.3 arm 1 fixture does not grant Skill"
else
  fail "A14.3 arm 1 fixture unexpectedly grants Skill"
fi

printf -- '---\r\ntools: Read, Bash\r\n---\r\nfollow the tdd skill\r\n' > "$SCRATCH/a14/arm2.md"
if names_skill "$SCRATCH/a14/arm2.md"; then
  pass "A14.3 arm 2 (bare name + skill) is flagged"
else
  fail "A14.3 arm 2 (bare name + skill) was not flagged"
fi
if ! grants_skill "$SCRATCH/a14/arm2.md"; then
  pass "A14.3 arm 2 fixture does not grant Skill"
else
  fail "A14.3 arm 2 fixture unexpectedly grants Skill"
fi

printf -- '---\r\ntools: Read, Bash\r\n---\r\napply your standards skill\r\n' > "$SCRATCH/a14/arm3.md"
if names_skill "$SCRATCH/a14/arm3.md"; then
  pass "A14.3 arm 3 (standards skill) is flagged"
else
  fail "A14.3 arm 3 (standards skill) was not flagged"
fi
if ! grants_skill "$SCRATCH/a14/arm3.md"; then
  pass "A14.3 arm 3 fixture does not grant Skill"
else
  fail "A14.3 arm 3 fixture unexpectedly grants Skill"
fi

# shellcheck disable=SC2016
printf -- '---\r\ntools: Read, Bash\r\n---\r\napply `<layer>-standards`\r\n' > "$SCRATCH/a14/arm4.md"
if names_skill "$SCRATCH/a14/arm4.md"; then
  pass "A14.3 arm 4 (backticked -standards) is flagged"
else
  fail "A14.3 arm 4 (backticked -standards) was not flagged"
fi
if ! grants_skill "$SCRATCH/a14/arm4.md"; then
  pass "A14.3 arm 4 fixture does not grant Skill"
else
  fail "A14.3 arm 4 fixture unexpectedly grants Skill"
fi

printf -- '---\r\ntools: Read, Skill, Bash\r\n---\r\none body line\r\n' > "$SCRATCH/a14/grant.md"
if grants_skill "$SCRATCH/a14/grant.md"; then
  pass "A14.3 grant fixture grants Skill"
else
  fail "A14.3 grant fixture does not grant Skill"
fi

printf -- '---\r\ntools: Read, mcp__x__Skillful\r\n---\r\none body line containing the word Skill\r\n' > "$SCRATCH/a14/substring.md"
if ! grants_skill "$SCRATCH/a14/substring.md"; then
  pass "A14.3 substring fixture does not grant Skill"
else
  fail "A14.3 substring fixture unexpectedly grants Skill"
fi

printf -- '---\r\ntools: TaskStop, Skill\r\n---\r\none body line\r\n' > "$SCRATCH/a14/floor.md"
if grants_skill "$SCRATCH/a14/floor.md"; then
  pass "A14.3 floor fixture grants Skill"
else
  fail "A14.3 floor fixture does not grant Skill"
fi

# shellcheck disable=SC2016
printf -- '---\r\ntools: Read, Bash\r\nskills: [dispatch-weight]\r\n---\r\nload `dispatch-weight` first\r\n' > "$SCRATCH/a14/preload.md"
if ! a14_needs_grant "$SCRATCH/a14/preload.md"; then
  pass "A14.3 preload fixture (names only the skill it preloads, no Skill grant) is not flagged"
else
  fail "A14.3 preload fixture was flagged — a skills: preload needs no Skill grant"
fi

# shellcheck disable=SC2016
printf -- '---\r\ntools: Read, Bash\r\n---\r\nload `dispatch-weight` first\r\n' > "$SCRATCH/a14/nopreload.md"
if a14_needs_grant "$SCRATCH/a14/nopreload.md"; then
  pass "A14.3 nopreload fixture (same body, no skills:) is flagged"
else
  fail "A14.3 nopreload fixture was not flagged — the exemption reaches skills the agent does not preload"
fi

# shellcheck disable=SC2016
printf -- '---\r\ntools: Read, Bash\r\nskills: [dispatch-weight]\r\n---\r\nload `dispatch-weight`, then follow the tdd skill\r\n' > "$SCRATCH/a14/mixed.md"
if a14_needs_grant "$SCRATCH/a14/mixed.md"; then
  pass "A14.3 mixed fixture (preloads one skill, names another) is flagged"
else
  fail "A14.3 mixed fixture was not flagged — preloading one skill exempted a different one"
fi

fi

# ---------------------------------------------------------------- A15
# Slices run one at a time in the main checkout. A slice template that mentions a worktree
# sends an agent to a checkout Serena cannot index. The probe is `worktree`, not
# `git worktree`: a mention spelled `git -C <repo> worktree` would slip past the longer literal.
if want A15; then
banner "A15 · no slice template mentions a worktree"

a15_mentions() { grep -qi worktree "$1"; }

A15_FILES="
$AGENTS/slice-layer-specialist.md
$AGENTS/aligner.md
$AGENTS/integrator.md
$AGENTS/integration-tester.md
$COMMANDS/start-ticket.md
$TEMPLATES/skills/to-tickets/SKILL.md"

mkdir -p "$SCRATCH/a15"
printf 'git -C repo Worktree add\n' > "$SCRATCH/a15/hit.md"
printf 'one checkout, one branch\n' > "$SCRATCH/a15/clean.md"
if a15_mentions "$SCRATCH/a15/hit.md"; then
  pass "A15.0 the probe flags a worktree mention"
else
  fail "A15.0 the probe missed a worktree mention — the probe is broken, not the tree"
fi
if ! a15_mentions "$SCRATCH/a15/clean.md"; then
  pass "A15.0 the probe leaves a clean file alone"
else
  fail "A15.0 the probe flagged a file with no worktree in it"
fi

for f in $A15_FILES; do
  rel="${f#"$REPO"/}"
  if [ ! -f "$f" ]; then
    fail "A15 $rel does not exist — a missing file must not pass as no mention"
  elif a15_mentions "$f"; then
    fail "A15 $rel mentions a worktree — slices run in the main checkout, which Serena indexes"
  else
    pass "A15 $rel does not mention a worktree"
  fi
done
fi

# ---------------------------------------------------------------- A16
# The planner's file list says where a change goes, not who depends on it. An
# implementation agent dispatched without the code-access dispatch paragraph edits
# the files it was handed and never asks Serena who calls them, and the result has
# the normal SHAPE. So every weighing command references code-access, the skill
# holds the paragraph, and every editing agent's handoff reports its Serena calls,
# which @repo-reviewer checks, so a run that never touched Serena shows as a zero.
#
# A slice variant hands off in the shape its base requires, so it passes on its
# base's line.
#
# Catches: a dispatch with no Serena paragraph, the paragraph leaving the skill,
# and an editor whose handoff cannot show a run that skipped Serena.
if want A16; then
banner "A16 · implementation dispatch carries the Serena paragraph"

A16_WEIGHS=""
for stem in $(stems "$COMMANDS"); do
  [ "$(command_class "$stem")" = "weighs" ] && A16_WEIGHS="$A16_WEIGHS $stem"
done
if [ -n "$A16_WEIGHS" ]; then
  pass "A16.1 weighing commands found:$A16_WEIGHS"
else
  fail "A16.1 no command classifies as weighs — command_class is broken, not the tree"
fi
for stem in $A16_WEIGHS; do
  if grep -qF 'code-access' "$COMMANDS/$stem.md"; then
    pass "A16.1 /$stem references code-access"
  else
    fail "A16.1 /$stem dispatches implementation agents but never references code-access — the dispatch carries no Serena paragraph"
  fi
done

if [ ! -f "$CODE_ACCESS" ]; then
  fail "A16.2 templates/skills/code-access/SKILL.md does not exist — there is no dispatch paragraph to paste"
elif tr -d '\r' < "$CODE_ACCESS" | grep -q '^## Dispatch paragraph'; then
  pass "A16.2 the code-access skill holds a ## Dispatch paragraph section"
else
  fail "A16.2 the code-access skill has no ## Dispatch paragraph section — the commands reference a paragraph that is not there"
fi

if [ -n "$EDITORS" ]; then
  pass "A16.3 editing agents found: $(setlike "$EDITORS")"
else
  fail "A16.3 no editing agents found — A1's probe is broken, not the tree"
fi
for stem in $EDITORS; do
  base="${stem#slice-}"
  if grep -qF 'Serena calls:' "$AGENTS/$stem.md"; then
    pass "A16.3 $stem's handoff reports its Serena calls"
  elif [ "$base" != "$stem" ] && [ ! -f "$AGENTS/$base.md" ]; then
    fail "A16.3 $stem hands off in the shape of $base, which does not exist"
  elif [ "$base" != "$stem" ] && grep -qF 'Serena calls:' "$AGENTS/$base.md"; then
    pass "A16.3 $stem reports its Serena calls through $base's handoff shape"
  else
    fail "A16.3 $stem's handoff has no Serena calls: line — a run that never touched Serena reads like one that did"
  fi
done

if [ ! -f "$AGENTS/repo-reviewer.md" ]; then
  fail "A16.4 templates/agents/repo-reviewer.md does not exist"
elif grep -qF 'Serena calls:' "$AGENTS/repo-reviewer.md"; then
  pass "A16.4 repo-reviewer checks the editors' Serena calls: line"
else
  fail "A16.4 repo-reviewer never checks a Serena calls: line — a missing or unexplained zero goes unreported"
fi
fi

# ---------------------------------------------------------------- A17
# start-ticket.md numbers the dispatch sites and every other "site N" in the repo borrows
# that number. A copy that drifts still reads fine and sends the reader to another site,
# so each mention must sit within two lines of the word that names its site.
# A17_KW is the tripwire, like A1's EXPECTED_EDITORS: word N names site N, and renaming
# a site means changing the word here.
#
# Catches: a doc that says "site 3" about the re-pass while the pipeline says 4.
A17_KW="initial drift slice re-pass bounce-back secondary"

# a17_kw N — the word that names dispatch site N
a17_kw() { printf '%s\n' "$A17_KW" | awk -v n="$1" '{print $n}'; }

# a17_scan FILE — one "LINE N ok|bad" per "site N" mention (N in 1-6, any case, not the
# tail of a longer word). ok = site N's word is on the mention's line or within 2 lines
# either side. CRs are stripped first: on Linux awk does not.
a17_scan() {
  tr -d '\r' < "$1" | awk -v kws="$A17_KW" '
    BEGIN { split(kws, kw, " ") }
    { line[NR] = " " tolower($0) " " }
    END {
      for (i = 1; i <= NR; i++) {
        s = line[i]
        while (match(s, /[^a-z]site [1-6][^0-9]/)) {
          n = substr(s, RSTART + RLENGTH - 2, 1)
          v = "bad"
          for (j = i - 2; j <= i + 2; j++)
            if (j >= 1 && j <= NR && index(line[j], kw[n])) v = "ok"
          print i, n, v
          s = substr(s, RSTART + RLENGTH - 1)
        }
      }
    }'
}

if want A17; then
banner "A17 · dispatch-site numbers agree with start-ticket.md"

START_TICKET="$COMMANDS/start-ticket.md"

# A17.0 — the source names all six sites, so the scan below is comparing against
# something.
if [ ! -f "$START_TICKET" ]; then
  fail "A17.0 templates/commands/start-ticket.md is missing"
else
  a17_seen="$(a17_scan "$START_TICKET" | awk '{print $2}' | sort -u | tr '\n' ' ')"
  for n in 1 2 3 4 5 6; do
    case " $a17_seen" in
      *" $n "*) pass "A17.0 start-ticket.md names dispatch site $n ($(a17_kw "$n"))" ;;
      *) fail "A17.0 start-ticket.md never names dispatch site $n ($(a17_kw "$n")) — the source of the numbering has no site $n" ;;
    esac
  done

  # A17.1 — inside the source, every number sits beside its own word.
  a17_bad=0
  while read -r ln n verdict; do
    [ "$verdict" = "bad" ] || continue
    a17_bad=1
    fail "A17.1 start-ticket.md:$ln says site $n with no '$(a17_kw "$n")' within 2 lines"
  done <<EOF
$(a17_scan "$START_TICKET")
EOF
  [ "$a17_bad" = "0" ] && pass "A17.1 every site N in start-ticket.md sits beside its own word"
fi

# A17.2 — the site table in 07-the-flows.md: row N is site N.
A17_ROWS="$(awk '/^\| # \| Dispatch site \|/{f=1; next} f && !/^\|/{exit} f && /^\|[- |]*\|$/{next} f' "$FLOWS" 2>/dev/null | tr -d '\r')"
if [ ! -f "$FLOWS" ]; then
  fail "A17.2 docs/shared/07-the-flows.md is missing"
elif [ -z "$A17_ROWS" ]; then
  fail "A17.2 found no site table in 07-the-flows.md — its header row changed, or the probe is broken"
else
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    num="$(printf '%s\n' "$row" | awk -F'|' '{gsub(/[[:space:]]/, "", $2); print $2}')"
    cell="$(printf '%s\n' "$row" | awk -F'|' '{print tolower($3)}')"
    case "$num" in
      [1-6]) ;;
      *) fail "A17.2 07 table has a row numbered '$num' — rows are numbered 1-6"; continue ;;
    esac
    kw="$(a17_kw "$num")"
    case "$cell" in
      *"$kw"*) pass "A17.2 07 table row $num is the $kw site" ;;
      *) fail "A17.2 07 table row $num is not the $kw site — start-ticket.md numbers it $num" ;;
    esac
  done <<EOF
$A17_ROWS
EOF
fi

# A17.3 — every other mention under templates/, docs/ and examples/. Files are read off
# disk with find, never git grep, which cannot see an untracked file.
a17_files=0; a17_mentions=0; a17_off=0
while IFS= read -r f; do
  [ "$f" = "$START_TICKET" ] && continue
  a17_files=$((a17_files+1))
  rel="${f#"$REPO"/}"
  while read -r ln n verdict; do
    [ -n "$ln" ] || continue
    a17_mentions=$((a17_mentions+1))
    [ "$verdict" = "bad" ] || continue
    a17_off=1
    fail "A17.3 $rel:$ln says site $n with no '$(a17_kw "$n")' within 2 lines"
  done <<EOF2
$(a17_scan "$f")
EOF2
done <<EOF
$(find "$TEMPLATES" "$REPO/docs" "$REPO/examples" -name '*.md' -type f | sort)
EOF
if [ "$a17_files" -gt 0 ]; then
  pass "A17.3 scanned $a17_files other markdown files ($a17_mentions site mentions)"
else
  fail "A17.3 the find returned no markdown — the probe is broken, not the tree"
fi
[ "$a17_off" = "0" ] && pass "A17.3 every other site N mention sits beside its own word"

# A17.4 — the scanner itself, in both directions, on fixtures with known answers.
a17_fx="$SCRATCH/a17"
mkdir -p "$a17_fx"
printf 'Dispatch site 3 is the one a plan-only weight misses.\nIt reads the re-pass weight.\n' > "$a17_fx/bad.md"
printf 'Dispatch site 4 is the one a plan-only weight misses.\nIt reads the re-pass weight.\n' > "$a17_fx/good.md"
printf 'site 4\nx\nre-pass\n' > "$a17_fx/edge2.md"
printf 'site 4\nx\ny\nre-pass\n' > "$a17_fx/edge3.md"
printf 'a website 3 and the opposite 4 and site 10\n' > "$a17_fx/words.md"
printf 'site 1 and site 2 here\ninitial dispatch\n' > "$a17_fx/two.md"

a17_expect() {
  local got
  got="$(a17_scan "$a17_fx/$2")"
  if [ "$got" = "$3" ]; then pass "A17.4 $1"
  else fail "A17.4 $1 — the scan gave [$got], expected [$3]"; fi
}
a17_expect "site 3 beside re-pass is flagged" bad.md "1 3 bad"
a17_expect "site 4 beside re-pass is accepted" good.md "1 4 ok"
a17_expect "the word two lines away is accepted" edge2.md "1 4 ok"
a17_expect "the word three lines away is flagged" edge3.md "1 4 bad"
a17_expect "website 3, opposite 4 and site 10 are not mentions" words.md ""
a17_expect "two mentions on one line are judged separately" two.md "1 1 ok
1 2 bad"
fi

# ---------------------------------------------------------------- A18
# Only the session dispatches agents. A template whose tools: line holds Agent can launch
# another agent, and the nesting leaves no trace in the output. Agent(<name>) is the
# restricted form of the same grant.
#
# Catches: a reviewer or gatherer that fans out on its own again, and a template with
# no tools: line, which inherits every tool, Agent included.
a18_tools() {
  tr -d '\r' < "$1" | awk '/^---$/{n++; next} n==1' | sed -n 's/^tools:[[:space:]]*//p' | head -1
}

# a18_grants_agent TOOLS — does a tools: value hold Agent as a whole token?
a18_grants_agent() {
  printf '%s\n' "$1" | tr ',' '\n' | tr -d ' \t\r' | grep -qE '^Agent(\(.*\))?$'
}

# a18_verdict FILE — the one per-file decision, used by the fixture case and the tree
# loop alike: "no-tools" (no tools: line, so it inherits every tool), "agent" (its
# tools: line grants Agent) or "ok".
a18_verdict() {
  if ! tr -d '\r' < "$1" | awk '/^---$/{n++; next} n==1' | grep -q '^tools:'; then
    echo no-tools
  elif a18_grants_agent "$(a18_tools "$1")"; then
    echo agent
  else
    echo ok
  fi
}

if want A18; then
banner "A18 · no agent template holds Agent in its tools: line"

# A18.0 — the token probe, in both directions.
if a18_grants_agent "Read, Agent, Skill"; then pass "A18.0 the probe flags a bare Agent"
else fail "A18.0 the probe missed a bare Agent — the probe is broken, not the tree"; fi
if a18_grants_agent "Read, Agent(worker)"; then pass "A18.0 the probe flags Agent(<name>)"
else fail "A18.0 the probe missed Agent(<name>) — the probe is broken, not the tree"; fi
if ! a18_grants_agent "Read, Agents, SubAgent, mcp__x__Agent"; then
  pass "A18.0 the probe leaves lookalike tokens alone"
else
  fail "A18.0 the probe flagged a lookalike token"
fi

# A18.0 — a template with frontmatter and no tools: line inherits every tool.
A18FIX="$SCRATCH/a18"
mkdir -p "$A18FIX" && printf -- '---\nname: no-tools\ndescription: fixture\nmodel: x\n---\n\nBody.\n' > "$A18FIX/no-tools.md"
if [ "$(a18_verdict "$A18FIX/no-tools.md")" = "no-tools" ]; then
  pass "A18.0 a template with no tools: line is flagged"
else
  fail "A18.0 a template with no tools: line passes — it inherits every tool, Agent included"
fi

a18_read=0
for stem in $(stems "$AGENTS"); do
  [ -n "$(a18_tools "$AGENTS/$stem.md")" ] && a18_read=$((a18_read+1))
  case "$(a18_verdict "$AGENTS/$stem.md")" in
    agent)    fail "A18 @$stem holds Agent in its tools: line — only the session dispatches agents" ;;
    no-tools) fail "A18 @$stem has no tools: line — it inherits every tool, Agent included" ;;
    *)     pass "A18 @$stem does not hold Agent" ;;
  esac
done
if [ "$a18_read" -gt 0 ]; then
  pass "A18.0 read a tools: line from $a18_read agent templates"
else
  fail "A18.0 read no tools: line from any agent — the frontmatter reader is broken, not the tree"
fi
fi

# ---------------------------------------------------------------- A19
# The context checkpoint is wired by prose: one gate line per /start-ticket gate, a
# Resume: reader in /resume-ticket, and a threshold that lives in occupancy.py alone.
# A gate line a rewrite drops is a gate that never measures, and nothing in the run
# says so. A threshold restated in prose is a second number that drifts from the one
# the script applies.
#
# Catches: a gate site lost from start-ticket.md, resume-ticket.md no longer reading
# the gate handoff, the threshold written as a number outside the script, and a second
# threshold constant inside it.
CHECKPOINT_DIR="$TEMPLATES/skills/context-checkpoint"
A19_SLUGS="plan-approval alignment review-verdict review-fix"
A19_THRESHOLD_RE='30 ?%|30 percent|per cent|0\.3'
A19_PROSE="$COMMANDS/start-ticket.md $COMMANDS/resume-ticket.md $CHECKPOINT_DIR/SKILL.md $TEMPLATES/skills/handoff/SKILL.md"

# a19_missing_gates FILE — the slugs with no line holding both the backticked skill
# name and `gate: <slug>`, space-separated; empty when every gate is wired.
a19_missing_gates() {
  local slug missing=""
  for slug in $A19_SLUGS; do
    # shellcheck disable=SC2016
    tr -d '\r' < "$1" | grep -F '`context-checkpoint`' \
      | grep -qE "gate: $slug([^[:alnum:]-]|$)" || missing="$missing $slug"
  done
  printf '%s' "${missing# }"
}

# a19_restates FILE — does this file write the threshold as a number?
a19_restates() { tr -d '\r' < "$1" | grep -qE "$A19_THRESHOLD_RE"; }

if want A19; then
banner "A19 · the context checkpoint is wired at every gate, and its threshold lives in one place"
A19FIX="$SCRATCH/a19"
mkdir -p "$A19FIX"

# A19.0 — the probes, in both directions, before they judge the tree.
tr -d '\r' < "$COMMANDS/start-ticket.md" | grep -vE 'gate: alignment([^[:alnum:]-]|$)' > "$A19FIX/no-alignment.md"
if [ "$(a19_missing_gates "$A19FIX/no-alignment.md")" = "alignment" ]; then
  pass "A19.0 a start-ticket.md with the alignment gate line removed is flagged, by name"
else
  fail "A19.0 removing the alignment gate line was not flagged as exactly [alignment] — the probe is broken, not the tree"
fi
{ [ -f "$CHECKPOINT_DIR/SKILL.md" ] && tr -d '\r' < "$CHECKPOINT_DIR/SKILL.md"; printf 'Hand off once the session is past 30%% of its window.\n'; } > "$A19FIX/restated.md"
if a19_restates "$A19FIX/restated.md"; then
  pass "A19.0 a skill copy that adds \"30%\" is flagged"
else
  fail "A19.0 a skill copy that adds \"30%\" passed — the threshold probe is broken, not the tree"
fi
printf 'set PLAYBOOK_CONTEXT_WINDOW=200000; without it the script assumes 1,000,000.\n' > "$A19FIX/windows.md"
if a19_restates "$A19FIX/windows.md"; then
  fail "A19.0 the window numbers read as a restated threshold — the probe would refuse the skill's own window line"
else
  pass "A19.0 the window numbers (200000, 1,000,000) are not read as the threshold"
fi

# A19.1 — the four gate lines
a19_gaps="$(a19_missing_gates "$COMMANDS/start-ticket.md")"
if [ -z "$a19_gaps" ]; then
  pass "A19.1 start-ticket.md runs \`context-checkpoint\` at every gate: $A19_SLUGS"
else
  fail "A19.1 start-ticket.md has no context-checkpoint line for gate(s): $a19_gaps — that gate never measures"
fi

# A19.2 — the reader of the gate handoff
if tr -d '\r' < "$COMMANDS/resume-ticket.md" | grep -qF 'manual_handoffs' \
   && tr -d '\r' < "$COMMANDS/resume-ticket.md" | grep -qF 'Resume:'; then
  pass "A19.2 resume-ticket.md reads the gate handoff's Resume: line from manual_handoffs/"
else
  fail "A19.2 resume-ticket.md no longer names manual_handoffs/ and Resume: — a gate handoff is written and never read"
fi

# A19.3 — no prose copy of the threshold
for f in $A19_PROSE; do
  rel="${f#"$REPO"/}"
  if [ ! -f "$f" ]; then
    fail "A19.3 $rel does not exist — a missing file must not pass as a clean one"
  elif a19_restates "$f"; then
    fail "A19.3 $rel restates the threshold as a number — the script owns it"
  else
    pass "A19.3 $rel does not restate the threshold"
  fi
done

# A19.4 — one threshold constant in the script
if [ ! -f "$CHECKPOINT_DIR/occupancy.py" ]; then
  fail "A19.4 templates/skills/context-checkpoint/occupancy.py does not exist"
else
  a19_n="$(tr -d '\r' < "$CHECKPOINT_DIR/occupancy.py" | grep -cE '^[[:space:]]*THRESHOLD_FRACTION[[:space:]]*=[^=]')"
  if [ "$a19_n" = "1" ]; then
    pass "A19.4 occupancy.py assigns THRESHOLD_FRACTION exactly once"
  else
    fail "A19.4 occupancy.py assigns THRESHOLD_FRACTION $a19_n times, not once"
  fi
fi
fi

# ---------------------------------------------------------------- A20
# Each layer specialist preloads a short write-time rule set, <layer>-write-core,
# through its skills: line, and the full <layer>-standards stays with review. A skill
# that sets disable-model-invocation is not preloaded, and nothing reports it; a
# skills: line that loses the entry leaves the specialist writing with no rules at all.
#
# Catches: a specialist template that stops preloading code-access or the write-core,
# the flag that switches the preload off, and a write-core whose closing line naming
# what it leaves to review was cut.
WRITE_CORE="$TEMPLATES/skills/write-core/SKILL.md"

# a20_preloads FILE — does this template's skills: list code-access AND <layer>-write-core?
a20_preloads() {
  local s
  s="$(fm_skills "$1")"
  printf '%s\n' "$s" | grep -qx 'code-access' && printf '%s\n' "$s" | grep -qxF '<layer>-write-core'
}

if want A20; then
banner "A20 · both layer specialists preload <layer>-write-core, and nothing switches it off"
A20FIX="$SCRATCH/a20"
mkdir -p "$A20FIX"

# A20.0 — the probe, against the two shapes a regression takes
tr -d '\r' < "$AGENTS/layer-specialist.md" \
  | sed 's/^skills:.*/skills: [code-access]/' > "$A20FIX/no-write-core.md"
tr -d '\r' < "$AGENTS/layer-specialist.md" \
  | sed 's/^skills:.*/skills: [<layer>-write-core]/' > "$A20FIX/no-code-access.md"
if ! a20_preloads "$A20FIX/no-write-core.md" && ! a20_preloads "$A20FIX/no-code-access.md"; then
  pass "A20.0 a skills: line missing either entry is flagged"
else
  fail "A20.0 a skills: line missing one entry passed — the probe is broken, not the tree"
fi

# A20.1 — the preload, in both specialists
for stem in layer-specialist slice-layer-specialist; do
  if a20_preloads "$AGENTS/$stem.md"; then
    pass "A20.1 $stem preloads code-access and <layer>-write-core"
  else
    fail "A20.1 $stem's skills: does not list both code-access and <layer>-write-core — it writes without its rules"
  fi
done

# A20.2 — the template itself
if [ ! -f "$WRITE_CORE" ]; then
  fail "A20.2 templates/skills/write-core/SKILL.md does not exist — a missing skill must not pass as an unflagged one"
else
  if [ "$(fm_field "$WRITE_CORE" name | tr -d '\r')" = "<layer>-write-core" ]; then
    pass "A20.2 the write-core template is named <layer>-write-core"
  else
    fail "A20.2 the write-core template's name: is not <layer>-write-core — the preload names a skill that is never generated"
  fi
  if [ "$(fm_field "$WRITE_CORE" user-invocable | tr -d '\r')" = "false" ]; then
    pass "A20.2 the write-core template sets user-invocable: false"
  else
    fail "A20.2 the write-core template does not set user-invocable: false"
  fi
  if frontmatter "$WRITE_CORE" | tr -d '\r' | grep -q '^disable-model-invocation:'; then
    fail "A20.2 the write-core template sets disable-model-invocation — that blocks the skills: preload, silently"
  else
    pass "A20.2 the write-core template leaves disable-model-invocation unset, so the preload loads it"
  fi
  if tr -d '\r' < "$WRITE_CORE" | sed '/^[[:space:]]*$/d' | tail -1 | grep -q '^Not here on purpose:'; then
    pass "A20.2 the write-core template ends by naming what it leaves to review"
  else
    fail "A20.2 the write-core template's last line does not start \"Not here on purpose:\""
  fi
fi
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
a12 "A12.2 · only the main session runs work in the background" \
    "$A12_AGENTS_README" 'Only the main session runs work in the background'

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

# --- A12.6 · review-guidelines skill stub and repo-reviewer reference
a12_6_status='STATUS: NOT FILLED IN YET'
if [ -f "$TEMPLATES/skills/review-guidelines/SKILL.md" ]; then
  pass "A12.6 · templates/skills/review-guidelines/SKILL.md exists"
else
  fail "A12.6 · templates/skills/review-guidelines/SKILL.md does not exist"
fi
if [ -f "$TEMPLATES/skills/review-guidelines/SKILL.md" ] && grep -qF "$a12_6_status" "$TEMPLATES/skills/review-guidelines/SKILL.md"; then
  pass "A12.6 · templates/skills/review-guidelines/SKILL.md carries the status marker"
else
  fail "A12.6 · templates/skills/review-guidelines/SKILL.md is missing the status marker"
fi
if grep -qF "$a12_6_status" "$TEMPLATES/agents/repo-reviewer.md"; then
  pass "A12.6 · templates/agents/repo-reviewer.md carries the status marker"
else
  fail "A12.6 · templates/agents/repo-reviewer.md is missing the status marker"
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
# purpose: tests/test-docs.sh fails without running anything when there is no python,
# and this check has to run on the machine that has none.
A12_WIRINGS="$TEMPLATES/hooks/settings-hooks.snippet.json $TEMPLATES/mcp/settings.json.snippet"
A12_SKIP="$(sed -n 's/^SKIP_HOOKS[[:space:]]*=[[:space:]]*{\(.*\)}.*/\1/p' "$REPO/install-lib.py" \
            | tr -d '" ' | tr ',' ' ')"
if [ -n "$A12_SKIP" ]; then
  pass "A12.8 · SKIP_HOOKS parsed out of install-lib.py: $A12_SKIP"
else
  fail "A12.8 · SKIP_HOOKS did not parse out of install-lib.py — the set below is being derived from nothing"
fi
# An agent-scoped hook (its header says so) belongs in agent frontmatter and in
# NEITHER snippet: a snippet entry would fire it for every session, not just the
# agents that carry it. It leaves this set and is judged on its own below.
a12_agent_scoped() { sed -n '1,4p' "$1" | grep -q 'Agent-scoped:'; }
A12_WIRED=""
A12_AGENT=""
for f in "$TEMPLATES"/hooks/*.sh; do
  b="$(basename "$f")"
  case " $A12_SKIP " in *" $b "*) continue ;; esac
  if a12_agent_scoped "$f"; then
    A12_AGENT="$A12_AGENT $b"
    continue
  fi
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
for b in $A12_AGENT; do
  for w in $A12_WIRINGS; do
    wrel="${w#"$REPO"/}"
    if grep -qF "$b" "$w"; then
      fail "A12.8 · $b is agent-scoped and $wrel wires it — it would fire in every session, not only in the agents that carry it"
    else
      pass "A12.8 · $b is agent-scoped and absent from $wrel"
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

# a12_agent_placements AGENT.md -> "event<TAB>matcher<TAB>hookfile" per command in
# the frontmatter's `hooks:` block. Events are the capitalised keys under it; the
# frontmatter ends at the second `---`, so a hook named in the body never counts.
a12_agent_placements() {
  awk '
    { sub(/\r$/, "") }
    NR == 1 { if ($0 !~ /^---[[:space:]]*$/) exit; next }
    /^---[[:space:]]*$/ { exit }
    /^[^[:space:]]/ { inhooks = ($0 ~ /^hooks:[[:space:]]*$/); ev = ""; matcher = ""; next }
    !inhooks { next }
    /^[[:space:]]+[A-Z][A-Za-z]*:[[:space:]]*$/ {
      ev = $0; gsub(/[[:space:]:]/, "", ev); matcher = ""; next
    }
    match($0, /matcher:[[:space:]]*.*/) {
      m = substr($0, RSTART, RLENGTH)
      sub(/^matcher:[[:space:]]*/, "", m); sub(/[[:space:]]+$/, "", m); gsub(/["\047]/, "", m)
      matcher = m
    }
    match($0, /hooks\/[A-Za-z0-9_-]+\.sh/) {
      h = substr($0, RSTART, RLENGTH); sub(/^hooks\//, "", h)
      printf "%s\t%s\t%s\n", ev, matcher, h
    }' "$1"
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
for b in $A12_AGENT; do
  decl="$(a12_declares "$TEMPLATES/hooks/$b")"
  want_ev="${decl%%	*}"
  want_alts="$(printf '%s' "${decl#*	}" | tr '/' ' ' | tr -s ' ')"
  if [ -z "$want_ev" ] || [ -z "$want_alts" ]; then
    fail "A12.8 · $b is agent-scoped and its header declares no event and matcher — nothing states what an agent must wire it under"
    continue
  fi
  A12_CHECKABLE=$((A12_CHECKABLE+1))
  carriers=""
  for a in "$TEMPLATES"/agents/*.md; do
    arel="${a#"$REPO"/}"
    got="$(a12_agent_placements "$a" | awk -F'\t' -v h="$b" '$3 == h {print $1 "\t" $2; exit}')"
    [ -n "$got" ] || continue
    got_ev="${got%%	*}"
    got_matcher="${got#*	}"
    missing=""
    for alt in $want_alts; do
      case "|$got_matcher|" in
        *"|$alt|"*) ;;
        *) missing="$missing $alt" ;;
      esac
    done
    if [ "$got_ev" != "$want_ev" ]; then
      fail "A12.8 · $b asks for $want_ev and $arel wires it under ${got_ev:-(no event)} — it will fire on the wrong event, or never"
    elif [ -n "$missing" ]; then
      fail "A12.8 · $b declares it guards [$want_alts] and $arel wires it under $got_ev/$got_matcher — missing:$missing"
    else
      pass "A12.8 · $b is wired under $got_ev/$got_matcher in $arel's frontmatter, covering the matcher it declares"
      carriers="$carriers $arel"
    fi
  done
  if [ -z "$carriers" ]; then
    fail "A12.8 · $b is agent-scoped and no templates/agents/*.md frontmatter wires it under the matcher it declares — it installs and never runs"
  fi
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
    build-chart-ticket|end-of-day|feeling-lucky|feeling-very-lucky)                 printf 'terminal' ;;
    fix-ticket|garden-memory|resume-massive|resume-ticket|start-massive)            printf 'terminal' ;;
    start-ticket|test-ticket)                                                       printf 'terminal' ;;
    # the skills a human is left standing at the end of
    adapt-to-stack|bootstrap|charting|cut-backlog|grilling|handoff)                 printf 'terminal' ;;
    pitch|prototype|research|to-questionnaire|to-tickets|wizard)                    printf 'terminal' ;;
    # always-loaded skills, the block's own definition, and a generation template
    commit-conventions|diagnose|dispatch-weight|memory-schema)                      printf 'not-terminal' ;;
    # run inside a hook and inside another flow, never a flow of its own
    memory-lint)                                                                    printf 'not-terminal' ;;
    # preloaded into agents through skills:, never run as a flow
    code-access)                                                                    printf 'not-terminal' ;;
    tdd|to-spec|wait-what|next-steps|engineering-standards|review-guidelines)       printf 'not-terminal' ;;
    # run inside a gate of another flow, and a generation template
    context-checkpoint|write-core)                                                  printf 'not-terminal' ;;
    *)                                                                              printf 'UNCLASSIFIED' ;;
  esac
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
if [ "$n_terminal" = "23" ]; then
  pass "23 terminal points, which is the inventory this landed against"
else
  fail "$n_terminal terminal points, not 23 — the inventory moved; change it here deliberately"
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
if [ -n "$PY" ]; then
  mkdir -p "$SCRATCH"
  ( cd "$REPO" && "$PY" install-lib.py discover templates "$SCRATCH/fakehome" ) \
    > "$SCRATCH/discover-n3.json" 2> "$SCRATCH/discover-n3.err"
  chk $? "install-lib.py discover runs (errors in $SCRATCH/discover-n3.err)"

  # The same /command regex install-lib.py links edges with, so this asks the
  # question the installer will answer rather than a lookalike of it.
  N3="$(cd "$REPO" && "$PY" -c '
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
  printf '    SKIP  python — no working python3 or python, so half of N3 NOT run\n'
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
# Catches: a reword that breaks the backtick match, leaving every call site pointing
# at a skill that was never installed. That fails silently: a missing skill is not
# an error, it is an absence.
if want N4; then
banner "N4 · discover puts skill:next-steps in every terminal unit's needs"
if [ -n "$PY" ]; then
  mkdir -p "$SCRATCH"
  ( cd "$REPO" && "$PY" install-lib.py discover templates "$SCRATCH/fakehome" ) \
    > "$SCRATCH/discover-n4.json" 2> "$SCRATCH/discover-n4.err"
  chk $? "install-lib.py discover runs (errors in $SCRATCH/discover-n4.err)"

  EDGES="$("$PY" -c '
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
  printf '    SKIP  python — no working python3 or python, so N4 NOT run\n'
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
