<!--
  TEMPLATE: per-repo instructions.
  Copy to <workspace>/<repo>/CLAUDE.md and fill in every <PLACEHOLDER>.
  This is LAYER 3 — facts true ONLY inside this repo. Loaded only when working here.
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

## Serena
- Verdict: **<yes / no>** — <if no, one line of why: e.g. "shell + YAML; there is no
  symbol graph to ask *who calls this?* of">.
- This line is the project's answer, and it overrides the global default. Nothing else
  restates it — see `docs/shared/04-serena.md`.

## Entry points / where things live
- <Startup / composition root>: `<path>`
- <The area this repo is usually changed in>: `<path>` (use Serena for the details)

## Local conventions that differ from the workspace default
- <e.g. this repo uses X test framework / Y folder layout / Z naming — only note the
  DIFFERENCES from the workspace CLAUDE.md.>

## Gotchas (things that will bite an agent)
- <e.g. "this service publishes event `X`; changing its payload breaks consumer repo
  `Y` — check before editing.">
- <e.g. "config key `Z` is duplicated across two files; keep them in sync.">

## The layer chain
<Keep ONE of the two shapes below and delete the other.>

**A. This repo IS the whole chain** (one repo, every layer — the usual solo shape):
- Chain: **<layer 1>** ──► **<layer 2>** ──► **<layer 3>**, one specialist agent per layer.
- Where each lives: `<path>` / `<path>` / `<path>`.

**B. This repo is ONE layer among sibling repos:**
- Layer: **<LAYER N>** — owned by `@<specialist-N>`.
- Reads the contract from: `<upstream layer / handoff>`.
- Writes the contract for: `<downstream layer / handoff>`.

## Do NOT
- <Anything specific to avoid here — e.g. "never hand-edit generated files under `gen/`".>
