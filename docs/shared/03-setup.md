# 03 — Setup from a clean machine

Order matters: capabilities first, then structure, then flows. You have a working setup
after step 4; steps 5–7 are additive.

---

## Step 1 — Install Claude Code and confirm it runs

Install the CLI (or desktop/IDE), authenticate, and run it once in a scratch folder to
confirm it starts. Pick your model and effort level in `~/.claude/settings.json` (see
[`../../templates/mcp/settings.json.snippet`](../../templates/mcp/settings.json.snippet)).

## Step 2 — Stand up Serena (eyes)

Serena is **mandatory** in this playbook, for reading code *and* for editing it
([04-serena.md](04-serena.md#mandatory-not-preferred)) — so get this step right before
anything else. Two install routes; pick one.

**Route A — plugin (simplest, recommended).** Install the `serena` plugin from the
official marketplace (`/plugin`). It runs Serena via `uvx` straight from upstream, so
there's no server to babysit and it updates with the plugin. Requires `uv` on PATH.

**Route B — project-scoped MCP server.** Run Serena yourself (follow its README; typically
a local HTTP server after indexing) and register it in `<workspace>/.mcp.json`
([`../../templates/mcp/project.mcp.json.snippet`](../../templates/mcp/project.mcp.json.snippet)).
Use this if you want to pin a version or point at a shared instance.

### Then: find your tool prefix — this bites

The route decides the tool namespace, and the agent templates name Serena's tools
explicitly, so the prefix must match:

| Route | Prefix | Example |
|---|---|---|
| A (plugin) | `mcp__plugin_serena_serena__` | `mcp__plugin_serena_serena__find_symbol` |
| B (`.mcp.json` key `serena`) | `mcp__serena__` | `mcp__serena__find_symbol` |

The templates ship with **`mcp__serena__`**. On Route A, search-and-replace
`mcp__serena__` → `mcp__plugin_serena_serena__` across `~/.claude/agents/`.

> **A wrong prefix fails silently.** An unresolvable name in a `tools:` list doesn't
> error — the agent simply has *no* code tools and quietly reads whole files instead,
> which is the exact behaviour the mandate exists to prevent. Confirm the real names with
> `/mcp` before trusting a copied agent.

### Verify
1. Ask Claude for "a symbols overview of `<some file>`" — confirm you get symbols, not a
   file dump.
2. Confirm the **write** tools are present too (`replace_symbol_body`, `rename_symbol`,
   `safe_delete_symbol`); a read-only Serena can't satisfy the mandate.
3. Serena is **per-project** — each solution/repo is its own Serena project. Activate the
   right one (`activate_project`) before working in it.

## Step 3 — Stand up Forgetful (memory)

1. Bring up the memory server and its PostgreSQL + pgvector backend (Docker is the easy
   path; use local embeddings so content stays on the host).
2. Register it as a **global** server in `~/.claude.json`
   ([`../../templates/mcp/global.claude.json.snippet`](../../templates/mcp/global.claude.json.snippet)).
3. Verify: create one test memory, then query it by meaning and confirm it comes back.

## Step 4 — Lay down the CLAUDE.md layers

Copy the three templates and fill in *your* facts:

- `templates/claude-md/global.CLAUDE.md`   → `~/.claude/CLAUDE.md`
- `templates/claude-md/workspace.CLAUDE.md` → `<workspace>/CLAUDE.md`
- `templates/claude-md/repo.CLAUDE.md`     → `<workspace>/<repo>/CLAUDE.md` (per repo)

See [06-claude-md-layers.md](06-claude-md-layers.md). **You now have a working setup** —
Claude reads by symbol, remembers across sessions, and knows your conventions.

## Step 5 — Adapt the implementation chain

Define your `layer-1 → layer-2 → …` chain and create one specialist agent per layer from
[`../../templates/agents/layer-specialist.md`](../../templates/agents/layer-specialist.md).
This is the single most important adaptation — see
[11-adapting-to-your-stack.md](11-adapting-to-your-stack.md).

## Step 6 — Add the guardrail hooks

Copy the hooks you want from `templates/hooks/` into `~/.claude/hooks/` and wire them in
`~/.claude/settings.json`. Start with:

- `block-dangerous-git.sh` — no push / reset --hard / force / --no-verify
- `block-mcp-writes.sh` — read-only veto on the tracker + git-host MCP
- `block-infra-staging.sh` — never commit `.claude/` / `CLAUDE.md`
- `cleanup-handoffs.sh` — wipe ephemeral handoffs at session end

**Verify each hook fires** before you trust it (try a `git push` in a scratch repo and
confirm it's blocked).

## Step 7 — Add the flows, one at a time

Copy `templates/commands/start-ticket.md` → `~/.claude/commands/`, plus the agents it
references (`ticket-analyzer`, `context-gatherer`, `planner`, your layer specialists,
`repo-reviewer`, `release-reviewer`). Run it on a small real ticket. Once that's smooth, add
`/fix-ticket`, `/test-ticket`, `/end-of-day`, `/garden-memory` as the need arises.

---

## Minimum viable version

If you want the smallest useful thing first: **Steps 1–4 only.** Serena + Forgetful + the
CLAUDE.md layers already change how every session feels. Add flows and hooks when the
manual repetition starts to hurt.
-e 
---
> **Last verified against:** Claude Code `2.1.219` — July 2026
