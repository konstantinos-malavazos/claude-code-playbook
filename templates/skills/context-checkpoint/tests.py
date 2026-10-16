#!/usr/bin/env python3
"""context-checkpoint tests. Run: python -I templates/skills/context-checkpoint/tests.py

Every case drives occupancy.py as the flow does, through its command line, against a
transcript tree built in a temp dir. Exit 0 only when every case passes.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
OCC = os.path.join(HERE, "occupancy.py")

SLUG = "C--work-repo"
SID = "0b9e5d1c-4f2a-4c55-9a51-3d0c7e2b8f10"
LOG_NAME = "context-checkpoint.log"
FIELDS = ("occupancy", "pct", "limit", "threshold", "verdict")

CASES = []


def case(fn):
    CASES.append((fn.__name__, fn))
    return fn


class Fail(Exception):
    pass


def check(cond, msg):
    if not cond:
        raise Fail(msg)


def assistant(inp, read=0, create=0, **extra):
    line = {"type": "assistant", "sessionId": SID,
            "message": {"model": "claude-opus-5-5", "role": "assistant",
                        "usage": {"input_tokens": inp,
                                  "cache_read_input_tokens": read,
                                  "cache_creation_input_tokens": create,
                                  "output_tokens": 7}}}
    line.update(extra)
    return json.dumps(line)


def user(text="go"):
    return json.dumps({"type": "user", "message": {"role": "user", "content": text}})


class Tree:
    """A projects dir, a scratchpad path that names SLUG/SID, and a log dir."""

    def __init__(self):
        self.root = tempfile.mkdtemp(prefix="ckpt-")
        self.projects = os.path.join(self.root, "projects")
        self.logs = os.path.join(self.root, "handoffs")
        os.makedirs(os.path.join(self.projects, SLUG))
        os.makedirs(self.logs)
        self.scratchpad = os.path.join(self.root, "Temp", "claude", SLUG, SID, "scratchpad")

    def transcript(self, lines, sid=SID, sub=None):
        d = os.path.join(self.projects, SLUG)
        if sub:
            d = os.path.join(d, sid, "subagents")
            os.makedirs(d, exist_ok=True)
            path = os.path.join(d, sub)
        else:
            path = os.path.join(d, sid + ".jsonl")
        with open(path, "wb") as fh:
            fh.write(("\n".join(lines) + "\n").encode("utf-8"))
        return path

    def run(self, *extra, env=None, scratchpad=None, log_dir=True, projects=True):
        argv = [sys.executable, "-I", OCC,
                "--scratchpad", scratchpad or self.scratchpad,
                "--gate", "plan-approval", "--ticket", "T-1"]
        if projects:
            argv += ["--projects-dir", self.projects]
        if log_dir:
            argv += ["--log-dir", self.logs]
        argv += list(extra)
        e = {k: v for k, v in os.environ.items()
             if k not in ("PLAYBOOK_CONTEXT_WINDOW", "WORKSPACE_HANDOFFS_ROOT",
                          "CLAUDE_CONFIG_DIR")}
        e.update(env or {})
        p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           env=e, cwd=self.root)
        return p

    def log_rows(self, log_dir=None):
        path = os.path.join(log_dir or self.logs, LOG_NAME)
        if not os.path.exists(path):
            return []
        with open(path, "rb") as fh:
            data = fh.read()
        check(b"\r" not in data, "the log holds a CR byte")
        return [r.split("\t") for r in data.decode("utf-8").split("\n") if r]

    def close(self):
        shutil.rmtree(self.root, ignore_errors=True)


def parse(p):
    """The one output line as a dict, after asserting its shape and exit code."""
    check(p.returncode == 0, "exit %d, stderr %r" % (p.returncode, p.stderr[:300]))
    out = p.stdout
    check(b"\r" not in out, "stdout holds a CR byte: %r" % out)
    check(out.endswith(b"\n") and out.count(b"\n") == 1,
          "stdout is not exactly one LF-terminated line: %r" % out)
    pairs = out.decode("utf-8").strip().split(" ")
    got = dict(kv.split("=", 1) for kv in pairs)
    check(tuple(k for k, _ in (kv.split("=", 1) for kv in pairs)) == FIELDS,
          "fields are not %s in order: %r" % (" ".join(FIELDS), out))
    for k in ("occupancy", "limit", "threshold"):
        check(got[k].isdigit(), "%s=%r is not an integer" % (k, got[k]))
    check(got["verdict"] in ("continue", "recommend-handoff"), "verdict=%r" % got["verdict"])
    return got


def with_tree(fn):
    def run():
        t = Tree()
        try:
            fn(t)
        finally:
            t.close()
    run.__name__ = fn.__name__
    return run


# ---------------------------------------------------------------- fail-open
@case
@with_tree
def missing_transcript_fails_open(t):
    got = parse(t.run())
    check(got["verdict"] == "continue", "verdict %r" % got["verdict"])


@case
@with_tree
def malformed_last_line_fails_open(t):
    t.transcript([user(), assistant(900000), '{"type": "assistant", "message": {'])
    got = parse(t.run())
    check(got["verdict"] == "continue", "a malformed line read as %r" % got["verdict"])


@case
@with_tree
def no_assistant_turn_fails_open(t):
    t.transcript([user(), user("again")])
    got = parse(t.run())
    check(got["verdict"] == "continue", "verdict %r" % got["verdict"])


@case
@with_tree
def unwritable_log_dir_fails_open(t):
    t.transcript([user(), assistant(900000)])
    blocker = os.path.join(t.root, "not-a-dir")
    with open(blocker, "wb") as fh:
        fh.write(b"x")
    p = t.run("--log-dir", blocker, log_dir=False)
    got = parse(p)
    check(got["verdict"] == "continue", "an unwritable log still read as %r" % got["verdict"])


@case
@with_tree
def non_integer_window_fails_open(t):
    t.transcript([user(), assistant(900000)])
    got = parse(t.run(env={"PLAYBOOK_CONTEXT_WINDOW": "200k"}))
    check(got["verdict"] == "continue", "a window of 200k read as %r" % got["verdict"])


@case
@with_tree
def non_positive_window_fails_open(t):
    t.transcript([user(), assistant(900000)])
    got = parse(t.run("--window", "0"))
    check(got["verdict"] == "continue", "a window of 0 read as %r" % got["verdict"])


@case
@with_tree
def unknown_flag_fails_open(t):
    t.transcript([user(), assistant(900000)])
    got = parse(t.run("--no-such-flag", "x"))
    check(got["verdict"] == "continue", "an unknown flag read as %r" % got["verdict"])


@case
@with_tree
def scratchpad_too_short_fails_open(t):
    t.transcript([user(), assistant(900000)])
    got = parse(t.run(scratchpad="scratchpad"))
    check(got["verdict"] == "continue", "verdict %r" % got["verdict"])


# ---------------------------------------------------------------- which transcript
@case
@with_tree
def session_from_windows_scratchpad(t):
    t.transcript([user(), assistant(250000)])
    pad = "C:\\Users\\someone\\AppData\\Local\\Temp\\claude\\%s\\%s\\scratchpad" % (SLUG, SID)
    got = parse(t.run("--window", "200000", scratchpad=pad))
    check(got["occupancy"] == "250000", "occupancy %r from a Windows path" % got["occupancy"])


@case
@with_tree
def session_from_posix_scratchpad(t):
    t.transcript([user(), assistant(250000)])
    pad = "/tmp/claude/%s/%s/scratchpad/" % (SLUG, SID)
    got = parse(t.run("--window", "200000", scratchpad=pad))
    check(got["occupancy"] == "250000", "occupancy %r from a POSIX path" % got["occupancy"])


@case
@with_tree
def subagent_transcript_is_not_read(t):
    t.transcript([user(), assistant(1000)])
    t.transcript([user(), assistant(990000)], sub="agent-x.jsonl")
    got = parse(t.run("--window", "200000"))
    check(got["occupancy"] == "1000", "read %r — the subagent's transcript" % got["occupancy"])
    check(got["verdict"] == "continue", "verdict %r" % got["verdict"])


@case
@with_tree
def other_session_is_not_read(t):
    t.transcript([user(), assistant(1000)])
    other = t.transcript([user(), assistant(990000)], sid="ffffffff-0000-0000-0000-000000000000")
    later = os.path.getmtime(other) + 3600
    os.utime(other, (later, later))
    got = parse(t.run("--window", "200000"))
    check(got["occupancy"] == "1000", "read %r — a newer, fuller other session" % got["occupancy"])


@case
@with_tree
def sums_the_three_usage_fields(t):
    t.transcript([user(), assistant(100, read=20000, create=3000)])
    got = parse(t.run())
    check(got["occupancy"] == "23100", "occupancy %r, not 100+20000+3000" % got["occupancy"])


@case
@with_tree
def last_assistant_line_wins(t):
    t.transcript([user(), assistant(900000), user(), assistant(5000), user("tool result")])
    got = parse(t.run("--window", "200000"))
    check(got["occupancy"] == "5000", "occupancy %r, not the last assistant turn" % got["occupancy"])


@case
@with_tree
def sidechain_line_is_not_this_session(t):
    t.transcript([user(), assistant(5000), assistant(990000, isSidechain=True)])
    got = parse(t.run("--window", "200000"))
    check(got["occupancy"] == "5000", "occupancy %r — a sidechain turn" % got["occupancy"])


# ---------------------------------------------------------------- the window
@case
@with_tree
def window_default_is_one_million(t):
    t.transcript([user(), assistant(250000)])
    got = parse(t.run())
    check(got["limit"] == "1000000", "limit %r" % got["limit"])
    check(got["verdict"] == "continue", "250k of 1M read as %r" % got["verdict"])


@case
@with_tree
def window_from_env(t):
    t.transcript([user(), assistant(250000)])
    got = parse(t.run(env={"PLAYBOOK_CONTEXT_WINDOW": "200000"}))
    check(got["limit"] == "200000", "limit %r" % got["limit"])
    check(got["verdict"] == "recommend-handoff", "250k of 200k read as %r" % got["verdict"])


@case
@with_tree
def window_from_flag(t):
    t.transcript([user(), assistant(250000)])
    got = parse(t.run("--window", "200000"))
    check(got["limit"] == "200000", "limit %r" % got["limit"])
    check(got["verdict"] == "recommend-handoff", "250k of 200k read as %r" % got["verdict"])


@case
@with_tree
def window_flag_beats_env(t):
    t.transcript([user(), assistant(250000)])
    got = parse(t.run("--window", "1000000", env={"PLAYBOOK_CONTEXT_WINDOW": "200000"}))
    check(got["limit"] == "1000000", "limit %r — the env won over the flag" % got["limit"])
    check(got["verdict"] == "continue", "verdict %r" % got["verdict"])


@case
@with_tree
def threshold_is_printed_in_tokens(t):
    t.transcript([user(), assistant(1000)])
    got = parse(t.run("--window", "200000"))
    th = int(got["threshold"])
    check(0 < th < 200000, "threshold %r is not a token count inside the window" % got["threshold"])
    check(got["pct"] == "0.5", "pct %r for 1000 of 200000" % got["pct"])


# ---------------------------------------------------------------- the log
@case
@with_tree
def log_row_on_continue(t):
    t.transcript([user(), assistant(1000)])
    got = parse(t.run())
    rows = t.log_rows()
    check(len(rows) == 1, "%d log rows" % len(rows))
    r = rows[0]
    check(len(r) == 10, "row has %d fields, not 10: %r" % (len(r), r))
    check(r[1] == SID and r[2] == "T-1" and r[3] == "plan-approval", "row %r" % r)
    check(r[4] == got["occupancy"] and r[8] == "continue" and r[9] == "", "row %r" % r)


@case
@with_tree
def log_row_on_recommend(t):
    t.transcript([user(), assistant(250000)])
    parse(t.run("--window", "200000"))
    rows = t.log_rows()
    check(len(rows) == 1 and rows[0][8] == "recommend-handoff", "rows %r" % rows)


@case
@with_tree
def log_row_on_failure(t):
    parse(t.run())
    rows = t.log_rows()
    check(len(rows) == 1, "%d log rows on a failed check" % len(rows))
    check(rows[0][8] == "continue" and rows[0][9] != "", "row %r carries no error" % rows[0])


@case
@with_tree
def log_rows_append(t):
    t.transcript([user(), assistant(1000)])
    parse(t.run())
    parse(t.run())
    check(len(t.log_rows()) == 2, "the second check did not append")


@case
@with_tree
def log_dir_from_env(t):
    t.transcript([user(), assistant(1000)])
    alt = os.path.join(t.root, "alt")
    os.makedirs(alt)
    parse(t.run(env={"WORKSPACE_HANDOFFS_ROOT": alt}, log_dir=False))
    check(len(t.log_rows(alt)) == 1, "WORKSPACE_HANDOFFS_ROOT was not used")


def _home_transcript(home, tokens):
    d = os.path.join(home, "projects", SLUG)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, SID + ".jsonl"), "wb") as fh:
        fh.write((user() + "\n" + assistant(tokens) + "\n").encode("utf-8"))


@case
@with_tree
def projects_dir_from_claude_config_dir(t):
    cfg = os.path.join(t.root, "cfg")
    _home_transcript(cfg, 4321)
    got = parse(t.run(projects=False, env={"CLAUDE_CONFIG_DIR": cfg}))
    check(got["occupancy"] == "4321", "CLAUDE_CONFIG_DIR/projects was not read: %r" % got)


@case
@with_tree
def projects_dir_defaults_to_home_claude(t):
    home = os.path.join(t.root, "home")
    _home_transcript(os.path.join(home, ".claude"), 1234)
    got = parse(t.run(projects=False, env={"HOME": home, "USERPROFILE": home}))
    check(got["occupancy"] == "1234", "~/.claude/projects was not read: %r" % got)


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
    out.append("passed %d failed %d" % (passed, failed))
    sys.stdout.buffer.write(("\n".join(out) + "\n").encode("utf-8"))
    return 1 if failed or not passed else 0


if __name__ == "__main__":
    sys.exit(main())
