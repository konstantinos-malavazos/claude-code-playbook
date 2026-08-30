#!/usr/bin/env bash
# Docs scrub (issue #109). Every assertion here is a claim the DOCS make that has a
# checkable referent in the tree, asserted against the tree rather than against
# whoever last counted:
#
#   D-A  every internal link and anchor resolves
#   D-B  no prose count contradicts the tree
#   D-C  every /command named in prose ships a template, or is allowlisted
#   D-D  the README layout tree names every top-level entry
#
#   bash tests/test-docs.sh              # all sections
#   bash tests/test-docs.sh D-B D-D      # only these
#
# Deterministic and offline: no network, no model, no install. It reads the docs
# and the tree and asserts the docs still describe the tree.
#
# WHY THIS EXISTS. #109 found the same failure four times, and it has one shape:
# a number derived once by globbing a directory that also holds a README.md, then
# copied to four places and never re-derived. "17 of the 21 agents" and "seven
# guardrail hooks" were both one too high the day they were written, and both were
# printed to the user at the moment the installer refuses to proceed. Nothing in
# the output could have told anyone. The durable fix is not to recount — it is to
# stop writing the number down, and derive it here instead.
#
# The same argument covers the layout tree (a contributor looking for `tests/` was
# told the repo had none), the links (one bad relative href, and two working ones
# filed as broken because nobody re-checked), and the commands named in prose
# (`/hotfix` sits in a decision table beside flows that ship).
#
# Every assertion names the failure it catches, because an assertion whose failure
# nobody can picture gets deleted the first time it goes red.
#
# What this does NOT do: judge whether an explanation is any GOOD. That is review,
# not a test. Only claims with a checkable referent are in scope.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

PASS=0; FAIL=0
FAILED_NAMES=()

pass() { PASS=$((PASS+1)); printf '    PASS  %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); printf '    FAIL  %s\n' "$1"; }
banner() { printf '\n=== %s\n' "$1"; }

WANT="$*"
want() { [ -z "$WANT" ] && return 0; case " $WANT " in *" $1 "*) return 0;; esac; return 1; }

# Every section reads markdown, and the fenced-block rule is the one thing they all
# have to agree on, so the readers live in one python module the sections import.
PY="$(command -v python3 || command -v python || true)"

printf 'docs scrub — %s\n' "$REPO"

if [ -z "$PY" ]; then
  printf '\n    SKIP  python3 — NOT INSTALLED on this machine, so NOTHING here ran\n'
  printf '\n=== 0 passed, 0 failed (suite skipped)\n'
  exit 0
fi

# ---------------------------------------------------------------- shared readers
#
# md_files      — every tracked .md file, so an untracked scratch file cannot fail
#                 the suite and a tracked one cannot escape it
# strip_fences  — a fenced block is a picture of markdown, not markdown. #92 filed a
#                 `](link)` inside `charting/SKILL.md`'s output template as a broken
#                 link; it is the placeholder in a template the agent fills in.
# headings      — the anchors GitHub will generate, INCLUDING headings inside a
#                 blockquote. #92 also filed `#re-derive-never-store` as broken; the
#                 heading is real, written `> ### Re-derive, never store`.
READERS="$REPO/tests/.docs-readers.py"
cat > "$READERS" <<'PYEOF'
import io, os, re, subprocess, sys

REPO = os.environ["DOCS_REPO"]

def tracked(ext=None):
    out = subprocess.check_output(["git", "-C", REPO, "ls-files"]).decode("utf-8")
    for line in out.splitlines():
        if ext is None or line.endswith(ext):
            yield line

def read(rel):
    with io.open(os.path.join(REPO, rel), encoding="utf-8", errors="replace") as f:
        return f.read()

FENCE = re.compile(r"^\s{0,3}(```+|~~~+)")

def strip_fences(text):
    """Blank out every fenced block, keeping line numbers intact."""
    out, marker = [], None
    for line in text.splitlines():
        m = FENCE.match(line)
        if marker is None:
            if m:
                marker = m.group(1)[0] * 3
                out.append("")
                continue
            out.append(line)
        else:
            if m and m.group(1)[0] * 3 == marker:
                marker = None
            out.append("")
    return "\n".join(out)

HEADING = re.compile(r"^\s{0,3}(?:>\s?)*(#{1,6})\s+(.*?)\s*#*\s*$")

def slug(title):
    """GitHub's heading anchor: strip inline markup, lowercase, drop everything that
    is not a letter, digit, space, hyphen or underscore, then space -> ONE hyphen.
    An em dash surrounded by spaces therefore yields a DOUBLE hyphen, which is the
    rule that produced this checker's first false positives."""
    t = re.sub(r"`([^`]*)`", r"\1", title)
    t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t)
    t = re.sub(r"[*_]+", "", t)
    t = t.lower()
    t = "".join(c for c in t if c.isalnum() or c in " -_")
    return t.replace(" ", "-")

def anchors(text):
    """Every anchor a file offers. Duplicated headings get GitHub's -1/-2 suffixes."""
    seen, out = {}, set()
    for line in strip_fences(text).splitlines():
        m = HEADING.match(line)
        if not m:
            continue
        s = slug(m.group(2))
        n = seen.get(s, 0)
        seen[s] = n + 1
        out.add(s if n == 0 else "%s-%d" % (s, n))
    for m in re.finditer(r'<a\s+(?:id|name)="([^"]+)"', text):
        out.add(m.group(1))
    return out
PYEOF

# ---------------------------------------------------------------- D-A
# Catches: a bad relative href, and a rename that silently orphans a `#`-link.
if want D-A; then
banner "D-A · every internal link and anchor resolves"
DOCS_REPO="$REPO" "$PY" - <<'PYEOF' > "$REPO/tests/.docs-out" 2>&1
import os, re, sys
sys.path.insert(0, os.path.join(os.environ["DOCS_REPO"], "tests"))
sys.dont_write_bytecode = True
import importlib.util
spec = importlib.util.spec_from_file_location(
    "readers", os.path.join(os.environ["DOCS_REPO"], "tests", ".docs-readers.py"))
R = importlib.util.module_from_spec(spec); spec.loader.exec_module(R)

REPO = R.REPO
LINK = re.compile(r"(?<!\\)\[(?:[^\[\]]|\[[^\]]*\])*\]\(\s*(<[^>]*>|[^()\s]*(?:\([^()]*\)[^()\s]*)*)\s*(?:\"[^\"]*\")?\)")
SCHEME = re.compile(r"^[a-z][a-z0-9+.-]*:", re.I)

files = list(R.tracked(".md"))
anchor_cache = {}

def anchors_of(rel):
    if rel not in anchor_cache:
        anchor_cache[rel] = R.anchors(R.read(rel))
    return anchor_cache[rel]

bad, checked = [], 0
for rel in files:
    body = R.strip_fences(R.read(rel))
    for n, line in enumerate(body.splitlines(), 1):
        # An inline `code span` is prose about a path, not a link, but a
        # [text](target) inside one is still written as a link, so spans are
        # left alone and only fences are stripped.
        for m in LINK.finditer(line):
            target = m.group(1).strip("<>")
            if not target or SCHEME.match(target) or target.startswith("//"):
                continue
            # A template's own placeholder is not a path anyone can resolve.
            if "<" in target or ">" in target:
                continue
            path, _, frag = target.partition("#")
            checked += 1
            if path:
                dest = os.path.normpath(os.path.join(os.path.dirname(rel), path))
                full = os.path.join(REPO, dest)
                if not os.path.exists(full):
                    bad.append("%s:%d  no such path: %s" % (rel, n, target)); continue
                if not dest.endswith(".md"):
                    continue
                dest_rel = dest.replace(os.sep, "/")
            else:
                dest_rel = rel
            if frag and frag not in anchors_of(dest_rel):
                bad.append("%s:%d  no such anchor: %s" % (rel, n, target))

print("CHECKED %d" % checked)
for b in bad:
    print("BAD " + b)
PYEOF
D_A_CHECKED="$(sed -n 's/^CHECKED //p' "$REPO/tests/.docs-out")"
# Positive control: a matcher that found no links would pass by having nothing to
# judge. The repo has hundreds; a two-digit count means the regex broke.
if [ "${D_A_CHECKED:-0}" -ge 100 ]; then
  pass "the link matcher found $D_A_CHECKED internal links to check"
else
  fail "the link matcher found only ${D_A_CHECKED:-0} internal links — the matcher is broken, not the docs"
  sed -n '1,5p' "$REPO/tests/.docs-out"
fi
if grep -q '^BAD ' "$REPO/tests/.docs-out"; then
  while IFS= read -r b; do fail "${b#BAD }"; done < <(grep '^BAD ' "$REPO/tests/.docs-out")
else
  pass "every internal link and anchor resolves"
fi
fi

# ---------------------------------------------------------------- D-B
# The counts are DERIVED here and compared to every place the prose writes one
# down. The hook total is read from the installer's own SKIP_HOOKS, so the doc and
# the installer cannot drift apart even if both are edited.
#
# Catches: §2 and §4 of #109, permanently, including the next agent added.
if want D-B; then
banner "D-B · no prose count contradicts the tree"
DOCS_REPO="$REPO" "$PY" - <<'PYEOF' > "$REPO/tests/.docs-out" 2>&1
import glob, os, re, sys, importlib.util
spec = importlib.util.spec_from_file_location(
    "readers", os.path.join(os.environ["DOCS_REPO"], "tests", ".docs-readers.py"))
R = importlib.util.module_from_spec(spec); spec.loader.exec_module(R)
REPO = R.REPO

# --- derive, from the tree ------------------------------------------------
# README.md is documentation for the template set, not an agent — and it contains
# `mcp__serena__` because it explains the prefix. Counting it is the exact bug.
agent_files = [f for f in sorted(glob.glob(os.path.join(REPO, "templates/agents/*.md")))
               if os.path.basename(f) != "README.md"]
AGENTS = len(agent_files)
SERENA = len([f for f in agent_files if "find_symbol" in R.read(os.path.relpath(f, REPO))])

# The installer's own exclusion list, so a hook added to SKIP_HOOKS moves this
# number without anyone editing this file.
lib = R.read("install-lib.py")
m = re.search(r"SKIP_HOOKS\s*=\s*\{([^}]*)\}", lib)
skip = set(re.findall(r'"([^"]+)"', m.group(1))) if m else set()
hook_files = [os.path.basename(f) for f in sorted(glob.glob(os.path.join(REPO, "templates/hooks/*.sh")))]
HOOKS = len([f for f in hook_files if f not in skip])

print("DERIVED agents=%d serena=%d hooks=%d skip=%s" % (AGENTS, SERENA, HOOKS, ",".join(sorted(skip))))

WORDS = {"one":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7,"eight":8,
         "nine":9,"ten":10,"eleven":11,"twelve":12,"thirteen":13,"fourteen":14,
         "fifteen":15,"sixteen":16,"seventeen":17,"eighteen":18,"nineteen":19,
         "twenty":20,"twenty-one":21,"twenty-two":22}
NUM = r"(?:\d+|" + "|".join(sorted(WORDS, key=len, reverse=True)) + r")"

def val(tok):
    return int(tok) if tok.isdigit() else WORDS[tok.lower()]

# --- the claim shapes -----------------------------------------------------
# "N of the M agents" / "N of its M agents" — N is the Serena-declaring subset and
# M is the whole set. This is the phrasing the Serena gate prints.
OF_AGENTS = re.compile(r"\b(%s) of (?:the|its) (%s) agents\b" % (NUM, NUM), re.I)
# A bare "N agents" is almost always a flow's dispatch count ("5-7 agents", "two
# agents in parallel") and says nothing about the inventory. Only a count written in
# the same breath as the Serena claim is an inventory claim — which is the one #109
# found spelled out in words: "seventeen agents that refuse to run".
BARE_AGENTS = re.compile(r"\b(%s) agents\b" % NUM, re.I)
INVENTORY = re.compile(r"Serena|refuse to run", re.I)
# A count with a qualifier between it and the noun ("four blocking hooks") is a claim
# about a subset, not the total, and deliberately does not match.
HOOKS_RE = re.compile(r"\b(%s) (?:guardrail )?hooks\b" % NUM, re.I)

# The docs and the two installers. tests/ is excluded: a suite that reasons ABOUT
# these numbers is not a doc making a claim.
SOURCES = [f for f in R.tracked()
           if f.endswith((".md", ".sh", ".ps1"))
           and not f.startswith("tests/")
           and not f.startswith("templates/hooks/test-hooks.sh")]

bad, seen = [], 0
for rel in SOURCES:
    for n, line in enumerate(R.strip_fences(R.read(rel)).splitlines(), 1):
        for m in OF_AGENTS.finditer(line):
            seen += 1
            a, b = val(m.group(1)), val(m.group(2))
            if (a, b) != (SERENA, AGENTS):
                bad.append("%s:%d  \"%s\" — the tree says %d of the %d agents"
                           % (rel, n, m.group(0), SERENA, AGENTS))
        if INVENTORY.search(line) and not OF_AGENTS.search(line):
            for m in BARE_AGENTS.finditer(line):
                seen += 1
                v = val(m.group(1))
                if v != SERENA:
                    bad.append("%s:%d  \"%s\" — %d agents declare Serena tools, not %d"
                               % (rel, n, m.group(0), SERENA, v))
        for m in HOOKS_RE.finditer(line):
            seen += 1
            v = val(m.group(1))
            if v != HOOKS:
                bad.append("%s:%d  \"%s\" — the installer wires %d hooks (SKIP_HOOKS excluded)"
                           % (rel, n, m.group(0), HOOKS))

print("SEEN %d" % seen)
for b in bad:
    print("BAD " + b)
PYEOF
sed -n 's/^DERIVED /           derived: /p' "$REPO/tests/.docs-out"
D_B_SEEN="$(sed -n 's/^SEEN //p' "$REPO/tests/.docs-out")"
D_B_SKIP="$(sed -n 's/^DERIVED .*skip=//p' "$REPO/tests/.docs-out")"
# Two positive controls. An empty SKIP_HOOKS would silently make the hook total
# wrong-but-consistent, and a regex that matched nothing would pass by default.
if [ -n "$D_B_SKIP" ]; then
  pass "SKIP_HOOKS parsed out of install-lib.py: $D_B_SKIP"
else
  fail "SKIP_HOOKS did not parse — the hook total is being derived from nothing"
fi
if [ "${D_B_SEEN:-0}" -ge 4 ]; then
  pass "found $D_B_SEEN written-down counts to check"
else
  fail "found only ${D_B_SEEN:-0} written-down counts — the claim regexes are broken, not the docs"
fi
if grep -q '^BAD ' "$REPO/tests/.docs-out"; then
  while IFS= read -r b; do fail "${b#BAD }"; done < <(grep '^BAD ' "$REPO/tests/.docs-out")
else
  pass "every written-down count matches the tree"
fi
fi

# ---------------------------------------------------------------- D-C
# A `/command` in prose reads as something the user can type. The ones that ship
# are templates/commands/*.md and templates/skills/*/. Everything else has to be
# on the allowlist below, which is the tripwire: a new flow named in the docs but
# never written fails here until somebody decides which it is.
#
# Catches: #109 §8's `/hotfix`, and #104's `/close-ticket`.
if want D-C; then
banner "D-C · every /command named in prose ships, or is allowlisted"
DOCS_REPO="$REPO" "$PY" - <<'PYEOF' > "$REPO/tests/.docs-out" 2>&1
import glob, os, re, importlib.util
spec = importlib.util.spec_from_file_location(
    "readers", os.path.join(os.environ["DOCS_REPO"], "tests", ".docs-readers.py"))
R = importlib.util.module_from_spec(spec); spec.loader.exec_module(R)
REPO = R.REPO

SHIPS = set()
for f in glob.glob(os.path.join(REPO, "templates/commands/*.md")):
    stem = os.path.basename(f)[:-3]
    if stem != "README":
        SHIPS.add(stem)
# listdir, not a `*/` glob: glob returns OS-separated paths, so on Windows the
# trailing separator is a backslash and rstrip("/") leaves it on — every skill then
# basenames to the empty string and the whole set collapses to one entry.
skills_dir = os.path.join(REPO, "templates", "skills")
for name in sorted(os.listdir(skills_dir)):
    if os.path.isdir(os.path.join(skills_dir, name)):
        SHIPS.add(name)

# The allowlist is short on purpose and split by REASON, because "it is on the list"
# is not a reason. Anything added needs a line saying which of the three it is.

# 1. Claude Code built-ins. The user really can type these; no template ships them
#    because the harness owns them.
BUILTINS = {
    "mcp", "plugin", "goal", "clear", "compact", "config", "help", "init",
    "resume", "agents", "doctor", "model", "login", "logout", "cost", "memory",
    "permissions", "status", "vim", "hooks", "review", "pr-comments",
    "effort", "workflows", "deep-research",
}

# 2. Not a command at all — the regex cannot tell these from one, and a human can.
NOT_A_COMMAND = {
    "tmp",              # `cd /tmp && …` — a filesystem path
    "foo", "deploy",    # illustrative skill names in the two README naming examples
    "triage",           # a local-markdown tracker ROLE string, not a flow
}

# 3. Named in prose, deliberately not shipped. THIS is the group the assertion
#    exists for, and every entry is a debt with an owner.
UNSHIPPED = {
    # #109 §8: docs/shared/12-when-not-to-use.md describes a `/hotfix` PATTERN you
    # assemble by hand. The decision-table row now says so too, instead of sitting
    # formatted identically to the rows whose commands ship.
    "hotfix",
    # Issue #104 owns these two templates. They are named in the flow catalogue and
    # do not exist yet. DELETE THESE TWO NAMES when #104 ships them — that is what
    # makes this list a tripwire rather than a place to bury things.
    "close-ticket", "confirm-deployment",
}

ALLOW = BUILTINS | NOT_A_COMMAND | UNSHIPPED

# A command reference, not a path fragment: nothing path-like before it, and no
# slash after the name. The lookbehind excludes `docs/shared/x.md`, `../../templates/`
# and `and/or`; `)` and `]` catch `repo(s)/paths`; and `<`/`>` catch the placeholder
# segments this repo's own paths are full of — `<repo>/lint-recheck-batch<N>.md`,
# `issues/<n>/comments`, `</script>`.
CMD = re.compile(r"(?<![A-Za-z0-9_.~/)\]<>\-])/([a-z][a-z0-9]*(?:-[a-z0-9]+)*)(?![/\w.-])")

bad, seen = [], 0
for rel in R.tracked(".md"):
    for n, line in enumerate(R.strip_fences(R.read(rel)).splitlines(), 1):
        for m in CMD.finditer(line):
            name = m.group(1)
            seen += 1
            if name in SHIPS or name in ALLOW:
                continue
            bad.append("%s:%d  /%s is named in prose but ships no template" % (rel, n, name))

print("SHIPS %d" % len(SHIPS))
print("SEEN %d" % seen)
for b in sorted(set(bad)):
    print("BAD " + b)
PYEOF
D_C_SHIPS="$(sed -n 's/^SHIPS //p' "$REPO/tests/.docs-out")"
D_C_SEEN="$(sed -n 's/^SEEN //p' "$REPO/tests/.docs-out")"
if [ "${D_C_SHIPS:-0}" -ge 30 ] && [ "${D_C_SEEN:-0}" -ge 20 ]; then
  pass "${D_C_SEEN} /command references checked against ${D_C_SHIPS} shipped templates"
else
  fail "matcher broken: ${D_C_SEEN:-0} references against ${D_C_SHIPS:-0} templates"
fi
if grep -q '^BAD ' "$REPO/tests/.docs-out"; then
  while IFS= read -r b; do fail "${b#BAD }"; done < <(grep '^BAD ' "$REPO/tests/.docs-out")
else
  pass "every /command in prose ships a template or is allowlisted"
fi
fi

# ---------------------------------------------------------------- D-D
# The tree is an index, and an index that silently omits an entry is worse than no
# index: a contributor reading *Repo layout* to find where the tests live was told
# the repo has none.
#
# Catches: #109 §5, and the next top-level directory added.
if want D-D; then
banner "D-D · the README layout tree names every top-level entry"
DOCS_REPO="$REPO" "$PY" - <<'PYEOF' > "$REPO/tests/.docs-out" 2>&1
import os, re, subprocess, importlib.util
spec = importlib.util.spec_from_file_location(
    "readers", os.path.join(os.environ["DOCS_REPO"], "tests", ".docs-readers.py"))
R = importlib.util.module_from_spec(spec); spec.loader.exec_module(R)
REPO = R.REPO

# Tracked, so an ignored scratch file (.claude/, a .stackdump) is not a gap in the
# index — and a newly tracked one is.
top = sorted(set(subprocess.check_output(
    ["git", "-C", REPO, "ls-tree", "--name-only", "HEAD"]).decode("utf-8").split()))

readme = R.read("README.md")
m = re.search(r"^```\s*\nclaude-code-playbook/\n(.*?)^```", readme, re.M | re.S)
if not m:
    print("BAD README.md  the `claude-code-playbook/` layout tree is gone")
    print("TREE 0"); raise SystemExit
block = m.group(1)
# Only the top level: a line whose connector sits in the first column.
named = set()
for line in block.splitlines():
    mm = re.match(r"^[├└]── ([^\s]+)", line)
    if mm:
        named.add(mm.group(1).rstrip("/"))

print("TREE %d" % len(named))
for entry in top:
    if entry not in named:
        print("BAD README.md  the layout tree does not name top-level `%s`" % entry)
PYEOF
D_D_TREE="$(sed -n 's/^TREE //p' "$REPO/tests/.docs-out")"
if [ "${D_D_TREE:-0}" -ge 5 ]; then
  pass "parsed $D_D_TREE top-level entries out of the README tree"
else
  fail "parsed only ${D_D_TREE:-0} entries out of the README tree — the parser is broken, not the tree"
fi
if grep -q '^BAD ' "$REPO/tests/.docs-out"; then
  while IFS= read -r b; do fail "${b#BAD }"; done < <(grep '^BAD ' "$REPO/tests/.docs-out")
else
  pass "every tracked top-level entry appears in the layout tree"
fi
fi

rm -f "$REPO/tests/.docs-out" "$REPO/tests/.docs-readers.py"

# ---------------------------------------------------------------- tally
printf '\n=== %s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" != "0" ]; then
  printf '\nfailed:\n'
  for n in "${FAILED_NAMES[@]}"; do printf '  - %s\n' "$n"; done
  exit 1
fi
exit 0
