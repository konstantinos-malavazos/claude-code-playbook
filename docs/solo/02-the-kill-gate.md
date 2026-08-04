# 02 — The kill gate

The kill gate is **stage 1** of the [solo path](01-the-solo-path.md). You arrive holding
nothing but an idea — no repo, no spec, nobody to tell you whether it is any good.

The stage answers **is this worth building at all?** It ends in a verdict: **build**,
**kill**, or **park**. It takes about an hour. On *build* it creates a private repo and
hands over to [charting](03-charting.md); on *kill* or *park* the path stops here, which
is the whole point of putting it first.

The stage is **the kill gate**. The skill is **`/pitch`**. The output is a **verdict**.
Three names, kept distinct — otherwise you can never say which one you mean.

You run it with **`/pitch`**, from
[`templates/skills/pitch/SKILL.md`](../../templates/skills/pitch/SKILL.md). That template
owns the mechanics and this doc does not repeat them. The
[`pitch-judge` agent](../../templates/agents/pitch-judge.md) ships alongside it.

> **A doc alone could not be this stage.** The failure mode the gate exists to prevent is
> talking yourself through your own checklist — reading each line, nodding, proceeding.
> A page cannot stop you doing that. An agent asking one question at a time and waiting
> can. The gate also has real work you cannot do quickly by hand: finding out whether the
> thing already exists, and finding out what the hard part is.

---

## The six questions

Asked **one at a time**, in this order. About an hour, end to end.

| # | Question | Who answers it |
|---|---|---|
| 0 | **What does this idea's value rest on?** — novelty, execution, or the building itself | you |
| 1 | What is it, and who is it for? | you |
| 2 | Does it already exist? | a cold [`/research`](../../templates/skills/research/SKILL.md) subagent |
| 3 | What is the smallest thing you could build that would tell you this works? | you — the agent pushes on size |
| 4 | What is the hard part? | a cold [`/research`](../../templates/skills/research/SKILL.md) subagent |
| 5 | What does it cost you if you never build it? | you |

**"Just me" is a legitimate answer to question 1**, and usually an honest one. The gate is
not asking you to justify an audience you do not have.

**Question 5 does not carry a knife.** For a project you are building for fun, the honest
answer to *what does it cost you if you never build it* is "nothing" — and that is fine.
It informs the verdict. It never kills.

**Only questions 2 and 4 spawn agents.** The rest are you talking. An agent on those is
cost with no return, and the gate has to stay cheap enough that you keep running it.

---

## Question zero, and why it goes first

Question zero is the load-bearing one, and its position in the list is not an accident.

The weight of every later question depends on it. A casual game survives *"similar games
already exist"* completely untouched. The same finding is fatal to an idea whose entire
claim is that nobody has done this. The discriminator is **not** who the thing is for —
it is what its value rests on:

| The value rests on | Meaning |
|---|---|
| **Novelty** | The value is that nobody has done this. |
| **Execution** | Plenty have done it. Yours will be nicer, simpler, or just yours. |
| **The building itself** | Fun, or learning. Whether it already exists is nearly beside the point. |

One minute of your time, and it decides two things:

- **Which later questions are allowed to kill.** See the table below.
- **How the search agents are briefed.** When the claim is novelty, question 2 hunts for a
  killer. When the claim is execution, it comes back with what exists and what is good
  about it — useful inspiration, not a verdict.

**It is asked before the searches on purpose.** You commit to the class *before* you know
which question is loaded. Classify afterwards and you will quietly demote a novelty idea
to "execution" the moment the search turns up a competitor.

---

## The three hard kills

Most of the gate is conversation. A named few answers kill on the spot — no appeal, and
never weighed against how much you want to build the thing. That is what *hard* means.

| Hard kill | Applies to |
|---|---|
| **You cannot say what the first version is** — after real pushback you still cannot name the smallest thing that would teach you whether this works | every class |
| **It already exists and it is good** — the claim was novelty, and the claim is false | novelty only |
| **The hard part is the whole project** — the unknown *is* the idea, nobody has solved it, and there is no cheap way for you to find out whether it is possible | novelty and execution |

The first holds for every class because everything downstream assumes a first version
exists. Charting has nothing to chart, the bootstrap nothing to scaffold, the backlog
nothing to cut up. It fails here, or it fails later and far more expensively.

The third catches the idea that sounds fine right up until you look at the technical
reality — question 2 waves it through and question 4 stops it. For a learn-something
project it is not a kill at all. It may be the entire point.

**The net effect is deliberate.** A casual evening project faces one hard kill. An idea
that claims it will make you rich faces all three. The gate is harsher on grand claims
than on small ones by construction, not by mood.

> **Why not a scoring rubric?** Ideas are not comparable, 7 out of 10 means nothing, and a
> checklist invites arguing each line down until everything passes. But pure conversation
> is worse: if every answer only feeds a final judgement call, you make that call in the
> direction you already wanted to go. Most questions inform; a named few kill.

---

## How the gate stays honest

Telling a model to be harsh does not work. It performs harshness — theatrical meanness
that is not real judgement, and you learn to ignore it within two sessions. What actually
changes the odds is **structure**.

| Mechanism | Why it works |
|---|---|
| **The search agents run cold** | A fresh subagent never heard you say this will make you rich. It cannot mirror enthusiasm it was never shown. This is the real argument for subagents at the gate — worth more than any instruction. |
| **The agent gives its verdict before you give yours** | If you go first, it agrees with you. If it must commit before it knows what you want, it has nothing to agree with. The strongest of the four, and it costs nothing. |
| **The agent states the case for killing, out loud, every time** | Not optional, not conditional on it having concerns. The best argument against, written before any verdict, even for ideas it likes. |
| **`pitch-judge` reads the record blind** | A fourth agent that knows nothing about who is who. Below. |

### `pitch-judge`

A separate agent — [`templates/agents/pitch-judge.md`](../../templates/agents/pitch-judge.md)
— that reads the record and returns its own independent verdict. It runs **once,
automatically**, as part of the gate. It is not an appeals court you get to invoke, so
there is no reprieve-shopping.

**It receives a case file, never a transcript.** This is the part worth understanding,
because the obvious design fails. A relabelled conversation gives itself away in about two
lines: one side asks every question, one side says *"let me go and search."* Work out who
is who and the judge is back to deferring to you. So there is no dialogue at all — the six
questions with their settled answers, the two search reports, and the two verdicts labelled
only **Verdict 1** and **Verdict 2**, in random order. Nothing to infer from, because there
is no asker and no answerer.

**It counts in both directions.** It confirms when you and the agent both said build. It
**breaks the tie when you disagreed**, which is where it earns its keep and is not rare. It
can kill something you both approved.

**But a hard kill that has already fired cannot be argued away — by the judge or by
anyone.** If the claim was novelty and the search found the thing exists and is good, that
is over. Nobody weighs it against enthusiasm; that is what *hard* meant. The judge **can**
fire a hard kill the two of you missed. It can never un-fire one.

---

## Park needs a trigger

Park is where a gate goes to die. *"Not right now"* is how you avoid saying no, and if
parking is free then everything gets parked, nothing gets killed, and you have built
exactly the theatre this stage exists to prevent.

> **To park, name a thing that will end — and that you will notice ending.**

The test is not about time.

| Park | Verdict |
|---|---|
| *"Not until the house move is done"* | Fine. It ends, and you will notice. |
| *"Not until the baby sleeps through"* | Fine. Same reason. |
| *"Not until the March crunch is over"* | Fine. It has a date. |
| *"When things calm down"* | **Kill.** It does not end, and you would not notice if it did. |

No trigger means **kill**, said plainly and recorded with its reason.

**What makes that strict rule liveable is that a kill is not a deletion.** It is a recorded
no. Have the idea again in a year, find the entry, read why past-you said no, and disagree
with better information if you want to. Nothing is thrown away — which removes the pressure
to park things dishonestly in the first place.

---

## The ideas file

One file, four kinds of entry.

| Entry | What it holds |
|---|---|
| **Unjudged** | The inbox. Ideas that have not been through the gate yet. |
| **Parked** | With its trigger. |
| **Killed** | With its reason. |
| **Built** | One line, pointing at the repo. |

`/pitch` reads it at the start, so it can tell you when you are re-having an idea you
already killed. It writes the entry when the verdict lands.

**Where it lives is your choice, and it has two required properties: private, and backed
up with history.** Pick a path once and give it to the skill.

| Option | Private | Backed up | History | |
|---|---|---|---|---|
| **Cloud-synced folder** — Drive, Dropbox, OneDrive | yes | yes | cloud versioning only | The easy default. Not real version control, but enough. |
| **A private git repo** | yes | yes | yes | All three properties. See the upgrade below. |
| **A second disk** | yes | no | no | Neither offsite nor history. The laptop and the record die together. |

**Free upgrade if you pick the private git repo:** the ideas become issues rather than
lines in a file, and the tracker adapter you already installed works on it as-is — dates,
search and history for no new machinery. See
[`templates/trackers/`](../../templates/trackers/README.md). This is not required. Demanding
a repo before you are allowed to write an idea down is friction at the exact moment the
gate is meant to be free.

### It must not go in `~/.claude/`

Two concrete dangers and one category error:

| | |
|---|---|
| **Dotfiles get published** | `~/.claude/` holds exactly the things people share — settings, skills, agents — and this playbook itself tells you to put files there. Sooner or later someone sweeps their unjudged ideas into a public dotfiles repo without noticing. That is not reversible. |
| **It is not backed up** | One file, one machine, no history. The whole record dies with the laptop. |
| **It is the wrong kind of thing** | `~/.claude/tracker.md` is *configuration* the agent reads. An ideas file is *personal data*. Colocating them because both happen to be global is the wrong reason. |

---

## The gate, end to end

```
        AN IDEA
           │
           ▼
   Q0  what does the value rest on? ──► novelty │ execution │ the building itself
           │                                    └─── sets which questions can kill,
           │                                         and how the searches are briefed
           ▼
   Q1  what is it, who is it for?           you
   Q2  does it already exist?               COLD /research subagent
   Q3  what is the smallest version?        you  ── the agent pushes on size
   Q4  what is the hard part?               COLD /research subagent
   Q5  what if you never build it?          you  ── informs, never kills
           │
           ▼
   the agent writes the CASE FOR KILLING, then commits to ITS verdict
           │                                     (before it hears yours)
           ▼
   you give yours ──►  CASE FILE  ──►  pitch-judge   weighs only, no dialogue,
                       no transcript                 verdicts labelled 1 and 2
           │                                         in random order
           ▼
   ┌───────┴────────────────────────┐
   │  any hard kill fired?          │──► YES ──► KILL. No appeal, by anyone.
   └───────┬────────────────────────┘            The judge can fire one. It can
           │ NO                                  never un-fire one.
           ▼
   ┌───────┴──────┬──────────────────┐
   ▼              ▼                  ▼
 BUILD          PARK               KILL
   │         needs a trigger    recorded with
   │         that will END      its reason —
   │         and that you       a no, not a
   │         will NOTICE        deletion
   │         ending
   ▼
 private repo created (name confirmed with you)
 map SEEDED as issue #1
   │
   ▼
 2. CHARTING
```

---

## What a build verdict hands over

The agent creates a **private** repo, after confirming the name with you, and the map is
its issue #1. That is the [spine doc](01-the-solo-path.md)'s *repo is the gate's output*
rule — which is why [the bootstrap](04-the-bootstrap.md) scaffolds and never creates.

**Issue #1 arrives seeded, not empty.** Otherwise charting opens by asking you what the
project is, an hour after you told the gate.

| Part of the map | What the gate writes into it |
|---|---|
| **Destination** | Already known. On this path it is always *a backlog of work units on a scaffolded repo that passes the seam* — see [03-charting.md](03-charting.md#the-destination-you-hand-it). Charting never asks. |
| **Notes** | The premise: what it is, who it is for, which of the three classes it is, and **the smallest version**. That last one then sits in front of you every session — the cheapest available brake on charting sprawling into a product nobody asked for. |
| **First ticket** | **The hard part**, as a `research` ticket. The gate already found it and phrased it sharply, so charting's fog rule makes it a ticket rather than fog — and `research` runs unattended, so charting has work in flight from its first session. Too vague to phrase means it goes into *Not yet specified* instead. |

The gate also writes the **built** line into the ideas file, pointing at the new repo.

---

## The gate is not "when not to use this playbook"

[`12-when-not-to-use.md`](../shared/12-when-not-to-use.md) is the other doc that tells you
to stop. The two do not overlap:

| | Asks |
|---|---|
| **`12-when-not-to-use.md`** | Is the pipeline the wrong **tool** for this work? |
| **The kill gate** | Is this the wrong **idea**? |

Neither substitutes for the other, and a gate cheap enough to run in an hour does not need
a gate in front of it.

### The spike clash, and why it is not one

A careful reader will spot this, and on the face of it it looks like a hole.

`12-when-not-to-use.md` says **spike work must not go through `/start-ticket`** — the
pipeline's linear chain fights the shape of discovery. And the kill gate produces exactly a
spike: *the smallest version that would prove this works*, plus a named hard part nobody
has solved. So the solo path appears to end by feeding a spike into a pipeline that rejects
spikes.

**It does not, because the hard part never reaches the pipeline as a spike.** It becomes a
`research` ticket on the map and is burned off **during charting** — stage 2, before the
repo is scaffolded and long before a backlog exists. By the time work units arrive at
`/start-ticket`, the exploratory part is over and what is left is buildable. That is the
`research` ticket type doing precisely the job `12-when-not-to-use.md` says an
investigation agent should do, at the only point on the path where it is cheap.

---

## Why this doc exists

The [spine](01-the-solo-path.md) tells you where the gate sits. The
[`/pitch` template](../../templates/skills/pitch/SKILL.md) tells you how it runs. Neither
answers the questions a reader has while standing *in* the stage:

- **Question zero is doing most of the work**, and it goes first for a reason that is easy
  to miss and expensive to get wrong.
- **The gate is deliberately uneven.** It is harsher on an idea claiming novelty than on an
  evening project, and that asymmetry is designed rather than accidental.
- **Honesty here is structural, not attitudinal.** Cold agents, order of reveal, a
  mandatory case for killing, an anonymised judge. Any later work that needs an
  anti-sycophancy mechanism should start from these four rather than re-derive them.
- **Park is the dangerous verdict**, not kill — and the trigger rule is what keeps it from
  swallowing everything.
- **A kill costs you nothing you cannot get back.** That is what makes the strict rules
  bearable.

Read this before your first `/pitch`. Read [01-the-solo-path.md](01-the-solo-path.md) for
where this stage sits in the whole, and [03-charting.md](03-charting.md) for what happens
the moment a *build* verdict lands.

---
> **Last verified against:** Claude Code `2.1.220` — July 2026
