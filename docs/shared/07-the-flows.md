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
- **Two-tier review.** `@repo-reviewer` works in-repo (diff, acceptance criteria, tests).
  `@release-reviewer` checks cross-repo blast radius (contract/payload coupling,
  downstream consumers, schema collisions).
- **One commit per branch per repo.** Amend-as-you-go; the reviewer asserts it.
- **Guardrails are hooks, not trust.** Push is blocked unless the repo is allowlisted. The
  tracker is read-only. AI-infra files are never committed, **except the repo's own
  `CLAUDE.md` and the generated `.claude/agents/` and `.claude/skills/`, which a fresh
  clone needs**.

---

## The flagship: `/start-ticket <TICKET-ID>`

Turns a ticket id into a reviewed, single-commit branch.

```
@ticket-analyzer      tracker → structured brief (no code/memory lookups)
        │
@context-gatherer     heavy memory + Serena sweep in a THROWAWAY context;
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

1. **Retrieval is offloaded.** The gatherer's expensive context is discarded. The planner
   only sees the brief.
2. **Models are matched to work.** Use a cheaper, faster model for mechanical, bounded
   tracks (analyzer, per-layer implementers). Use a stronger model for design, judgement
   and review. Pin exact model *ids* so an alias does not silently downgrade you.
3. **Handoffs are files.** Inspect them under `…/handoffs/<TICKET>/` while it runs. They
   vanish at session end.

---

## The flow catalogue

| Flow | What it does | Why it exists |
|---|---|---|
| **`/start-ticket`** | ticket id → reviewed single-commit branch (the flagship) | the default path for ~95% of tickets |
| **`/pitch`** *(solo)* | raw idea → a **verdict**: build, kill or park. Six questions in about an hour, two cold search subagents, and an anonymised `pitch-judge` | the furthest upstream thing here, because it runs before a repo exists. Stops ideas that should never reach a pipeline at all. [solo 02](../solo/02-the-kill-gate.md) |
| **`/charting`** | foggy effort → a **map** of tickets on the tracker, resolved one per session until nothing is left to decide. Generates the **dependency picture** on demand | upstream of everything here: work too big for one session and too foggy to plan. Hands off to `/start-ticket` once the route is clear. **Both entrances run it.** [solo 03](../solo/03-charting.md) is stage 2 on a greenfield repo; run it directly on a codebase that already exists, which is also what [team 03](../team/03-massive-tickets.md) wraps its three commands around |
| **`/bootstrap`** *(solo)* | decided-but-empty repo → a **scaffolded one**, plus one report: seven checks, evidence per row, no classification | the only flow that runs **once per project**. It makes `/start-ticket`'s preconditions true — including the layer specialists, which it calls `/adapt-to-stack` to generate. [solo 04](../solo/04-the-bootstrap.md) |
| **`/cut-backlog`** *(solo)* | closed map + scaffolded repo → an ordered **backlog** of work units, approved on a board before anything is created, then the same **dependency picture** over the tickets that now exist | the last stage of the solo path, and where it stops. Units are cut from the **smallest version**, not from the map's decisions — one unit = one thing the app can now do. [solo 05](../solo/05-cutting.md) |
| **`/prototype`** | a design question nobody can settle on paper → **throwaway code built to be reacted to and then deleted**: one interactive harness for *does this logic hold up*, or several radically different takes on one screen for *what should this look like* | some decisions only get answered by looking at them run. It is the skill behind charting's `prototype` ticket type — and the reaction is the output, so an agent that builds three variants and picks one has answered nothing. [`templates/skills/prototype/`](../../templates/skills/prototype/SKILL.md) |
| **`/adapt-to-stack`** | a repo's `CLAUDE.md` → **one layer specialist, its slice-mode variant and one standards skill per layer**, in that repo's own `.claude/`, created and never overwritten, ending in one report | the chain is written down once and everything downstream is generated from it — copying it by hand is transcription, and transcription drifts. **Not a stage**: it runs wherever the layer files first get made real, and again every time the chain grows. [11](11-adapting-to-your-stack.md) |
| **decompose path** | large ticket → independent **parallel slices** in git worktrees → one commit per repo | when a ticket is too big for one sequential pass. [09](09-decompose-path.md) |
| **`/start-massive`** *(team)* | a **foggy** ticket on an existing codebase → a local map of small tickets, then stops | `/charting` pointed at a mature multi-repo workspace instead of a greenfield repo. Use when you sit down to plan and cannot. [team 03](../team/03-massive-tickets.md) |
| **`/resume-massive`** *(team)* | walks that map — one ticket per session: claim, dispatch by type, gist, close, regenerate. Owns the three endings and the closing review sequence | a map runs for weeks; every session has to start from the map rather than from memory. [team 03](../team/03-massive-tickets.md) |
| **`/build-chart-ticket`** *(team)* | one `make:<layer>` ticket off a map → gatherer delta → planner → the single layer specialist the label names → review, but only once that repo has no other makes left | the map already decomposed the work, so this deliberately has **no** track allocation and no slice fork. [team 03](../team/03-massive-tickets.md) |
| **`/fix-ticket`** | QA bounce-back → diagnose root cause → fix → **amend in place** | a returned ticket stays one ticket / one commit |
| **`/test-ticket`** | E2E **integration test** against staging, or against **local** where there is no staging tier — produce the real event, reconcile the resulting row/state, **and bank/reuse a per-scenario test recipe in memory** | proves it works where it will actually run *and* learns how to produce each scenario's events once, then reuses it |
| **`/resume-ticket`** | reopen an in-flight ticket across sessions; if it had **deferred decisions**, collect the now-available answers and re-enter in delta mode | tickets span days; open questions get answered later; state survives the handoff wipe via durable memory |
| **`/close-ticket`** | finalize + consolidate into memory | clean end-of-ticket bookkeeping |
| **`/end-of-day`** | **daily memory nomination**: harvest the day's durable conclusions, dedupe vs memory, approve each item individually | deliberate memory — nothing enters the knowledge base un-reviewed. [10](10-memory-hygiene.md) |
| **`/garden-memory`** | **periodic memory hygiene**: golden-query retrieval eval + duplicate/stale/orphan sweep with per-item approval | catches retrieval regressions; stops the memory decaying into a junk drawer. [10](10-memory-hygiene.md) |
| **`/confirm-deployment`** | **release gate** (not ticket-scoped): review a tag-to-tag delta across repos before a production deploy — code review + deploy-risk scan (migrations, queues, config/secrets) → GO/NO-GO | a last read-only safety net before prod |
| ad-hoc: **investigation** | read-only forensic agent: writes parametrised queries, proves root cause from returned data only, no prod writes | drift/discrepancy analysis without risk |

You don't need all of these. Start with `/start-ticket`. Add the others as the pain they
solve shows up.

**`(solo)` / `(team)` marks a flow only one entrance installs.** Unmarked means both. The
template READMEs carry the same split per file:
[commands](../../templates/commands/README.md), [agents](../../templates/agents/README.md),
[skills](../../templates/skills/README.md). They are the authority on what to copy.
Note `/charting` is deliberately unmarked while all three `*-massive` flows are team. The
skill is shared, but the flow wrapped around it is not.

**The dependency picture has no row of its own because it is not a flow.** It has no
command and no agents. It is a page ([`templates/views/`](../../templates/views/README.md))
that two of the flows above fill with data and open, for the trackers that cannot draw
their own dependencies.

---

## The standout feature: `/test-ticket` *learns*

The hardest part of an end-to-end test is working out **how to produce the event**
(which message / API call, in what order, for that specific scenario). The first time
`/test-ticket` tests a `(scenario × event)` combination, it traces that path once. It then
**banks it in memory as a reusable recipe**. Every future test of that scenario **reuses
the banked recipe instead of re-deriving it**.

To stop the recipe silently rotting, each recipe stores a **fingerprint** of the flow it
was derived from (e.g. the ordered acceptance-test steps). On every reuse the planner
re-pulls the source and diffs the fingerprint. If the process changed, the recipe is
marked stale and re-derived. Memory that self-checks.

This is the compounding loop (PHILOSOPHY §4) applied to **testing**. The second time you
E2E-test a scenario, the agent does not re-learn how to produce it. It pulls the recipe
it banked last time, checks nothing moved, and runs it.

---

## Deferred decisions (the grilling gate)

Real tickets have open questions that only a human (or a spec that doesn't exist yet)
can answer. Rather than block, the grilling gate lets you **defer**. A deferred question
is managed, not forgotten, so dependent work proceeds. `/resume-ticket` can pick it up
days later when the answer lands. What *managed* requires is owned by
[`templates/skills/grilling/`](../../templates/skills/grilling/SKILL.md). Where the gate
sits in the pipeline is [08-ticket-pipeline.md](08-ticket-pipeline.md).

---

## Hand-built flows vs dynamic workflows

A **dynamic workflow** is a different built-in mechanism. Claude writes a JavaScript
script for the task you describe, and a runtime executes it in the background. The script
fans work across subagents while your session stays responsive. Intermediate results live
in the script's variables, not the model's context.

The flows in this playbook are **hand-drawn topology**. You choose the agents, the order
and the handoffs, and every hook in `templates/hooks/` fires at each step. A dynamic
workflow is **generated topology**. You describe the goal and Claude writes the plan, so
the shape can differ run to run.

**Decide between them like this:**

- **Hand-built flow** — the shape of the work is known and repeats, and you want the
  guardrail hooks enforced at each step. The ticket pipeline is the canonical case.
- **Dynamic workflow** — the shape depends on what's actually in the repo and the width
  isn't known up front: "audit every file under `<PATH>`," "port every module in `<DIR>`."
- **Neither** — the task is one change in one file. See
  [12-when-not-to-use.md](12-when-not-to-use.md).

**Verified constraints** (see the [workflows docs](https://code.claude.com/docs/en/workflows)):

- Requires Claude Code v2.1.154+. Available on all paid plans. On Pro, enable it via the
  "Dynamic workflows" row in `/config`. On by default for Max, Team and Enterprise, but an
  org can disable it via managed settings.
- Trigger with the keyword `ultracode` in your prompt, or plain phrasing like "use a
  workflow" / "run a workflow." (Before v2.1.160 the literal keyword was `workflow`;
  the plain phrasing has always worked, in both versions.)
- **The keyword is an opt-in only in a prompt you type yourself.** As of v2.1.210 it does
  **not** start a workflow from `claude -p`, a scheduled task, an SDK prompt not stamped
  as human input, or a webhook/PR comment relayed into the session. A flow cannot trigger
  one on your behalf.
- `/effort ultracode` makes Claude choose a workflow for every substantive task in the
  session. To start a session already in it, `claude --effort ultracode` — **v2.1.203+**.
- Runtime caps: 16 concurrent agents (fewer on low-core machines), 1000 agents total per
  run. These are hard caps.
- The "Dynamic workflow size" guideline needs **v2.1.202+**. Before that there was no
  guideline and the effective behaviour was `unrestricted`. Values map to agent counts —
  `small` <5, `medium` <15, `large` <50, `unrestricted` none. **As of v2.1.219 the default
  is `medium`**. Earlier versions still defaulted to `unrestricted`. It's advisory, not a
  cap, because a prompt calling for a different scale overrides it. Set it from any
  settings file with the `workflowSizeGuideline` key, the form worth templating. The
  `/config` row hides once one is set.
- A run that grows unusually large gets a **`Large workflow` warning** on its progress
  line — more than 25 agents scheduled, or a projected token total past 1.5M
  (**v2.1.203+**). It is advisory: it does not pause or cap the run. Choosing a size
  guideline replaces the 25-agent threshold with that guideline's count, and sessions with
  ultracode on never show it.
- **"No mid-run user input" is narrower than it sounds.** The *script* cannot ask you
  anything, and it has no direct filesystem or shell access. Agents do the reading,
  writing and running. But **agent permission prompts still interrupt**: a shell command,
  web fetch or MCP call outside your allowlist prompts you mid-run. Allowlist what the
  agents need *before* a long run, or it will stop and wait for you. For genuine sign-off
  between stages, run each stage as its own workflow.
- **The spawned subagents always run in `acceptEdits`, whatever the session's permission
  mode**, and inherit your tool allowlist. File edits are auto-approved inside a run. Know
  that before you point one at a repo you care about.
- Monitor a run with `/workflows`. Press `s` on a finished run to save its script as a
  command, to `.claude/workflows/` (project, shared) or `~/.claude/workflows/` (personal).
- Resume only works within the same session. Exiting Claude Code restarts the workflow
  next session.
- `/deep-research` is the bundled workflow, and the cheapest way to see the machinery
  before writing your own. Since v2.1.218 it only runs when you invoke it.

### Where the guardrails stop

Agents spawned inside a workflow always run in `acceptEdits` mode, whatever the session's
own permission mode is. They inherit the session's tool allowlist, and file edits are
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

---
> **Last verified against:** Claude Code `2.1.226` — August 2026
