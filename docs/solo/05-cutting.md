# 05 — Cutting

Cutting is **stage 4** of the [solo path](01-the-solo-path.md), and the last one. You
arrive holding a **closed map**, a **real repo** that builds and runs, and one pass/fail
report from [the bootstrap](04-the-bootstrap.md) covering seven of the seam's eight items.

The stage answers **cut it into work units the pipeline can run.** It ends when those units
exist in the tracker, ordered, and **you have approved them** — which is the eighth item —
and hands over to [`/start-ticket`](../shared/08-ticket-pipeline.md).

The stage is **cutting**. The artifact is **the backlog**. Two names, kept distinct — and
this stage is why the rule is written down. It used to be called *the backlog* and it
produced *the backlog*, sitting as the last row of a table in
[the spine](01-the-solo-path.md#the-four-stages) whose very next line forbids exactly that.

You run it with **`/cut-backlog`**, from
[`templates/skills/cut-backlog/SKILL.md`](../../templates/skills/cut-backlog/SKILL.md).
That template owns the mechanics; this doc owns *where the units come from and why they are
shaped this way*.

> The `/cut-backlog` template is still being written — that link is dead until it lands.
> The decisions it will be built from are on this page.

---

## What you arrive with

| | Where it came from |
|---|---|
| **The smallest version** | One sentence, written into the map's Notes at the [kill gate](02-the-kill-gate.md#what-a-build-verdict-hands-over), stage 1. **This is the source of the units.** |
| **A closed map** | Every decision resolved, each recoverable from its own ticket. **Closed and frozen** — nothing on it moves again during this stage. |
| **A real repo** | The stub builds and runs, one folder per layer, layer specialists on disk. Tickets can name paths that exist. |
| **One report** | Seven of the seam's eight items. [Item 6](01-the-solo-path.md#the-seam--where-the-solo-path-stops) — *the backlog exists* — is the one this stage makes true. |

**Nothing on the map is reopened here.** If cutting turns up a decision that was wrong,
that is [the backwards step](03-charting.md#one-backwards-step) — one step, deliberately
taken — not a judgement you make while writing tickets.

---

## The units come from the smallest version, not from the decisions

This is the whole stage in one line, and it is the opposite of what the shape suggests. You
are standing on a pile of resolved decisions, so it looks like the job is converting them
into work.

**They do not convert.** A decision like *"seam item 4 becomes two branches"* is not
something anyone can build. The buildable thing was *write the doc*, and that had to be
said separately.

The scope was named **three stages earlier**:

| | Says | Where it lives |
|---|---|---|
| **The smallest version** | **What.** The units are cut from this. | The map's Notes, written by the gate |
| **The map's decisions** | **How**, and **what not to do**. Constraints on every unit, never units themselves. | Each in its own closed ticket |

That also closes a joint in the path. The gate's first hard kill is *you cannot say what
the first version is* — and if stage 4 cuts from that sentence, then **stage 4 can only run
because stage 1 passed.** The hard kill is not a mood about ambition; it is a precondition
three stages downstream.

**Two sources were considered and rejected**, and it is worth knowing why so you do not
reinvent them:

| Rejected source | Why |
|---|---|
| **The decisions** | Produces a backlog shaped like your *thinking* rather than like the *product* — and tickets nobody can pick up and run. |
| **A fresh spec** (the [`/to-spec`](../shared/09-decompose-path.md) shape) | After a cleared map a spec is mostly transcription, and it becomes a **second place the decisions live**. |

---

## One ticket = one thing the app can now do

> **One ticket = one thing the app can now do, all the way through the layers it needs.**

Plumbing-only tickets are **forbidden**. *"Set up the SQLite tables"* is not a unit — it
happens **inside** *"add a habit"*, the first unit that needs it.

The reason is verification, not tidiness. A plumbing ticket finishes with **nothing to
run**, so the two-tier review at the end of [`/start-ticket`](../shared/08-ticket-pipeline.md)
has no behaviour to review, and you find out it was wrong two tickets later. This is the
vertical-slice argument [09-decompose-path.md](../shared/09-decompose-path.md) already makes
about slices *inside* a ticket, applied one level up to the tickets themselves.

| | Unit? |
|---|---|
| *Add a habit* | **Yes** — a screen, a write, a row. It carries whatever plumbing it needs. |
| *Tick a habit off for today* | **Yes** — and it needs the one above first. |
| *Set up the SQLite schema* | **No.** Nothing to run at the end. |
| *Wire up navigation* | **No.** Same reason. |

### Why the pipeline's usual size bar is not reused

[`12-when-not-to-use.md`](../shared/12-when-not-to-use.md#tickets-too-small) sets the
pipeline's bar: worth it when the change *touches 2+ files that aren't in the same method,
or requires a decision the codebase doesn't encode yet.*

**On a day-one repo that bar returns *yes* to everything**, and structurally so:

- The codebase encodes nothing at all, so the second clause is universally true.
- The repo is a stub with one empty folder per layer, so the first ticket through it
  necessarily touches several.

**A bar that cannot return *no* is not a bar.** It is the right bar in an established
codebase and the wrong one here, which is why this stage states its own.

---

## Dependencies are real, and the ticket body holds the truth

Order is a **fact about the work** — *"tick a habit off"* cannot come before *"add a
habit"* — so it is written down as a dependency rather than implied by a position in a
list.

Dependencies show up in three places, and **exactly one of them is the truth**:

| | Role |
|---|---|
| **The ticket body** — *"needs #6 first"* | **The truth.** The only representation that exists on every tracker. |
| **Native blocked-by links** | **A picture of it.** Renders the graph in the tracker's own UI, where the tracker has them. |
| **A generated HTML view** | **A picture of it.** So trackers with no native edges can still show you where you are. |

The body wins because it is the only one that **needs no per-tracker answer**. Nominating
the native edge would put the truth somewhere different on GitHub than on local files —
exactly the branching [`templates/trackers/`](../../templates/trackers/README.md) exists to
prevent.

**A line in a body is normally a stale-data trap, and here it is not.** The map deliberately
refuses to record blocking that way, because a map's graph churns for weeks as fog clears.
A backlog differs on both counts:

- The dependency graph is **authored in one sitting** and then stops moving.
- The line names **which ticket**, never whether that ticket is finished. Open-or-closed is
  looked up live, every time.

**A line that names an id cannot go stale. A line that caches a state can.**

---

## A board on screen, and nothing is created until you approve

Cutting renders the whole backlog as a **board you edit in place** — reorder, merge, split,
drop, rewrite. When you approve it, **every ticket is created at once.**

The alternative is to create them first and tidy up in the tracker, which means editing a
dozen real issues one at a time, deleting the ones you did not want, and writing to a shared
surface before anyone has agreed what belongs on it.

---

## The scope check is a trace, not a count

The obvious brake is a number: *more than about ten tickets, go back to the smallest
version.* It does not work, and why it does not is more useful than the rule that replaces
it.

**The count cannot vary for two reasons.** The ticket count *is* the number of things the
app can do, which is pinned by the smallest-version sentence. Three or four for *"add a
habit and tick it off each day, on my phone."* To reach twenty you do not need the count to
drift — **you need the sentence to have grown**, and there is exactly one place it can grow:
charting, which runs for weeks and settles things like *habits can be archived* that were
never in the sentence.

So the check measures the cause directly:

> **Every ticket on the board points at the phrase in the smallest version it comes from.
> A ticket that points at nothing is flagged.**

Then, per flagged ticket, you choose:

| Choice | What it means |
|---|---|
| **Cut it** | Scope that crept in during charting. It was never in the first version. |
| **Update the sentence** | The first version really did grow — say so **out loud**, and change the smallest version deliberately. |

Silently keeping it is the one option that is not available.

Two things the trace does that a count cannot: it **names which ticket** is the problem, and
it treats an honestly-large first version differently from a bloated one. A count punishes
both the same.

**The general form is worth keeping:** when a number varies for exactly one reason, check
the reason directly. The count was a proxy for *did charting add scope*, and the proxy is
strictly worse than the question.

---

## What goes inside each ticket

### The constraints are copied in, not linked

*"Add a habit"* must obey charting's decisions — SQLite, on device, single screen. Those go
**into the body**, not behind a link.

**The consumer decides this.** [`08-ticket-pipeline.md`](../shared/08-ticket-pipeline.md)
is explicit that `@ticket-analyzer` does **no** code or memory lookups — it reads the ticket
and nothing else. A link to decision #7 is a door the first agent in the pipeline never
opens.

Copying normally means drift, and here it cannot: **the map is closed and frozen before this
stage runs**, so only one of the two copies can still change. That is the rule worth
carrying — *duplication is dangerous when both copies can change*, not merely because there
are two of them.

### And a *Where this came from* section at the bottom

Every work ticket ends with one:

```
---
Where this came from
- From map #1 — habit tracker
- Storage on device, SQLite — decision #7
- Single screen — decision #11
```

Only the decisions constraining **this** ticket. Without it a copied constraint is
**unfalsifiable**: six weeks later *"Storage: SQLite"* is either a decision or a typo, and
nothing on the page tells you which. This is what makes the copy safe rather than merely
convenient.

**At the bottom**, below the working content, because the analyzer parses the top.

---

## Work tickets are standalone, not children of the map

They are ordinary issues sitting **beside** the map, not under it.

Charting's frontier query asks the tracker *which children of #1 are open?* If work units
are children, that query starts returning **jobs** — and charting only knows how to resolve
**questions**. A closed map with a dozen open children also reads, correctly, as a map that
never finished.

They still came from the map, and that has to be recoverable — so each body carries the one
line **`From map #1`** and no parent link. The history survives; the map's tooling does not
see them.

---

## The stage, end to end

```
   THE SMALLEST VERSION ──────────────────────────┐   (one sentence, from the
   "add a habit and tick it off each day,         │    kill gate — stage 1)
    on my phone"                                  │
                                                  ▼
   THE CLOSED MAP ─── decisions ───────────►  CUT INTO UNITS
   SQLite · on device ·                       one per thing the app can do
   single screen                                  │
        │                                         ▼
        │  copied into                       ORDER THEM
        │  every ticket                      "needs #6 first" in the body
        │  that they bind                         │
        │                                         ▼
        └──────────────────────────────────►  THE BOARD ◄── you edit in place
                                                  │
                                          ┌───────┴────────┐
                                          ▼                ▼
                                    TRACE EVERY       points at
                                    TICKET TO A       nothing?
                                    PHRASE            ──► FLAG IT
                                          │                │
                                          │           cut it, or change
                                          │           the sentence out loud
                                          ▼
                                    YOU APPROVE
                                          │
                                          ▼
                                 ALL TICKETS CREATED AT ONCE
                                          │
                                          ▼
                                 SEAM ITEM 6 HOLDS ──► /start-ticket
```

---

## What cutting hands to `/start-ticket`

| | |
|---|---|
| **An ordered backlog** | Units in the tracker, dependencies in the bodies, and **you approved it** — seam item 6, the last one. |
| **Self-contained tickets** | Each carries its own constraints, so `@ticket-analyzer` needs nothing but the ticket. |
| **A recoverable origin** | `From map #1` plus the decisions that bind each unit. |

With item 6 true, all eight [seam](01-the-solo-path.md#the-seam--where-the-solo-path-stops)
checks hold. **The solo path stops here.** Everything after this is the shared pipeline, and
none of it is solo-specific.

---

## Why this doc exists

The template will tell you how to run `/cut-backlog`. The spine tells you where stage 4
sits. Neither answers the questions a reader has while standing **in** the stage, holding
weeks of decisions and wondering what to do with them:

- **The decisions are not the source of the work.** The smallest version is, and it was
  written three stages ago, before any of this existed.
- **The size bar the rest of the playbook uses does not apply here**, and it fails in a way
  that is invisible — it says *yes* to everything on a day-one repo.
- **Dependencies live in the ticket body**, which everywhere else in this playbook would be
  a stale-data trap, and here is not.
- **The scope check is a trace, not a count** — and the trace names the ticket that is
  wrong, which is the thing a count never can.
- **Nothing is created until you approve the board**, because a tracker is a bad place to
  change your mind.

Read this before your first cut. Read [01-the-solo-path.md](01-the-solo-path.md) for the
seam it completes, and [04-the-bootstrap.md](04-the-bootstrap.md) for the repo it is
writing tickets against.

---
> **Last verified against:** Claude Code `2.1.220` — July 2026
