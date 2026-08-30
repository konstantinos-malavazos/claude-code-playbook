---
name: handoff
description: >-
  Compact the current conversation into a handoff document a fresh session can pick up from.
  Use at the end of a working session, before a context limit, or when parking work you will
  return to later. Writes ONE file per subject to the root of <workspace>/.claude/handoffs/,
  reads and supersedes any existing file for that subject rather than sitting beside it, and
  carries only what exists nowhere else.
argument-hint: "[what the next session will focus on]"
disable-model-invocation: true
---

# Handoff

Write a document that lets a fresh agent continue this work. You are not summarising the
conversation. You are writing down **the part of it that would otherwise be lost.**

## Where it goes, and why the location is not a preference

Save it as a **file at the root** of `<workspace>/.claude/handoffs/` — **never inside a
`<TICKET-ID>/` subdirectory.**

This is mechanical, not stylistic. The `SessionEnd` hook
([`../../hooks/cleanup-handoffs.sh`](../../hooks/cleanup-handoffs.sh)) removes every
subdirectory of the handoffs root and keeps the root itself:

```sh
find "$HANDOFFS_ROOT" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
```

`-type d` is the whole story. **Directories go, root-level files stay.** A handoff written one
level too deep is deleted by the hook that fires as you finish writing it, and nothing warns
you — the next session simply finds nothing. Check the path before you write, not after.

## One file per subject

| Case | File |
|---|---|
| Ticket work | `handoff-<TICKET-ID>.md` |
| A topic with no ticket | `handoff-<topic-kebab>.md` |
| A charted map | `handoff-chart-<slug>.md` |

**A second handoff for the same subject supersedes the first. It does not sit beside it.**
Two live handoffs for one subject is the failure this rule exists to prevent: the next session
reads one of them, and neither file says which.

**Read the existing file before you write.** Carry forward anything still live that this
conversation never revisited — open questions, blockers, decisions taken in a session you were
not part of. Then overwrite.

**Never blind-overwrite.** The file you are about to replace may hold the only record of a
session nobody in this conversation attended. Losing it costs more than a stale paragraph does.

**The one exception:** if the arguments describe a genuinely different focus for the next
session on the same subject, write a second file suffixed with that focus
(`handoff-<TICKET-ID>-stg-retest.md`) and cross-reference the two, each naming the other.

## Lead with what cannot be recovered

**Open the document with the things a fresh session cannot reconstruct on its own**, and say
plainly that they are unrecoverable. Everything else in the file is a convenience; this part is
the reason the file exists.

The usual candidates:

- **An uploaded file, a pasted log, or anything else that arrived through the conversation.**
  Attachments do not survive into a new session. If the work depends on one, say so at the top,
  name it, and say it must be re-supplied — otherwise the next session starts by guessing.
- A decision taken in conversation and not yet written into code, a commit, memory or a ticket.
- A verbal constraint from the user that is not in any file.
- What the user has already rejected, so the next session does not re-propose it.

## Carry only what exists nowhere else

**Do not duplicate what is already recorded. Reference it.** A handoff that restates memory or
a `CLAUDE.md` goes stale the moment either changes, and the reader has two copies with no way
to tell which is current — so a duplicated fact is worse than an absent one.

Reference, don't copy: pipeline handoffs under `<workspace>/.claude/handoffs/<TICKET-ID>/`,
memories by id, `CLAUDE.md` files, the ticket in your tracker, the branch and commit sha.

Carry, because it lives nowhere else:

- **the resume point** — what is in flight, what is finished, what nothing has started
- decisions made in conversation, with the reason, not just the conclusion
- facts established here and not yet written back to memory
- what is blocked on the user, stated as a question they can answer

## Suggested shape

```
# <subject> — handoff
## Read this first     what a fresh session cannot recover, and what must be re-supplied
## Where the work is   merged / in flight / not started · branch · PR · commit sha
## Decisions           what was settled, and why — the reasoning, not just the verdict
## Open                what is genuinely the user's call, phrased as answerable questions
## Suggested skills    which skills the next session should invoke, and when
## Resume point        the next concrete unit of work
```

**Include the suggested-skills section.** A fresh session does not know which of the installed
skills apply to this subject, and naming them is cheap.

## Rules

- **Redact secrets.** API keys, passwords, tokens, personal data. Name a config *path* if the
  next session needs one; never its contents.
- **Write the reasoning, not just the outcome.** "We chose A" leaves the next session free to
  undo it. "We chose A because B fails when C" does not.
- **If the user passed arguments, treat them as the next session's focus** and tailor the
  document to it — what that focus needs carried, and what it does not.
- **Do not write a handoff nobody will read.** If the work is finished and merged, and nothing
  is open, say so in one line rather than manufacturing a document.

**Then the `next-steps` block.** The file by path; that **closing this session and opening a
fresh one pointed at that file** is the whole reason it was written — the resume point is
already inside it, and a fresh context is what it was sized for; and the skills the document
names, so the next session opens with them instead of finding them. Nothing to commit: a
handoff is session state, not a repo artifact.
