# 03 — Charting

Charting is **stage 2** of the [solo path](01-the-solo-path.md). You arrive holding a
*build* verdict, a private repo the [kill gate](02-the-kill-gate.md) created, and a map
sitting in that repo as issue #1 — and almost nothing else that is actually settled.

The stage answers **what are we building, and on what?** It ends when nothing is left to
decide, and hands over to [the bootstrap](04-the-bootstrap.md).

The stage is **charting**. The artifact is **the map**. They never share a name — otherwise
you can never say which one you mean.

You run it with **`/charting`**, from
[`templates/skills/charting/SKILL.md`](../../templates/skills/charting/SKILL.md). That
template owns the mechanics and this doc does not repeat them. What it deliberately does
**not** know is the one thing this doc supplies: where the solo path is going.

---

## The destination you hand it

`/charting` is general. It charts a docs effort or a data migration as readily as a
product, so the destination is an **input** — supplied once, at the start, and every
session orients to it before choosing a ticket.

On the solo path the destination is always the same:

> **A backlog of work units on a scaffolded repo that passes the seam.**

The seam is the eight checks in
[the spine doc](01-the-solo-path.md#the-seam--where-the-solo-path-stops); it owns them in
full and this doc does not restate them.

That is where the *solo path* ends. It is **not** where *charting* ends, and confusing the
two is the single easiest way to lose this stage.

| What the destination might suggest | What charting actually does |
|---|---|
| Charting produces the backlog | The backlog is **stage 4**. Charting decides what goes in it. |
| Charting scaffolds the repo | Scaffolding is **stage 3**. Charting decides what to scaffold. |
| Charting stops when the repo is real | Charting stops when **nothing is left to decide** before stages 3 and 4 can run. |

The destination is the horizon every ticket is aimed at. It fixes the scope — anything
past it is out of scope, and on this path *"past it"* means deployment, hosting, and
release. Charting itself stops well short of the horizon, at the last decision.

---

## The map, in one paragraph

The map is a single issue on the repo's tracker — issue #1, created by the gate. Its
tickets are its child issues, one question each, sized to a single agent session. The map
is an **index, not a store**: a decision lives in exactly one place, its own ticket, and
the map only gists it and links to it.

You never talk to the tracker directly. Charting states an intent — *create*, *close*,
*claim*, *is this blocked?*, *give me the frontier* — and the one installed tracker adapter
answers it. Which tracker you are actually on is the adapter's business, not yours and not
the skill's. The adapters, and the full verb list, are in
[`templates/trackers/`](../../templates/trackers/README.md).

The [flow catalogue](../shared/07-the-flows.md) lists `/charting` alongside the pipeline
flows it eventually hands off to.

---

## What a session feels like

**One ticket per session.** Not a rule about tidiness — a ticket is *sized* to a fresh
context window, and two tickets in one session means the second one runs on the remains of
the first.

| Step | What you do |
|---|---|
| 1 | Open the map. The low-resolution view — destination, notes, what is already decided. Not every ticket body. |
| 2 | Take a ticket from **the frontier** — the open, unblocked, unclaimed ones. Claim it before any work. |
| 3 | Resolve it. Usually a [`/grilling`](../../templates/skills/grilling/SKILL.md) conversation, one question at a time. Sometimes a [`/research`](../../templates/skills/research/SKILL.md) subagent, sometimes manual work. |
| 4 | Post the answer as a resolution comment, **gist first**, and close the ticket. |
| 5 | Look at what the answer just made visible, and ticket it. |

Step 5 is the one that feels like nothing and is actually the stage working. See
[fog of war](#fog-of-war) below.

**The gist line is not a formality.** Every resolution comment opens with a one-line
summary, because the map's decision list is rebuilt from those first lines rather than
hand-maintained. Skip it once and regeneration stops being mechanical.

**A session that runs out before the ticket does** posts a progress comment and keeps the
claim. Nothing is lost and nothing is jammed — the claim was never a lock. Resuming across
many sessions is its own subject and its own doc.

---

## Fog of war

You cannot chart what you cannot yet see, and pretending otherwise produces a map full of
tickets that turn out to be wrong. So the map is **deliberately incomplete**. Beyond the
live tickets sits the fog: decisions you can tell are coming but cannot yet phrase.

The test is whether you can **state the question precisely now** — not whether you can
answer it now.

| | Where it goes |
|---|---|
| The question is already sharp — even if you cannot act on it yet | **A ticket** |
| You can see something is there, but not what it is asking | **Not yet specified**, on the map |
| It sits past the destination | **Out of scope**, on the map — it never graduates |

Resolving a ticket clears the fog ahead of it. Whatever just became sharp graduates into
new tickets, and the patch it came from is deleted, so it lives in exactly one place.

Expect the map to **grow** for the first several sessions. That is not scope creep; it is
the fog thinning. Charting is over when the map stops growing and the frontier empties.

---

## Decide, or make — never both

Every ticket on the map is a **decision** or a **make**.

| | A decision ticket | A make ticket |
|---|---|---|
| Produces | an answer, no files | a file on disk |
| Ends when | you and the agent agree | the file lands |
| Predictable? | no | yes |
| Finding the other kind | normal — spawn the make ticket on close | **stop and open a decision ticket** |

They fail differently, which is why they cannot share a ticket: put both in one and the
unpredictable half eats the context the predictable half needed.

**Charting produces decisions by default.** The pull to just go and build the thing is
almost always the signal that you have reached the edge of the map — which on this path
means stage 3 is waiting for you, not that charting needs to stretch.

The one make the solo path **guarantees** is the last ticket on the map: the tail's
bootstrap checks. Others turn up as decisions spawn them, and that is the rule working
rather than the map drifting. What tells you a make has drifted is not its existence but
its subject — a make that would produce something belonging to **stage 3 or 4** is charting
reaching past its own stopping point.

---

## The tail

Choosing the stack is a real decision, and charting is already the machine for resolving
decisions — so it lives **on the map** rather than standing as a stage of its own. Two
tickets, in this order:

| | Ticket | Kind |
|---|---|---|
| 1 | **Name the stack** | decision |
| 2 | **Write the bootstrap checks** — the exact build command, the test command if this stack gates on one, the Serena index check if the verdict calls for one | make |

Together they are **the tail**, and **neither is takeable while any other ticket on the map
is open.** Product decisions shape the stack far more than the stack shapes the product, so
every one of them goes first.

**How the stack actually gets chosen is its own doc** —
[06-choosing-the-stack.md](06-choosing-the-stack.md). This section owns *placement and
ordering*; that one owns *method*: read-level rather than write-level, mainstream-first,
propose-and-kill rather than comparison, and the three things ticket 1 decides.

This is a **rule you follow, not blocker wiring you maintain.** Marking the tail blocked by
every other ticket would be correct and would also demand a new edge every time you create
a ticket — the kind of bookkeeping that gets forgotten once and then silently lies to you.

**The rule has a documented escape.** Occasionally a product question genuinely cannot be
answered without the stack — *"should this work offline?"* is a product question whose
honest answer depends on whether offline is nearly free or three weeks of work in the stack
you would pick. When a ticket is truly stuck on this, take the stack early **and record why
in its answer.** A stuck ticket is a signal worth writing down, not a rule to bend around
quietly.

The tail's second ticket is what makes [the bootstrap](04-the-bootstrap.md) testable: its
checks are what stage 3 runs to prove it is done.

---

## One backwards step

Stages run forwards, with **one step back allowed**. From charting's side that means two
different things depending on which direction you are facing:

| | What it means |
|---|---|
| **Something downstream comes back** | The bootstrap or the backlog hits a decision that turns out to be wrong. You reopen the map and add a ticket. You do not push forward on something you now know is wrong. |
| **You want to go back further** | You cannot. Charting does not reopen the kill gate — the way to un-decide *build* is to **abandon**, below. |

One step, not a spiral. If the map keeps reopening, the thing it is telling you is in the
next section.

---

## Two endings

```
                       ┌──────────────────────────────────────┐
   THE KILL GATE       │            CHARTING                  │
   verdict: BUILD ────►│                                      │
   repo exists,        │  destination in ──► map (issue #1)   │
   map is issue #1     │                       │              │
                       │        ┌──────────────┴───────┐      │
                       │        ▼                      │      │
                       │   claim a frontier ticket      │     │
                       │        │                       │     │
                       │   resolve it ──► gist, close   │     │
                       │        │                       │     │
                       │   fog thins ──► new tickets ───┘     │
                       │        │                             │
                       │   frontier empties                   │
                       │        │                             │
                       │   THE TAIL, last, nothing else open: │
                       │     1. name the stack   (decision)   │
                       │     2. bootstrap checks (make)       │
                       │        │                             │
                       └────────┼─────────────────────────────┘
                                │
                 ┌──────────────┴───────────────┐
                 ▼                              ▼
             CLEARED                        ABANDONED
        one memory written             one memory written
                 │                       (what you learned)
                 ▼                              │
        3. THE BOOTSTRAP                        ▼
                                        the path stops here
             ◄──── one backwards step allowed ────
```

**Cleared** is the ordinary ending: the frontier is empty, the fog is gone, the tail is
resolved, and there is nothing left to decide before someone goes and does the thing.

**Abandoned** is an ending, not a failure — and [the spine doc](01-the-solo-path.md) says
why the path needs one: the gate is deliberately cheap, so it decides on very little
information, and charting is where the true size of the thing shows up.

**How you tell which one you are in** — the test is not *"is this hard?"*, because
everything worth building is hard by stage 2. The test is:

> **Would this fact have changed the gate's verdict, if you had known it at the gate?**

If yes, the gate was working from information it did not have, and abandoning is the
correct outcome rather than a change of heart. If no — it is merely bigger, or duller, or
more tangled than you hoped — that is ordinary, and it is what the backlog is for.

Two tells that the answer is yes, both of which show up as map behaviour rather than as a
feeling:

| Tell | What it means |
|---|---|
| **The map will not stop growing.** Every resolution graduates more fog than it clears, session after session. | The thing is not the size the gate judged. |
| **You keep spending the backwards step.** Decisions do not stay decided. | The premise underneath them is the thing that is actually wrong. |

Abandon by closing the map with a resolution that says what you learned. The repo is
private and stays where it is — a costly thing to have discovered in three sessions of
conversation is still the cheapest way to have discovered it.

---

## What charting hands to the bootstrap

| | |
|---|---|
| **A cleared map** | Every decision closed, and each one recoverable from its own ticket. |
| **A named stack** | Seam check 1, done. |
| **The bootstrap checks** | Written against the actual stack, which is what makes stage 3 testable. |
| **One memory** | *What this project is and why.* Written when the map closes — one per map, never one per ticket, so stage 3 can add the second and the [seam](01-the-solo-path.md#the-seam--where-the-solo-path-stops) arithmetic comes out at exactly two. See [05-forgetful.md](../shared/05-forgetful.md). |

Serena is **not** indexed yet, and that is correct rather than broken — the repo is a day
old and empty. Stage 3 is what makes [seam check 4](01-the-solo-path.md#the-seam--where-the-solo-path-stops)
hold, on whichever branch the tail's verdict put it. See
[04-serena.md](../shared/04-serena.md).

---

## Why this doc exists

The skill template tells you how charting works. The spine tells you where charting sits.
Neither answers the questions a reader actually has while standing *in* the stage:

- The destination you hand the skill is where the **path** ends, not where **charting**
  ends — and charting stopping short of it is the design, not a shortfall.
- A map that grows for several sessions is the stage working correctly.
- The stack is not a stage; it is the last two tickets, and there is a written escape for
  the one case where waiting is dishonest.
- There are two ways out, and there is a test for which one you are looking at.

Read this while you are charting. Read [01-the-solo-path.md](01-the-solo-path.md) before
you start and
[`templates/skills/charting/SKILL.md`](../../templates/skills/charting/SKILL.md) when you
want the mechanics.

---
> **Last verified against:** Claude Code `2.1.220` — July 2026
