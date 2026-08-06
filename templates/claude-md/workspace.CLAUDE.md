<!--
  TEMPLATE: workspace / multi-repo atlas.
  Copy to <workspace>/CLAUDE.md and fill in every <PLACEHOLDER>.
  This is LAYER 2 — the map of THIS workspace: which repos exist, which branch ships,
  how a change moves through the stack. Auto-loaded for any repo under the workspace.
  ONLY IF YOU HAVE SIBLING REPOS. With a single repo there is no layer 2 — skip this
  file; its facts live in the global and per-repo layers.
  See docs/shared/06-claude-md-layers.md and docs/shared/11-adapting-to-your-stack.md.
-->

# <WORKSPACE NAME> — workspace atlas

You are inside a multi-repo workspace. Each subfolder is an independent git repo with its
own `CLAUDE.md`. Cross-repo edits are normal and ALLOWED — the sequential chain below is
the dominant change pattern.

## Repo map

| Path | Stack | Purpose | Default specialist |
|---|---|---|---|
| `<repo-a>/` | <stack> | <what it does> | `@<layer-1-specialist>` |
| `<repo-b>/` | <stack> | <what it does> | `@<layer-2-specialist>` |
| `<repo-c>/` | <stack> | <what it does> | `@<layer-3-specialist>` |

## Main branch per repo (prod target)

The branch each repo ships to production from. Rebase onto this before cutting a feature
branch. (Repos differ — write them down; don't assume.)

This table is an **index**, not the owner: each repo also states its own branch in its
`CLAUDE.md`. It earns its place because working in `<repo-a>/` you may need what
`<repo-b>/` ships from, and `<repo-b>/CLAUDE.md` is not loaded.

| Repo | Main branch |
|---|---|
| `<repo-a>` | `<main|develop|...>` |
| `<repo-b>` | `<main|develop|...>` |

For any repo not listed: detect via `git symbolic-ref refs/remotes/origin/HEAD` and ASK
before branching.

## New-branch workflow

The sequence and its stop rules are in the **global** `CLAUDE.md` — identical in every
repo, so it is stated once there. The only workspace-specific input is the branch name,
from the table above.

## Sequential implementation chain (MANDATORY order)

For any change touching multiple layers, follow this order. Never reverse. Each layer
hands the next a contract.

1. **<LAYER 1>** (`@<specialist-1>`): <what it changes> in `<repo>`. Writes the
   contract to `.claude/handoffs/<TICKET-ID>/<specialist-1>.md`.
2. **<LAYER 2>** (`@<specialist-2>`): <what it changes>, honouring layer-1's contract.
3. **<LAYER 3>** (`@<specialist-3>`): <what it changes>, honouring layer-2's contract.

Single-layer tickets skip the chain (only the relevant specialist runs).

## Cross-repo rules

Cross-repo search/exploration is ALLOWED when tracing a contract across repos. Default to
the active repo when scope is ambiguous; widen on demand.

## Canonical mappings (source of truth)

<If you have a lookup table everything depends on — environments, service codes, an
id↔name map — put it here ONCE, or point to the one file that owns it. Never paste it
into per-repo files.>

## Handoffs

Ephemeral pipeline state → `<workspace>/.claude/handoffs/<TICKET-ID>/<agent>.md`
(`.gitignore`d, cleared at session end). Durable knowledge → memory, on APPROVE only.
