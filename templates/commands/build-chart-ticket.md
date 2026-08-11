---
description: Implement ONE make ticket from a chart - context delta → planner → the single layer specialist the label names → review, but only if that repo has no other make tickets left. Guards hard on "claimed and open" and fails loudly. Stops and hands the question back if the planner meets a real decision. Writes nothing to the map and never closes the ticket.
argument-hint: <KEY>#<NN>
---

# Build Chart Ticket — $ARGUMENTS

`$ARGUMENTS` is `<KEY>#<NN>`: the map's folder and the ticket's number. Everything below
reads the chart folder for `<KEY>`.

**`<TICKET-ID>` below is the map's own key**, unless `map.md`'s Notes carry a
`Development ticket:` line, which wins. It is what the branch and the commit carry, and what
the agents below take as their argument.

This is the implementation stage of the massive flow. `/resume-massive` normally calls it.
You can call it by hand, but the guards do not relax when you do.

**Read your tracker adapter first.** It says what these tickets are on disk. The `charting`
skill is not needed here: charting decided; this executes.

**This command writes nothing to the chart and nothing to the development ticket.** Not a
comment, not a close, not a new ticket. The caller owns every one of those. Where the
adapter puts the chart on a shared tracker, a write here is visible to everyone.

## 0. Guards — fail loudly, never work around

Stop with a plain sentence if any of these is false. Do **not** fix them on the way past.

| Check | Fail how |
|---|---|
| the chart folder exists | no such map. `/start-massive <KEY>` charts one |
| ticket `<NN>` exists | no ticket `<NN>` on this map |
| `Type:` is a `make:<layer>` | this is a `<type>` ticket, not a make. `research` runs AFK, `grilling` and `task` need the human. All three belong to `/resume-massive` |
| exactly one `make:` type | a ticket needing two layers was mis-typed at chart time. Say which two, and stop. The map should split it |
| `State: open` | already resolved. Reopen it deliberately or pick another |
| `Claim:` is not `—` | **unclaimed.** `/resume-massive` claims before it dispatches; a hand-run needs a claim first |
| every number in `Blocked by:` is **`resolved` on disk** | still blocked by `<NN> — <title>`. Read each blocker's file; never trust the line |

**Check them in that order.** `Type:` is intrinsic to the ticket and `Claim:` is transient,
so an unclaimed `grilling` should be refused as *not a make* — the answer that tells the
caller something — rather than as *unclaimed*, which they could fix and still be wrong.

**The `Claim:` guard is what makes this command safe to dispatch**, now that it carries no
`disable-model-invocation`. A run nobody asked for lands on a ticket nobody claimed, and
stops here. Never relax it to *claim it yourself and carry on*. That is the guard.

## 1. Read the brief — it already exists

There is **no `@ticket-analyzer` here.** The ticket file and the map are the brief; nothing
needs fetching.

1. The ticket — the `## Question` *and* the `## Comments`. A comment may carry a decision
   made after the ticket was written.
2. `map.md` — the **Destination** (what this ticket serves) and the **Notes** (the domain,
   the skills to consult, the contested terms, the repo's final commit message).
3. `context.md` — and its staleness stamp.

## 2. Context delta, not a fresh sweep

**If `context.md` is older than your memory-refresh cadence**, refresh the destination layer
first. An out-of-date sweep is worse than none, because it reads as current.

Then invoke `@context-gatherer <TICKET-ID>` for **the delta only**: what this ticket touches
that `context.md` does not already cover. Pass it the ticket's Question and tell it
`context.md` is the baseline.

**One sweep is not enough for a multi-week map, and that is why this step exists.** The
destination-scoped sweep reaches the obvious neighbours. It does not reach the landmine one
hop out from a ticket that did not exist when it ran.

## 3. Plan — and stop if it meets a decision

Invoke `@planner <TICKET-ID>`. Give it the ticket Question and `map.md`'s Destination and
Notes as its scope.

The planner will end with open design questions. Take each one and **try to answer it from
the code yourself** with a pinpoint symbol lookup. Record what the code settles, with
`file:line`.

**Whatever survives that is a real decision, and it ends the session.** You do not write it
down anywhere. You hand it back:

1. Return a **decision report** to the caller: the question phrased so a human can answer
   it, and how far the implementation got before you stopped.
2. **End the session.** Say that the question now needs the human.

Filing the `grilling` ticket, adding it to this ticket's `Blocked by:` and posting the
progress comment all belong to `/resume-massive`. Answering the question here would spend
the context the implementation needed, and bury the answer in a make ticket where nobody
looks for it.

## 4. The branch — one per repo, for the whole map

The map's Notes name the repo's final commit message. The branch is one per repo, shared by
every ticket that touches it.

- **Not there yet?** The planner creates it: fetch, check out the repo's main branch, pull
  with rebase, then branch.
- **Already there?** Check it out and rebase it onto the repo's main branch. **Rebase, never
  merge.** Days pass between children.
- Dirty tree, or a conflict on the rebase → **stop and ask.** Never auto-stash, never resolve
  silently.

## 5. Implement — one specialist, named by the label

`make:<layer>` dispatches `@<layer>-specialist`, and that specialist's own file says whether
its layer ships tests.

**The label already chose. There is no track-allocation step**, no slice fork, no worktrees,
no aligner, no integrator. Charting decomposed this map already; slicing a chart child again
is slicing twice.

**One commit per repo, amend-as-you-go.** The first ticket to touch a repo commits with the
message from `map.md` Notes. Every later one amends into it. Never rewrite the message. If
it no longer describes the work, stop and surface it.

**Push the branch where `~/.claude/repo-allowlist` permits it.** But only after the last
amend for this repo, never mid-flight, because the next amend would need a force-push and
that is hook-blocked. **Never merge.** Never stage AI-infra files. Explicit paths in
`git add`, never `-A`, never `.`.

## 6. Review — only when the repo is finished

Ask the tracker: **is any *other* `make:` ticket for this repo still open or blocked?**

**This ticket does not count itself.** It is still `open` and still claimed while you ask.
`/resume-massive` closes it only after you hand back. Counting it makes the answer always
*yes*, and the review never fires on any map.

- **Yes** → skip review. More is coming, and reviewing half a repo produces a verdict that
  goes stale in a day.
- **No** → this ticket finished the repo. Invoke `@repo-reviewer <TICKET-ID>`, which
  dispatches `@release-reviewer` itself. Then **copy its verdict into the chart's
  `reviews/<repo>.md` in this same session**, before session end clears the handoffs, and
  keep the MR/PR description it drafted.

Ask this live, every time. Never store a "repo is ready for review" flag. It rots exactly
like a `Blocked by:` line does.

## 7. Hand back — do not close the ticket

Both exits from this command are text handed to the caller. Step 3's decision report is one.
This is the other: the work landed, so return a **draft resolution comment** and let
`/resume-massive` post it:

```markdown
<one-line gist — what this ticket settled or delivered. This line is contract.>

Files: <paths>
Commit: <sha, and the repo branch it is on>
Design decisions worth keeping: <the ones the code alone will not tell the next session>
Review: <not yet — N makes left for this repo | verdict in reviews/<repo>.md>
```

**The design decisions belong in that comment**, not in a handoff file. Handoffs are gone by
morning. The ticket is the durable record of what this child decided.

If a human ran this command directly, say plainly: the ticket is still open and still
claimed, and `/resume-massive <KEY>` is what closes it and regenerates the map.
