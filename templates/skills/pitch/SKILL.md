---
name: pitch
description: >-
  Put a raw idea through a one-hour kill gate and come out with a verdict — build, kill,
  or park. Six questions asked one at a time, two cold search subagents, three hard kills,
  and an anonymised third-party judge. Use when the user has an idea and no repo, or says
  "is this worth building" / "should I build this" / "pitch this" / "kill or build". NOT
  for work that already has a ticket, a repo, or a spec.
---

# Pitch — the burden of proof is on the idea

The user makes the case. You do not have to be talked into saying no.

This is **stage 1** of the solo path: it answers *is this worth building at all?* and ends
in a verdict — **build**, **kill**, or **park**. About an hour. Everything downstream
assumes it ran.

> The stage is **the kill gate**. The skill is **`/pitch`**. The output is a **verdict**.
> Three names, never merged.

The reader-facing explanation of *why* the gate is shaped this way lives in
`docs/solo/02-the-kill-gate.md`. **This file is the mechanics.** Where the two overlap,
this one says *what you do*; that one says *why it works*.

## Before the first question

**Read the ideas file** at `<IDEAS-FILE-PATH>`.

If this idea — or something close enough that the user would recognise it — is already in
there, say so **before** question zero, and say which kind of entry it is:

| Found as | What you do |
|---|---|
| **killed** | Name it, quote the recorded reason, and ask what is different now. Do not refuse to run; past-you is allowed to be wrong. But the burden just went up. |
| **parked** | Name it and check the trigger. If the trigger has fired, this is a resumption. If not, ask what changed. |
| **unjudged** | Nothing special. This is the inbox and you are about to empty this entry. |
| **built** | Point at the repo. The user may have forgotten. Stop and check before doing anything else. |

If the file does not exist yet, create it on the first verdict, not now.

## The six questions

**One at a time. Wait for each answer.** Do not batch them, do not present them as a form,
and do not answer any of the human-owned ones yourself.

| # | Question | Who answers | Spawns an agent |
|---|---|---|---|
| 0 | **What does this idea's value rest on?** — novelty, execution, or the building itself | human | no |
| 1 | What is it, and who is it for? | human | no |
| 2 | Does it already exist? | `/research` subagent | **yes — cold** |
| 3 | What is the smallest thing you could build that would tell you this works? | human | no |
| 4 | What is the hard part? | `/research` subagent | **yes — cold** |
| 5 | What does it cost you if you never build it? | human | no |

**Only 2 and 4 spawn agents.** An agent on the others is cost with no return, and the gate
has to stay cheap enough that the user keeps running it.

**"Just me" is a complete answer to question 1.** Do not push for an audience the user does
not claim to have.

**Question 5 informs and never kills.** For a project built for fun the honest answer is
"nothing", and that is fine.

**On question 3, push on size — once, properly.** The first answer is almost always too
big. Ask what could be cut and still teach them the same thing. If after real pushback they
still cannot name a first version, that is hard kill 1 and it fires.

## Question zero governs everything after it

Ask it **first**, before either search. The user commits to the class before they know
which question is loaded. Classify afterwards and a novelty idea quietly becomes an
"execution" idea the moment the search finds a competitor.

The answer sets two things.

**Which hard kills are armed:**

| Class | Armed |
|---|---|
| **Novelty** — the value is that nobody has done this | all three |
| **Execution** — plenty have done it; theirs will be nicer, simpler, or just theirs | 1 and 3 |
| **The building itself** — fun, or learning | 1 only |

**How you brief the search subagents:**

| Class | Question 2's brief | Question 4's brief |
|---|---|---|
| **Novelty** | *Hunt for a killer.* Find the closest existing thing and judge honestly whether it is good. | Find whether anyone has solved the hard part, and how. |
| **Execution** | *Find what exists and what is good about it.* This is inspiration, not a verdict. | Same. |
| **The building itself** | Light touch — what exists, for reference only. | Find whether the hard part is tractable at hobby scale. |

## Briefing a cold search

Both searches are `/research` subagents. **Do not write new search-agent templates** — that
skill exists and does exactly this.

**They run cold, and that is the point.** A fresh subagent never heard the user's
enthusiasm, so it cannot mirror it.

> **Never tell a search agent how the user feels about the idea**, how excited they are,
> what verdict you are leaning towards, or what you hope it finds. Give it the question,
> the class-appropriate brief above, and nothing else.

Give it a **question, not a topic** — *"is there an existing open-source tool that does X
for Y, and is it any good?"*, not *"look into competitors"*.

## The three hard kills

Apply these **mechanically**. They are not weighed, not scored, and never balanced against
how much the user wants to build the thing. That is what *hard* means.

| # | Hard kill | Fires when | Armed for |
|---|---|---|---|
| 1 | **No first version** | after real pushback on question 3, they still cannot name the smallest thing that would teach them whether this works | every class |
| 2 | **It already exists and it is good** | the claim was novelty, and question 2 found the thing, and it is good | novelty only |
| 3 | **The hard part is the whole project** | the unknown *is* the idea, nobody has solved it, and there is no cheap way to find out if it is possible | novelty, execution |

**When one fires, say so plainly and stop weighing.** Do not soften it, do not offer three
ways to rescue the idea, and do not carry on to the next question hoping it balances out.
Record it and go to the verdict.

**A hard kill that has fired cannot be un-fired — by you, by the user, or by the judge.**

## Order of operations — the reveal is the mechanism

This sequence is not a suggestion. Two of the three anti-sycophancy mechanisms are just
*when* things happen.

```
   read the ideas file
        │
   Q0 ──► class fixed  ──► arms the kills, briefs the searches
        │
   Q1 ──► human
   Q2 ──► COLD /research subagent   ── never told how the user feels
   Q3 ──► human, you push on size
   Q4 ──► COLD /research subagent
   Q5 ──► human
        │
   ┌────┴──────────────────────────────────────────────┐
   │  1. you write THE CASE FOR KILLING — every time    │
   │  2. you commit to YOUR verdict                     │
   │  3. ONLY THEN do you ask for the user's            │
   └────┬──────────────────────────────────────────────┘
        │
   build the CASE FILE ──► dispatch pitch-judge ──► independent verdict
        │
   resolve ──► BUILD │ KILL │ PARK
        │
   write the ideas-file entry     ── always
   on BUILD: create the repo, seed issue #1
```

**Step 1 is unconditional.** Write the best argument against the idea before any verdict,
even for ideas you like, even when you are about to say build. Not a caveat paragraph — the
strongest case you can actually make.

**Step 2 before step 3, always.** If the user goes first you will agree with them. Commit in
writing, then ask. This is the strongest mechanism here and it costs nothing.

## Dispatching `pitch-judge`

Runs **once, automatically**, as part of the gate. Never on demand — an appeals court the
user can invoke is a reprieve-shopping machine.

**It receives a case file, never a transcript.** A relabelled conversation identifies itself
in about two lines: one side asks every question, one side says *let me go and search*. Work
out who is who and the judge is back to deferring to the user.

**The judge has no tools, so it cannot read a file.** The case file goes **in the dispatch
prompt itself**, not on disk.

Build it exactly like this:

```markdown
## The idea
<one paragraph — what it is, who it is for>

## Class
<novelty | execution | the building itself>

## The questions, answered
1. What is it, and who is it for? — <the settled answer>
3. The smallest version that would prove it — <the settled answer>
5. What it costs if never built — <the settled answer>

## Search report: does it already exist?
<the subagent's findings, verbatim>

## Search report: what is the hard part?
<the subagent's findings, verbatim>

## Verdict 1
<verdict + reasoning>

## Verdict 2
<verdict + reasoning>
```

**Rules for building it:**

- **No dialogue.** Settled answers only. Nothing that reads as a turn in a conversation.
- **No attribution anywhere.** Not in the answers, not in the search reports, not in the
  verdicts. Strip *I think*, *you said*, *the user*, *I searched* — anything that names a
  side.
- **Randomise which verdict is 1 and which is 2**, every run. If they came out identical,
  say so in a `## Note` line rather than fabricating a difference.
- **Verbatim search reports.** Do not summarise them into your own framing; that is your
  voice leaking into the judge's evidence.

## Resolving the verdict

In this order. Stop at the first rule that applies.

| | Rule |
|---|---|
| 1 | **Any hard kill fired — by you, the user, or the judge** → **KILL**. No appeal, no weighing, no exceptions. |
| 2 | **You and the user agreed** → that verdict, unless the judge dissents to *kill*, which carries. |
| 3 | **You and the user disagreed** → **the judge breaks the tie.** This is where it earns its keep, and it is not rare. |
| 4 | **The verdict is park** → apply the trigger test below. It may become a kill. |

The judge counts in **both** directions: it confirms, it breaks ties, and it can kill
something you and the user both approved. It can **fire** a hard kill the two of you missed.
It can never **un-fire** one.

## Park requires a trigger

> **To park, the user must name a thing that will end — and that they will notice ending.**

Not a length of time. A thing that ends.

| | |
|---|---|
| *"after the house move"* · *"when the March crunch is over"* · *"once the baby sleeps through"* | park |
| *"when things calm down"* · *"when I have more time"* · *"eventually"* | **kill** |

**No trigger means kill**, said plainly and recorded with its reason. Ask once, accept a
real answer, and do not help the user manufacture a trigger — offering candidate triggers is
how park swallows the whole gate.

Say the thing that makes this bearable, out loud: **a kill is a recorded no, not a
deletion.** They can have the idea again in a year, read why past-them said no, and disagree
with better information.

## Writing the ideas file

Always, on every verdict. `<IDEAS-FILE-PATH>` — the user picks the path, and it must be
**private and backed up with history**. Never `~/.claude/`: dotfiles get published, they are
not backed up, and this is personal data rather than configuration.

| Entry | Records |
|---|---|
| **unjudged** | the idea, and the date it arrived. The inbox. |
| **parked** | the idea, the trigger, and the date |
| **killed** | the idea, **which rule killed it** (which hard kill, or the reasoning), and the date |
| **built** | the idea, the repo, and the date |

Write the reason at the length past-them will need in a year, not the length that is
convenient now.

## On a build verdict

1. **Confirm the repo name with the user.** Ask; do not pick one and announce it.
2. **Create the repo — private.** Through the tracker adapter's verbs, never a raw CLI call.
3. **Seed the map as issue #1.** It arrives filled in, not empty — otherwise charting opens
   by asking what the project is, an hour after the gate was told.

| Section | What you write |
|---|---|
| **Destination** | Fixed on this path: *a backlog of work units, on a scaffolded, Serena-indexed repo.* Charting never asks. |
| **Notes** | The premise — what it is, who it is for, the class, and **the smallest version**. That last line then sits in front of the user every session. |
| **Decisions so far** | Empty. |
| **Not yet specified** | The hard part, **only if too vague to phrase as a question**. |
| **Out of scope** | Deployment, hosting, CI, release. |

4. **The hard part becomes the map's first ticket**, typed `research` — you already found it
   and phrased it sharply, so the fog rule makes it a ticket rather than fog. `research`
   runs unattended, so charting has work in flight from its first session. Too vague to
   phrase means it goes to *Not yet specified* instead.
5. **Write the built line** into the ideas file, pointing at the new repo.
6. **Stop.** Charting is the next session, not the rest of this one.

## Stop condition

The gate is done when a verdict is recorded in the ideas file — and on *build*, when the
repo exists with a seeded issue #1.

**It is not done when you have run out of questions.** An hour of conversation that ends
without a recorded verdict is the exact theatre this gate exists to prevent.
