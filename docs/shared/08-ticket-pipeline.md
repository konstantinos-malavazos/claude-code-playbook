# 08 — The `/start-ticket` pipeline, step by step

This is the flagship flow generalized. The tracker is never named — the installed adapter
at `~/.claude/tracker.md` answers for it (see
[`../../templates/trackers/README.md`](../../templates/trackers/README.md)). Substitute
your layer specialists for the implementer steps, and your git host for "MR/PR".

---

## Roles at a glance

| Step | Agent | Scope (tools) | Output |
|---|---|---|---|
| 1 | `ticket-analyzer` | tracker read only | `ticket-analyzer.md` — structured brief |
| 2 | `context-gatherer` | memory + Serena, read only | `context-gatherer.md` — distilled brief + blast-radius flags |
| 3 | `planner` | Serena read + branch creation; **no memory writes** | `planner.md` — plan, track allocation, final commit message, branch |
| 3b | grilling gate | (human) | answers or **deferred** open questions |
| 4 | layer specialists (in chain order) | **Serena edit** + build/test in their repo | code + `<layer>.md` handoff |
| 5 | `repo-reviewer` | Serena read, run tests; **comments only** | `repo-reviewer.md` — provisional verdict + MR description |
| 6 | `release-reviewer` | cross-repo Serena read; **comments only** | appended findings → final verdict |
| 7 | orchestrator + human | — | consolidated memory; agent pushes the branch where allowlisted, human opens the MR/PR |

Handoffs live in `<workspace>/.claude/handoffs/<TICKET>/` and evaporate at session end.

Every step from 2 onward is bound by the same rule: **Serena is the only sanctioned way
to read code, and the only sanctioned way to change it** (see
[04](04-serena.md#mandatory-not-preferred)). Steps 2, 3, 5 and 6 read through it; step 4
*writes* through it.

---

## Step 1 — Analyze (`@ticket-analyzer`)

Fetch the ticket, parse summary + acceptance criteria + any linked spec. Write a
structured brief. **No** code or memory lookups here — that's the gatherer's job, scoped
to the terms this brief surfaces. Keeping analysis separate keeps each context focused.

## Step 2 — Gather context (`@context-gatherer`)

The expensive step, done in a **throwaway context**. Query memory for everything related
to the topic/component; use Serena (`find_symbol`, `find_referencing_symbols`) to map the
blast radius (who consumes the thing you're about to change) — semantically, not by grep.
First-pass detection of coupling and stale wiring. Distil it
all into `context-gatherer.md` — the planner reads only this, not the raw sweep.

## Step 3 — Plan (`@planner`)

Consume both briefs. Do pinpoint Serena reads to finalize the design. Produce a
step-by-step plan with **Serena-verified file/symbol targets** and a **risk assessment**, allocate work
to layer specialists in chain order, decide **slice-count** (1 = sequential;
>1 = decompose — see [09](09-decompose-path.md)), write the **final commit message**, and
create the feature branch (following the new-branch workflow in the global `CLAUDE.md`,
onto the branch this repo ships from). The planner
**cannot** write to memory — design only.

## Step 3b — Grilling gate (human)

Before implementation, the planner surfaces only what the **code and briefs cannot
answer** — genuine product/spec decisions. For each, you either answer or **defer**, and a
deferral has to be managed rather than forgotten before the planner may proceed.
[`templates/skills/grilling/`](../../templates/skills/grilling/SKILL.md) owns what that
requires — including recording the open question in the durable ticket state, which is how
`/resume-ticket` picks it up when the answer arrives.

## Step 4 — Implement (layer specialists, in chain order)

Each specialist reads the planner + upstream-layer handoffs, implements its layer, runs
the local build/tests, and commits with **amend-as-you-go** so the branch stays **one
commit per repo**. It writes its own handoff (e.g. the contract the next layer must
honour). If two or more layers were touched, an **alignment gate** checks they agree
(column names ↔ field names ↔ payload members) before review.

Implementation is **Serena-only**: read the target symbol with `find_symbol` and its
callers with `find_referencing_symbols`, change it with `replace_symbol_body` /
`insert_after_symbol` / `rename_symbol` / `safe_delete_symbol`, then clear
`get_diagnostics_for_file` on every file touched *before* the build. `Edit`/`Write` on
code are reserved for languages Serena doesn't index — and if Serena can't act on an
assigned file, the specialist **stops and surfaces it** rather than downgrading.

## Step 5 — Review (`@repo-reviewer`)

Re-fetch the ticket, walk the diff **in the home repo**, validate against acceptance
criteria, run the tests, check the commit convention (including one-commit-per-branch),
draft a **provisional** verdict + MR/PR description, then dispatch `@release-reviewer`.
Comments only — never edits code.

## Step 6 — Release review (`@release-reviewer`)

Cross-repo blast radius: contract/payload coupling, downstream consumers, schema
collisions, anything the in-repo view can't see. Appends findings; the first reviewer
consolidates them into the **final verdict**.

## Step 7 — Land

- **REQUEST CHANGES** → back to the relevant specialist (amend, don't add commits).
- **APPROVE** → consolidate the ticket's handoffs into **one durable memory** (root
  cause / design / blast radius / recipes), then **the agent pushes the branch** where
  `~/.claude/repo-allowlist` permits it and the **human opens the MR/PR**. The agent never
  merges — push moves a branch, merge changes the trunk, and only the second one is the
  step this pipeline keeps for a person.

---

## Why it's shaped this way

- **Analyzer ≠ gatherer ≠ planner** so no single context carries analysis + the heavy
  sweep + design at once.
- **Planner can't write memory / code** so design can't have side effects.
- **Reviewers can't edit** so review stays honest.
- **One commit per branch** so a ticket is one reviewable, revertable unit.
- **Human owns push/MR** so the irreversible outward step always has a person on it.

[`examples/ticket-flow-walkthrough.md`](../../examples/ticket-flow-walkthrough.md) narrates
one invented ticket through all seven steps.

---
> **Last verified against:** Claude Code `2.1.226` — August 2026
