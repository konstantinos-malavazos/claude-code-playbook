---
name: add-feature
description: >-
  Put one feature for a product that already exists through a gate, and come out with a
  verdict and a route — build it, or record why not. Runs the seam checks read-only, asks
  six questions one at a time, sends cold lookups inward through Serena and outward through
  /research, applies two hard kills, and routes a build by fog, never by size: onto the open
  map, into one work ticket, or into a small map. Use when the user says "add a feature",
  "should I build this feature", or "I want X in my app". NOT for a raw idea with no repo
  (/pitch), a project that is not at the seam or wants a new destination (/adopt), or work
  that already has a ticket (/start-ticket).
---

# Add feature — the burden of proof is on the feature

The user makes the case for the feature. The product does not owe it a place.

This is the solo path's way back in from the far side of the seam. A product that passes
the seam gets an idea for one more thing, and this answers *does this belong in it, and
how does it enter?* It ends in a verdict — **build** or **kill** — and, on build, a route.

> The stage is **the feature gate**. The skill is **`/add-feature`**. The output is a
> **verdict** plus a **route**. Three names, never merged.

The stage itself is described in
[`docs/solo/10-the-feature-gate.md`](../../../docs/solo/10-the-feature-gate.md). This file
is how to run it.

**Worked example, used throughout:** a game prototype that passes the seam. The user wants
a **daily challenge** — one generated level a day, the same for everybody.

## Before the first question

**Search the closed `<LABEL-PREFIX>:feature` issues.** Every verdict this gate ever gave is
one of them. Use the adapter's *list*, then *read* the ones whose title is close enough that
the user would recognise it. Do this before the seam check, so a repeat is named first.

If this feature has been through the gate before, say so **before** question zero, and say
which kind of verdict it got:

| Found as | What you do |
|---|---|
| **killed** | Name it, quote the recorded reason, and ask what is different now. Do not refuse to run; past-you is allowed to be wrong. But the burden just went up. |
| **rerouted** | It was off-destination last time. Ask whether `/adopt` has since moved the destination. If not, the answer has not changed. |
| **built** | Point at the work ticket or map it routed to. The user may have forgotten. Stop and check before doing anything else. |

Nothing found is the normal case. Carry on.

## The seam check — read-only

**Run the eight seam checks**
([`docs/solo/01-the-solo-path.md`](../../../docs/solo/01-the-solo-path.md#the-seam--where-the-solo-path-stops))
and **change nothing**. This gate judges features for a product that is set up. It never
sets one up. Then look for an open `<LABEL-PREFIX>:map` issue, found by its label.

| Seam | Open map | What you do |
|---|---|---|
| all eight hold | either | carry on to question zero |
| any check fails | **none** | **Stop.** Name each failing check, by number and name. Say: *"This project is not at the seam, so a feature has nowhere to land. Run `/adopt` — it decides where the project enters."* |
| any check fails | **yes** | **Stop.** Name each failing check. Say: *"This project is on the solo path but not at the seam yet. Finish charting first — map #N is still open."* |

**`/add-feature` never repairs setup.** Not a missing memory, not a missing specialist, not
one line of `CLAUDE.md`. Each fix belongs to the stage that owns it, and a gate that patches
its own precondition has stopped being a gate.

## The six questions

**One at a time. Wait for each answer.** The rhythm is
[grilling's](../grilling/SKILL.md#running-the-round): post the whole numbered list once,
then ask each in its own turn, in its ~8-line format. Do not batch them, do not present
them as a form, and do not answer any of the human-owned ones yourself.

| # | Question | Who answers | Spawns an agent |
|---|---|---|---|
| 0 | **Does it move the product toward its destination?** | human | no |
| 1 | What is it, and which of the product's users want it? | human | no |
| 2 | Does it already exist? | `@serena-lookup` inward, `/research` outward | **yes — both cold** |
| 3 | What is the smallest first version? | human | no |
| 4 | What is the hard part, in **this** code? | `@serena-lookup` | **yes — cold** |
| 5 | What does it cost you if you never build it? | human | no |

**Question zero is asked first, before anything is dispatched**, so no lookup has returned
when the user answers it. Read the destination first — from the memory *what this project
is and who it is for*, or from the map's Notes — and quote it in the question. The user
judges the feature against what the project already recorded, not against a destination
invented on the spot to fit it. `/pitch`'s own question zero is untouched: that one is asked
once, at a project's birth. This one checks against what it wrote down.

> ❓ **Q0 of 6** — **Does a daily challenge move the game toward "a puzzle game people
> come back to every day, on the Play Store"?**

**"Just me" is a complete answer to question 1**, as on `/pitch`. Do not push for users the
product does not claim to have.

**On question 3, push on size — once, properly.** The first answer is almost always too big.
Ask what could be cut and still ship the feature's point. *"A daily level, a leaderboard,
streaks, and a push reminder"* cut to *"one seeded level a day, no leaderboard"* is the
push working. If after real pushback they still cannot name a first version, that is hard
kill 1 and it fires.

**Question 5 informs and never kills.** "Nothing much" is an honest answer and a fine one.

**A decision the user settles in the gate is settled.** *"Same level worldwide, or by local
date?"* — the user answers *"by local date; nobody waits for midnight UTC"*. That becomes a
constraint with a trace, not an open decision. What they cannot settle here stays open, and
open decisions are what the route turns on.

## Briefing the cold lookups

Three dispatches, each answering one question. **State each one's role in one line as you
dispatch it** — that line plus the named agent or skill is the whole persona.

| Dispatch | At | Role, in one line |
|---|---|---|
| `@serena-lookup` | Q2 | an inward reader answering *does the product already do this?* |
| `/research` subagent | Q2 | an outward searcher answering *is there a library or a known pattern for this?* |
| `@serena-lookup` | Q4 | an inward reader answering *what in this code depends on, or would have to change for, this?* |

Give each a **question, not a topic** — *"is there a daily or date-seeded level anywhere,
and what generates levels?"*, not *"look at level generation"*.

> **Never tell a lookup how the user feels about the feature**, how much they want it, what
> verdict you are leaning towards, or what you hope it finds. Give it the question and
> nothing else.

**They run cold, and that is the point.** A fresh agent never heard the enthusiasm, so it
cannot mirror it.

**The interview carries on while they run, so you own checking on them** — at each multiple
of the expectation you stated when you dispatched. A lookup that never came back is not a
verdict of "nothing found", and the Q2 lookup arms hard kill 2.

In the example, the Q2 lookup returns `LevelGen.seed()` at its `file:line` — levels are
already generated from a seed — and **no scheduler**: nothing in the game runs on a date.
The research subagent finds nothing worth a dependency. The Q4 lookup names who calls
`LevelGen.seed()` and that the save file has no notion of a day. The hard part is small:
a seed from the local date, and remembering that today's level was played.

## The hard kills

Apply these **mechanically**. They are not weighed, not scored, and never balanced against
how much the user wants the feature.

| # | Hard kill | Fires when |
|---|---|---|
| 1 | **No first version** | after real pushback on question 3, they still cannot name the smallest version of the feature |
| 2 | **The product already does it** | the Q2 lookup found it, **and it works**. Point at the code — the `file:line` sites the lookup returned |

**"Found something close" is not hard kill 2.** `LevelGen.seed()` is half the feature, not
the feature: it becomes a constraint on the build, never a kill. Kill 2 fires only when the
thing the user asked for is already there and working — check by running it when the
lookup's sites leave any doubt.

**When one fires, say so plainly and stop weighing.** Do not offer ways to rescue it, and do
not carry on to the next question hoping it balances out. Record it and go to the verdict.

**A hard kill that has fired cannot be un-fired**, by you or by the user.

**One reroute, not a kill: off-destination.** Question zero answered *no* means the feature
pulls the product somewhere it has not decided to go. That is not this gate's call to make
in either direction. Choosing a new destination is adoption's job, so stop, record it as
**rerouted**, and point at [`/adopt`](../adopt/SKILL.md). Do not ask questions 1–5 first.

## The verdict — a closed `:feature` issue

**Always, on every outcome — build, kill, or reroute.** Create one issue labelled
`<LABEL-PREFIX>:feature`, then *close* it at once. It is a record, not a ticket: nothing is
worked from it, and the route's own tickets carry the work.

| It holds | What you write |
|---|---|
| **Title** | the feature, short — *Daily challenge* |
| **The verdict** | **build**, **kill**, or **rerouted** — and on a kill, **which rule** killed it, at the length past-you will need in a year |
| **The gate answers** | the settled answer to each question asked, 0 to 5 |
| **The lookups** | each report verbatim, its `file:line` sites intact |
| **Settled in the gate** | each decision the user settled — *by local date, not worldwide* |
| **Still open** | each decision the user could not settle — *do we need a server for a leaderboard?* |
| **The route** | on build: the map or ticket it went to, by id |

**Not the ideas file.** That file holds projects. A feature belongs to a product, so its
verdict lives in that product's tracker, where the next run of this gate searches for it.

When no hard kill fired and the destination held, **the user decides build or kill**, with
question 5's answer in front of them. Recorded either way.

## The route — fog decides, never size

On **build**, the route turns on one thing: are there open decisions? Size never chooses
it. A large feature with nothing left to decide is still one work ticket — and if it is too
big for one sequential pass, that is
[the decompose path](../../../docs/shared/09-decompose-path.md), which `/start-ticket`
already takes. A small feature with one real unknown still goes through charting.

Check the rows in order. Stop at the first that applies.

| | When | Route |
|---|---|---|
| 1 | **An open map exists** | Add to **that** map: each open decision as a child ticket, typed as charting types them — or, with none open, one child ticket for the feature itself. **One product, one open frontier.** Next: `/charting` against that map. |
| 2 | **No open decisions** | **One work ticket**, in cut-backlog's shape, below. Next: `/start-ticket` against it. |
| 3 | **Open decisions** | **A small map**: one issue labelled `<LABEL-PREFIX>:map`, taking the next free issue number, its Notes holding the feature's smallest version and `From feature #23 — daily challenge`. Each open decision becomes its child ticket, typed as charting types them. Next: `/charting` against it. |

**Row 2's ticket has the five parts
[`/cut-backlog`](../cut-backlog/SKILL.md) gives every unit**, so `@ticket-analyzer` reads it
the same way. The constraints are **copied in**, each traced to the gate. With the
leaderboard cut from the first version, the daily challenge has nothing open, and verdict
issue `#23` routes to:

**Title:** `Play today's daily challenge`

```markdown
Open the daily challenge and play the same level as everyone else on your local date.

## Constraints

- Seed the level from the local date through `LevelGen.seed()`. No new generator.
- Local date, not UTC. No server, no network calls.
- One play per day counts; the save file records the date last played.

---
Where this came from
- From feature #23 — daily challenge
- Seed through LevelGen.seed() — gate answer, #23
- Local date, not UTC — gate answer, #23
- One play per day — gate answer, #23
```

There is no `needs #… first` line here because nothing blocks it. Where the feature does
wait on an open ticket, the line goes after the first one, as in cut-backlog.

**Keep the leaderboard and the route changes.** *"Do we need a server for a leaderboard?"*
cannot be settled in the gate — it is fog. That is row 3: a small map, with that question
as its first ticket, typed `research`.

## Order of operations

```
   search closed :feature issues   ── killed / rerouted / built? say so first
        │
   seam check, read-only
        ├── fails, no open map   ──► STOP: name the checks, point at /adopt
        ├── fails, open map      ──► STOP: finish charting first
        │
   Q0 ──► human, against the RECORDED destination  ── before anything is dispatched
        ├── no ──► REROUTE to /adopt
        │
   Q1 ──► human
   Q2 ──► COLD @serena-lookup inward  +  COLD /research outward
   Q3 ──► human, you push on size                  ── hard kill 1
   Q4 ──► COLD @serena-lookup — the hard part, in this code
   Q5 ──► human, informs only
        │                                          ── hard kill 2 when Q2's report lands
   verdict ──► BUILD │ KILL
        │
   create the :feature issue, close it   ── always
        │
   on BUILD, route by fog:
        open map?        ──► onto that map         ──► /charting
        nothing open?    ──► one work ticket       ──► /start-ticket
        decisions open?  ──► a small map           ──► /charting
```

## Ending

**Every outcome ends with the `next-steps` block**, after the report. What it carries
differs by outcome:

| Outcome | Landed | Next command | Session |
|---|---|---|---|
| **Stopped at the seam, no map** | the failing checks, by number; nothing created | `/adopt` | fresh: adoption surveys the whole project |
| **Stopped at the seam, open map** | the failing checks and the open map, by id | `/charting` with that map's number | fresh: charting is sized to one |
| **Rerouted** | the closed `:feature` issue, by id | `/adopt` | fresh: adoption surveys the whole project |
| **Killed** | the closed `:feature` issue, by id, with which rule killed it | none — a kill is a recorded no, not a deletion | this one is over |
| **Build, onto the open map** | the `:feature` issue and each new child ticket, by id | `/charting` with that map's number | fresh: charting is sized to one |
| **Build, one work ticket** | the `:feature` issue and the ticket, by id | `/start-ticket` with that ticket's id | fresh: one ticket per session |
| **Build, a small map** | the `:feature` issue, the new map and its tickets, by id | `/charting` with the new map's number | fresh: charting is sized to one |

Nothing to commit on any of them: this gate writes to the tracker, never to the repo. Fill
every argument in — `/start-ticket 24`, never a placeholder.

## Stop condition

The gate is done when the `:feature` issue is closed with its verdict, and on *build*, when
the route's tickets exist.

**It is not done when you have run out of questions**, and it never starts the build.
Implementing the feature in this session is the one thing it must not do: the next unit is
sized to a fresh context.
