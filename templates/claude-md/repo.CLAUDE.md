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

## Build / test / run
```
# install:   <command>
# build:     <command>
# test:      <command>
# run local: <command>
```

## Main branch (prod target)
- This repo ships from **`<main|develop|...>`**. Rebase onto it before cutting a feature
  branch — the workflow itself is in the global `CLAUDE.md`; this line supplies the name.
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

## Do NOT
- <Anything specific to avoid here — e.g. "never hand-edit generated files under `gen/`".>
