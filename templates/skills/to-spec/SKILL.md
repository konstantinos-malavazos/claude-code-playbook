---
name: to-spec
description: >-
  Turn an approved planner.md into a slice-ready spec for a large ticket — the problem and
  the solution in user terms, the testing seam that proves each behaviour, and the behaviour
  boundaries to slice along. Runs inside the /start-ticket DECOMPOSE path, after the planner
  set slice-count > 1 and you approved the plan, and before /to-tickets. It is a thin
  transform of briefs that already exist: no interview, no re-exploration of the codebase.
  Not for a normal single-slice ticket.
---

# to-spec — plan → slice-ready spec

> Prior art: Matt Pocock's `to-spec` skill (MIT), upstream-renamed from `to-prd`. This is an
> adaptation, not a copy. Two differences: it interviews nobody and re-explores nothing,
> because the plan is already approved and `@context-gatherer` already swept; and it writes
> an internal file, never an issue published to a tracker.

## When this runs

Only in the `/start-ticket` **decompose path** — the planner set `slice-count > 1` and you
approved the plan. On a single-slice ticket this skill does not run and the pipeline
proceeds as normal. The path is
[docs/shared/09](../../../docs/shared/09-decompose-path.md).

## Inputs — read these three, and nothing else

- `<workspace>/.claude/handoffs/<TICKET-ID>/planner.md` — the approved plan: design, layer
  allocation, steps, risk, `## Open questions for grilling`. **Do not duplicate it.**
- `<workspace>/.claude/handoffs/<TICKET-ID>/context-gatherer.md` — domain vocabulary,
  rulings, blast radius. Reuse its words so the spec speaks the project's language.
- `<workspace>/.claude/handoffs/<TICKET-ID>/ticket-analyzer.md` — the acceptance criteria,
  verbatim.

## What this adds — the only reason it exists

The plan already holds the *how*: files, symbols, layers, commits. This spec adds the two
things `/to-tickets` needs in order to cut good slices.

1. **Testing seams** — where each behaviour is verified. Read `## Testing seams` in the
   repo's `CLAUDE.md` and name the produce/verify step or the integration entry point that
   proves each behaviour. Keep the seams few and at the highest sensible level, and prefer
   an integration point that already exists.
   **A layer with no code test path is proven on the deployed environment rather than in a
   test project.** Where that is the case, say so and name the `/test-ticket` step as the
   seam. Do not invent a unit test for a layer the repo does not unit-test.
2. **Behaviour boundaries** — the user-facing behaviours, each as
   "As a `<actor>`, I want `<capability>`, so that `<benefit>`." These are the natural lines
   to slice along.

Everything else — problem, solution, out of scope — is context in a few lines, not a second
copy of the plan.

## Steps

1. Read the three input files.
2. Write the problem and the solution in **user terms**, 1–3 sentences each.
3. List the **behaviours** as numbered user stories. Where the work is the same change
   applied across N independent units, group by unit explicitly — that grouping is the
   strongest slice hint there is.
4. Give each behaviour its **testing seam**. Note the shared ones: two behaviours on one
   seam usually cannot be sliced apart cleanly.
5. State **out of scope**, and the **decisions that affect slicing** — a shared schema or
   contract, an ordering constraint. Name no file paths; they live in `planner.md`.
6. Write the spec to `<workspace>/.claude/handoffs/<TICKET-ID>/slice-spec.md` and hand back
   to the orchestrator, which runs `/to-tickets` next.

## Output — write to `handoffs/<TICKET-ID>/slice-spec.md`

```
# Slice-ready spec — <TICKET-ID>

## Problem (user terms)
<1–3 sentences>

## Solution (user terms)
<1–3 sentences>

## Behaviours (slice candidates)
1. As a <actor>, I want <capability>, so that <benefit>.   [units: <names>]
2. ...

## Testing seams
| Behaviour # | Seam (the `## Testing seams` step, /test-ticket step, or integration entry point) | Shared with # |
|---|---|---|

## Decisions that affect slicing
- Shared schema / contract: <what two behaviours must agree on>
- Ordering: <X must land before Y, because ...>

## Out of scope
- <...>

## Source
- Plan: planner.md · Context: context-gatherer.md   (not duplicated here)
```

## Hard rules

- **Never write to the tracker.** This is an internal file; one `<TICKET-ID>` stays one
  ticket.
- **Never write to memory.** Everything here is pre-merge and ephemeral. The durable record
  is the one consolidated memory written when the ticket lands.
- **Do not re-explore the codebase.** Reuse `planner.md` and `context-gatherer.md`. If a
  fact you need is genuinely missing, name it and stop — a fresh sweep here re-runs work
  that already cost a full agent.
- **Do not restate the plan.** No file paths, no commit list, no symbol names.
- Keep it short. **If the spec is longer than the plan, you over-wrote it.**
