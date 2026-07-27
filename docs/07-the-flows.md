# 07 — The flows (pillar three)

A **flow** is a slash command that orchestrates a chain of **scoped specialist agents**.
This is the part that makes the setup a *way of working* rather than two clever MCP
servers. Each flow encodes a repeatable process so you type one line instead of
re-driving the same ten steps by hand.

---

## The design ideas behind every flow

- **Sequential implementation chain.** A change moves through your stack in a fixed
  order (your `schema → service → consumer` equivalent). Flows execute that order.
- **Retrieval is offloaded.** A throwaway gatherer context does the heavy memory + code
  sweep and hands the planner a *distilled brief*. Cheap planner, focused design.
- **Each agent is scoped.** The analyzer reads the tracker but not code; the planner
  designs but can't write files; reviewers read but can't edit. Scope = cheap + safe.
- **Handoffs are files, not chat.** Agents pass context through
  `<workspace>/.claude/handoffs/<TICKET>/<agent>.md`, which **auto-delete at session
  end**. In-flight noise never pollutes durable memory.
- **Two-tier review.** `@repo-reviewer` works in-repo (diff, acceptance criteria, tests);
  `@release-reviewer` checks cross-repo blast radius (contract/payload coupling,
  downstream consumers, schema collisions).
- **One commit per branch per repo.** Amend-as-you-go; the reviewer asserts it.
- **Guardrails are hooks, not trust.** Push is hard-blocked; the tracker is read-only;
  AI-infra files are never committed.

---

## The flagship: `/start-ticket <TICKET-ID>`

Turns a ticket id into a reviewed, single-commit branch.

```
@ticket-analyzer      Jira → structured brief (no code/memory lookups)
        │
@context-gatherer     heavy memory + code-nav sweep in a THROWAWAY context;
        │             writes a distilled brief; read-only
@planner              consumes briefs → design + track allocation + branch;
        │             flags "decompose?" for very large tickets
   grilling gate      ask the human ONLY what the code/brief can't answer
        │             (open questions can be deferred — see below)
   {decompose?}
        ├── slice-count = 1 (the ~95% default):
        │     <layer-1 specialist> → <layer-2 specialist> → <layer-3 specialist>
        │     (sequential; ONE commit) → alignment gate (if 2+ layers touched)
        │
        └── slice-count > 1 (large ticket): see 09-decompose-path.md
              /to-spec → /to-tickets (slice board → human approves)
              → parallel slices in git worktrees → @aligner → @integrator
              → @integration-tester
        │
@repo-reviewer        in-repo: diff, acceptance criteria, tests, commit convention
        │
@release-reviewer     cross-repo blast radius
        │
   verdict ── REQUEST CHANGES ──► back to the specialists
        └──── APPROVE ──► consolidate the ticket into ONE durable memory
                          ──► YOU push & open the MR/PR
```

Full step-by-step: [08-ticket-pipeline.md](08-ticket-pipeline.md).

### Three things to notice while it runs

1. **Retrieval is offloaded** — the gatherer's expensive context is discarded; the
   planner only sees the brief.
2. **Models are matched to work** — a cheaper/faster model for mechanical, bounded tracks
   (analyzer, per-layer implementers); a stronger model for design, judgement, and
   review. Pin exact model *ids* so an alias doesn't silently downgrade you.
3. **Handoffs are files** — inspect them under `…/handoffs/<TICKET>/` while it runs; they
   vanish at session end.

---

## The flow catalogue

| Flow | What it does | Why it exists |
|---|---|---|
| **`/start-ticket`** | ticket id → reviewed single-commit branch (the flagship) | the default path for ~95% of tickets |
| **decompose path** | large ticket → independent **parallel slices** in git worktrees → one commit per repo | when a ticket is too big for one sequential pass. [09](09-decompose-path.md) |
| **`/fix-ticket`** | QA bounce-back → diagnose root cause → fix → **amend in place** | a returned ticket stays one ticket / one commit |
| **`/test-ticket`** | E2E **staging integration test** — produce the real event, reconcile the resulting row/state, **and bank/reuse a per-scenario test recipe in memory** | proves it works on staging *and* learns how to produce each scenario's events once, then reuses it |
| **`/resume-ticket`** | reopen an in-flight ticket across sessions; if it had **deferred decisions**, collect the now-available answers and re-enter in delta mode | tickets span days; open questions get answered later; state survives the handoff wipe via durable memory |
| **`/close-ticket`** | finalize + consolidate into memory | clean end-of-ticket bookkeeping |
| **`/end-of-day`** | **daily memory nomination**: harvest the day's durable conclusions, dedupe vs memory, approve each item individually | deliberate memory — nothing enters the knowledge base un-reviewed. [10](10-memory-hygiene.md) |
| **`/garden-memory`** | **periodic memory hygiene**: golden-query retrieval eval + duplicate/stale/orphan sweep with per-item approval | catches retrieval regressions; stops the memory decaying into a junk drawer. [10](10-memory-hygiene.md) |
| **`/confirm-deployment`** | **release gate** (not ticket-scoped): review a tag-to-tag delta across repos before a production deploy — code review + deploy-risk scan (migrations, queues, config/secrets) → GO/NO-GO | a last read-only safety net before prod |
| ad-hoc: **investigation** | read-only forensic agent: writes parametrised queries, proves root cause from returned data only, no prod writes | drift/discrepancy analysis without risk |

You don't need all of these. Start with `/start-ticket`; add the others as the pain they
solve shows up.

---

## The standout feature: `/test-ticket` *learns*

The hardest part of an end-to-end test is figuring out **how to produce the event**
(which message / API call, in what order, for that specific scenario). The first time
`/test-ticket` tests a `(scenario × event)` combination, it traces that path once and
**banks it in memory as a reusable recipe**. Every future test of that scenario **reuses
the banked recipe instead of re-deriving it**.

To stop the recipe silently rotting, each recipe stores a **fingerprint** of the flow it
was derived from (e.g. the ordered acceptance-test steps). On every reuse the planner
re-pulls the source and diffs the fingerprint — if the process changed, the recipe is
marked stale and re-derived. Memory that self-checks.

This is the compounding loop (PHILOSOPHY §4) applied to **testing**: the second time you
E2E-test a scenario, the agent doesn't re-learn how to produce it — it pulls the recipe
it banked last time, checks nothing moved, and runs it.

---

## Deferred decisions (the grilling gate)

Real tickets have open questions that only a human (or a spec that doesn't exist yet)
can answer. Rather than block, the grilling gate lets you **defer**: for each open
question, note who owns the answer and how expensive it is to reverse later, then plan
around it with a sensible default or a placeholder so dependent work isn't blocked. The
open questions are written into the durable ticket state so `/resume-ticket` can pick
them up days later when the answer lands. See [08-ticket-pipeline.md](08-ticket-pipeline.md).

---

## Hand-built flows vs dynamic workflows

A **dynamic workflow** is a different built-in mechanism: a JavaScript script Claude
writes for the task you describe, which a runtime executes in the background — fanning
work across subagents while your session stays responsive. Intermediate results live in
the script's variables, not the model's context.

The flows in this playbook are **hand-drawn topology** — you choose the agents, the
order, and the handoffs, and every hook in `templates/hooks/` fires at each step. A
dynamic workflow is **generated topology** — you describe the goal and Claude writes the
plan, so the shape can differ run to run.

**Decide between them like this:**

- **Hand-built flow** — the shape of the work is known and repeats, and you want the
  guardrail hooks enforced at each step. The ticket pipeline is the canonical case.
- **Dynamic workflow** — the shape depends on what's actually in the repo and the width
  isn't known up front: "audit every file under `<PATH>`," "port every module in `<DIR>`."
- **Neither** — the task is one change in one file. See
  [13-when-not-to-use.md](13-when-not-to-use.md).

**Verified constraints** (see the [workflows docs](https://code.claude.com/docs/en/workflows)):

- Requires Claude Code v2.1.154+; available on all paid plans. On Pro, enable it via the
  "Dynamic workflows" row in `/config`. On by default for Max, Team, and Enterprise; an
  org can disable it via managed settings.
- Trigger with the keyword `ultracode` in your prompt, or plain phrasing like "use a
  workflow" / "run a workflow." (Before v2.1.160, the literal word "workflow" was the
  only trigger.)
- `/effort ultracode` makes Claude choose a workflow for every substantive task in the
  session.
- Runtime caps: 16 concurrent agents (fewer on low-core machines), 1000 agents total per
  run. These are hard caps.
- As of v2.1.219, the "Dynamic workflow size" guideline defaults to medium (aim for
  fewer than 15 agents). It's advisory, not a cap — a prompt calling for a different
  scale overrides it. Set it from any settings file with the `workflowSizeGuideline`
  key, the form worth templating; the `/config` row hides once one is set.
- No mid-run user input — the script coordinates agents but has no direct filesystem or
  shell access itself.
- Monitor a run with `/workflows`; press `s` on a finished run to save its script as a
  command, to `.claude/workflows/` (project, shared) or `~/.claude/workflows/` (personal).
- Resume only works within the same session — exiting Claude Code restarts the workflow
  next session.
- `/deep-research` is the bundled workflow — the cheapest way to see the machinery before
  writing your own; since v2.1.218 it only runs when you invoke it.

### Where the guardrails stop

Agents spawned inside a workflow always run in `acceptEdits` mode and inherit the
session's tool allowlist regardless of the session's own permission mode — file edits are
auto-approved. The hooks in `templates/hooks/` are **not** a step-level gate inside a
workflow, and there is no mid-run intervention once it starts.

What actually remains under your control:
- **Scope the run narrowly** — a broad goal is a broad blast radius, since nothing checks
  each step as it happens.
- **Set the tool allowlist before starting** — it's inherited, not renegotiated per agent.
- **Pin `workflowSizeGuideline` in settings** — a stable, reviewable default beats
  relying on whatever the model infers per prompt.
- **Read the plan at the approval prompt** — that's the one checkpoint before the script
  runs unattended.
-e 
---
> **Last verified against:** Claude Code `2.1.219` — July 2026
