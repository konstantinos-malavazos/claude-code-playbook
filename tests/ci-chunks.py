"""Turn the README's installer-suite chunks into the Windows CI matrix.

    python3 tests/ci-chunks.py [README.md [tests/test-installer.sh]]

Prints two lines for $GITHUB_OUTPUT, one job per chunk:

    chunks=["installer-i1", ...]
    sections={"installer-i1": "13 17 1 ...", ...}

Exits 1, naming the section, unless every section of the suite is in exactly one chunk
and each coupled group (`if want A || want B`) sits inside one chunk. A coupled group
split across two jobs runs its shared section in both.
"""
import io
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The README parse is test-docs.sh D-J's, so the chunks D-J checks are the jobs CI runs.
HEAD = "### Running the installer suite"
CHUNK = re.compile(r"bash tests/test-installer\.sh[ \t]+(\S.*)$")
NAME = re.compile(r"\$S/([A-Za-z0-9_-]+)")
WANT = re.compile(r"(?:^|[^A-Za-z0-9_])want ([A-Za-z0-9]+)")
GUARD = re.compile(r"^\s*if\s+(want\s+\S+(?:\s*\|\|\s*want\s+\S+)+)\s*;\s*then\b")


def read(path):
    with io.open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def readme_chunks(text):
    out, inside, fenced = [], False, False
    for line in text.splitlines():
        if line.startswith("```"):
            fenced = not fenced
        if line.startswith(HEAD):
            inside = True
        elif inside and not fenced and (line.startswith("---") or re.match(r"#{1,6} ", line)):
            break
        elif inside:
            m = CHUNK.search(line)
            if m:
                n = NAME.search(line)
                out.append(("installer-" + (n.group(1) if n else str(len(out) + 1)),
                            m.group(1).split()))
    return out


def suite_sections(text):
    """The suite's section ids, by its own unknown-id rule, and its coupled groups."""
    ids, groups = set(), []
    for line in text.splitlines():
        if line.lstrip().startswith("#"):
            continue
        ids.update(WANT.findall(line))
        m = GUARD.match(line)
        if m:
            groups.append([p.split()[1] for p in m.group(1).split("||")])
    return ids, groups


def main(argv):
    readme = argv[1] if len(argv) > 1 else os.path.join(REPO, "README.md")
    suite = argv[2] if len(argv) > 2 else os.path.join(REPO, "tests", "test-installer.sh")
    chunks = readme_chunks(read(readme))
    ids, groups = suite_sections(read(suite))
    where = {}
    for name, sections in chunks:
        for i in sections:
            where.setdefault(i, []).append(name)

    bad = []
    if not chunks:
        bad.append("found no installer chunks under %r in %s" % (HEAD, readme))
    if not ids:
        bad.append("found no sections in %s" % suite)
    names = [n for n, _ in chunks]
    for n in sorted(set(n for n in names if names.count(n) > 1)):
        bad.append("two chunks are both named %s" % n)
    for i in sorted(ids - set(where)):
        bad.append("section %s is in no README chunk, so no CI job runs it" % i)
    for i in sorted(where):
        if i not in ids:
            bad.append("README chunk %s names %s, which is not a section of the suite"
                       % (where[i][0], i))
        elif len(where[i]) > 1:
            bad.append("section %s is in more than one chunk (%s), so CI runs it twice"
                       % (i, " ".join(where[i])))
    for g in groups:
        owners = sorted(set(where[i][0] for i in g if i in where))
        if len(owners) > 1:
            bad.append("the coupled sections %s are split across chunks %s, so their"
                       " shared setup runs twice" % (" ".join(g), " ".join(owners)))
    if bad:
        for b in bad:
            sys.stderr.write("ci-chunks: %s\n" % b)
        return 1

    out = "chunks=%s\nsections=%s\n" % (
        json.dumps(names),
        json.dumps(dict((n, " ".join(s)) for n, s in chunks)))
    sys.stdout.buffer.write(out.encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
