---
name: next-steps
description: >-
  The four-field block a flow prints LAST, so a finished stage never leaves the user holding
  it with no next move: what landed and where, what is theirs to do, the literal next command
  with its argument filled in, and whether it runs in this session or a fresh one. Auto-loads
  at any terminal point of a flow — a finished stage, a verdict, a report, a
  stop-with-a-question — and whenever a template is about to write a hand-back. Triggers on
  "hand back", "next steps", "what now", "stop condition", "the session is over".
---

# Next steps — end by saying what the human does now

Every flow knows precisely when it is finished. A **stop condition** says what you must not
do next, and a **report** says what landed. Neither of those is a next step. This block is.

**It is the last thing printed, and it never replaces the stage's own report** — it follows
it. If it is restating the report above it, it is too long.

---

## The four fields, in this order

| Field | What it carries |
|---|---|
| **Landed** | one line: what this stage produced, and where it is — branch and sha, ticket ids, file paths. Never an artifact without its path or id |
| **Yours now** | only what the user must do, because only they can: commit, push, open the MR/PR, approve the board, send the questionnaire, run the wizard, restart the session |
| **Next command** | the literal command with the argument **filled in** — `/charting 7`, `/start-ticket ABC-123`, `/resume-massive PLATFORM` |
| **This session or a fresh one** | stated outright, with the one-clause reason |

```
**Landed** — <what this stage produced, and where it is>
**Yours now** — <only what they must do, because only they can>
**Next command** — `/<command> <argument, filled in>`
**This session or a fresh one** — <which, and why, in one clause>
```

**A field with nothing to say says so** — *nothing to commit*, *nothing to run*, *none, this
one is over* — and never disappears. An ending with a field missing reads as an unfinished
conversation, which is the thing this block exists to stop.

---

## Rules

**Fill the argument in.** `/charting 7`, never `/charting <number>`. Where the id genuinely
cannot be known yet, say what to look at to get it. Never print the placeholder.

**Never name a command that does not ship.** Check that it is installed before you name it.
A line pointing at a command the user does not have is worse than no line, because they go
looking for it.

**Commit lines are per-stage, never uniform.** One stage commits itself when green and
commits nothing when red; another ends in *never commit, never push*; a fix **amends**, so
there is no new commit to look for. Read the stage's own rule and say that one. A blanket
*commit your work* is wrong more often than it is right.

**Never say merge, and never say push to trunk.** That is a guardrail everywhere else in
this pipeline, and this block must not quietly reintroduce it.

**Push only where `~/.claude/repo-allowlist` permits it.** Where it does not, say plainly
that the branch is local and unpushed, and give the one line to add.

**Say why a fresh session, in one clause.** It is a context-sizing rule — the next unit is
*sized* to a fresh context — not housekeeping. *"One ticket per session, because the next one
is sized to a fresh context"* is the whole sentence.

**A stop-with-a-question gets a block too.** The next step is answering it. These are the
endings most likely to leave the user waiting for the agent while the agent waits for them,
so **Yours now** is the question and **Next command** is *none — answer here*.

---

## Worked examples

A green report that commits itself:

```
**Landed** — 7 of 7 seam checks pass. One commit on `master`, a1b3f9c: CLAUDE.md, the stub, and the layer specialists under `.claude/`.
**Yours now** — nothing. Check a row against its evidence if you want to.
**Next command** — `/cut-backlog`
**This session or a fresh one** — fresh: cutting reads the whole map, and this context is full of scaffolding.
```

A red report that commits nothing:

```
**Landed** — 4 of 7 seam checks pass, in the report above. Nothing committed — red commits nothing, on purpose.
**Yours now** — decide whether checks 2, 4 and 5 are wrong checks or a wrong stack. That judgement is yours.
**Next command** — `/bootstrap`, once you have decided. Safe to re-run: every finished step skips itself.
**This session or a fresh one** — either; a re-run re-derives its state from the disk.
```

A verdict with nothing to run:

```
**Landed** — killed, by the no-trigger rule. Recorded in the ideas file with its reason and today's date.
**Yours now** — nothing to commit and nothing to run.
**Next command** — none. A kill is a recorded no, not a deletion: the entry is there to disagree with in a year.
**This session or a fresh one** — this one is over.
```

---

## You must NOT

- Print the block before the stage's report, or instead of it.
- Print a placeholder argument, a command that does not ship, or an artifact without its
  path or id.
- Say *commit your work* without reading the stage's own commit rule.
- Restate the report. Four lines, each carrying something the report did not.
