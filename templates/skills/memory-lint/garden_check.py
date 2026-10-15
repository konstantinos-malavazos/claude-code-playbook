#!/usr/bin/env python3
"""garden_check: read-only staleness checks over a dump of stored memories.

usage   garden_check.py <memories.json> --workspace <dir>

input   a JSON array of stored memories, as the memory server returns them: id, title,
        content, context, keywords, tags, importance, project_ids, source_files and,
        in a multi-repo workspace, source_repo (the repo folder's name under <dir>).
        A memory without source_repo is checked against <dir> itself when <dir> is a
        git repo.
main    per repo, from the "Main branch per repo" table in <dir>/CLAUDE.md, else from
        refs/remotes/origin/HEAD. Neither: a "main branch unknown" row, never a guess.
checks  a-source-files  each source_files path exists, case-exact, in the main tree
        b-code-symbol   each backticked code symbol in content is on main (git grep -w)
        c-lint          lint.py re-run on the memory as a create (FAIL lines only)
        d-duplicate     same type, and a similar title or a shared source_files path
stdout  one row per finding, LF only: memory_id <TAB> check <TAB> finding <TAB> proposed_action
exit    0 when the run completes, whatever it found; 2 on input it cannot read.

It never writes to git or to memory, and it never calls the memory server.
"""
import argparse
import difflib
import importlib.util
import json
import os
import re
import subprocess
import sys

# Importing lint by path would otherwise drop a __pycache__ into the skill folder,
# and the installer copies a skill as a whole directory.
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
EXIT_UNREADABLE = 2


def _load_lint():
    spec = importlib.util.spec_from_file_location("memory_lint", os.path.join(HERE, "lint.py"))
    if spec is None or spec.loader is None:
        raise ImportError("cannot load lint.py beside garden_check.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _git(repo, *args):
    p = subprocess.run(["git"] + list(args), cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return p.returncode, p.stdout


def _is_repo(path):
    return os.path.isdir(path) and os.path.exists(os.path.join(path, ".git"))


def _field(value):
    return " ".join(str(value).split())


def main_branch_table(workspace):
    """Repo name -> branch, from the "Main branch per repo" table. Template rows are skipped."""
    try:
        with open(os.path.join(workspace, "CLAUDE.md"), "rb") as fh:
            text = fh.read().decode("utf-8-sig", "replace")
    except OSError:
        return {}
    table, in_section = {}, False
    for line in text.splitlines():
        if line.startswith("#"):
            in_section = bool(re.match(r"#+\s*main branch", line, re.IGNORECASE))
            continue
        if not in_section or not line.lstrip().startswith("|"):
            continue
        cells = [c.strip().strip("`").strip() for c in re.split(r"(?<!\\)\|", line.strip())[1:-1]]
        if len(cells) < 2:
            continue
        repo, branch = cells[0].rstrip("/"), cells[1]
        if not repo or not branch or "<" in repo or "<" in branch or repo.lower() == "repo":
            continue
        if not set(repo) - set("-: "):
            continue
        table[repo] = branch
    return table


def _verify(repo, ref):
    rc, _ = _git(repo, "rev-parse", "--verify", "-q", ref + "^{commit}")
    return rc == 0


def resolve_main(repo, name, table):
    """(ref, label) for the repo's main branch, or (None, why)."""
    if name in table:
        branch = table[name]
        for ref in ("refs/heads/" + branch, "refs/remotes/origin/" + branch):
            if _verify(repo, ref):
                return ref, branch
        return None, "main branch unknown: '%s' from CLAUDE.md does not resolve in %s" % (branch, name)
    rc, out = _git(repo, "symbolic-ref", "-q", "refs/remotes/origin/HEAD")
    ref = out.decode("utf-8", "replace").strip()
    if rc == 0 and ref and _verify(repo, ref):
        return ref, ref[len("refs/remotes/"):] if ref.startswith("refs/remotes/") else ref
    return None, ("main branch unknown for %s: not in the CLAUDE.md table and no "
                  "refs/remotes/origin/HEAD" % name)


def _tree(repo, ref):
    rc, out = _git(repo, "ls-tree", "-r", "-z", "--name-only", ref)
    files = set(p for p in out.decode("utf-8", "replace").split("\0") if p) if rc == 0 else set()
    dirs = set()
    for f in files:
        parts = f.split("/")[:-1]
        for i in range(1, len(parts) + 1):
            dirs.add("/".join(parts[:i]))
    lower = {}
    for p in files | dirs:
        lower.setdefault(p.lower(), p)
    return files, dirs, lower


def _removal(repo, ref, path):
    """('renamed', new) / ('deleted', None) / ('absent', None) for a path not in the tree."""
    rc, out = _git(repo, "log", ref, "--follow", "-M", "--name-status", "--format=%x01%H", "--", path)
    if rc != 0:
        return "absent", None
    commit = None
    for chunk in out.decode("utf-8", "replace").split("\x01")[1:]:
        lines = chunk.splitlines()
        if any(l.split("\t")[:1] == ["D"] or (l.startswith("R") and l.split("\t")[1:2] == [path])
               for l in lines[1:]):
            commit = lines[0].strip()
            break
    if not commit:
        return "absent", None
    # --follow filters the diff to the old name, so a rename away from it reads as "D".
    # Only a diff of the whole commit can pair the old name with the new one.
    rc, out = _git(repo, "diff-tree", "-r", "-M", "--name-status", "-z", "--no-commit-id", commit)
    toks = out.decode("utf-8", "replace").split("\0") if rc == 0 else []
    i = 0
    while i < len(toks):
        status = toks[i]
        if status[:1] in ("R", "C") and i + 2 < len(toks):
            if status[:1] == "R" and toks[i + 1] == path:
                return "renamed", toks[i + 2]
            i += 3
        else:
            i += 2
    return "deleted", None


class Repo(object):
    def __init__(self, path, name, table):
        self.path, self.name = path, name
        self.ref, self.label = resolve_main(path, name, table)
        self._tree = None

    def tree(self):
        if self._tree is None:
            self._tree = _tree(self.path, self.ref)
        return self._tree


def _repo_for(mem, workspace, table, cache):
    name = mem.get("source_repo")
    if isinstance(name, str) and name.strip():
        name = name.strip().rstrip("/").split("/")[-1]
        path = os.path.join(workspace, name)
        if not _is_repo(path):
            if os.path.basename(os.path.normpath(workspace)) == name and _is_repo(workspace):
                path = workspace
            else:
                return None, "repo unknown: no git repo '%s' under the workspace" % name
    elif _is_repo(workspace):
        path, name = workspace, os.path.basename(os.path.normpath(workspace))
    else:
        return None, "repo unknown: no source_repo, and the workspace is not a git repo"
    if path not in cache:
        cache[path] = Repo(path, name, table)
    return cache[path], None


def check_source_files(repo, files):
    rows = []
    tree_files, tree_dirs, lower = repo.tree()
    for path in files:
        if not isinstance(path, str) or not path:
            continue
        p = path.rstrip("/")
        if p in tree_files or p in tree_dirs:
            continue
        if p.lower() in lower:
            actual = lower[p.lower()]
            rows.append(("case mismatch: '%s' is '%s' on %s" % (path, actual, repo.label),
                         "update source_files to '%s'" % actual))
            continue
        how, new = _removal(repo.path, repo.ref, p)
        if how == "renamed":
            gone = "" if new in tree_files else " (and '%s' is not on %s either)" % (new, repo.label)
            rows.append(("'%s' renamed to '%s' on %s%s" % (path, new, repo.label, gone),
                         "update source_files to '%s'" % new))
        elif how == "deleted":
            rows.append(("'%s' deleted on %s" % (path, repo.label),
                         "update source_files, or mark the memory obsolete"))
        else:
            rows.append(("'%s' not found on %s and never was" % (path, repo.label),
                         "fix the path in source_files"))
    return rows


def code_symbols(content, pattern):
    seen = []
    for tok in re.findall(r"`([^`\n]+)`", content or ""):
        tok = tok.strip()
        if pattern.match(tok):
            tok = tok[:-2] if tok.endswith("()") else tok
            if tok not in seen:
                seen.append(tok)
    return seen


def check_code_symbols(repo, symbols):
    rows = []
    for sym in symbols:
        rc, _ = _git(repo.path, "grep", "-q", "-w", "-F", "-e", sym, repo.ref, "--")
        if rc == 1:
            rows.append(("`%s` not found on %s" % (sym, repo.label), "confirm-via-serena"))
        elif rc != 0:
            rows.append(("git grep failed for `%s` (exit %d)" % (sym, rc), "re-run the check"))
    return rows


def check_duplicates(mems, lint, vocab, ratio):
    rows = []
    keyed = []
    for m in mems:
        types = lint.type_tags(m.get("tags"), vocab)
        title = m.get("title") if isinstance(m.get("title"), str) else ""
        repo = m.get("source_repo") or ""
        files = m.get("source_files") if isinstance(m.get("source_files"), list) else []
        keyed.append((m, types[0] if len(types) == 1 else None, title.lower(),
                      set((repo, f) for f in files if isinstance(f, str))))
    for i in range(len(keyed)):
        a, ta, title_a, files_a = keyed[i]
        if ta is None:
            continue
        for j in range(i + 1, len(keyed)):
            b, tb, title_b, files_b = keyed[j]
            if tb != ta:
                continue
            why = []
            sm = difflib.SequenceMatcher(None, title_a, title_b)
            if title_a and title_b and sm.real_quick_ratio() >= ratio and sm.quick_ratio() >= ratio:
                r = sm.ratio()
                if r >= ratio:
                    why.append("title similarity %.2f" % r)
            shared = sorted(f for _, f in files_a & files_b)
            if shared:
                why.append("shared source_files: " + ", ".join(shared))
            if why:
                rows.append((_mid(a), "near-duplicate of %s (%s; same type %s)" % (_mid(b), "; ".join(why), ta),
                             "review: merge into one memory, or link the two"))
    return rows


def _mid(mem):
    return mem.get("id", mem.get("memory_id", "?"))


def garden_settings(vocab):
    garden = vocab.get("garden")
    if not isinstance(garden, dict):
        raise ValueError("vocab.json lacks a garden object")
    missing = [k for k in ("code_symbol_pattern", "duplicate_title_ratio") if k not in garden]
    if missing:
        raise ValueError("vocab.json garden lacks " + ", ".join(missing))
    ratio = garden["duplicate_title_ratio"]
    if isinstance(ratio, bool) or not isinstance(ratio, (int, float)):
        raise ValueError("vocab.json garden duplicate_title_ratio is not a number")
    return re.compile(garden["code_symbol_pattern"]), ratio


def run(mems, workspace, lint, vocab, sym_rx, ratio):
    table = main_branch_table(workspace)
    rows, cache = [], {}
    for m in mems:
        mid = _mid(m)
        files = m.get("source_files") if isinstance(m.get("source_files"), list) else []
        symbols = code_symbols(m.get("content"), sym_rx)
        if files or symbols:
            repo, why = _repo_for(m, workspace, table, cache)
            if repo is None:
                rows.append((mid, "setup", why, "set source_repo on the memory"))
            elif repo.ref is None:
                rows.append((mid, "setup", repo.label,
                             "add the repo to the Main branch per repo table in CLAUDE.md"))
            else:
                rows += [(mid, "a-source-files") + r for r in check_source_files(repo, files)]
                rows += [(mid, "b-code-symbol") + r for r in check_code_symbols(repo, symbols)]
        for level, rule, reason in lint.lint_create(m, vocab):
            if level == "FAIL":
                rows.append((mid, "c-lint", "FAIL %s: %s" % (rule, reason),
                             "update the memory to the current vocabulary"))
    for mid, finding, action in check_duplicates(mems, lint, vocab, ratio):
        rows.append((mid, "d-duplicate", finding, action))
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser(description="Read-only staleness checks over a memory dump.")
    ap.add_argument("memories", help="JSON array of stored memories")
    ap.add_argument("--workspace", required=True, help="workspace (or single repo) directory")
    args = ap.parse_args(argv)
    try:
        with open(args.memories, "rb") as fh:
            mems = json.loads(fh.read().decode("utf-8-sig"))
        if not isinstance(mems, list) or not all(isinstance(m, dict) for m in mems):
            raise ValueError("expected a JSON array of memory objects")
        if not os.path.isdir(args.workspace):
            raise ValueError("workspace is not a directory: %s" % args.workspace)
        lint = _load_lint()
        vocab = lint.load_vocab()
        sym_rx, ratio = garden_settings(vocab)
    except Exception as exc:
        sys.stderr.write("garden_check: cannot read input: %s\n" % exc)
        return EXIT_UNREADABLE
    rows = run(mems, os.path.abspath(args.workspace), lint, vocab, sym_rx, ratio)
    text = "".join("\t".join(_field(c) for c in row) + "\n" for row in rows)
    sys.stdout.buffer.write(text.encode("utf-8"))
    sys.stdout.buffer.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
