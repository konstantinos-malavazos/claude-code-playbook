---
name: grilling
description: >-
  Stress-test a plan or design by interviewing the user until every branch of the decision
  tree is resolved — OR explicitly deferred. Maps the decisions, posts the whole numbered
  set up front, then asks them one at a time. Use when the user wants to pressure-test
  their thinking, says "grill me", or when a plan has open questions before implementation.
  This is the deferred-decision gate of the pipeline.
---

# Grilling — resolve or defer every open question

Your job is to find the decisions the plan is silently assuming and force each one into
the open.

> Prior art: Matt Pocock's `grilling` skill (MIT). This is a re-derivation, not a copy. It
> keeps the upstream's decision tree and its question format, replaces the ask-the-whole-round
> rhythm with one question per turn (see [Running the round](#running-the-round)), and adds
> the defer gate this pipeline needs.

## Ask only what the room cannot already answer

**Never ask the user something Serena, memory, or the briefs can settle.** A fact you could
look up is not a decision, and spending a question on it is how a grilling loses the room.

| The question needs… | Who answers it |
|---|---|
| a fact about **our** code | Serena — pinpoint symbol reads, right now |
| a fact from **outside** — a vendor API, a spec, a version | a `/research` subagent |
| something only **seeing it run** settles | `/prototype` |
| a **judgement** — taste, priority, risk appetite, product intent | the user. This skill |

**Finding facts is your job, never the user's**, and a fact-finding subagent does not stop
the interview. Dispatch it and carry on: only the questions *downstream* of that fact wait
for it. Everything else in the tree is still askable now.

## The decision tree

Map the plan as a tree: **every decision branches into the decisions that hang off it.**

**A question whose answer depends on an open question is a later question, not this one.**
Asking it early forces the user to guess at an answer they have not given yet. So: ask what
is askable, and **re-derive what is askable after every answer**: one answer can add
branches, close branches, or make a planned question meaningless.

## One question is ~8 lines. Count them

This is a hard limit, not a target. A question that runs long is the failure mode here, and
plain words do not save it. **15 plain lines lose the room exactly as fast as jargon does.**

```
❓ **Q3 of 7** — **<short title>**: <one line naming the decision in ordinary words.>

<Option A — two or three lines.>
<Option B — two or three lines.>

➡️ <your recommendation, with ONE reason.>
```

- **One idea per sentence.** Name the thing in ordinary words before using the repo's term
  for it, and never use a term the design has not defined yet.
- **Two or three options**, one line of consequence each. Not a trade-off table.
- **One reason for the recommendation.** Reasons stack invisibly. Three good ones read as
  a wall. Hold the rest for the write-up.
- **One question per turn.** Never tack a second question onto the end of the first.
- **Evidence you found while researching is not preamble.** It belongs in the resolution
  comment, not in front of the question.
- **"Give me an example" means a worked trace**, not a better abstraction: invent a concrete
  case, name it, and walk it through with real values filled in.

## Running the round

Post the shape of the whole thing before asking anything.

1. **Two or three plain sentences** on what this session decides overall.
2. **The full numbered list** of the questions you can ask now — titles only.
3. **Then Q1**, and wait.

**Never open with Q1.** A first question that lands cold gets *"what are we deciding?"* every
time, and numbering alone does not fix it. The user wants to see how much is left before
they answer any of it.

**Ask one at a time and wait.** The list up front already gives the user the shape, and a
wall of simultaneous questions is what they have to decode instead of answer.

**The count is allowed to grow. Say so out loud when it does.** If a sub-question turns out
to be a real decision, announce *"the plan grew to 8, and here is why"*. Silently asking a
question you did not promise is what breaks the countdown.

**Re-asking is three parts, not one.** When the user asks to go back: restate the earlier
question and its settled answer in one line each, then the remaining numbered list, then the
question. The running record of what is decided so far is part of the countdown, not
bookkeeping you keep to yourself.

**When they say they did not understand, do not rephrase — re-explain from the concrete
thing:** the file, the map section, the line. Same move as
[`/wait-what`](../wait-what/SKILL.md), which they can also type at you.

## Push until it is implementable

**Never accept an answer too vague to implement.** Follow the branch until the decision is
concrete enough that a specialist could act on it without guessing. One re-ask, naming
exactly what was missing.

Then resolve the question to one of two things — **answered**, or **deferred**.

## The standing "defer" option

Real decisions sometimes belong to a person or a spec that does not exist yet. Deferring is
legitimate, but it must be *managed*, not forgotten:

- **Own it** — name who or what answers it: a person, a spec page, a future ticket.
- **Price it** — how expensive is it to reverse if we guess wrong now? Cheap → take a
  sensible default and move on. Expensive → placeholder, and build no dependents on it.
- **Unblock** — plan around it so independent work proceeds.
- **Record it** — write the open question into the durable ticket state, so
  [`/resume-ticket`](../../commands/resume-ticket.md) picks it up when the answer lands.

**A deferral with no owner and no price is a silent assumption wearing a label.**

## Stop condition

Stop when every question in the tree is either answered or deferred-with-a-plan, and the
user has confirmed you have reached a shared understanding. **A plan with three well-managed
deferrals is finished. A plan with one silent assumption is not.**

Do not act on the plan until that confirmation.

**Then the `next-steps` block**, and it differs by where the grilling ran. **In-pipeline** —
the answers and the managed deferrals are recorded, the confirmation is theirs, and the flow
that dispatched this resumes in **this** session with them. **Standalone** — name the plan's
own next command with its id filled in, and say whether it is sized to a fresh session. Every
deferral carries its owner into the block: a deferral with nobody named is the silent
assumption this skill exists to catch.
