<!--
  TEMPLATE: per-repo instructions.
  Copy to <repo>/CLAUDE.md and fill in every <PLACEHOLDER>. One per repo, always.
  This is LAYER 3 — facts true ONLY inside this repo. Loaded only when working here.
  With one repo this is the ONLY CLAUDE.md below the global one; there is no layer 2.
  Keep it LEAN: the 20 facts that stop a wrong turn, not a re-description of the repo.
  Point, don't paste — where Serena applies, let it find the code details.
  See docs/shared/06-claude-md-layers.md.
-->

# <REPO NAME>

## What this repo is
<One or two sentences: stack, and what it's responsible for in the workspace.>

## Settled names
<The words this project uses for things — one line each, copied from the map's Notes and
already pruned of the ones that died. A name earns a line only if it is contested, or if a
newcomer would read it wrong. DELETE the example and leave the section empty if the effort
settled none — empty is a valid answer, not a gap.>
- **<name>** — <what it means here; and what it is NOT, where the ordinary reading differs.>

## Build / test / run
```
# install:   <command>
# build:     <command>
# test:      <command>
# run local: <command>
```

## Main branch (prod target)
- This repo ships from **`<main|develop|...>`**. Rebase onto it before cutting a feature
  branch. The workflow itself is in the global `CLAUDE.md`; this line supplies the name.
- Detect rather than guess: `git symbolic-ref refs/remotes/origin/HEAD`.

## Serena
- Verdict: **<yes / no>** — <if no, one line of why: e.g. "shell + YAML; there is no
  symbol graph to ask *who calls this?* of">.
- This line is the project's answer, and it overrides the global default. Nothing else
  restates it — see `docs/shared/04-serena.md`.

## Entry points / where things live
- <Startup / composition root>: `<path>`
- <The area this repo is usually changed in>: `<path>` (use Serena for the details)

## Local conventions that differ from the default
- <e.g. this repo uses X test framework / Y folder layout / Z naming — only note the
  DIFFERENCES from the layer above: the workspace CLAUDE.md if you have sibling repos,
  otherwise the global one.>

## Gotchas (things that will bite an agent)
- <e.g. "this service publishes event `X`; changing its payload breaks consumer repo
  `Y` — check before editing.">
- <e.g. "config key `Z` is duplicated across two files; keep them in sync.">

## The layer chain
<Keep ONE of the two shapes below and delete the other.>
<This section is what generates the layer specialists — see docs/shared/11-adapting-to-your-stack.md.>

**A. This repo IS the whole chain** (one repo, every layer — the usual solo shape):
- Chain: **<layer 1>** ──► **<layer 2>** ──► **<layer 3>**, one specialist agent per layer.
- Where each lives: `<path>` / `<path>` / `<path>`.

**B. This repo is ONE layer among sibling repos:**
- Layer: **<LAYER N>** — owned by `@<specialist-N>`.
- Reads the contract from: `<upstream layer / handoff>`.
- Writes the contract for: `<downstream layer / handoff>`.

**Model per layer — OPTIONAL, and normally omitted.** State one only where you genuinely
know that layer is mechanical or design-heavy; a stated id is written into that
specialist's `model:`, and an absent one means the field is left out and the specialist
inherits whatever you picked for the session. **Omitting is the right day-one answer** —
on a new repo nobody knows yet, guessing from a layer's name is guessing, and model ids
rot. Delete these lines if you are stating none — and an unfilled `<model-id>` left behind
counts as absent, never as a model called `<model-id>`.
- <layer 1>: `<model-id>`
- <layer 2>: `<model-id>`

## Testing seams
<This section is the whole stack half of `/test-ticket` — see docs/shared/07-the-flows.md.
`@test-planner` and `@tester` read it and take NOTHING else about your stack from anywhere
else. Absent or still bracketed, they STOP and name the line they needed. They never guess a
produce path: a test that produced nothing and reconciled nothing still returns a normal-
shaped report, and nothing downstream can tell that apart from a pass.>

- **Environment.** Target `<staging | local>`; hosts `<…>`. REFUSE outright: `<prod patterns>`.
  <Staging where you have one, local where you don't. If local, say what local IS — a compose
  file, a seeded database, a fake broker. "Local" alone is not an answer an agent can act on.>
- **Recipe key.** `<scenario> × <event>` | `<tenant> × <scenario> × <event>`
  <What makes two recipes different — the generalisation of the `(scenario × event)` pair in
  docs/shared/07-the-flows.md. Add a part for every axis that genuinely changes the produce
  path: a tenant, a region, a plan tier. The event is always the last part. Too few parts and a
  recipe gets reused across paths that differ — and the failure is silent, because the wrong
  recipe still runs and still lands a row.>
- **Flow source.** `<path or repo stating the flow of record>` · make current: `<command>`
  <Whatever a human would read to learn *what has to happen, in what order*: an acceptance-test
  suite, an API contract, a spec. `@test-planner` fingerprints it and diffs that fingerprint
  before it reuses any banked recipe. **NONE is a valid answer** — say so explicitly, and accept
  that recipes degrade from *verified before reuse* to *banked and trusted*.>
- **Produce driver.** `<command>`
  Contract: `<cmd> --event <name> --key <k=v>… --payload <json>` → stdout: the ids it created.
  Non-zero exit means nothing was produced.
  <**The project owns this; `@tester` calls it and never reimplements it.** An agent hand-rolling
  a multi-call auth chain writes a new produce path instead of exercising yours, and then proves
  the new one. If you have no driver, the honest ladder is: an HTTP endpoint that starts the flow
  → a project CLI → a direct queue publish, last. **No driver and no ladder means `/test-ticket`
  cannot run here** — say that, rather than leaving the line bracketed.>
- **Verify store.** read via `<command>` → lands in `<store / table / key>`
  <How `@tester` reads back, read-only, always. Same ladder shape: a connected MCP server → a CLI
  client → an HTTP read. The agent composes the query; this line only says how a query runs.>
- **Propagation.** timeout `<90s>` · poll `<2s>` · stable reads `<2>`
  <Landing is asynchronous and it flaps. One matching read is not proof — a late re-sync can
  revert a row that was already correct. N consecutive matching reads is proof.>

## Do NOT
- <Anything specific to avoid here — e.g. "never hand-edit generated files under `gen/`".>
