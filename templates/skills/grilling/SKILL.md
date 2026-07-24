---
name: grilling
description: >-
  Stress-test a plan or design by interviewing the user relentlessly until every open
  branch of the decision tree is resolved — OR explicitly deferred. Use when the user
  wants to pressure-test their thinking, says "grill me", or when a plan has open
  questions before implementation. This is the deferred-decision gate of the pipeline.
---

# Grilling — resolve or defer every open question

Your job is to find the decisions the plan is silently assuming and force each one into
the open. Ask **only** what the code and the briefs cannot answer — never re-ask
something Serena or memory can settle.

## The loop
For each open question:
1. **State it sharply** — the decision, the options, and what each implies downstream.
2. **Push** — don't accept a vague answer; follow the branch until the decision is
   concrete enough to implement.
3. Resolve to one of:
   - **Answered** — the user decides; record it.
   - **Deferred** — see below.

## The standing "defer" option (on every question)
Real decisions sometimes belong to a person or a spec that doesn't exist yet. Deferring
is legitimate — but it must be *managed*, not forgotten:
- **Own it** — name who/what answers it (a person, a spec page, a future ticket).
- **Price it** — how expensive is it to reverse if we guess wrong now? (Cheap → pick a
  sensible default and move on. Expensive → placeholder + don't build dependents on it.)
- **Unblock** — plan around it with a default or a placeholder so independent work
  proceeds.
- **Record it** — write the open question into the durable ticket state so
  `/resume-ticket` can pick it up when the answer lands.

## Stop condition
Stop when every open question is either answered or deferred-with-a-plan. A plan with
three well-managed deferrals is finished; a plan with one silent assumption is not.
