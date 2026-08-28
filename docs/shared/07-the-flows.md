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
2. **Models are matched to work, and then to the ticket.** Pin a cheap, fast model on
   mechanical, bounded tracks (analyzer, per-layer implementers) and a stronger one on
   design, judgement and review. Then let the planner's per-track **weight** raise an
   implementer for one run when the ticket is shaped badly for a cheap model — see
   [Model escalation](#model-escalation-cheap-by-default-escalated-by-weight). Pin exact
   model *ids* so an alias does not silently downgrade you.
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

## Model escalation: cheap by default, escalated by weight

An agent's `model:` is a static property of its file. The difficulty of the ticket it is
about to be handed is not. This section is the missing dial between the two.

### Why pipeline position is the wrong thing to price on

- **An agent loop re-sends its accumulated context on every step.** A track's cost is
  therefore *steps x context size*, and the context grows as the steps accumulate. That is
  **superlinear in steps, not linear in tokens**. A model that is cheaper per token but
  takes several times more steps on a long task costs **more** per ticket, not less.
- **Upstream planning removes DISCOVERY steps from the implementer. It does not remove
  EDITING steps.** The gatherer and the planner hand over Serena-verified file/symbol
  targets, so the implementer stops hunting. It still has to hold several files consistent
  through a signature change, and **that** is where step count explodes. No amount of
  planning upstream makes that part cheaper.
- **Therefore: pipeline position does not decide the implementer's model. Ticket shape
  does.** *"Implementers are mechanical, so implementers are cheap"* prices the **role**.
  The cost lives in the **ticket**.

> **One measurement, and it is a snapshot rather than a recommendation.** As of **August
> 2026**, the [DeepSWE long-horizon benchmark](https://deepswe.datacurve.ai/) measured a
> cheaper-per-token model taking roughly **2.7x the steps** of a stronger one on multi-file
> repository tasks, and costing about **twice as much per task** as a result. Read it as an
> illustration of the mechanism above — steps, not token price, set the bill — and not as a
> standing verdict on any named model. Re-measure before you rely on the ratio: every model
> in it will have moved.

### a. The weight is per dispatch, not per ticket

**This is the part most setups get wrong**, and it is worth doing before anything else:
**inventory every place your pipeline hands work to an implementation agent.** In a mature
pipeline it is five or six sites, and typically **only one of them has the plan in hand**.

**Run the inventory off the tool lists, not off the job titles.** The test is *can this agent
edit code* — grep your agent files for the edit verbs and see which ones come back. Reading
the names instead misses the agents that quietly write and amend (a cross-slice test writer
is an editing agent) and wastes weights on the ones that only look like implementers. An
agent that edits but already pins the strong tier needs no weight either, because a weight
may only raise its floor.

| # | Dispatch site | Has the plan? | Weighed by |
|---|---|---|---|
| 1 | the initial track dispatch, in chain order | **yes** | `@planner`, in the plan |
| 2 | each parallel slice on the decompose path ([09](09-decompose-path.md)) | yes, per slice | `@planner`, per slice |
| 3 | the **review-fix re-pass** after `REQUEST CHANGES` | no | `@repo-reviewer`, in the verdict |
| 4 | the **drift fix** after the alignment gate | no | `@aligner`, with its drift report |
| 5 | the QA bounce-back (`/fix-ticket`) | no | `@fixer-planner`, in the fix plan |
| 6 | a secondary command that dispatches a specialist directly (`/build-chart-ticket`) | its own | its own planner step |

**A `weight` field on the plan covers site 1 and silently misses the rest.** Site 3 is the
most expensive one to miss: it is where a track that has *just failed review* gets handed
back to the same model that failed it, on the reasoning that the ticket was classified light
an hour ago.

Whoever has just looked at the work does the weighing. **The orchestrator never computes one
itself** — it reads the weight and routes. That keeps the judgement with the agent holding
the evidence, and keeps the orchestrator scoped to the one job it has.

### b. One definition, many call sites

The classification rule lives in **one named unit** that every dispatch site invokes:
[`templates/skills/dispatch-weight/`](../../templates/skills/dispatch-weight/SKILL.md).

Six sites restating "heavy means more than N files" is six copies of a threshold. They will
not be six copies for long. Tune the criteria **in the skill**, and every site moves at once
— the same argument this repo already makes for generating layer specialists instead of
copying them ([11](11-adapting-to-your-stack.md)).

### c. The rule itself

Classify **the change about to be made** as `light` or `heavy`, with a **one-line reason
naming the criterion that fired**. Suggested starting criteria, to be tuned per team: file
count over a threshold, more than one repo, a shared contract or signature with multiple
callers, a placeholder seam left by a deferred decision
([the grilling gate](#deferred-decisions-the-grilling-gate)) — and, on a fix pass, several
review findings against one track, or **any** finding saying the *design* was wrong rather
than the details.

The reason line is what makes the thresholds auditable later, and
[the calibration loop below](#calibrating-it-and-the-trap-it-catches) reads those lines. A
weight nobody can audit drifts.

### d. Three invariants, and what breaks without each

| Invariant | The rule | What happens without it |
|---|---|---|
| **Asymmetry** | Raise on suspicion, lower only on evidence. | The cheap direction wins ties — and its failures are the ones invisible in the output. |
| **Ratchet** | A re-dispatch never runs below the tier that track last ran at. | A fresh classification sends a track that just failed review back to the model that failed it. The classification is not wrong; it answered a question about the fix while the evidence was about the model. |
| **Floor** | The frontmatter `model:` is a floor a weight may raise and never lower. | A per-dispatch heuristic silently overrules a decision made by somebody who knew the agent — once per dispatch, forever. |

The ratchet is also why *"escalate one tier whenever review sends it back"* is not a
substitute for re-classifying. It is wrong twice: a returned ticket can be a one-line rename
that needs nothing, and on a track that was **already** `heavy`, *one tier up* names nothing
at all.

### e. Pin exact model ids — and know where you cannot

> **Footgun: a bare tier alias is not a model id.** An alias resolves to whatever the org
> default for that tier currently is, which is usually **a generation behind what you meant**,
> and it moves under you with no diff and no notice. The failure is silent in both
> directions: you never see the downgrade, and the bill never explains itself. The same rule
> is stated for the frontmatter in
> [`templates/agents/README.md`](../../templates/agents/README.md).
>
> **The dispatch override can only name a tier.** Verified against Claude Code `2.1.226`:
> the subagent dispatch takes a **tier alias** — one of a short fixed list of tier names,
> `<MODEL-TIER-ALIAS>` — and **not** a full model id. So the frontmatter is the only place an
> exact id can be pinned, and an
> escalated run lands on whatever that tier resolves to on the day. **That is a known cost of
> escalating, not a step you forgot to configure.** Re-check it after an upgrade: the answer
> is a property of the harness, not of this playbook.

### Why not two versions of each agent

The obvious alternative is a cheap twin and a strong twin of every implementer, and it does
buy the one thing the override cannot: an **exact** id on the escalated path. Take the
override anyway.

**The model is a dispatch parameter, not part of an agent's identity.** Fork an agent when
its **behaviour** differs — a different worktree, a different handoff path, different commit
rules. That is why `slice-layer-specialist` exists next to `layer-specialist`
([09](09-decompose-path.md)): slice mode changes where the agent works and what it commits,
not how clever it is. Never fork one because only its capability tier differs.

**The cost compounds, and this pipeline already forks for behaviour.** Two variants per role
become **four** the moment you add a tier axis to the slice axis, and every behaviour fix
then has to land in all four. That is transcription with a multiplier, and this repo already
refuses hand-copying for exactly that reason: *"Copying is transcription, and transcription
drifts"* ([11](11-adapting-to-your-stack.md)).

**If you genuinely need the exact id, generate the twin rather than copying it.** The layer
specialists are already generated one per layer by
[`/adapt-to-stack`](11-adapting-to-your-stack.md) from a single source, so a second file
written from that same source inherits the generator's answer to drift. It is a change to the
generator's contract: decide it **once, deliberately** — not per layer and not per ticket.

### Calibrating it, and the trap it catches

**Log four things in the track's handoff at every dispatch — the dispatched model, the
weight, the reason, and the pass number** — then read them back across several tickets. The
pass number is what turns the log into a signal: it separates *classified light and finished*
from *classified light three times and still going*. Two readings, two different fixes:

- **Tracks dispatched `light` keep failing review** → the **thresholds are too loose**.
  Tighten the criteria in the skill until the flag predicts the failures.
- **Nearly every dispatch classifies heavy** → the model is not the problem. **The tickets
  are too big**, and the fix belongs in the ticket-cutting stage — the decompose path
  ([09](09-decompose-path.md)) or `/cut-backlog` ([solo 05](../solo/05-cutting.md)) — not in
  the dispatch line.

Worth saying plainly, because the second reading is the easy one to miss: **reaching for a
bigger model is the cheaper-looking way to hide a sizing problem.** It works, it never shows
up in a diff, and it bills you for the sizing problem once per ticket instead of once.

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
