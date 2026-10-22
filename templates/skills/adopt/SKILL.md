---
name: adopt
description: >-
  Take over a project that already exists but was not built through the solo path — a
  folder, a repo, or a prototype — and come out with a verdict and an entry point. Serena
  first, a cold survey of the code, gate questions asked one at a time, the same hard kills
  and anonymised judge as the kill gate, then the project enters at /pitch, charting or
  cutting, with the map seeded and the setup done. Use when the user says "I have a
  prototype" / "continue this project" / "take over this repo" / "I already started building
  this". NOT for a raw idea with no folder (that is /pitch), NOT for one feature on a product
  already past the seam (that is /add-feature), and NOT for a ticket someone wrote (that is
  /start-ticket).
---

# Adopt — the code is evidence, not a reason

The folder exists. That is a fact about the past, not an argument for the future.

This is **adoption**: the solo path's way in for a project that started somewhere else. It
answers two questions in order — *is this worth continuing?* and *where does it enter?* — and
ends in a **verdict**, **build**, **kill** or **park**, plus, on build, an **entry point**.
It scaffolds nothing. Code exists.

> The stage is **adoption**. The skill is **`/adopt`**. The output is a **verdict** plus an
> **entry point**. Never merged.

What it is for, and where it sits on the path, is
[09-adoption.md](../../../docs/solo/09-adoption.md). Where the path ends is
[the seam](../../../docs/solo/01-the-solo-path.md#the-seam--where-the-solo-path-stops).

## Which run is this?

**Read the tells first.** Nothing records where adoption stopped; you re-derive it.

| You find | This run is | Do |
|---|---|---|
| No map carrying an `Adopted:` line for this folder | **the first run** | everything below, from *Before the first question* |
| A map labelled `<LABEL-PREFIX>:map`, **open**, its Notes carrying `Adopted:` | charting is not finished | nothing. Point at `/charting` with that map's id, and stop |
| That map **closed**, `Adopted:` in its Notes, and **no `CLAUDE.md`** — or one with no Serena verdict line, which a prototype's own will not have | **the setup run** | only [Setup](#setup--no-scaffolding), then the handover |
| That map closed, `Adopted:` in its Notes, a setup commit, and an open *Run /cut-backlog (fresh session)* task | adoption is finished | nothing. Point at `/cut-backlog`, and stop |

The `Adopted:` line is a fact about **origin**, not a stored stage. Every tell above is
something charting, the bootstrap and cutting already read for their own reasons.

## Before the first question

Three things, in this order.

**1. Read the ideas file.** Exactly as [`/pitch`](../pitch/SKILL.md) does: the path the user
already gave, or ask once. The project may already be in there, and the same table applies —
killed raises the burden, parked checks the trigger, built points at the repo. A prototype is
often an idea that never went through the gate, so **unjudged** is the common case.

**2. Index the folder in Serena.** Register the project and start its server
(`serena-up`) before anything reads code. If Serena does not index the language — GDScript
is the usual one — that is code-access escape 1, *language not indexed*, and the survey
names it in its brief. **There is no other grep fallback.**

**3. Dispatch `@project-surveyor` cold.** State its role in one line as you dispatch: *a
surveyor reading this folder for what it is, with no stake in what it becomes.* Give it the
folder and nothing about how the user feels about the project. It writes the **survey brief**
to `<workspace>/.claude/handoffs/adopt-<project>/survey.md` — named after the project,
because no ticket exists yet. Its sections are fixed: Stack · Likely layer chain ·
Build/test/run commands as found · How finished (stub / prototype / shipped) · Seam gaps
(which of the eight checks fail) · Open issues on the tracker (number, title, looks like a
decision or work) · Escapes used. The template is
[`project-surveyor.md`](../../agents/project-surveyor.md).

**The interview carries on while it reads, so you own checking on it** — at each multiple of
the expectation you stated when you dispatched. A survey that never came back is not a brief
that found nothing. The entry point is read off it.

## The gate questions

**One at a time. Wait for each answer.** Post the whole numbered list first, then ask in the
[`grilling`](../grilling/SKILL.md) rhythm and its question format. Do not answer any of the
human-owned ones yourself.

| # | Question | Who answers | Waits for |
|---|---|---|---|
| 0 | **What does this project's value rest on?** — novelty, execution, or the building itself | human | nothing. Asked first |
| 1 | **What did the prototype actually teach you?** | human | nothing |
| 2 | **What is the destination, and who is it for?** — *"polished, on the Play Store, for me and my kids"* | human | nothing |
| 3 | **What is the hard part now?** | human names it; a cold `/research` subagent checks whether anyone has solved it | the survey's *How finished* and *Seam gaps* sharpen it |
| 4 | **What does it cost you if you never finish?** | human | nothing |
| 5 | **Bring these onto the map?** — the open tracker issues the survey flagged as decisions, listed by number and title | human | **the survey** |

**Questions that need survey facts wait for the survey.** The others do not, and asking
them while it reads is what keeps the gate inside an hour.

**On question 1, push once, properly.** *"It seems nice"* is a feeling, not evidence. Ask what
it showed that they did not know before they built it. Then ask for the next version that
would teach them the next thing — **the first version from here**. That sentence goes on the
map's Notes, and cutting cuts from it.

**Question 2 replaces the kill gate's "who is it for".** "Just me" is a complete answer. The
destination is where the user wants the product to end up; the map's own destination stays
the solo path's, the seam.

**Question 3's hard part has often moved** — from *can I build it* to the store, the polish,
the devices. Brief the `/research` subagent with the question, the class-appropriate brief
from [`/pitch`](../pitch/SKILL.md#question-zero-governs-everything-after-it), and nothing
else. Same rule for **novelty**: dispatch a second cold `/research` subagent right after
question zero, on *does this already exist, and is it good?* — kill 2 needs its evidence.
State each one's role in one line as you dispatch; that line plus the named skill is the
whole persona.

**Question 4 informs and never kills.** It is the question this gate weighs against sunk
cost, below.

## Sunk cost — the bias this gate exists to fight

**Hours already spent are not evidence that more hours are worth spending.** The kill gate
fights enthusiasm; adoption fights that, plus the weight of a folder the user built.

- **Do not count the work done as a reason to continue.** Not in your case, not in your
  verdict, not in the case file.
- **Question 4 is the honest version of the pull.** What never finishing costs them going
  forward is a fact about the future. What starting cost them is not.
- **Strip it from the case file.** *"Three months in"*, *"most of it already works"*, *"it would
  be a shame"* — none of it reaches the judge.

The code still counts — as **evidence of what the project is**, through the survey brief. A
working prototype that taught something is a strong case. A big one that taught nothing is
not, however big.

## Question zero governs the kills

Asked first, before the survey returns and before any search, for the reason `/pitch` gives:
classify afterwards and a novelty project quietly becomes an execution one the moment
something similar turns up. The arming table is `/pitch`'s, unchanged.

| Class | Armed |
|---|---|
| **Novelty** | all three |
| **Execution** | 1 and 3 |
| **The building itself** | 1 only |

## The hard kills

Applied **mechanically** — not weighed, not scored, never balanced against how much the user
wants to finish.

| # | Hard kill | Fires when | Armed for |
|---|---|---|---|
| 1 | **The prototype taught nothing, and no first version can be named** | after real pushback on question 1, they cannot say what it showed them *and* cannot name the next version that would teach them whether this works | every class |
| 2 | **It already exists and it is good** | the claim was novelty, and the existence search found the thing, and it is good | novelty only |
| 3 | **The hard part is the whole project** | the unknown *is* the project, nobody has solved it, and there is no cheap way to find out | novelty, execution |

**When one fires, say so plainly and stop weighing.** Record it and go to the verdict. A
hard kill that has fired cannot be un-fired — by you, by the user, or by the judge.

> **"The stack cannot reach the destination" is not a kill.** A Flutter prototype that has to
> become a console game is a project with a stack decision still open. It enters at
> **charting**, with the *Name the stack* ticket left **open**. A rebuild is charting, not a
> route around it.

## The open issues

Question 5 is one question, not one per issue. List the issues the survey flagged as
decisions, by number and title, and ask which to bring.

| Answer | What you do |
|---|---|
| **Brought** | each becomes a ticket on the map, typed as charting types it, its body linking the original. A brought decision is an open decision, so the route is charting |
| **Not brought** | leave it untouched. No comment, no label, no close |

**The issues you leave alone confuse no tell.** They lack the `From map #N` line, so cutting
and the past-the-seam tell never count them as work units. Issues the survey called *work*
are not asked about: cutting cuts its own units from the first version.

## The verdict

The **order of operations is `/pitch`'s**, and so is the reveal: write **the case for
killing**, every time; commit to **your** verdict in writing; only then ask for the user's.

**Then dispatch [`@pitch-judge`](../../agents/pitch-judge.md)** — the same anonymised third
party, once, automatically, never on demand. It weighs a case file and gathers nothing, which
fits adoption unchanged. Build the case file exactly as `/pitch` describes, with these
sections in place of its question answers and search reports:

```markdown
## The project
<one paragraph — what it is, where it wants to end up, who it is for>

## Class
<novelty | execution | the building itself>

## The questions, answered
1. What the prototype taught — <the settled answer>
   The first version from here — <the settled answer>
2. The destination — <the settled answer>
4. What it costs if never finished — <the settled answer>

## Survey report: what the folder holds
<the brief's Stack, How finished and Seam gaps sections, verbatim>

## Search report: what is the hard part?
<the subagent's findings, verbatim>

## Search report: does it already exist?          ← novelty only
<the subagent's findings, verbatim>

## Verdict 1
## Verdict 2
```

Every `/pitch` rule for building it holds: **no dialogue, no attribution, verbatim reports,
randomise which verdict is 1** — plus one more: **no sunk cost**. Nothing that says how long
it took or how much exists.

**Resolve it by `/pitch`'s table**, in its order: any hard kill → kill; agreement → that
verdict unless the judge dissents to kill; disagreement → the judge breaks the tie; park
needs **a trigger, a thing that ends** — no trigger means kill.

## The three entry points

On **build**, the survey brief and the answers decide where the project enters. Fog decides,
never size.

| Entry point | When | What you do |
|---|---|---|
| **Back to `/pitch`** | nothing in the folder shows the idea works yet — it is still an idea | no map, no repo, no setup. Write the ideas-file entry as **unjudged**, naming the folder and the survey brief. The folder becomes the gate's reference material, not its repo |
| **Charting** | the destination is clear and the route is foggy — or the stack cannot reach it | [seed the map](#the-map) with the decisions the code already made as **closed** tickets, and the fog open. Setup waits until the map clears |
| **Cutting** | destination and route both clear | seed the map, **close it at once**, then run [setup](#setup--no-scaffolding) straight after the verdict |

**Cutting still gets a map.** `/cut-backlog` needs a closed map and the first-version sentence
in its Notes. A map closed the hour it opened is the cheap way to give it both.

**Cutting is only clear when both tail tickets close from the code**: the stack, chain and
Serena verdict read off the survey, and build/test/run commands the survey found working. Either
one open is fog, and the route is charting.

## Creating the repo — only if none exists

**Adoption creates nothing that exists.** A folder that is already a repo on the tracker keeps
its repo, its history and its issues.

A bare local folder, on a charting or cutting verdict, needs one: **confirm the name with the
user** — ask, do not announce — then **create it private**, through the tracker adapter's
verbs, never a raw CLI call. Pushing the folder's history to it is a push, so
`~/.claude/repo-allowlist` decides; ask, as bootstrap step 1 does.

## The map

One issue labelled `<LABEL-PREFIX>:map`, shaped as [charting](../charting/SKILL.md#the-map)
shapes it. **It takes the next free issue number.** An adopted repo may already hold issues,
so it is rarely #1. Charting finds it by label, never by number.

| Section | What you write |
|---|---|
| **Destination** | Fixed on this path: *a backlog of work units on a scaffolded repo that passes the seam.* Charting never asks |
| **Notes** | What it is and who it is for, the class, the user's destination, **the first version from here**, and one line `Adopted: <survey brief path>` |
| **Decisions so far** | Generated, as charting generates it — from the closed children below |
| **Not yet specified** | Fog too vague to phrase as a question |
| **Out of scope** | Deployment, hosting, CI, release — the user's destination is the direction, not this map's end |

**The decisions the code already made become closed child tickets** — created, then closed at
once, each with a resolution comment that cites the survey's evidence. The stack is the
first: **Name the stack** closes from the code with the stack, the layer chain, the test gate
and the Serena verdict. **Write the bootstrap checks** closes with the commands as found.
Either one the code cannot settle stays **open**, and that is the charting route.

**Brought issues become open tickets on it**, linking their originals. **The hard part**, if
it is phrased sharply, becomes a `research` ticket, as it does on a pitch-born map.

**On the cutting route, close the map now**, with no handover task: setup runs next, in this
session. **On the charting route, leave it open and stop.** When charting closes a map whose
Notes carry `Adopted:`, it opens the task **Run /adopt (fresh session)** instead of
**Run /bootstrap (fresh session)**, and the next run of `/adopt` reads the tells and does only
the setup.

Then write the ideas file's **built** line, pointing at the repo and the survey brief.

## Setup — no scaffolding

The bootstrap's steps **1, 3, 5, 6, 7 and 8**, run against code that already exists. Read
[`bootstrap`](../bootstrap/SKILL.md) for each step's mechanics; the differences are below.
**Step 2 does not run** — there is no stub to scaffold and no folder to create — and Serena
was indexed before the first question.

| When | On the cutting route | On the charting route |
|---|---|---|
| Setup runs | straight after the verdict, this session | on the setup run, after charting closes the map |

**The line holds exactly as in the bootstrap:** before every write, *does this land inside the
repo?* Inside → do it. Anywhere else, or no path at all → show it and wait. **The one change
is what sits inside the repo:** the user's code. Setup writes `CLAUDE.md` and the generated
agent and skill files, and **never touches a line of existing code**.

| # | Step | What changes on an adopted repo |
|---|---|---|
| 1 | **Ask the two allowlist questions, and wait** | nothing. Asked before setup, as there |
| 3 | **Write `CLAUDE.md`** | the six things — stack, commands, branch, layer chain, Serena verdict, settled names — copied from the closed map, **never chosen**. A prototype's own `CLAUDE.md` is kept and the six added to it |
| 5 | **Generate the layer specialists and the stack skills** | `/adapt-to-stack`, unchanged. Each specialist names the folder the code **already** uses for its layer |
| 6 | **Verify the tracker adapter** | nothing. Verify, never install |
| 7 | **Write the two memories** | memory one, *what this project is and who it is for*: charting wrote it on the charting route; on the cutting route the map closed in this session, so **you** write it. Memory two as there. Show both, and wait |
| 8 | **Run every seam check, report once, stop** | the same seven rows, every check, every time. Row 2 is *the code builds and runs*. Green makes one commit, explicit paths, only the files setup wrote. Red commits nothing and classifies nothing |

**Then, green only, the handover.** On the setup run, look for the open task titled exactly
**Run /adopt (fresh session)** — charting opened it when the map closed — and propose closing
it. On either route, propose opening one task titled exactly
**Run /cut-backlog (fresh session)**, claimed to the user, unless one is already open. Both are
tracker writes: **show both and wait.** Red writes nothing to the tracker, and the incoming
task stays open.

**Do not write a progress file.** A dead setup run is resumed by running `/adopt` again: the
tells say *setup run*, and each step skips itself as the bootstrap's do.

## Order of operations

```
   read the tells ──► setup run? ──────────────────────────────┐
        │ first run                                             │
   read the ideas file                                          │
   index Serena ──► dispatch @project-surveyor (COLD) ──┐       │
        │                                               │       │
   Q0 ──► class fixed ──► arms the kills                │       │
        │  (novelty: COLD /research — does it exist?)   │       │
   Q1 ──► human, you push once                          │       │
   Q2 ──► human                                         │       │
   Q3 ──► human + COLD /research — the hard part        │       │
   Q4 ──► human, weighed against sunk cost              │       │
   Q5 ──► waits for the survey brief ◄──────────────────┘       │
        │                                                       │
   ┌────┴─────────────────────────────────────────────┐         │
   │  1. you write THE CASE FOR KILLING — every time   │         │
   │  2. you commit to YOUR verdict                    │         │
   │  3. ONLY THEN do you ask for the user's           │         │
   └────┬─────────────────────────────────────────────┘         │
        │                                                       │
   build the CASE FILE ──► dispatch pitch-judge ──► independent verdict
        │                                                       │
   resolve ──► KILL │ PARK ──► ideas file, linking the brief     │
        │                                                       │
      BUILD ──► entry point                                     │
        ├── back to /pitch ──► ideas file: unjudged ──► stop    │
        ├── charting ──► repo if none · map, open ──► stop      │
        │                 … charting closes it ──► Run /adopt ──┤
        └── cutting  ──► repo if none · map, closed at once     │
                          │                                     │
                          ▼                                     ▼
                   SETUP: allowlist · CLAUDE.md · specialists · adapter
                          · memories · seam checks · report · commit if green
                          │
                   green ──► close Run /adopt (if open) · open Run /cut-backlog
```

## Where you stop

| You stop when | And you say |
|---|---|
| The verdict is kill or park | the ideas-file entry, and the `next-steps` block |
| The entry point is back to `/pitch` | the unjudged entry, and the block |
| The charting map is seeded | the map by id, and the block. Setup is a later run |
| Setup step 1, before anything else | the two allowlist questions, and the exact line you propose to add |
| A write lands outside the repo | what you are about to write, and where |
| The setup report is done | nothing more — no classification, no fix, no re-run |
| Something genuinely needs deciding during setup | what it is, and that it belongs on the map, not in setup |

## End with the `next-steps` block

Every outcome ends with it, after its own report. What each one carries:

| Outcome | What landed | What is the user's | Next command, and which session |
|---|---|---|---|
| **Kill or park** | the verdict and the rule behind it, in the ideas file at its path, linking the survey brief | nothing to commit and nothing to run; on a park, the trigger, which is theirs to notice | none — this one is over |
| **Back to `/pitch`** | the unjudged entry, naming the folder and the survey brief | nothing to commit | `/pitch`, fresh — the kill gate must not inherit this session's view of the folder |
| **Charting** | the repo, created or existing, and the map by id and url, with the closed decision tickets the code made; the ideas file's built line | nothing to commit — adoption has written no file in the repo yet | `/charting` with the map's id filled in, fresh — charting is sized to one session |
| **Cutting, setup green** | the closed map by id; the setup commit's sha and what it staged | the *Run /cut-backlog (fresh session)* task by id, claimed to them; cutting closes it | `/cut-backlog`, fresh — cutting re-reads the whole map |
| **Setup run, green** | as cutting green, plus the closed *Run /adopt (fresh session)* task by id | as cutting green | as cutting green |
| **Setup, red** | the checks that pass, in the report above; nothing committed, on purpose | classify each failed row as a wrong check or a wrong stack — a wrong stack reopens the map | `/adopt` once they have, in either session — safe to re-run, every finished step skips itself |

## Stop condition

**Adoption is done when a verdict is recorded in the ideas file** — and on build, when the
entry point's own landing exists: the unjudged entry, the open map, or the setup report.

**It is not done when you have run out of questions**, and it is not done when the setup is
green. A red setup report is a finished run. Adoption's job is the verdict and the entry
point, not a guarantee that the code was good.
