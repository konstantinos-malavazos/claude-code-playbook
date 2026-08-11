---
name: to-questionnaire
description: >-
  Turn a decision you cannot answer alone into a questionnaire for one other person to
  fill in — async, or together in a meeting. Use when the answer is a fact somebody else
  holds, and neither the code, the docs nor your own judgement can settle it.
disable-model-invocation: true
---

# To questionnaire — pull the answer out of the person who has it

The fourth kind of open question. `research` reads documents, `grilling` asks the human in
the room, `task` gets someone to *do* something. This one asks someone what they **know**.

> Prior art: Matt Pocock's `to-questionnaire` skill (MIT). Re-derivation: same three steps
> and document shape, with the repo's own file convention instead of a fixed path.

## Grill the send, not the subject

Interview the user about the **send** only — who it goes to, and what they need back. They
can always answer that. They cannot answer the subject. That is why there is a questionnaire.

1. **Who is it going to?** One exchange: the recipient's role, what they know, their
   relationship to the user. This sets the tone and how much context the document carries.
2. **What do you need back?** One exchange: the decisions or facts blocked on this person.
   Done when you have a concrete list of what the user must walk away able to decide.
3. **Write it**, aimed at the gap between the two.

**Every question targets the gap.** A question the user could answer themselves is padding,
and padding is what makes a recipient skim.

## Where the file goes

**Match whatever convention the repo already uses for notes**, the same rule
[`research`](../research/SKILL.md) follows. If there is none, put it beside the ticket's
handoffs. Name the path in your report either way. A questionnaire nobody can find was not
written.

## The document

Order questions **most-important-first**, because async means you may get only one pass.
Group them under `##` themes once there are more than a handful.

```markdown
# <Title>

**Purpose:** why this exists and the decision riding on it.

**From:** <user> — **To:** <recipient> — **How your answers will be used:** <where they go>

## Context
One paragraph, for a recipient who was not in the user's head. Enough to answer well.

## How to answer
Deadline and rough effort. Partial answers and "I don't know" are useful — flag anything
you are unsure of rather than skipping it.

## <Theme>

### <One question, one idea — never compound>

_Why this matters: <one line, only where the question could be misread.>_

>

## Anything else?
Anything we did not ask that we should know?
```

The `>` under each question is the answer stub. Leave it empty. A recipient types into it.

## Stop condition

Stop when the file exists and **every item from step 2 is covered by a question**. Sending
it is the user's, not yours.
