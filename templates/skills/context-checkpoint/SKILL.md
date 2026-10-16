---
name: context-checkpoint
description: >-
  Measure how full this session's context window is, at a flow gate, and recommend a handoff
  when it is past the threshold. Runs occupancy.py against this session's own transcript,
  logs every check, and never blocks: any failure reads as continue. Run by the /start-ticket
  orchestrator at its plan-approval, alignment, review-verdict and review-fix gates, at most
  once per gate. Triggers on "context checkpoint", "is the session full".
---

# Context checkpoint

A long `/start-ticket` run fills the session's context, and a full context answers worse
without saying so. At each gate the flow measures how full it is, from the session's own
transcript, and on a recommendation it writes a handoff and stops there, so the rest of the
run starts fresh.

**The script measures; it never acts.** It prints one line and logs one row. Whether to
write the handoff is yours, by the rule below, and ending or clearing the session is the
user's.

## Run it

```bash
python3 ~/.claude/skills/context-checkpoint/occupancy.py \
  --scratchpad "<scratchpad path>" \
  --gate <slug> --ticket <TICKET-ID> \
  --log-dir "<workspace>/.claude/handoffs"
```

- **`--scratchpad`** is the scratchpad directory your system prompt names, copied whole. The
  script derives this session's transcript from it and reads only that file: never a newest
  file, never a subagent's transcript.
- **`--gate`** is the slug the gate line names: `plan-approval`, `alignment`,
  `review-verdict` or `review-fix`.
- **`--window <tokens>`**, when you know this session's context window. Without it the
  script reads the env `PLAYBOOK_CONTEXT_WINDOW`, and without that it assumes 1,000,000.
- **Interpreter:** `python3`; where that is not found, `python`.

On a 200K-window session, set `PLAYBOOK_CONTEXT_WINDOW=200000` (for example under `env` in `~/.claude/settings.json`), or the checkpoint never fires.

## Read the line

It prints exactly one line:

```
occupancy=<int> pct=<n.n> limit=<int> threshold=<int> verdict=continue|recommend-handoff
```

`limit` is the window it used and `threshold` is in tokens. Do not restate the threshold as
a number anywhere: the script owns it, and a second copy drifts.

| Verdict | You |
|---|---|
| `continue` | carry on with the gate as the flow says |
| `recommend-handoff` | write the gate handoff below, tell the user, and **stop at this gate** |

A measurement failure prints `verdict=continue` and exits 0. Do not retry it and do not
measure some other way: a failed check is a missed checkpoint, never a blocked flow.

## On `recommend-handoff`

1. **Invoke the `handoff` skill** for its gate-checkpoint case. The file is
   `<workspace>/.claude/handoffs/<TICKET-ID>/manual_handoffs/<gate>-<utc>.md`, with `<utc>` as
   `YYYYMMDDTHHMMSSZ`, and its first line is exactly
   `Resume: ticket=<TICKET-ID> gate=<gate> next=<re-entry step>`.
2. **Tell the user** the session is past the checkpoint, name the file, and say that
   `/resume-ticket <TICKET-ID>` in a fresh session picks the run up at that gate.
3. **Stop at the gate.** Do not dispatch the next stage.

**Never clear, compact or end the session yourself.** The handoff makes a fresh start
possible; taking it is the user's decision.

## Rules

- **At most once per gate.** A gate the run passes again — a second review-fix pass is a new
  gate — gets its own check.
- **Never act on the line without running the script.** An estimate of your own context is
  the guess this skill exists to replace.
