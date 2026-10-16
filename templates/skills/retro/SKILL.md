---
name: retro
description: >-
  Turn a finished session into proposed playbook improvements — where the agent got lost,
  what a check could have caught, what review missed — each naming the playbook file to
  change, most severe first. Proposes only; files nothing. Use when the user types /retro.
disable-model-invocation: true
---

# retro — a session into playbook improvements

> Prior art: mattpocock/skills@49dd158 `retro` (MIT), adapted. It keeps the upstream's
> candidate categories, maps each one to a playbook file, and files nothing on its own.

You are proposing changes to the **environment** the agents run in — templates, hooks,
suites, `CLAUDE.md` — so the next run goes better. You are not fixing the session's code.

## Steps

1. **Read the session.** Default to this one. If the user names another, read its
   transcript under `~/.claude/projects/<project>/`. Read what happened, not what the
   session said happened: a claim in a summary is a lead to check in the tool calls.
2. **Find candidates** in the six categories below. Every candidate cites the moment in the
   session (the tool call or the message) that shows it.
3. **Name the playbook file to change** for each one, and the change in one line. A
   candidate with no file to change is an observation, not a candidate: drop it.
4. **Rank them, most severe first.** Severity is what it cost or would cost on the next
   run: a wrong result shipped beats a wrong result caught, which beats wasted time.
5. **Present the list** and stop. Each item reads as a draft issue: a title, the evidence,
   the file, the change.

## The six categories

| Category | Look for | Usually changes |
|---|---|---|
| **Navigation** | the agent took long to find a file or a fact, or missed a hidden dependency between files | the repo's `CLAUDE.md` (a pointer, not a paragraph), or the agent template that should have named it |
| **A catchable mistake** | an error a hook, a suite check or a linter could have caught. Check first whether that check already exists and was unwired or broken — that is the finding, not a new check | `templates/hooks/`, a test suite, the repo's CI |
| **A review miss** | a defect that got past review | the `review-guidelines` skill, a `<layer>-standards` skill, or the reviewer agent's template. A mechanical rule gets a check instead (row above) |
| **A no-op instruction** | an instruction the agent followed, ignored or contradicted with no change in what it did | the file that holds it — usually a deletion |
| **An expensive tool call** | a call that cost far more than its answer was worth: a whole-file read for one symbol, a full suite for one check | the agent's template or the skill that sent it there |
| **Missing information** | a fact the agent needed and could not reach — a log, a service, a decision | the dispatching command or agent, or the setup docs |

Implementation runs under the most context pressure, review under the least. A standard
belongs with the reviewer, not in every implementer's prompt.

## Rules

- **Never file, edit or commit.** The output is the list. The user picks which items become
  issues, and files them through the tracker adapter (`~/.claude/tracker.md`) one approval at
  a time.
- Redact secrets in any evidence you quote: write `<REDACTED>`.
- No candidate for its own sake. An empty category says "nothing found" in one line.

Then the `next-steps` block: the list is what landed, choosing and filing the items is the
user's, and the next command is the first approved issue's flow, in a fresh session.
