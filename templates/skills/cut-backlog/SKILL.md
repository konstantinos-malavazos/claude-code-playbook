---
name: cut-backlog
description: >-
  Cut a closed charting map into an ordered backlog of work units — one ticket per thing
  the app can now do, traced back to the smallest version, shown on a board you approve,
  then created in the tracker all at once. Use when charting has closed and the repo is
  scaffolded, or the user says "cut the backlog" / "turn the map into tickets" / "what do
  I build first". NOT for a map that is still open, and NOT for adding one ticket to a
  backlog that already exists.
disable-model-invocation: true
---

# Cutting — one ticket per thing the app can now do

This is **stage 4** of the solo path, and the last one. Everything has been decided and the
repo is real. You turn one sentence into a backlog, hand it over, and stop.

> The stage is **cutting**. The artifact is **the backlog**. They never share a name.

> Prior art: `/to-spec` and `/to-tickets`. This is a re-derivation, not a copy — and it is
> **one command, not two**. `/to-spec` existed to write a spec first; after a cleared map a
> spec is mostly transcription, and it becomes a second place the decisions live.

The reader-facing explanation of *why the units are shaped this way* lives in
`docs/solo/05-cutting.md`. **This file is the mechanics.** Where the two overlap, this one
says *what you do*; that one says *why it works*. Do not re-argue it here.

**Decide nothing.** Every choice this stage needs was made in charting. **Nothing on the map
is reopened here** — if cutting turns up a decision that was wrong, say so and stop. That is
the backwards step, it is one deliberate step, and it is the human's to take. It is never a
judgement you make while writing tickets.

## Before the first step

Three things must already exist. Check all three before cutting anything.

| | Where it comes from | If it is missing |
|---|---|---|
| **The smallest version** — one sentence | the map's Notes, written by the kill gate in stage 1 | **Stop.** It is the source of every unit. Without it you will cut from the decisions, which is the one thing this stage must not do. |
| **A closed map** | charting, stage 2 | **Stop.** Constraints are copied out of it, and copying is only safe while one of the two copies cannot change. |
| **A scaffolded repo** | the bootstrap, stage 3 | **Stop.** Tickets written against an empty repo name paths that do not exist. |

**Do not fill a gap by writing the sentence yourself.** A missing smallest version is not an
invitation to summarise the map into one. Say which of the three is missing and stop.

## Talk to the tracker in verbs, never in commands

Cutting never names a tracker and never writes a raw CLI call. It states an intent in the
contract's vocabulary, and the one installed adapter doc at `~/.claude/tracker.md` answers
it. One tracker in context, never four.

The verbs this stage uses: **create · read · edit body · label · mark blocked**, and the
composed **whole graph**. Nothing here branches on which tracker is underneath — where a
tracker lacks a verb natively the adapter fakes it, and you are never told.

## The seven steps

In order. Each one needs something the one before it produced.

| # | Step |
|---|---|
| 1 | Read the smallest version out of the map |
| 2 | Cut the units |
| 3 | Order them, and write each dependency down |
| 4 | Trace every unit to a phrase |
| 5 | **Render the board and stop** |
| 6 | Create every ticket at once |
| 7 | Generate the picture |

### 1 — Read the smallest version out of the map

Read the map. The **Notes** hold one sentence — *"add a habit and tick it off each day, on
my phone."* That sentence is the source of every unit.

Then read the closed decisions the same way, and read them as **constraints**:

| | Says | What you do with it |
|---|---|---|
| **The smallest version** | **What.** | Cut units from it. |
| **The map's decisions** | **How**, and **what not to do**. | Bind units with them. Never cut a unit from one. |

**Decisions do not convert into work.** *"Seam item 4 becomes two branches"* is not something
anyone can build. If you find yourself turning a decision into a ticket, you are cutting from
the wrong artifact — go back to the sentence.

### 2 — Cut the units

> **One unit = one thing the app can now do, all the way through the layers it needs.**

**Plumbing-only units are forbidden.** Plumbing rides inside the first unit that needs it.

| Candidate | Unit? |
|---|---|
| *Add a habit* | **Yes** — a screen, a write, a row. It carries whatever schema it needs. |
| *Tick a habit off for today* | **Yes** — and it needs the one above first. |
| *Set up the SQLite schema* | **No.** Nothing to run at the end. |
| *Wire up navigation* | **No.** Same reason. |

The test is the end of the ticket, not the start: **when this is done, what can the app do
that it could not do before?** If the answer is *"nothing yet, but the next one will be
easier"*, it is not a unit — the two-tier review at the end of `/start-ticket` has no
behaviour to review, and the mistake surfaces two tickets later.

**Do not apply the pipeline's usual size bar** — *touches 2+ files, or needs a decision the
codebase does not encode.* On a day-one repo it returns *yes* to everything: the codebase
encodes nothing, and a stub with one empty folder per layer guarantees the first ticket
touches several. A bar that cannot return *no* is not a bar. The rule above is this stage's
own.

### 3 — Order them, and write each dependency down

Order is a **fact about the work** — *"tick a habit off"* cannot come before *"add a
habit"* — so it is recorded, never implied by position in a list.

> **Each real dependency is a plain line in the unit's body: `needs #6 first`.**
> **That line is the truth.** Everything else is a picture of it.

Only real ones. *Would be nicer to do this first* is not a dependency; **cannot be built
until that exists** is.

The line names **which ticket**, never whether that ticket is finished — open-or-closed is
looked up live, every time. That is why a line in a body is safe here and nowhere else on
this path.

### 4 — Trace every unit to a phrase

> **Every unit points at the phrase in the smallest version it comes from. A unit that
> points at nothing is flagged on the board.**

This is the scope check, and it is a **trace, not a count**. Do not brake on the number of
units — the count *is* the number of things the app can do, which the sentence already pins.

**You do not resolve a flag.** Carry it to the board and let the human choose:

| Choice | What it means |
|---|---|
| **Cut it** | Scope that crept in during charting. It was never in the first version. |
| **Update the sentence** | The first version really did grow — said **out loud**, and changed on purpose. |

Silently keeping a flagged unit is the one option that is not available — to them or to you.

### 5 — Render the board, and stop

Render the whole backlog on screen. **Nothing is written to the tracker yet.**

```markdown
## The backlog — 4 units

Smallest version: "add a habit and tick it off each day, on my phone"

| # | What you can do when it is done | Needs | Traces to |
|---|---|---|---|
| 1 | Add a habit — name it, save it, see it in the list | — | "add a habit" |
| 2 | Tick a habit off for today | 1 | "tick it off each day" |
| 3 | Reopen the app and still see the last few days | 1, 2 | "each day" |
| 4 | Archive a habit without losing its history | 1 | **⚠ nothing** |

**⚠ Unit 4 traces to no phrase.** Cut it, or change the sentence out loud.

Reorder · merge · split · drop · rewrite. Nothing exists in the tracker yet.
```

**The numbers are board positions, not ticket ids.** No ids exist until step 6, and saying
otherwise invites the human to reference a number that will not survive.

> **This is a hard stop, and it is deliberate.** Do not create anything, do not create the
> first one *"to get started"*, and do not treat a nod at the plan as approval of the board.
> Wait for it.

Two reasons, and the second is the one that generalises. Editing a board is free while
editing a dozen filed issues is a dozen edits, a dozen deletions and a re-order. And **the
tracker is a surface you write to only after agreeing what belongs on it** — creating a
dozen issues unattended is the wrong default anywhere, on any tracker, however private.

Loop here as long as the human keeps editing. Re-render the whole board after each change,
including the traces — a merge or a split changes what points at what.

### 6 — Create every ticket at once

On approval, create them all, in one burst, with no further check-ins.

Two rules about *what* you create:

- **Standalone, never children of the map.** Charting's frontier query asks *which children
  of the map are open?*. Work units filed as children turn that query into a list of jobs,
  and a closed map with a dozen open children reads as a map that never finished.
- **In dependency order** — every blocker before the thing it blocks. That way each id a
  body needs already exists when you write it, and no unit needs a second pass to fill in
  its `needs #…` line.

Each ticket carries five things. Board unit 2, once board unit 1 has been created as `#6`:

**Title:** `Tick a habit off for today`

```markdown
Tick today's box on a habit, and see it stay ticked.

needs #6 first

## Constraints

- Storage on device, SQLite. No network calls.
- One screen; no navigation stack.

---
Where this came from
- From map #1 — habit tracker
- Storage on device, SQLite — decision #7
- Single screen — decision #11
```

The dependency line can name `#6` because unit 1 was created first. That is the whole reason
for the rule above.

| | |
|---|---|
| **The title** | the unit, short |
| **What you can do when it is done** | one sentence, first line |
| **The dependency line** | `needs #6 first`, or nothing |
| **The constraints, copied in** | the decisions that bind **this** unit |
| **`Where this came from`, at the bottom** | the map, and which decision each constraint came from |

**Why the constraints are copied rather than linked.** The consumer decides this:
`@ticket-analyzer` is the first agent in the pipeline and it does **no** code and **no**
memory lookups — it reads the ticket and nothing else. A link to decision #7 is a door it
never opens. Copying normally means drift, and here it cannot, because **the map is closed
and frozen before this stage runs** — only one of the two copies can still change. That is
the rule worth carrying: *duplication is dangerous when both copies can change*, not merely
because there are two of them.

**Why the trace section sits at the bottom.** The analyzer parses the top. Everything above
the rule is working content it must act on; `Where this came from` is provenance for a human
reading the ticket six weeks later, and it earns its place by making a copied constraint
**falsifiable** — without it, *"Storage: SQLite"* is either a decision or a typo and nothing
on the page says which.

**One line, `From map #1`, and no parent link.** The history stays recoverable; the map's
tooling still does not see them.

### 7 — Generate the picture

Two representations, both derived from the body lines you just wrote, and neither of them the
truth.

**Record each dependency with *mark blocked*.** One call per `needs #…` line. What the
adapter does with it — a native edge, a fallback — is not your business and you are not told.

Then draw it:

> **Ask for the whole graph over the units you just created, fill the data slot in
> `~/.claude/dependency-graph.html`, write it to `.claude/dependency-graph.html`, ensure
> `.claude/` is in the repo's `.gitignore` **with `!.claude/agents/` and
> `!.claude/skills/` beside it**, and open it — one command, and never on ticket-close.**

The page's own header comment carries the data-slot schema and the two rules that fail
silently. Do not restate them here; read them there.

Four things about a backlog in particular:

- **Name the units when you ask.** *The whole graph* takes two scopings — the children of a
  parent, **or a named set of tickets** — and a backlog has no parent, which is step 6's
  whole point. Ask for the graph over **the ids in hand**. That is the contract's second
  scoping, not a workaround for a gap in it.
- **Ask the tracker even though you already hold every field.** You created these units one
  step ago; a picture drawn from your own notes would cost nothing, and that is exactly why
  it is worth nothing. **A fetch is a read-back.** Drawn from the session's notes the picture
  shows what you *meant* to create; drawn from the tracker it shows what **landed**. Let the
  fourth create of four fail and the remembered picture still draws four boxes while the
  fetched one draws three — a create that silently failed becomes a **missing box rather
  than an invisible one**, in the single artifact you were going to open anyway.
- **It gets the legend only.** The sidebar's *Not yet specified* and *Out of scope* sections
  belong to a map. The page omits them when they are absent — nothing to configure.
- **`blockedBy` comes from the ticket bodies, not from the tracker.** The page consumes a
  list of ticket numbers and does not care who derived them. That is the data slot doing its
  job, and it is what keeps the body the truth.

## Where you stop

Four stops, and none of them is a failure of the stage:

| You stop when | And you say |
|---|---|
| The board is rendered | nothing more. It is the human's turn, however obvious the next edit looks |
| A unit traces to nothing | which unit, and that the choice is cut-it or change-the-sentence |
| One of the three inputs is missing | which one, and which stage has not finished |
| Something genuinely needs deciding | what it is, and that reopening the map is the backwards step and the human's call |

## Stop condition

**The stage is done when the tickets exist, they are ordered, and the human has approved
them.** That is seam **item 6** — the last of the eight to come true, not the eighth — and
the solo path stops there.

Everything after this is the shared pipeline. Do not start the first ticket — hand over to
`/start-ticket` and stop.
