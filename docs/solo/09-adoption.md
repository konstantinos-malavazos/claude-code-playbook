# 09 — Adoption

Adoption is the solo path's **side door**. The [front door](01-the-solo-path.md) is an idea:
you walk through the [kill gate](02-the-kill-gate.md), charting, the bootstrap and cutting,
in that order. The side door is for a project that **already exists** but was not built
that way. A folder, a repo, a prototype that works on your phone and that you now want to
polish and publish to the Play Store.

The stage answers two questions, in order: **is this worth continuing?** and **where does
it enter?** It ends in a **verdict**, **build**, **kill** or **park**, and on build an
**entry point**: back to the kill gate, into charting, or straight into cutting. It
scaffolds nothing. The code is already there.

The stage is **adoption**. The skill is **`/adopt`**. The output is a **verdict** plus an
**entry point**. Kept distinct — a build verdict can still send you back to the gate.

You run it with **`/adopt`**, from
[`templates/skills/adopt/SKILL.md`](../../templates/skills/adopt/SKILL.md). That template
owns the mechanics and this doc does not repeat them. This doc owns *why adoption is shaped
the way it is*. The template owns *how to run it*. The
[`project-surveyor` agent](../../templates/agents/project-surveyor.md) ships alongside it.

> **The code is evidence, not a reason.** A folder you built is a fact about the past.
> It tells you what the project is. It does not tell you whether more hours are worth
> spending on it. Adoption exists to keep those two apart.

---

## Where the side door joins

```
   AN IDEA                            A PROJECT THAT ALREADY EXISTS
      │                               (folder · repo · prototype)
      │                                          │
      ▼                                          ▼
 1. KILL GATE  ◄──── back to /pitch ────  ADOPTION  /adopt
   /pitch             (still an idea)            │
      │                                          ├── kill / park ──► ideas file
      ▼                                          │
 2. CHARTING  ◄───── charting route ─────────────┤  map seeded, OPEN
      │                                          │
      │   map closes ──► Adopted: ? ──► yes ──► /adopt again: SETUP only
      │                     │ no                 │
      ▼                     ▼                    │
 3. BOOTSTRAP  ◄────────────┘                    │
   (scaffold)                                    │
      │                                          │
      ▼                                          │
 4. CUTTING  ◄────── cutting route ──────────────┘  map seeded, CLOSED at once,
      │                                             then SETUP in the same session
      ▼
 THE SEAM ──► /start-ticket, /add-feature
```

Adoption never replaces a stage. It decides **which stage the project should have been
standing in**, does the work that stage's predecessors would have left behind, and hands
over. Past [the seam](01-the-solo-path.md#the-seam--where-the-solo-path-stops), new work on
the product goes through [the feature gate](10-the-feature-gate.md) instead.

---

## What you arrive with

| | What it means here |
|---|---|
| **A folder, maybe a repo** | Code you or someone else wrote. Possibly issues on a tracker. Adoption **creates nothing that exists**. A bare folder gets a private repo, confirmed with you, only on a charting or cutting verdict. |
| **Possibly an entry in the ideas file** | Usually **unjudged**. A prototype is often an idea that never went through the gate. |
| **A feeling about it** | The thing this stage is built to keep out of the verdict. |
| **No map, no `CLAUDE.md` of the playbook's shape** | Nothing that says where on the path this project sits. Adoption re-derives it. |

---

## Serena first, then a cold survey

**Serena indexes before anything reads code.** The survey is the stage's only source of
facts about the folder, and the survey reads through Serena. Indexing after the survey would
mean the survey read the code blind, and every fact it reported would be one you cannot
check by asking *who calls this?* If Serena does not index the language — GDScript is the
usual one — that is code-access escape 1, *language not indexed*, and the survey says so in
its brief. **There is no quiet grep fallback.** A brief that names its own blind spot is
worth more than one that hides it.

**The surveyor runs cold.** It is given the folder and nothing about how you feel about the
project. This is the same argument the kill gate makes for its cold search agents, with more
force: the gate fights enthusiasm for an idea; here there is also a folder you built, and
every way you describe it carries weight. *"Most of it already works"* is the sentence a
warm agent would echo back. A surveyor that never heard it reports **how finished** the code
is — stub, prototype, shipped — and **which seam checks fail**, and nothing else.

**The brief has fixed sections**, so the rest of the stage can read it the same way every
time. Stack and layer chain become map tickets. *How finished* and *Seam gaps* reach the
judge verbatim. *Open issues* becomes one question.

**The interview does not wait for it.** Questions that need survey facts wait. The rest are
asked while it reads. That is what keeps adoption inside an hour.

---

## Why the questions are not `/pitch`'s

The skeleton is the kill gate's: question zero first, one question at a time, hard kills
applied mechanically, the case for killing written every time, the same anonymised
[`pitch-judge`](../../templates/agents/pitch-judge.md). The questions themselves change,
because a prototype has already done part of the gate's job, and brought a new bias with it.

| # | Question | Why it differs from `/pitch` |
|---|---|---|
| 0 | **What does the value rest on?** — novelty, execution, or the building itself | It does not. Asked first, for the same reason: classify after the search and novelty quietly becomes execution. |
| 1 | **What did the prototype actually teach you?** | Replaces *the smallest first version*. The prototype **was** a first version. The live question is what it proved — and then the **first version from here**, the next thing that would teach you something. *"It seems nice"* is a feeling, not evidence. |
| 2 | **What is the destination, and who is it for?** | Replaces *who is it for*. A prototype has a direction already: *"polished, on the Play Store, for me and my kids."* |
| 3 | **What is the hard part now?** | The hard part has usually **moved** — from *can I build it* to the store, the polish, the devices. A cold `/research` subagent checks it, as at the gate. |
| 4 | **What does it cost you if you never finish?** | Informs, never kills, as at the gate. Here it is also the honest version of the pull you feel — a fact about the future. |
| 5 | **Bring these onto the map?** — the open issues the survey flagged as decisions | New. Only an existing repo has issues. One question, not one per issue. |

### Sunk cost is the bias

The kill gate's enemy is enthusiasm. Adoption has that one, plus a heavier one: **hours
already spent feel like a reason to spend more.** They are not. So:

| Rule | Why |
|---|---|
| **The work done never counts as a reason to continue** | Not in the agent's case, not in its verdict. |
| **Question 4 asks about the future only** | What never finishing would cost you is a fact. What starting cost you is not. |
| **Sunk cost is stripped from the case file** | *"Three months in"*, *"it would be a shame"* — none of it reaches the judge. The judge's whole value is that it cannot be leaned on. |

**The code still counts — as evidence of what the project is.** A small prototype that taught
you something is a strong case. A big one that taught you nothing is not, however big.

### The hard kills, adapted

| Hard kill | Applies to |
|---|---|
| **The prototype taught nothing, and no first version from here can be named** | every class |
| **It already exists and it is good** | novelty only |
| **The hard part is the whole project** | novelty and execution |

The first is the gate's *no first version* kill, reshaped for a project that already had
one. **"The stack cannot reach the destination" is not a kill.** A Flutter prototype that
has to become a console game has a stack decision still open. That is the charting route,
with the stack ticket left open. A rebuild is charting, not a way round it.

---

## Three entry points, not the bootstrap

The obvious design is to send every adopted project to the bootstrap. It fails twice. The
bootstrap **scaffolds**, and there is code it must not touch. And the bootstrap assumes a
**cleared map**, when an adopted project can be at any level of fog — from *still just an
idea* to *every decision already made in the code*.

So the verdict picks where the project enters, and **fog decides, never size**:

| Entry point | When | Why it is this one |
|---|---|---|
| **Back to `/pitch`** | nothing in the folder shows the idea works yet | It is still an idea. The gate's questions fit better than adoption's, and the folder becomes reference material. Adoption writes an **unjudged** ideas-file entry naming the folder and the survey brief — and makes no map and no repo, so the gate starts clean. |
| **[Charting](03-charting.md)** | the destination is clear, the route is foggy — or the stack cannot reach it | Open decisions are charting's job. The decisions the code already made are recorded as **closed** tickets, so charting does not re-ask them. |
| **[Cutting](05-cutting.md)** | destination and route both clear | Nothing is left to decide. Setup runs straight after the verdict, then cutting. |

**Cutting is only clear when the code closes the tail.** The stack, chain and Serena verdict
read off the survey, and build/test/run commands the survey found working. Either one open
is fog, and fog is charting.

---

## The map is always created

Even on the cutting route, where there is nothing left to chart. **[Cutting](05-cutting.md)
needs a closed map** with the first-version sentence in its Notes, because it cuts its work
units from that sentence and traces every one back to it. A map opened and closed in the same
hour is the cheap way to give it both. Skipping it would mean teaching cutting a second
input shape for one entry point.

**It takes the next free issue number.** A pitch-born repo's map is #1 because the repo is
new. An adopted repo may already hold dozens of issues, so its map rarely is. Charting finds
the map **by its label**, never by number, which is what lets this work at all.

**The issues you do not bring stay untouched.** No comment, no label, no close. They lack the
`From map #N` line, so no tell counts them as work units and nothing downstream is confused
by them.

---

## Setup waits for the map

Setup is the bootstrap's steps without the scaffolding: the allowlist questions, `CLAUDE.md`,
the layer specialists and stack skills, the adapter check, the two memories, every seam check,
one report. See [04-the-bootstrap.md](04-the-bootstrap.md) for why those steps run in that
order. **It never touches a line of existing code.**

| Route | When setup runs | Why |
|---|---|---|
| **Cutting** | straight after the verdict, in the same session | The map closed at once. Everything `CLAUDE.md` needs is already settled. |
| **Charting** | on a later run of `/adopt`, after charting closes the map | **The map can still change the stack.** A `CLAUDE.md` written now would record a stack, a chain and commands that charting may overturn — and the specialists generated from it would be wrong with it. |

On the cutting route adoption also writes memory one — *what this project is and who it is
for* — because charting, which normally writes it, never ran.

### The `Adopted:` marker and the handover

The map's Notes carry one line: `Adopted: <survey brief path>`. It is a fact about **origin**,
not a stored stage. Nothing records where adoption stopped; the stage is re-derived from tells
that other stages already read for their own reasons — map open or closed, `CLAUDE.md` present
or not, a setup commit, an open handover task.

The marker matters at one moment. **When charting closes a map, it reads the Notes.** A
pitch-born map hands over to the bootstrap with the task *Run /bootstrap (fresh session)*.
An adopted map must not, because the bootstrap scaffolds. So charting opens **Run /adopt
(fresh session)** instead. Running `/adopt` again, it finds the map closed, the `Adopted:`
line, and no `CLAUDE.md` of its shape — and does only the setup. On green it closes that task
and proposes **Run /cut-backlog (fresh session)**, exactly as the bootstrap does.

**Fresh session, both times.** Setup must not inherit the gate's conversation, and cutting
re-reads the whole map.

---

## How adoption relates to `/pitch` and `/add-feature`

| You have | Run | Why not the others |
|---|---|---|
| **An idea, no folder** | [`/pitch`](02-the-kill-gate.md) | Nothing to survey. |
| **A project with real code you want to continue** | `/adopt` | `/pitch` would ignore the evidence in the folder; `/add-feature` assumes the project already passes the seam. |
| **One feature on a product past the seam** | [`/add-feature`](10-the-feature-gate.md) | The project is already on the path. Adoption would re-judge the whole product to decide one feature. |

The doors connect in both directions. **Adoption can send a project back to `/pitch`** when
the folder proves nothing yet — and a folder sent back that way is in the gate's scope.
**`/add-feature` points at `/adopt`** when the seam checks fail with no open map, and
**reroutes** to it when a feature is off the product's destination, because choosing a new
destination is adoption's job.

---

## Why this doc exists

The [spine](01-the-solo-path.md) describes a path that starts from an idea. The
[`/adopt` template](../../templates/skills/adopt/SKILL.md) says how to take over a project
that did not. Neither answers the questions a reader has while standing at the side door:

- **Why the code reaches the verdict only as a survey.** Serena first, a cold surveyor, fixed
  brief sections — so what the folder *is* gets in and how you feel about it does not.
- **Why the questions change.** The prototype already answered the gate's *smallest first
  version*; what it taught, and the first version from here, is the live question.
- **Why sunk cost is the named bias**, and stripped from the case file.
- **Why there are three entry points, not one.** Fog decides where a project enters, and the
  bootstrap would scaffold over code.
- **Why the map always exists, and why setup waits for it.** Cutting needs a closed map; a
  charting map can still change the stack.

Read [02-the-kill-gate.md](02-the-kill-gate.md) first — adoption borrows its honesty
mechanisms whole. Then [03-charting.md](03-charting.md) or [05-cutting.md](05-cutting.md),
whichever your verdict sends you to.

---
> **Last verified against:** Claude Code `2.1.226` — August 2026
