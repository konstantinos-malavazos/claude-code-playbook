#!/usr/bin/env python3
"""memory-lint tests. Run: python -I templates/skills/memory-lint/tests.py

Every rule and every garden check has a known-bad case (it must be caught) and a
known-good case (it must pass). Exit 0 only when every case passes.
"""
import copy
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile

# Importing lint by path would otherwise drop a __pycache__ into the skill folder,
# and the installer copies a skill as a whole directory.
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
LINT_PY = os.path.join(HERE, "lint.py")
GARDEN_PY = os.path.join(HERE, "garden_check.py")
VOCAB_JSON = os.path.join(HERE, "vocab.json")


def _load_lint():
    spec = importlib.util.spec_from_file_location("memory_lint_under_test", LINT_PY)
    if spec is None or spec.loader is None:
        raise ImportError("cannot load " + LINT_PY)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


lint = _load_lint()

CASES = []


def case(fn):
    CASES.append((fn.__name__, fn))
    return fn


class Fail(Exception):
    pass


def check(cond, msg):
    if not cond:
        raise Fail(msg)


def base_vocab(**over):
    with open(VOCAB_JSON, "rb") as fh:
        v = json.loads(fh.read().decode("utf-8"))
    v = copy.deepcopy(v)
    v.update(over)
    return v


def good_args(**over):
    a = {
        "title": "Retry wrapper swallows the timeout error",
        "content": "The retry wrapper catches the timeout error and retries without a "
                   "deadline, so callers must pass one or the import never ends.",
        "context": "Seen while debugging the importer.",
        "keywords": ["retry", "timeout"],
        "tags": ["gotcha", "importer"],
        "importance": 8,
        "project_ids": [3],
        "source_files": ["src/retry.py"],
    }
    for k, val in over.items():
        if val is DROP:
            a.pop(k, None)
        else:
            a[k] = val
    return a


DROP = object()


def run_lint(args, vocab=None, tool="create_memory"):
    v = vocab if vocab is not None else base_vocab()
    return lint.lint({"tool_name": tool, "arguments": args}, v)


def fails_with(rule, args, vocab=None, tool="create_memory"):
    got = run_lint(args, vocab, tool)
    hit = [f for f in got if f[0] == "FAIL" and f[1] == rule]
    check(hit, "expected FAIL %s, got %r" % (rule, got))
    return hit


def passes(args, vocab=None, tool="create_memory"):
    got = run_lint(args, vocab, tool)
    bad = [f for f in got if f[0] == "FAIL"]
    check(not bad, "expected no FAIL, got %r" % (got,))
    return got


def cli(stdin_bytes, argv=None, cwd=None, script=None):
    cmd = [sys.executable, "-I"] + (argv if argv is not None else [script or LINT_PY])
    p = subprocess.run(cmd, input=stdin_bytes, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, cwd=cwd)
    return p.returncode, p.stdout, p.stderr


def payload_bytes(args, tool="create_memory"):
    return json.dumps({"tool_name": tool, "arguments": args}).encode("utf-8")


# ---------------------------------------------------------------- vocab as data

TICKET_TYPES = {
    "ruling": (9, "optional"), "contract": (8, "required"), "gotcha": (8, "required"),
    "architecture": (8, "required"), "investigation": (7, "optional"),
    "recipe": (7, "required"), "feature": (6, "required"),
}


@case
def vocab_ships_the_seven_types_with_their_bands():
    v = base_vocab()
    got = {k: (t.get("importance"), t.get("source_files")) for k, t in v.get("types", {}).items()}
    check(got == TICKET_TYPES, "types table differs: %r" % (got,))
    check(v.get("importance_tolerance") == 1, "importance_tolerance is not 1")


@case
def vocab_ships_tag_lists_empty():
    v = base_vocab()
    for key, empty in (("repo_tags", []), ("functional_tags", []), ("renames", {}), ("retired", {})):
        check(key in v and v[key] == empty, "%s should ship as %r, got %r" % (key, empty, v.get(key)))


@case
def lint_source_hardcodes_no_vocabulary():
    with open(LINT_PY, "rb") as fh:
        src = fh.read().decode("utf-8")
    leaked = [w for w in list(TICKET_TYPES) + ["watermark", "RESUME", "progress"] if w in src]
    check(not leaked, "lint.py hardcodes vocabulary: %r" % leaked)


# ---------------------------------------------------------------- type

@case
def type_one_type_tag_passes():
    passes(good_args())


@case
def type_tag_missing_fails():
    fails_with("type", good_args(tags=["importer"]))


@case
def type_two_type_tags_fails():
    fails_with("type", good_args(tags=["gotcha", "ruling", "importer"]))


# ---------------------------------------------------------------- importance

@case
def importance_at_band_edge_passes():
    passes(good_args(importance=9))


@case
def importance_outside_band_fails():
    fails_with("importance", good_args(importance=5))


@case
def importance_not_an_int_fails():
    fails_with("importance", good_args(importance="8"))


# ---------------------------------------------------------------- source_files

@case
def source_files_missing_on_required_type_fails():
    fails_with("source_files", good_args(source_files=DROP))


@case
def source_files_empty_on_required_type_fails():
    fails_with("source_files", good_args(source_files=[]))


@case
def source_files_absent_on_optional_type_passes():
    passes(good_args(tags=["ruling", "importer"], importance=9, source_files=DROP))


@case
def source_files_not_a_list_fails():
    fails_with("source_files", good_args(source_files="src/retry.py"))


@case
def source_files_empty_string_fails():
    fails_with("source_files", good_args(source_files=[""]))


@case
def source_files_absolute_posix_fails():
    fails_with("source_files", good_args(source_files=["/src/retry.py"]))


@case
def source_files_drive_letter_fails():
    fails_with("source_files", good_args(source_files=["C:/src/retry.py"]))


@case
def source_files_backslash_fails():
    fails_with("source_files", good_args(source_files=["src\\retry.py"]))


@case
def source_files_parent_segment_fails():
    fails_with("source_files", good_args(source_files=["../other/retry.py"]))


@case
def contract_with_one_side_fails():
    fails_with("source_files", good_args(tags=["contract", "importer"], source_files=["src/a.py"]))


@case
def contract_with_both_sides_passes():
    passes(good_args(tags=["contract", "importer"], source_files=["src/a.py", "api/b.py"]))


# ---------------------------------------------------------------- project_ids

@case
def project_ids_one_owner_passes():
    passes(good_args(project_ids=[7]))


@case
def project_ids_empty_fails():
    fails_with("project_ids", good_args(project_ids=[]))


@case
def project_ids_two_fails():
    fails_with("project_ids", good_args(project_ids=[3, 4]))


@case
def project_ids_not_int_fails():
    fails_with("project_ids", good_args(project_ids=["3"]))


# ---------------------------------------------------------------- required fields

def _required_case(field):
    def fn():
        hit = fails_with("required", good_args(**{field: DROP}))
        check(any(field in f[2] for f in hit), "required FAIL does not name %s: %r" % (field, hit))
    fn.__name__ = "required_field_missing_fails_" + field
    return fn


for _f in ("title", "content", "context", "keywords", "tags", "importance", "project_ids"):
    case(_required_case(_f))


@case
def required_fields_all_present_passes():
    passes(good_args())


# ---------------------------------------------------------------- keywords

@case
def keywords_at_cap_passes():
    passes(good_args(keywords=["k%d" % i for i in range(10)]))


@case
def keywords_over_cap_fails():
    fails_with("keywords", good_args(keywords=["k%d" % i for i in range(11)]))


# ---------------------------------------------------------------- tags

@case
def tags_at_cap_passes():
    passes(good_args(tags=["gotcha"] + ["t%d" % i for i in range(9)]))


@case
def tags_over_cap_fails():
    fails_with("tags", good_args(tags=["gotcha"] + ["t%d" % i for i in range(10)]))


@case
def tag_uppercase_fails():
    fails_with("tag-case", good_args(tags=["gotcha", "Importer"]))


@case
def tag_renamed_fails_and_names_replacement():
    v = base_vocab(renames={"db": "database"})
    hit = fails_with("tag-rename", good_args(tags=["gotcha", "importer", "db"]), v)
    check(any("database" in f[2] for f in hit), "rename FAIL does not name the replacement: %r" % hit)


@case
def tag_rename_target_passes():
    passes(good_args(tags=["gotcha", "importer", "database"]), base_vocab(renames={"db": "database"}))


@case
def tag_retired_fails():
    fails_with("tag-retired", good_args(tags=["gotcha", "importer", "legacy"]),
               base_vocab(retired={"legacy": "the legacy importer is gone"}))


@case
def tag_ticket_id_lowercase_fails():
    fails_with("tag-ticket-id", good_args(tags=["gotcha", "importer", "proj-1234"]))


@case
def tag_ticket_id_uppercase_fails():
    fails_with("tag-ticket-id", good_args(tags=["gotcha", "importer", "PROJ-1234"]))


@case
def tag_hyphenated_word_passes():
    passes(good_args(tags=["gotcha", "importer", "auth-flow"]))


@case
def repo_tags_empty_warns_and_passes():
    got = passes(good_args())
    warn = [f for f in got if f[0] == "WARN" and f[1] == "repo-tag"]
    check(warn and warn[0][2] == "repo_tags is empty \u2014 repo-tag rule not checked",
          "expected the repo_tags WARN, got %r" % (got,))


@case
def repo_tags_empty_type_tag_alone_fails():
    fails_with("repo-tag", good_args(tags=["gotcha"]))


@case
def repo_tags_filled_tag_outside_list_fails():
    fails_with("repo-tag", good_args(tags=["gotcha", "importer"]), base_vocab(repo_tags=["app", "lib"]))


@case
def repo_tags_filled_tag_in_list_passes_without_warn():
    got = passes(good_args(tags=["gotcha", "app"]), base_vocab(repo_tags=["app", "lib"]))
    check(not [f for f in got if f[0] == "WARN" and f[1] == "repo-tag"], "WARN still printed: %r" % (got,))


@case
def functional_tags_empty_any_tag_passes():
    passes(good_args(tags=["gotcha", "app", "anything-at-all"]), base_vocab(repo_tags=["app"]))


@case
def functional_tags_filled_unknown_tag_fails():
    fails_with("functional-tag", good_args(tags=["gotcha", "app", "other"]),
               base_vocab(repo_tags=["app"], functional_tags=["importer"]))


@case
def functional_tags_filled_known_tag_passes():
    passes(good_args(tags=["gotcha", "app", "importer"]),
           base_vocab(repo_tags=["app"], functional_tags=["importer"]))


# ---------------------------------------------------------------- content: rejected

def _content(text):
    return good_args(content=text)


@case
def content_file_line_ref_fails():
    fails_with("line_refs", _content("The guard lives in install-lib.py:1227 and skips agents."))


@case
def content_line_word_ref_fails():
    fails_with("line_refs", _content("The guard at line 123 skips agents."))


@case
def content_l_number_ref_fails():
    fails_with("line_refs", _content("See L123 in the guard for the skip."))


@case
def content_cache_level_and_port_pass():
    passes(_content("An L2 cache miss here is cheap; the server listens on localhost:8080."))


@case
def content_branch_is_merged_fails():
    fails_with("branch_state", _content("The branch feature/retry is merged, so the fix is live."))


@case
def content_is_current_branch_fails():
    fails_with("branch_state", _content("This work is the current branch for the importer."))


@case
def content_branch_naming_rule_passes():
    passes(_content("A branch name must start with the ticket id so the hook can read it."))


@case
def content_resume_word_fails():
    fails_with("flow_state", _content("RESUME from step four after the review."))


@case
def content_in_progress_fails():
    fails_with("flow_state", _content("The importer rewrite is in progress and half done."))


@case
def content_watermark_fails():
    fails_with("flow_state", _content("Read up to the watermark and stop there."))


@case
def content_lowercase_resume_passes():
    passes(_content("The job can resume after a restart because it is idempotent."))


@case
def content_rules_cover_title():
    fails_with("line_refs", good_args(title="Guard at retry.py:40 swallows timeouts"))


@case
def content_rules_cover_context():
    fails_with("flow_state", good_args(context="Written while the rewrite was in progress."))


# ---------------------------------------------------------------- content: warned

@case
def content_hard_count_warns_only():
    got = passes(_content("The parser accepts 5 flags and rejects the rest."))
    check([f for f in got if f[0] == "WARN" and f[1] == "hard_counts"], "no hard_counts WARN: %r" % (got,))


@case
def content_without_count_has_no_count_warn():
    got = passes(good_args())
    check(not [f for f in got if f[1] == "hard_counts"], "unexpected hard_counts finding: %r" % (got,))


# ---------------------------------------------------------------- update

@case
def update_partial_fields_passes():
    passes({"memory_id": 12, "importance": 3}, tool="update_memory")


@case
def update_two_type_tags_fails():
    fails_with("type", {"memory_id": 12, "tags": ["gotcha", "ruling", "importer"]}, tool="update_memory")


@case
def update_content_line_ref_fails():
    fails_with("line_refs", {"memory_id": 12, "content": "Moved to retry.py:88."}, tool="update_memory")


@case
def update_project_ids_two_fails():
    fails_with("project_ids", {"memory_id": 12, "project_ids": [1, 2]}, tool="update_memory")


@case
def update_keywords_over_cap_fails():
    fails_with("keywords", {"memory_id": 12, "keywords": ["k%d" % i for i in range(11)]}, tool="update_memory")


@case
def update_importance_outside_supplied_type_band_fails():
    fails_with("importance", {"memory_id": 12, "tags": ["gotcha", "importer"], "importance": 3},
               tool="update_memory")


@case
def update_tags_without_source_files_passes():
    passes({"memory_id": 12, "tags": ["gotcha", "importer"]}, tool="update_memory")


@case
def update_empty_source_files_on_supplied_required_type_fails():
    fails_with("source_files", {"memory_id": 12, "tags": ["gotcha", "importer"], "source_files": []},
               tool="update_memory")


# ---------------------------------------------------------------- other tools

@case
def other_tool_is_not_linted():
    got = run_lint({"query": "line 123 in progress RESUME"}, tool="query_memory")
    check(got == [], "query_memory was linted: %r" % (got,))


# ---------------------------------------------------------------- CLI contract

BAD = payload_bytes(good_args(tags=["importer"], importance=1, content="See retry.py:9."))


@case
def cli_good_write_exits_0_with_only_the_repo_tags_warn():
    rc, out, _ = cli(payload_bytes(good_args()))
    check(rc == 0, "exit %d, stdout %r" % (rc, out))
    check(out == "WARN repo-tag: repo_tags is empty \u2014 repo-tag rule not checked\n".encode("utf-8"),
          "stdout %r" % out)


@case
def cli_bad_write_exits_3_with_fail_lines():
    rc, out, _ = cli(BAD)
    lines = out.decode("utf-8").splitlines()
    check(rc == 3, "exit %d" % rc)
    check(any(l.startswith("FAIL type: ") for l in lines), "no 'FAIL type: ' line in %r" % lines)
    check(any(l.startswith("FAIL line_refs: ") for l in lines), "no 'FAIL line_refs: ' line in %r" % lines)


@case
def cli_stdout_is_lf_only():
    rc, out, _ = cli(BAD)
    check(out.count(b"\n") >= 2, "need two or more lines to prove it, got %r" % out)
    check(b"\r" not in out, "CR in stdout: %r" % out)


@case
def cli_crlf_payload_matches_lf_payload():
    lf = json.dumps({"tool_name": "create_memory", "arguments": good_args(tags=["importer"])}, indent=1)
    crlf = lf.replace("\n", "\r\n")
    a = cli(lf.encode("utf-8"))
    b = cli(crlf.encode("utf-8"))
    check(a[1] and a[:2] == b[:2], "LF %r vs CRLF %r" % (a[:2], b[:2]))


@case
def cli_bom_payload_is_read():
    rc, out, _ = cli(b"\xef\xbb\xbf" + BAD)
    check(rc == 3 and b"FAIL type: " in out, "exit %d stdout %r" % (rc, out))


@case
def cli_not_json_exits_3():
    rc, out, _ = cli(b"{not json")
    check(rc == 3 and out.startswith(b"FAIL payload: "), "exit %d stdout %r" % (rc, out))


@case
def cli_empty_stdin_exits_3():
    rc, out, _ = cli(b"")
    check(rc == 3 and out.startswith(b"FAIL payload: "), "exit %d stdout %r" % (rc, out))


@case
def cli_missing_tool_name_exits_3():
    rc, out, _ = cli(json.dumps({"arguments": good_args()}).encode("utf-8"))
    check(rc == 3 and out.startswith(b"FAIL payload: "), "exit %d stdout %r" % (rc, out))


@case
def cli_empty_tool_name_exits_3():
    rc, out, _ = cli(json.dumps({"tool_name": "", "arguments": good_args()}).encode("utf-8"))
    check(rc == 3 and out.startswith(b"FAIL payload: "), "exit %d stdout %r" % (rc, out))


@case
def cli_arguments_not_an_object_exits_3():
    rc, out, _ = cli(json.dumps({"tool_name": "create_memory", "arguments": ["x"]}).encode("utf-8"))
    check(rc == 3 and out.startswith(b"FAIL payload: "), "exit %d stdout %r" % (rc, out))


@case
def cli_whole_hook_payload_exits_3():
    whole = {"tool_name": "mcp__forgetful__execute_forgetful_tool",
             "tool_input": {"tool_name": "create_memory", "arguments": good_args(tags=["importer"])}}
    rc, out, _ = cli(json.dumps(whole).encode("utf-8"))
    check(rc == 3 and out.startswith(b"FAIL payload: "), "exit %d stdout %r" % (rc, out))


@case
def cli_other_tool_exits_0_silently():
    rc, out, _ = cli(payload_bytes({"query": "anything"}, tool="query_memory"))
    check(rc == 0 and out == b"", "exit %d stdout %r" % (rc, out))


@case
def cli_runs_through_runpy_from_another_cwd():
    prog = "import runpy,sys; p=sys.argv[1]; sys.argv=[p]; runpy.run_path(p, run_name='__main__')"
    tmp = tempfile.mkdtemp(prefix="ml-cwd-")
    try:
        rc, out, _ = cli(BAD, argv=["-c", prog, LINT_PY], cwd=tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    check(rc == 3 and b"FAIL type: " in out, "exit %d stdout %r" % (rc, out))


@case
def cli_missing_vocab_exits_3():
    tmp = tempfile.mkdtemp(prefix="ml-novocab-")
    try:
        shutil.copy(LINT_PY, os.path.join(tmp, "lint.py"))
        rc, out, _ = cli(payload_bytes(good_args()), script=os.path.join(tmp, "lint.py"))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    check(rc == 3 and out.startswith(b"FAIL vocab: "), "exit %d stdout %r" % (rc, out))


# ---------------------------------------------------------------- garden fixture

_GARDEN = {}


def _git_env(tmp):
    env = dict(os.environ)
    empty = os.path.join(tmp, "empty.gitconfig")
    if not os.path.exists(empty):
        open(empty, "wb").close()
    env.update({"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": empty,
                "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.invalid",
                "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.invalid"})
    return env


def _git(repo, env, *args):
    p = subprocess.run(["git"] + list(args), cwd=repo, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode != 0:
        raise RuntimeError("git %s failed: %s" % (" ".join(args), p.stderr.decode("utf-8", "replace")))
    return p.stdout.decode("utf-8", "replace")


def _write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(text.encode("utf-8"))


def _repo(ws, name, env, branch):
    r = os.path.join(ws, name)
    os.makedirs(r)
    _git(r, env, "init", "-q")
    _git(r, env, "symbolic-ref", "HEAD", "refs/heads/" + branch)
    return r


def _mem(mid, typ, title, repo, source_files=None, content="Plain words only.", tags_extra=None):
    imp = TICKET_TYPES[typ][0]
    m = {"id": mid, "title": title, "content": content, "context": "fixture",
         "keywords": ["fixture"], "tags": [typ] + (tags_extra or ["app"]),
         "importance": imp, "project_ids": [1]}
    if repo is not None:
        m["source_repo"] = repo
    if source_files is not None:
        m["source_files"] = source_files
    return m


def garden_fixture():
    if _GARDEN:
        return _GARDEN
    tmp = tempfile.mkdtemp(prefix="ml-garden-")
    env = _git_env(tmp)
    ws = os.path.join(tmp, "ws")
    os.makedirs(ws)
    _write(os.path.join(ws, "CLAUDE.md"),
           "# ws\n\n## Main branch per repo (prod target)\n\n| Repo | Main branch |\n|---|---|\n"
           "| `<repo-a>` | `<main\\|develop\\|...>` |\n| `app` | `main` |\n\n## Next\n")

    app = _repo(ws, "app", env, "main")
    _write(os.path.join(app, "src", "Main.py"), "def compute_total(xs):\n    return sum(xs)\n")
    _write(os.path.join(app, "docs", "old.md"),
           "".join("Line %d of a document that is long enough to be detected as a rename.\n" % i
                   for i in range(30)))
    _write(os.path.join(app, "gone.txt"), "soon gone\n")
    _git(app, env, "add", "-A")
    _git(app, env, "commit", "-q", "-m", "c1")
    _git(app, env, "mv", "docs/old.md", "docs/new.md")
    _git(app, env, "commit", "-q", "-m", "c2 rename")
    _git(app, env, "rm", "-q", "gone.txt")
    _git(app, env, "commit", "-q", "-m", "c3 delete")
    _git(app, env, "checkout", "-q", "-b", "feature")
    _write(os.path.join(app, "feat_only.py"), "def feature_only_func():\n    return 1\n")
    _git(app, env, "add", "-A")
    _git(app, env, "commit", "-q", "-m", "feature work")

    svc = _repo(ws, "svc", env, "trunk")
    _write(os.path.join(svc, "svc_only.py"), "X = 1\n")
    _git(svc, env, "add", "-A")
    _git(svc, env, "commit", "-q", "-m", "s1")
    _git(svc, env, "update-ref", "refs/remotes/origin/trunk", "refs/heads/trunk")
    _git(svc, env, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/trunk")
    _git(svc, env, "checkout", "-q", "-b", "work")
    _git(svc, env, "rm", "-q", "svc_only.py")
    _git(svc, env, "commit", "-q", "-m", "s2")
    _git(svc, env, "branch", "-q", "-D", "trunk")

    lib = _repo(ws, "lib", env, "dev")
    _write(os.path.join(lib, "lib.py"), "Y = 2\n")
    _git(lib, env, "add", "-A")
    _git(lib, env, "commit", "-q", "-m", "l1")

    mems = [
        _mem("a-ok", "ruling", "Totals are summed in one place", "app", ["src/Main.py"],
             content="Use `compute_total` for every sum."),
        _mem("a-case", "ruling", "Case mismatch fixture", "app", ["src/main.py"]),
        _mem("a-rename", "ruling", "Rename fixture", "app", ["docs/old.md"]),
        _mem("a-deleted", "ruling", "Deleted fixture", "app", ["gone.txt"]),
        _mem("a-feature", "ruling", "Feature branch file fixture", "app", ["feat_only.py"]),
        _mem("b-missing", "ruling", "Missing symbol fixture", "app", None,
             content="Call `vanished_func` before the import."),
        _mem("b-feature", "ruling", "Feature branch symbol fixture", "app", None,
             content="Call `feature_only_func` before the import."),
        _mem("c-drift", "ruling", "Drifted tag fixture", "app", None, tags_extra=["Importer"]),
        _mem("d-t1", "investigation", "Importer retries forever on timeout", "app", None),
        _mem("d-t2", "investigation", "Importer retries forever on timeouts", "app", None),
        _mem("d-x1", "recipe", "Importer retries forever on timeout", "app", ["docs/new.md"]),
        _mem("d-f1", "architecture", "Document layout overview", "app", ["docs/new.md"]),
        _mem("d-f2", "architecture", "Why pages render server side", "app", ["docs/new.md"]),
        _mem("d-n1", "feature", "Totals screen", "app", ["src/Main.py"]),
        _mem("d-n2", "feature", "Export to spreadsheet", "app", ["docs/new.md"]),
        _mem("svc-ok", "ruling", "Service fallback fixture", "svc", ["svc_only.py"]),
        _mem("lib-unknown", "ruling", "No main branch fixture", "lib", ["lib.py"]),
        _mem("no-repo", "ruling", "No repo fixture", None, ["lib.py"]),
    ]
    dump = os.path.join(tmp, "memories.json")
    with open(dump, "wb") as fh:
        fh.write(json.dumps(mems).encode("utf-8"))
    p = subprocess.run([sys.executable, "-I", GARDEN_PY, dump, "--workspace", ws],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    rows = []
    for line in p.stdout.decode("utf-8", "replace").split("\n"):
        if line:
            rows.append(line.split("\t"))
    _GARDEN.update({"tmp": tmp, "ws": ws, "env": env, "rc": p.returncode,
                    "raw": p.stdout, "err": p.stderr, "rows": rows})
    return _GARDEN


def rows_for(mid, check_name):
    return [r for r in garden_fixture()["rows"] if len(r) == 4 and r[0] == mid and r[1] == check_name]


def has_row(mid, check_name, *needles):
    got = rows_for(mid, check_name)
    check(got, "no %s row for %s; rows %r; stderr %r" % (check_name, mid, garden_fixture()["rows"],
                                                       garden_fixture()["err"][-400:]))
    text = " ".join(" ".join(r[2:]) for r in got)
    for n in needles:
        check(n in text, "%s row for %s does not mention %r: %r" % (check_name, mid, n, got))


def no_row(mid, check_name):
    got = rows_for(mid, check_name)
    check(garden_fixture()["rc"] == 0, "garden exit %d" % garden_fixture()["rc"])
    check(not got, "unexpected %s row for %s: %r" % (check_name, mid, got))


def pair_rows(a, b):
    return [r for r in garden_fixture()["rows"] if len(r) == 4 and r[1] == "d-duplicate"
            and ((r[0] == a and b in r[2]) or (r[0] == b and a in r[2]))]


# ---------------------------------------------------------------- garden checks

@case
def garden_completes_with_exit_0_and_rows():
    g = garden_fixture()
    check(g["rc"] == 0 and g["rows"], "exit %d rows %r stderr %r" % (g["rc"], g["rows"], g["err"][-400:]))


@case
def garden_rows_are_four_tab_fields_lf_only():
    g = garden_fixture()
    check(g["rows"] and all(len(r) == 4 for r in g["rows"]), "rows %r" % g["rows"])
    check(b"\r" not in g["raw"], "CR in garden stdout")


@case
def garden_a_present_file_no_row():
    no_row("a-ok", "a-source-files")


@case
def garden_a_case_mismatch_row():
    has_row("a-case", "a-source-files", "case", "src/Main.py")


@case
def garden_a_renamed_row():
    has_row("a-rename", "a-source-files", "renamed", "docs/new.md")


@case
def garden_a_deleted_row():
    has_row("a-deleted", "a-source-files", "deleted")


@case
def garden_a_checks_main_not_the_working_tree():
    has_row("a-feature", "a-source-files", "feat_only.py")


@case
def garden_b_present_symbol_no_row():
    no_row("a-ok", "b-code-symbol")


@case
def garden_b_missing_symbol_goes_to_serena():
    has_row("b-missing", "b-code-symbol", "vanished_func", "confirm-via-serena")


@case
def garden_b_checks_main_not_the_working_tree():
    has_row("b-feature", "b-code-symbol", "feature_only_func")


@case
def garden_c_lint_drift_row():
    has_row("c-drift", "c-lint", "tag-case")


@case
def garden_c_clean_memory_no_row():
    no_row("a-ok", "c-lint")


@case
def garden_d_similar_title_same_type_row():
    check(pair_rows("d-t1", "d-t2"), "no duplicate row for d-t1/d-t2: %r" % garden_fixture()["rows"])


@case
def garden_d_overlapping_source_files_row():
    check(pair_rows("d-f1", "d-f2"), "no duplicate row for d-f1/d-f2: %r" % garden_fixture()["rows"])


@case
def garden_d_different_type_no_row():
    no_row("d-x1", "d-duplicate")
    check(not pair_rows("d-t1", "d-x1"), "d-t1/d-x1 flagged across types")


@case
def garden_d_dissimilar_same_type_no_row():
    check(garden_fixture()["rc"] == 0, "garden exit %d" % garden_fixture()["rc"])
    check(not pair_rows("d-n1", "d-n2"), "d-n1/d-n2 flagged: %r" % pair_rows("d-n1", "d-n2"))


@case
def garden_main_from_origin_head_when_table_has_no_row():
    no_row("svc-ok", "a-source-files")
    no_row("svc-ok", "setup")


@case
def garden_main_unknown_row_and_no_guess():
    has_row("lib-unknown", "setup", "main branch unknown")
    no_row("lib-unknown", "a-source-files")


@case
def garden_repo_unknown_row():
    has_row("no-repo", "setup", "repo unknown")


@case
def garden_missing_input_exits_nonzero():
    p = subprocess.run([sys.executable, "-I", GARDEN_PY, os.path.join(HERE, "no-such-dump.json"),
                        "--workspace", HERE], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    check(p.returncode != 0, "exit %d for a missing dump" % p.returncode)


@case
def garden_invalid_json_exits_nonzero():
    tmp = tempfile.mkdtemp(prefix="ml-badjson-")
    try:
        bad = os.path.join(tmp, "m.json")
        with open(bad, "wb") as fh:
            fh.write(b"[{not json")
        p = subprocess.run([sys.executable, "-I", GARDEN_PY, bad, "--workspace", tmp],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    check(p.returncode != 0, "exit %d for invalid JSON" % p.returncode)


def _garden_with_vocab(edit):
    tmp = tempfile.mkdtemp(prefix="ml-gvocab-")
    try:
        for src in (LINT_PY, GARDEN_PY):
            shutil.copy(src, os.path.join(tmp, os.path.basename(src)))
        with open(VOCAB_JSON, "rb") as fh:
            vocab = json.loads(fh.read().decode("utf-8-sig"))
        edit(vocab)
        with open(os.path.join(tmp, "vocab.json"), "wb") as fh:
            fh.write(json.dumps(vocab).encode("utf-8"))
        dump = os.path.join(tmp, "m.json")
        with open(dump, "wb") as fh:
            fh.write(b"[]")
        p = subprocess.run([sys.executable, "-I", os.path.join(tmp, "garden_check.py"), dump,
                            "--workspace", tmp], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return p


@case
def garden_vocab_without_garden_exits_2():
    p = _garden_with_vocab(lambda v: v.pop("garden"))
    check(p.returncode == 2 and p.stderr.startswith(b"garden_check: cannot read input: "),
          "exit %d stderr %r" % (p.returncode, p.stderr[-300:]))


@case
def garden_vocab_garden_missing_a_key_exits_2():
    p = _garden_with_vocab(lambda v: v["garden"].pop("code_symbol_pattern"))
    check(p.returncode == 2 and p.stderr.startswith(b"garden_check: cannot read input: "),
          "exit %d stderr %r" % (p.returncode, p.stderr[-300:]))


# ---------------------------------------------------------------- runner

def _remove_tree(top):
    # git writes its object files read-only, and Windows refuses to delete those.
    for root, dirs, files in os.walk(top):
        for name in dirs + files:
            try:
                os.chmod(os.path.join(root, name), 0o700)
            except OSError:
                pass
    shutil.rmtree(top, ignore_errors=True)


def main():
    only = set(sys.argv[1:])
    passed = failed = 0
    out = []
    for name, fn in CASES:
        if only and name not in only:
            continue
        try:
            fn()
            passed += 1
            out.append("PASS %s" % name)
        except Exception as exc:  # a crash in a case is a failure of that case, not the run
            failed += 1
            out.append("FAIL %s: %s: %s" % (name, type(exc).__name__, str(exc).replace("\n", " ")[:600]))
    if _GARDEN.get("tmp"):
        _remove_tree(_GARDEN["tmp"])
    out.append("passed %d failed %d" % (passed, failed))
    sys.stdout.buffer.write(("\n".join(out) + "\n").encode("utf-8"))
    return 1 if failed or not passed else 0


if __name__ == "__main__":
    sys.exit(main())
