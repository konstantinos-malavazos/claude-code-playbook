# Example — the solo path, end to end

A sanitized walkthrough of the [solo path](../docs/solo/01-the-solo-path.md), so you can
see the shape of it before you run it. Two ideas go into the kill gate. One of them comes
out the other end as a backlog. The idea, the stack and the names are invented. Substitute
your own.

Each stage has its own doc and this page repeats none of them. Instead it shows what no
single stage doc can: what gets carried across each boundary, and where the path stops.

---

## Stage 1 — the kill gate

### The first idea, which does not survive

**You type:**
```
/pitch
```
> *"A browser extension that strips tracking junk out of any URL you copy."*

| | |
|---|---|
| **Q0 — what does the value rest on?** | **Novelty.** You believe nobody has done this properly. Answered before any searching, which is the point. |
| **Q1 — what is it, who is it for?** | A copy-button replacement. Just you. |
| **Q2 — does it already exist?** | A cold `/research` subagent goes and looks. It comes back with ClearURLs: open source, actively maintained, does the whole job, free. |

The class was novelty, so [hard kill 2](../docs/solo/02-the-kill-gate.md#the-three-hard-kills)
is armed: *it already exists and it is good*. Q2's answer fires it. That is what *hard*
means. Nothing that questions 3 to 5 can say gets weighed against it, and neither your
enthusiasm nor `pitch-judge` can argue it back.

One sitting. No repo, no map, no weekend. The ideas file gets a `killed` entry naming the
rule and the reason. In a year you can read why past-you said no, instead of having the
idea again from scratch.

> Had the class been the building itself, the same search result would have killed
> nothing. That is question zero doing its work.

### The second idea, which does

**You type:**
```
/pitch
```
> *"Something that looks at what's already in my kitchen and tells me only what I need to buy."*

| | |
|---|---|
| **Q0 — value rests on** | **Execution.** Meal planners exist. This one starts from the cupboard instead of from the recipe. |
| **Q1 — what, who** | A page on the laptop, for you and your partner, once a week. |
| **Q2 — does it exist?** | Cold subagent. Because the class is execution, the brief asks for *what exists and what is good about it* rather than a verdict. It comes back with three mature apps, and all of them assume you are buying every ingredient. |
| **Q3 — the smallest version** | You start with "a weekly meal planner". The agent pushes on size twice. You land on: **"pick five dinners for the week from recipes I've saved, and tell me what I have to buy."** |
| **Q4 — the hard part** | Cold subagent. The hard part is matching free-text pantry lines to recipe ingredients. *Passata*, *chopped tomatoes* and *tinned tomatoes* are one thing on the shelf and three strings on the page. Unsolved in general, but small in one household. |
| **Q5 — what it costs you never to build it** | A mildly annoying Sunday, forever. This informs and never kills. |

Hard kill 3 is armed for this class: *the hard part is the whole project*. It is considered
and it does not fire, because the search already named a cheap way to find out whether it is
tractable here. That is the judgement the gate exists to make, and the gate makes it out
loud.

The agent then writes **the case for killing**: the strongest one it can, for an idea it is
about to approve. It commits to its own verdict in writing, and only then asks for yours.
Both say build. `pitch-judge` reads the anonymised case file, with the two verdicts labelled
1 and 2 in random order, and returns build as well.

**Verdict: build.** The agent confirms the repo name with you, creates
`pantry-plan` **private**, seeds the map as issue #1, and writes the `built` line into
`~/Dropbox/notes/ideas.md`. Then it stops. Charting is the next session, not the rest of
this one.

### What stage 1 hands over

Issue #1 arrives filled in, not empty:

```markdown
## Destination
A backlog of work units on a scaffolded repo that passes the seam.

## Notes
A weekly dinner planner that starts from what is already in the kitchen.
For me and my partner, once a week, on a laptop.
Class: execution.
SMALLEST VERSION: pick five dinners for the week from recipes I've saved,
and tell me what I have to buy.

## Decisions so far
## Not yet specified
## Out of scope
- Deployment, hosting, CI, release.
```

Plus issue #2, the hard part, typed `research`. The gate phrased it sharply enough to be a
ticket rather than fog, and `research` runs unattended, so charting has work in flight
from its first session.

---

## Stage 2 — charting

Eight sessions over three weeks, one ticket each. The map is issue #1. Its tickets are its
children.

| Session | Ticket | What came out |
|---|---|---|
| 1 | **#2 — how do we match a pantry line to an ingredient?** (`research`) | A hand-written alias table does the job. It covers the ~60 things this kitchen actually holds. Embeddings were rejected: you cannot evaluate them without a test set nobody is going to build. Fog thins into two new tickets. |
| 2 | **#3 — where do recipes come from?** (`grilling`) | You type them in. No scraping, no import. *Importing from recipe sites* moves to **Out of scope**. It never graduates. |
| 3 | **#4 — what happens when a pantry line matches nothing?** (`grilling`) | The app shows the line beside the shopping list, and you teach it the alias there. **The app never guesses silently.** The word **alias** is settled here. It goes into the map's `Notes`. |
| 4 | **#5 — what does the week actually look like?** (`prototype`) | Three rough takes on one screen, and you react to them. One page: five rows, shopping list underneath, no calendar. |
| 5–6 | two smaller decisions | Then the map stops growing. The frontier empties, and nothing is left open. That is what separates *cleared* from [*stalled*](../docs/solo/03-charting.md#three-endings). |
| 7–8 | **the tail**, below | |

The map **grew** for the first three sessions. That is
[fog thinning](../docs/solo/03-charting.md#fog-of-war), not scope creep.

### The tail, last, with nothing else open

Two tickets, in order. Neither was takeable while any other ticket on the map was open
([why](../docs/solo/03-charting.md#the-tail)):

**Ticket 1 — name the stack** *(decision)*. One candidate is proposed and three checks try
to kill it: Python + FastAPI + SQLite, server-rendered HTML. No product decision rules it
out. Serena applies: there is a mature language server, and once the alias table has three
readers you *will* ask who calls this. You read Python fluently. Nothing kills it, so the
session ends there and [no comparison is run](../docs/solo/06-choosing-the-stack.md). The
same ticket names the layer chain, `storage → planner → web`, and answers the third thing
it owns: do tests gate? Here, no. `pytest` exits **5** on a repo with no tests, which is
neither a pass nor a failure, so gating on it means special-casing a number on day one.
That is a fact about Python, not a preference.

**Ticket 2 — write the bootstrap checks** *(make)*. It is written blind, against a repo that
does not exist yet. It writes down whatever ticket 1 decided:

```
build/run   python -m pantry_plan  → serves a page on :8000
tests       (none — ticket 1 said this stack does not gate on day one)
serena      find_symbol PantryLine → returns a real result, not empty
```

The map closes. **One memory** is written: *what this project is and why.*

### What stage 2 hands to the bootstrap

| | Where it is |
|---|---|
| **A cleared map** | Issue #1, closed. Every decision recoverable from its own ticket. |
| **The stack, and the chain** | Tail ticket 1's resolution comment. |
| **The Serena verdict: yes** | Same ticket. Decided by *will you ever need to ask who calls this?* |
| **The bootstrap checks** | Tail ticket 2. The first place they can run is stage 3. |
| **The settled name: `alias`** | The map's `Notes`. |
| **One memory** | *What this project is and why.* Stage 3 writes the second. |

Nothing is in anyone's head. Serena is not indexed, and that is correct, because the repo
is three weeks old and still empty.

---

## Stage 3 — the bootstrap

**You type:**
```
/bootstrap
```

**Step 1 is the only part that is yours.** Two questions, both about this repo, both
defaulting to no: may the agent push here (yes), and is this repo's `CLAUDE.md` its own
(yes). One line goes into `~/.claude/repo-allowlist`. Everything after this runs unattended,
which is why step 1 comes first rather than in the middle.

| Step | What it leaves behind |
|---|---|
| 2 — scaffold the stub | FastAPI's skeleton, plus `storage/`, `planner/`, `web/`. They are empty, because step 5 is about to write an agent file that names each path |
| 3 — write `CLAUDE.md` | stack · build/test/run commands · the main branch (detected, not asked) · the chain · Serena verdict: yes · settled names: `alias` |
| 4 — index Serena | the index, and a symbol query that comes back with real results |
| 5 — `/adapt-to-stack` | three specialists and three standards skills in the repo's own `.claude/`, created and never overwritten |
| 6 — verify the tracker adapter | **nothing.** It only reads. Free to redo |
| 7 — write memory two | *why this stack, why this chain, what was ruled out* — and **not** the stack or the chain themselves, which `CLAUDE.md` already carries |
| 8 — run every check, report once, stop | the report |

### The report, first run

```markdown
## Bootstrap report — pantry-plan

| # | Seam check | Result | Evidence |
|---|---|---|---|
| 1 | The stack is named | pass | CLAUDE.md:7 |
| 2 | The stub builds and runs | FAIL | `python -m pantry_plan` → No module named pantry_plan |
| 3 | The layer chain and the settled names are declared | pass | CLAUDE.md:12-19; `alias` matched against the map's Notes |
| 4 | Serena matches the verdict | pass | find_symbol PantryLine → 1 result |
| 5 | The tracker adapter matches this project | pass | github.md installed |
| 7 | Two memories exist | pass | "what pantry-plan is"; "why FastAPI + SQLite" |
| 8 | The layer specialists exist | pass | .claude/agents/{storage,planner,web}-specialist.md |

6 of 7 pass.
```

It classifies nothing, and that is deliberate. The classification is the most expensive
judgement on this path, and it is yours. Here it is easy, because you can see all seven at
once: one red is a typo. The tail wrote `python -m pantry_plan` and the generator laid the
package out as `src/pantry_plan`. You fix the check in place. Not a backwards step. Four
reds would have been.

Re-run: 7 of 7. Then one commit, with explicit paths. `git add -A` stays blocked whatever
step 1 answered.

> Item 6 — *the backlog exists* — is missing from the report on purpose. It is stage 4's,
> and this stage cannot speak to it.

### What the bootstrap hands to cutting

Less than the pile suggests, and that is the interesting part:

| What stage 3 produced | Does stage 4 read it? |
|---|---|
| `storage/`, `planner/`, `web/` on disk | **Yes.** Tickets name paths, and until now there were none to name. |
| One green report, seven of seven | **Yes**, as *what is left*. Item 6 is the only seam check still open, and it is this stage's. |
| `CLAUDE.md`, the specialists, the two memories, the commit | **No.** They are for `/start-ticket`, on the far side of the seam. |
| The constraints that go into every ticket | **No.** Those come from the closed map, three weeks upstream, not from anything the bootstrap wrote. |

---

## Stage 4 — cutting

**You type:**
```
/cut-backlog
```

It reads the smallest version out of the map's `Notes`. That is the sentence the gate wrote
three stages ago, not the pile of decisions you have been accumulating since. Then it
renders a board and stops.

```markdown
## The backlog — 4 units

| # | What you can do when it is done | Needs | Traces to |
|---|---|---|---|
| 1 | Type in a recipe and see it in your list | — | "recipes I've saved" |
| 2 | Type what's in the kitchen and see what's missing for one recipe | 1 | "what's already in my kitchen" |
| 3 | Pick five dinners and get one shopping list | 1, 2 | "pick five dinners for the week" |
| 4 | Teach the app a new alias from the unmatched list | 2 | ⚠ nothing |
```

Unit 4 is real work, and it is flagged. It traces to a *decision* (#4, the app never
guesses silently) and not to a phrase in the sentence. You have two choices, and silently
keeping it is not one of them: cut it, or change the smallest version out loud. You cut it.
It is a good second-version feature, and it was never in the first.

The [trace check](../docs/solo/05-cutting.md#the-scope-check-is-a-trace-not-a-count) named
the ticket. A count would only have told you the number was fine.

You approve three units. **All three tickets are created at once**. Nothing was in the
tracker until you said so. Each carries its dependency in the body, its constraints copied
in, and its origin at the bottom:

```markdown
Type what's in the kitchen and see what's missing for one recipe

needs #10 first

## Constraints
- Pantry lines are free text. Matching goes through the alias table.
- A line that matches nothing is shown, never guessed at.
- SQLite, on this machine.

---
Where this came from
- From map #1 — pantry-plan
- Alias table over ~60 items — decision #2
- Never guess silently — decision #4
```

The constraints are **copied, not linked**, because `@ticket-analyzer` reads the ticket and
nothing else. That is safe here and nowhere else: the map is closed and frozen, so only one
of the two copies can still change.

---

## The seam — all eight, on a real repo

| # | Check | What made it true |
|---|---|---|
| 1 | The stack is named | Tail ticket 1 → `CLAUDE.md:7` |
| 2 | The stub builds and runs | `python -m src.pantry_plan` serves a page. There is no test check, because item 2 makes one optional and the tail said this stack does not gate on one |
| 3 | The layer chain and the settled names are declared | `CLAUDE.md`; `alias` matched against the map's `Notes` |
| 4 | Serena matches the verdict | Verdict **yes**, index built, `find_symbol` returns results |
| 5 | The tracker adapter is installed | One adapter, from setup. Verified here, never installed here |
| 6 | The backlog exists | Three units, ordered, **and you approved them** |
| 7 | Two memories exist | *What pantry-plan is*, from charting. *Why this stack*, from the bootstrap |
| 8 | The layer specialists exist | Three agent files, generated by `/adapt-to-stack` at step 5 |

**The solo path stops here.** The next thing you type is `/start-ticket #10`, and from that
point on nothing is solo-specific.

---

### What to notice

- **The gate ran twice and produced one repo.** The sitting it spent killing the first idea
  is the cheapest hour anywhere on this path. Every stage after it is measured in weeks.
- **The hard part was burned off in stage 2**, as a `research` ticket, before the repo was
  scaffolded. It never arrives at `/start-ticket` as a spike, which is why the pipeline's
  no-spikes rule and the gate's *find the hard part* do not collide.
- **Every handoff is something you can go and read** — a ticket, a resolution comment, a
  file on disk. Nothing is carried between stages in your head, and nothing records *which
  stage you are in*. You [look at the repo](../docs/solo/01-the-solo-path.md#which-stage-are-you-standing-in).
- **The red check was legible only because all seven ran.** One red reads as a typo. Four
  would have read as a wrong stack, and that is a different stage.
- **Unit 4 was cut even though it was real work.** The trace check names *which* ticket
  drifted, and a ticket count never can.
- **Stage 2 was the long one.** Eight sessions of deciding, then one sitting each for
  stages 3 and 4. The path is front-loaded on purpose.
