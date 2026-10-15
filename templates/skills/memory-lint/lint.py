#!/usr/bin/env python3
"""memory-lint: check one Forgetful create_memory / update_memory call against vocab.json.

stdin   the hook's tool_input: {"tool_name": "<inner tool>", "arguments": {...}}
stdout  one line per finding, LF only: "FAIL <rule>: <reason>" or "WARN <rule>: <reason>"
exit    0  no FAIL (WARN lines allowed), or a tool that is not a memory write
        3  at least one FAIL, or stdin / vocab.json it cannot read

Every list, band and pattern lives in vocab.json beside this file. garden_check.py
imports this module and calls lint() / lint_create() / type_tags().
"""
import json
import os
import re
import sys

WRITE_TOOLS = ("create_memory", "update_memory")
VOCAB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vocab.json")

# 3, not 1: the hooks' interpreter loop (py_run in _lib/common.sh) reads 3 as "the
# program said no" and stops there. Any other non-zero code makes it hand the same
# payload to the next python on its list.
EXIT_FAIL = 3

VOCAB_KEYS = ("types", "importance_tolerance", "required_create_fields", "max_tags",
              "max_keywords", "repo_tags", "functional_tags", "renames", "retired",
              "ticket_id_pattern", "content_fields", "content_reject", "content_warn")

REPO_TAGS_EMPTY = "repo_tags is empty — repo-tag rule not checked"


def load_vocab(path=None):
    with open(path or VOCAB_PATH, "rb") as fh:
        vocab = json.loads(fh.read().decode("utf-8-sig"))
    if not isinstance(vocab, dict):
        raise ValueError("vocab.json is not a JSON object")
    missing = [k for k in VOCAB_KEYS if k not in vocab]
    if missing:
        raise ValueError("vocab.json lacks " + ", ".join(missing))
    if not isinstance(vocab["types"], dict) or not vocab["types"]:
        raise ValueError("vocab.json types table is empty")
    return vocab


def _rx(entry):
    return re.compile(entry["pattern"], re.IGNORECASE if entry.get("ignore_case") else 0)


def _one_line(value):
    return " ".join(str(value).split())


def _q(value):
    return "'%s'" % _one_line(value)


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _supplied(args, key):
    return key in args and args[key] is not None


def type_tags(tags, vocab):
    if not isinstance(tags, list):
        return []
    return [t for t in tags if isinstance(t, str) and t in vocab["types"]]


def _check_type(tags, vocab, out):
    found = type_tags(tags, vocab)
    if len(found) == 1:
        return found[0]
    if not found:
        out.append(("FAIL", "type", "no type tag — tags must hold exactly one of: "
                    + ", ".join(sorted(vocab["types"]))))
    else:
        out.append(("FAIL", "type", "%d type tags (%s) — keep exactly one"
                    % (len(found), ", ".join(found))))
    return None


def _check_tags(tags, vocab, out):
    if not isinstance(tags, list) or not all(isinstance(t, str) for t in tags):
        out.append(("FAIL", "tags", "tags must be a list of strings"))
        return False
    if len(tags) > vocab["max_tags"]:
        out.append(("FAIL", "tags", "%d tags — at most %d" % (len(tags), vocab["max_tags"])))
    ticket_rx = _rx(vocab["ticket_id_pattern"])
    for tag in tags:
        if tag != tag.lower():
            out.append(("FAIL", "tag-case", "%s must be lowercase" % _q(tag)))
        if tag in vocab["renames"]:
            out.append(("FAIL", "tag-rename", "%s is renamed — use %s"
                        % (_q(tag), _q(vocab["renames"][tag]))))
        if tag in vocab["retired"]:
            why = _one_line(vocab["retired"][tag] or "")
            out.append(("FAIL", "tag-retired", "%s is retired%s" % (_q(tag), (": " + why) if why else "")))
        if ticket_rx.search(tag):
            out.append(("FAIL", "tag-ticket-id", "%s looks like a ticket id — tag by "
                        "functionality and put the id in content" % _q(tag)))
    types = vocab["types"]
    repo_tags = vocab["repo_tags"]
    if not repo_tags:
        out.append(("WARN", "repo-tag", REPO_TAGS_EMPTY))
        if not [t for t in tags if t not in types]:
            out.append(("FAIL", "repo-tag", "no repo/project tag — add one besides the type tag"))
    elif not [t for t in tags if t in repo_tags]:
        out.append(("FAIL", "repo-tag", "no tag from repo_tags (%s)" % ", ".join(repo_tags)))
    functional = vocab["functional_tags"]
    if functional:
        for tag in tags:
            if tag not in types and tag not in repo_tags and tag not in functional:
                out.append(("FAIL", "functional-tag", "%s is not in functional_tags" % _q(tag)))
    return True


def _check_importance(value, typ, vocab, out):
    if not _is_int(value) or not 1 <= value <= 10:
        out.append(("FAIL", "importance", "importance must be an int from 1 to 10, got %s" % _q(value)))
        return
    if typ is None:
        return
    band = vocab["types"][typ]["importance"]
    tol = vocab["importance_tolerance"]
    if abs(value - band) > tol:
        out.append(("FAIL", "importance", "%s expects %d-%d, got %d" % (typ, band - tol, band + tol, value)))


_ABSOLUTE = re.compile(r"^(?:[/\\]|[A-Za-z]:)")


def _check_source_files(args, typ, vocab, create, out):
    spec = vocab["types"][typ] if typ else None
    required = bool(spec) and spec.get("source_files") == "required"
    if not _supplied(args, "source_files"):
        if create and required:
            out.append(("FAIL", "source_files", "%s requires source_files (repo-relative paths)" % typ))
        return
    files = args["source_files"]
    if not isinstance(files, list):
        out.append(("FAIL", "source_files", "source_files must be a list of repo-relative paths"))
        return
    for path in files:
        if not isinstance(path, str) or not path.strip():
            out.append(("FAIL", "source_files", "empty path in source_files"))
        elif _ABSOLUTE.match(path):
            out.append(("FAIL", "source_files", "%s is absolute — use a path relative to the repo root"
                        % _q(path)))
        elif "\\" in path:
            out.append(("FAIL", "source_files", "%s uses backslashes — use forward slashes" % _q(path)))
        elif ".." in path.split("/"):
            out.append(("FAIL", "source_files", "%s leaves the repo (..)" % _q(path)))
    if required and spec is not None:
        need = spec.get("min_source_files", 1)
        if len(files) < need:
            out.append(("FAIL", "source_files", "%s requires at least %d source_files, got %d"
                        % (typ, need, len(files))))


def _check_project_ids(value, out):
    if not isinstance(value, list) or len(value) != 1:
        n = len(value) if isinstance(value, list) else "not a list"
        out.append(("FAIL", "project_ids", "exactly one owning project id is required, got %s" % n))
    elif not _is_int(value[0]):
        out.append(("FAIL", "project_ids", "project id must be an int, got %s" % _q(value[0])))


def _check_keywords(value, vocab, out):
    if not isinstance(value, list):
        out.append(("FAIL", "keywords", "keywords must be a list"))
    elif len(value) > vocab["max_keywords"]:
        out.append(("FAIL", "keywords", "%d keywords — at most %d" % (len(value), vocab["max_keywords"])))


def _check_content(args, vocab, out):
    for level, groups in (("FAIL", vocab["content_reject"]), ("WARN", vocab["content_warn"])):
        for rule, entries in groups.items():
            for field in vocab["content_fields"]:
                text = args.get(field)
                if not isinstance(text, str):
                    continue
                for entry in entries:
                    m = _rx(entry).search(text)
                    if m:
                        out.append((level, rule, "%s contains %s" % (field, _q(m.group(0)))))
                        break


def _lint_args(args, vocab, create):
    out = []
    if create:
        for field in vocab["required_create_fields"]:
            if not _supplied(args, field):
                out.append(("FAIL", "required", "missing required field '%s'" % field))
    typ = None
    if _supplied(args, "tags") and _check_tags(args["tags"], vocab, out):
        typ = _check_type(args["tags"], vocab, out)
    if _supplied(args, "importance"):
        _check_importance(args["importance"], typ, vocab, out)
    _check_source_files(args, typ, vocab, create, out)
    if _supplied(args, "project_ids"):
        _check_project_ids(args["project_ids"], out)
    if _supplied(args, "keywords"):
        _check_keywords(args["keywords"], vocab, out)
    _check_content(args, vocab, out)
    return out


def lint_create(args, vocab):
    return _lint_args(args, vocab, create=True)


def lint_update(args, vocab):
    return _lint_args(args, vocab, create=False)


def lint(payload, vocab):
    """Findings for one tool_input, as (level, rule, reason) tuples."""
    if not isinstance(payload, dict):
        return [("FAIL", "payload", "expected a JSON object with tool_name and arguments")]
    if "tool_input" in payload:
        return [("FAIL", "payload", "got the whole hook payload — pass its tool_input")]
    tool = payload.get("tool_name")
    if not isinstance(tool, str) or not tool.strip():
        return [("FAIL", "payload", "tool_name is missing or empty")]
    if tool not in WRITE_TOOLS:
        return []
    args = payload.get("arguments")
    if not isinstance(args, dict):
        return [("FAIL", "payload", "arguments must be a JSON object")]
    return lint_create(args, vocab) if tool == "create_memory" else lint_update(args, vocab)


def _emit(findings):
    text = "".join("%s %s: %s\n" % (lvl, rule, _one_line(why)) for lvl, rule, why in findings)
    sys.stdout.buffer.write(text.encode("utf-8"))
    sys.stdout.buffer.flush()
    return EXIT_FAIL if any(f[0] == "FAIL" for f in findings) else 0


def main():
    raw = sys.stdin.buffer.read()
    try:
        vocab = load_vocab()
    except Exception as exc:
        return _emit([("FAIL", "vocab", "cannot read %s: %s" % (VOCAB_PATH, exc))])
    try:
        payload = json.loads(raw.decode("utf-8-sig"))
    except Exception as exc:
        return _emit([("FAIL", "payload", "not valid JSON: %s" % exc)])
    try:
        findings = lint(payload, vocab)
    except Exception as exc:
        findings = [("FAIL", "internal", "lint crashed: %s: %s" % (type(exc).__name__, exc))]
    return _emit(findings)


if __name__ == "__main__":
    sys.exit(main())
