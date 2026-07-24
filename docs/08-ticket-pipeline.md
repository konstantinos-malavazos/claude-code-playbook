# 08 — The `/start-ticket` pipeline, step by step

This is the flagship flow generalized. Substitute your tracker for "Jira", your layer
specialists for the implementer steps, and your git host for "MR/PR".

---

## Roles at a glance

| Step | Agent | Scope (tools) | Output |
|---|---|---|---|
| 1 | `ticket-analyzer` | tracker read only | `ticket-analyzer.md` — structured brief |
| 2 | `context-gatherer` | memory + code-nav, read only | `context-gatherer.md` — distilled brief + blast-radius flags |
| 3 | `planner` | code-nav read + branch creation; **no memory writes** | `planner.md` — plan, track allocation, final commit message, branch |
| 3b | grilling gate | (human) | answers or **deferred** open questions |
| 4 | layer specialists (in chain order) | edit + build/test in their repo | code + `<layer>.md` handoff |
| 5 | `reviewer` | code-nav read, run tests; **comments only** | `reviewer.md` — provisional verdict + MR description |
| 6 | `senior-reviewer` | cross-repo read; **comments only** | appended findings → final verdict |
| 7 | orchestrator + human | — | consolidated memory; human pushes & opens the MR/PR |

Handoffs live in `<workspace>/.claude/handoffs/<TICKET>/` and evaporate at session end.

---

## Step 1 — Analyze (`@ticket-analyzer`)

Fetch the ticket, parse summary + acceptance criteria + any linked spec. Write a
structured brief. **No** code or memory lookups here — that's the gatherer's job, scoped
to the terms this brief surfaces. Keeping analysis separate keeps each context focused.

## Step 2 — Gather context (`@context-gatherer`)

The expensive step, done in a **throwaway context**. Query memory for everything related
to the topic/component; use code-nav to map the blast radius (who consumes the thing
you're about to change). First-pass detection of coupling and stale wiring. Distil it
all into `context-gatherer.md` — the planner reads only this, not the raw sweep.

## Step 3 — Plan (`@planner`)

Consume both briefs. Do pinpoint code-nav reads to finalize the design. Produce a
step-by-step plan with **file/symbol targets** and a **risk assessment**, allocate work
to layer specialists in chain order, decide **slice-count** (1 = sequential;
>1 = decompose — see [09](09-decompose-path.md)), write the **final commit message**, and
create the feature branch (following the workspace new-branch workflow). The planner
**cannot** write to memory — design only.

## Step 3b — Grilling gate (human)

Before implementation, the planner surfaces only what the **code and briefs cannot
answer** — genuine product/spec decisions. For each, you either answer or **defer**:

- name **who owns** the answer (a person / a spec page / a future ticket),
- note **how expensive it is to reverse** if you guess wrong,
- let the planner proceed with a **sensible default or a placeholder** so dependent work
  isn't blocked.

Deferred questions are recorded in the durable ticket state so `/resume-ticket` can pick
them up when the answer arrives.

## Step 4 — Implement (layer specialists, in chain order)

Each specialist reads the planner + upstream-layer handoffs, implements its layer, runs
the local build/tests, and commits with **amend-as-you-go** so the branch stays **one
commit per repo**. It writes its own handoff (e.g. the contract the next layer must
honour). If two or more layers were touched, an **alignment gate** checks they agree
(column names ↔ field names ↔ payload members) before review.

## Step 5 — Review (`@reviewer`)

Re-fetch the ticket, walk the diff **in the home repo**, validate against acceptance
criteria, run the tests, check the commit convention (including one-commit-per-branch),
draft a **provisional** verdict + MR/PR description, then dispatch the senior reviewer.
Comments only — never edits code.

## Step 6 — Senior review (`@senior-reviewer`)

Cross-repo blast radius: contract/payload coupling, downstream consumers, schema
collisions, anything the in-repo view can't see. Appends findings; the first reviewer
consolidates them into the **final verdict**.

## Step 7 — Land

- **REQUEST CHANGES** → back to the relevant specialist (amend, don't add commits).
- **APPROVE** → consolidate the ticket's handoffs into **one durable memory** (root
  cause / design / blast radius / recipes), then the **human pushes and opens the
  MR/PR**. The agent never pushes.

---

## Why it's shaped this way

- **Analyzer ≠ gatherer ≠ planner** so no single context carries analysis + the heavy
  sweep + design at once.
- **Planner can't write memory / code** so design can't have side effects.
- **Reviewers can't edit** so review stays honest.
- **One commit per branch** so a ticket is one reviewable, revertable unit.
- **Human owns push/MR** so the irreversible outward step always has a person on it.
