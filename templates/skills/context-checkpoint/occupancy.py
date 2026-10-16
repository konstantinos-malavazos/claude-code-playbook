#!/usr/bin/env python3
"""How full is this session's context window? One line out, one log row, never a block.

  occupancy.py --scratchpad <path> [--window <tokens>] [--gate <slug>] [--ticket <id>]
               [--log-dir <dir>] [--projects-dir <dir>]

Prints exactly one line:

  occupancy=<int> pct=<n.n> limit=<int> threshold=<int> verdict=continue|recommend-handoff

Any failure prints verdict=continue and exits 0: a missed checkpoint, never a blocked flow.
Stdlib only.
"""
import json
import os
import sys
import time

# Provisional: the starting point, to be recalibrated from the logged rows.
THRESHOLD_FRACTION = 0.30

DEFAULT_WINDOW = 1000000
WINDOW_ENV = "PLAYBOOK_CONTEXT_WINDOW"
LOG_DIR_ENV = "WORKSPACE_HANDOFFS_ROOT"
LOG_NAME = "context-checkpoint.log"
FLAGS = ("--scratchpad", "--window", "--gate", "--ticket", "--log-dir", "--projects-dir")


class CheckFailed(Exception):
    pass


def parse_args(argv):
    args = {}
    i = 0
    while i < len(argv):
        flag = argv[i]
        if flag not in FLAGS:
            raise CheckFailed("unknown argument %r" % flag)
        if i + 1 >= len(argv):
            raise CheckFailed("%s needs a value" % flag)
        args[flag[2:]] = argv[i + 1]
        i += 2
    if not args.get("scratchpad"):
        raise CheckFailed("--scratchpad is required")
    return args


def session_of(scratchpad):
    """(slug, session id): the two directories above the scratchpad, either separator."""
    parts = [p for p in scratchpad.replace("\\", "/").split("/") if p]
    if len(parts) < 3:
        raise CheckFailed("scratchpad path %r has no <slug>/<session-id> above it" % scratchpad)
    slug, sid = parts[-3], parts[-2]
    for name in (slug, sid):
        if name in (".", "..") or ":" in name:
            raise CheckFailed("scratchpad path %r does not name a session" % scratchpad)
    return slug, sid


def window_of(flag_value):
    raw = flag_value if flag_value is not None else os.environ.get(WINDOW_ENV, "")
    if raw == "":
        return DEFAULT_WINDOW
    try:
        window = int(raw)
    except ValueError:
        raise CheckFailed("window %r is not an integer" % raw)
    if window <= 0:
        raise CheckFailed("window %r is not positive" % raw)
    return window


def last_usage(transcript):
    """The usage of the last assistant turn of this session, read from the end.

    Only lines after that turn are parsed: an unreadable one there is a failure,
    because the turn it may have been is unknown."""
    if not os.path.isfile(transcript):
        raise CheckFailed("no transcript at %s" % transcript)
    with open(transcript, "rb") as fh:
        lines = fh.read().split(b"\n")
    for n in range(len(lines) - 1, -1, -1):
        raw = lines[n].strip()
        if not raw:
            continue
        try:
            entry = json.loads(raw.decode("utf-8"))
        except ValueError:
            raise CheckFailed("line %d of the transcript is not JSON" % (n + 1))
        if not isinstance(entry, dict) or entry.get("type") != "assistant":
            continue
        if entry.get("isSidechain") is True:
            continue
        usage = (entry.get("message") or {}).get("usage")
        if not isinstance(usage, dict):
            raise CheckFailed("the last assistant turn carries no usage")
        total = 0
        for key in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"):
            val = usage.get(key, 0)
            if not isinstance(val, int) or isinstance(val, bool) or val < 0:
                raise CheckFailed("usage.%s is %r" % (key, val))
            total += val
        return total
    raise CheckFailed("the transcript has no assistant turn")


def clean(value):
    return str(value).replace("\t", " ").replace("\r", " ").replace("\n", " ")


def write_log(log_dir, row):
    with open(os.path.join(log_dir, LOG_NAME), "ab") as fh:
        fh.write(("\t".join(clean(v) for v in row) + "\n").encode("utf-8"))


def main(argv):
    r = {"sid": "", "ticket": "", "gate": "", "occupancy": 0, "limit": 0, "threshold": 0}
    verdict, error = "continue", ""
    log_dir = os.environ.get(LOG_DIR_ENV) or os.path.join(os.getcwd(), ".claude", "handoffs")
    try:
        args = parse_args(argv)
        r["ticket"], r["gate"] = args.get("ticket", ""), args.get("gate", "")
        log_dir = args.get("log-dir") or log_dir
        slug, r["sid"] = session_of(args["scratchpad"])
        r["limit"] = window_of(args.get("window"))
        r["threshold"] = int(r["limit"] * THRESHOLD_FRACTION)
        projects = args.get("projects-dir") or os.path.join(
            os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude"),
            "projects")
        r["occupancy"] = last_usage(os.path.join(projects, slug, r["sid"] + ".jsonl"))
        if r["occupancy"] >= r["threshold"]:
            verdict = "recommend-handoff"
    except Exception as exc:  # fail open: any failure is a missed checkpoint
        verdict, error = "continue", str(exc) or type(exc).__name__
    pct = "%.1f" % (100.0 * r["occupancy"] / r["limit"]) if r["limit"] else "0.0"
    row = [time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), r["sid"], r["ticket"],
           r["gate"], r["occupancy"], pct, r["limit"], r["threshold"], verdict, error]
    try:
        write_log(log_dir, row)
    except Exception as exc:
        verdict = "continue"
        error = error or ("cannot write the log in %s: %s" % (log_dir, exc))
    line = "occupancy=%d pct=%s limit=%d threshold=%d verdict=%s\n" % (
        r["occupancy"], pct, r["limit"], r["threshold"], verdict)
    sys.stdout.buffer.write(line.encode("utf-8"))
    sys.stdout.buffer.flush()
    if error:
        try:
            sys.stderr.buffer.write(("context-checkpoint: %s\n" % clean(error)).encode("utf-8"))
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    try:
        code = main(sys.argv[1:])
    except Exception:
        try:
            sys.stdout.buffer.write(
                b"occupancy=0 pct=0.0 limit=0 threshold=0 verdict=continue\n")
        except Exception:
            pass
        code = 0
    sys.exit(code)
