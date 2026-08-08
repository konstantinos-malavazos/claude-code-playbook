# 03 — Massive tickets (charting an existing codebase)

The [decompose path](../shared/09-decompose-path.md) splits a large ticket you can already
**plan**. This doc is for the one you cannot: an effort where the goal is clear, the route is
not, and finding the route is itself weeks of work.

The test is not size. It is **fog**.

| | Use |
|---|---|
| One change, one repo, plannable in a pass | [`/start-ticket`](../shared/08-ticket-pipeline.md) |
| Large, but you can already name the slices | [decompose path](../shared/09-decompose-path.md) |
| You can see the destination but not the route, and it spans sessions | **this doc** |

If you sit down to plan and cannot, that is the signal. A map you did not need costs more
than the work; running `/start-massive` on a ticket you could have planned wastes a session
proving that.

---

## Why this doc lives under `team/`

**Fog is not a team condition, and this flow is.** What sits here is the three commands, not
the ability to chart a codebase that already exists — and the two are worth keeping apart,
because only one of them moved.

The three commands assume, at minimum, a ticket somebody else wrote and an effort spanning
repos that no single one of them owns. That is what buys the chart folder outside any repo,
the closing review sequence over every repo touched, and `@map-reviewer` re-fetching
acceptance criteria that were never yours to edit. That is what the `—` against all three
rows of the [command table](../../templates/commands/README.md) records: a solo install does
not carry these files at all.

**Solo, the capability survives the move.** A builder past
[the seam](../solo/01-the-solo-path.md#the-seam--where-the-solo-path-stops) who hits a foggy
effort on the repo they already shipped runs **`/charting`** against it directly — the same
skill this flow runs, on their own tracker, one ticket per session. It is the same skill by
construction: `charting` stays `✓ ✓` in
[`templates/skills/README.md`](../../templates/skills/README.md), and the skill already
handles both situations explicitly, including
[the one where the index is sparse rather than empty](../../templates/skills/charting/SKILL.md).
Each make ticket goes to `/start-ticket`, which is where
[the flow catalogue](../shared/07-the-flows.md) already sends charting's output.

What they do without is this page's machinery: no `/build-chart-ticket` dispatching layer
specialists behind a review gate, no per-repo commit-message discipline, no closing sequence.
On one repo they own, `/start-ticket` and its own reviewers already cover that ground.

> **This is the sharper line the `solo` / `team` split was always drawing.** The old framing
> called this case *awkward* — neither door quite fitting. It is not awkward; it is a case
> where both doors chart and only one needs a flow wrapped around the charting.

---

## Charting, pointed at code that already exists

[`/charting`](../solo/03-charting.md) is stage 2 of the solo path: a greenfield repo, a
destination that is always *a backlog on a scaffolded repo*, and a map that produces almost
nothing but decisions.

This flow runs the **same skill** against the opposite situation — a mature multi-repo
workspace, a tracker id, and a destination supplied by whoever filed the ticket. Three things
change, and they are the whole of this doc:

| | Solo path | Massive ticket |
|---|---|---|
| Where the chart lives | `tickets/` in the repo, committed | `<workspace>/.claude/charts/<KEY>/`, **not** committed — no single repo owns a multi-repo effort |
| What the tickets are | mostly decisions | decisions **and** makes, because a spec-shaped ticket is mostly makes |
| What closes it | the stack is named, the bootstrap checks are written | every repo reviewed, the map audited, the conclusion banked |

The charting skill already says a map's mix depends on how much fog it started in. That
sentence is doing the work here.

---

## The three commands

```
/start-massive <TICKET-ID>        chart it, then STOP
        │
        │   one map, many sessions
        ▼
/resume-massive [<TICKET-ID>]     one ticket per session — claim, dispatch, bookkeep
        │
        ├── grilling  → you, here, with the human
        ├── research  → one background agent, claimed to it
        ├── task      → the human; claimed to them if it outlives the session
        └── make:<layer> → /build-chart-ticket <KEY>#<NN>
                              gatherer delta → planner → @<layer>-specialist
                              → review, but only when that repo has no other makes left
        │
        ▼
   frontier empties ──┬── DONE      → closing sequence, then stamp closed
                      ├── STALLED   → name who is blocking; leave it unstamped
                      └── ABANDONED → the human's call; stamp and stop
```

**`/start-massive` charts and stops.** It does not claim the first ticket. Sizing the map is
a whole session's work, and taking a ticket at the end of it spends the context that ticket
needed.

**One ticket per session** is not tidiness. A ticket is *sized* to a fresh context; two in one
session means the second runs on the remains of the first. `research` is the only exception,
because it runs in a background context.

---

## The label is the dispatch

A make ticket carries `make:<layer>`, where the layers are the implementation chain declared
in the repo's `CLAUDE.md` — the same source
[`/adapt-to-stack`](../shared/11-adapting-to-your-stack.md) generates the specialists from. A `schema → service → consumer` chain gives you `make:schema`
dispatching `@schema-specialist`, and so on. Add a layer to the chain and you get its ticket
type for free.

**There is no track-allocation step, no slice fork, no worktrees, no aligner or integrator.**
Charting already decomposed this effort; slicing a chart child again is slicing twice. This is
the one place the massive flow is *simpler* than `/start-ticket`, not more complex.

Cross-layer ordering is expressed as **blocking edges between tickets**, never as a hardcoded
chain — on a given map the chain order often is not the order the work has to run in.

---

## One branch per repo, one commit, for the whole map

The map's Notes carry **one final commit message per repo**, authored at chart time. This
looks premature and is not: one branch per repo carries one commit, and the first child to
touch a repo runs days before its siblings exist, so it cannot describe their work.

- First make ticket for a repo → creates the branch, commits with that message.
- Every later one → rebases onto main, amends into the same commit.
- A repo whose first make only graduates out of the fog later has no message yet; the walker
  asks for one then.

Never rewrite the message mid-map. If it stops describing the work, that is a signal to
surface, not to edit quietly.

---

## Two things that fail silently

Both were found by testing the plumbing rather than by reading it, and both look like
bookkeeping until they cost you a map.

**The review gate must exclude the ticket asking.** `/build-chart-ticket` reviews a repo only
when no *other* make ticket for it is still open. It cannot count itself — it is still open
while it asks, because the walker closes it afterwards. Count it and the answer is always
*yes*, and the review never fires on any map.

**A handed-off ticket must be claimed to whoever holds it.** The frontier is *open, unclaimed,
blockers resolved*. A `task` waiting on a person has no blocking edge, so left unclaimed it
stays takeable forever: every session picks it up, asks for the same thing, and ends. The
frontier never empties, so the map can neither stall nor close. Claiming it to the person
takes it off the frontier — which is the only way the frontier empties, and therefore the only
way the *stalled* ending is reachable at all. The same applies to a `research` ticket: left
unclaimed, the next session fires a second agent at a question already being answered.

---

## The three endings

**Done** — frontier empty *and* nothing open. Only then does the closing sequence run:

| | |
|---|---|
| 1 | one `@release-reviewer` per repo, **release mode**, in parallel — over `origin/<main>..<branch>`, a branch range and not a tag range |
| 2 | [`@map-reviewer`](../../templates/agents/map-reviewer.md), once, after all of them |
| 3 | every finding becomes a new ticket — **the map does not close this round** |
| 4 | one re-sweep, and only one. A third round means the map is wrong, not the code |
| 5 | bank the memories: one, or a hub plus one per repo. Never one per ticket |
| 6 | hand the unproven, artifact-shaped criteria to [`/test-ticket`](../shared/07-the-flows.md) |
| 7 | stamp `State: closed` on line 1 of `map.md` — last, and only here |

Step 1 exists because the first repo reviewed got its verdict on day 3, before the consumers
written on day 9 existed, and nothing has looked at it since.

**Stalled** — frontier empty, tickets still open, every one waiting on somebody outside the
session. **Never report this as finished, and never stamp it closed** — the day the blocker
clears it has to be pickable again. Name each waiting ticket and its owner; the owner is the
ticket's claim. One `grilling` ticket asking *proceed without X, or wait?* refills the
frontier.

**Abandoned** — only the human calls it. Stamp it, skip the review sequence, stop.

---

## What the map never caches

**Acceptance criteria.** They are not copied into the map, and a ticket that quotes one has
cached it. `@map-reviewer` re-fetches them at close, so a criterion edited in week two is
judged as it stands rather than as it was. This is easy to violate by accident — a ticket
called *"pick the file naming convention"* wants to paste the criterion into its own question.

**Anything the tracker owns.** These flows are read-only on the tracker, always. Every session
ends by printing text for **you** to paste.

---

## Why this doc exists

- The decompose path and this one both say "large ticket", and they solve different problems.
  Fog is the discriminator, not size.
- `/charting` reads as greenfield-only if you meet it through the solo path. It is not.
- Two of the rules above (the self-counting review gate, the unclaimed handoff) are invisible
  in a design read and fatal in a real run.
- Sitting under `team/` says the **flow** needs other people, not that the **fog** does. A
  reader who takes the folder as the whole claim concludes a solo builder cannot chart an
  existing codebase, which is false and would send them to `/start-ticket` with nothing to
  plan from.

The mechanics live in [`templates/skills/charting/SKILL.md`](../../templates/skills/charting/SKILL.md)
and in your [tracker adapter](../../templates/trackers/README.md). The commands are
[`start-massive`](../../templates/commands/start-massive.md),
[`build-chart-ticket`](../../templates/commands/build-chart-ticket.md) and
[`resume-massive`](../../templates/commands/resume-massive.md).

---
> **Last verified against:** Claude Code `2.1.220` — August 2026
