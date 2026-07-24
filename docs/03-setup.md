# 03 — Setup from a clean machine

Order matters: capabilities first, then structure, then flows. You have a working setup
after step 4; steps 5–7 are additive.

---

## Step 1 — Install Claude Code and confirm it runs

Install the CLI (or desktop/IDE), authenticate, and run it once in a scratch folder to
confirm it starts. Pick your model and effort level in `~/.claude/settings.json` (see
[`../templates/mcp/settings.json.snippet`](../templates/mcp/settings.json.snippet)).

## Step 2 — Stand up Serena (eyes)

1. Install/run the Serena MCP server (follow its README; it typically runs as a local
   HTTP server after indexing a project).
2. Register it as a **project-scoped** server in `<workspace>/.mcp.json`
   ([`../templates/mcp/project.mcp.json.snippet`](../templates/mcp/project.mcp.json.snippet)).
3. Verify: ask Claude "give me a symbols overview of `<some file>`" and confirm it
   returns symbols, not a file dump.

## Step 3 — Stand up Forgetful (memory)

1. Bring up the memory server and its PostgreSQL + pgvector backend (Docker is the easy
   path; use local embeddings so content stays on the host).
2. Register it as a **global** server in `~/.claude.json`
   ([`../templates/mcp/global.claude.json.snippet`](../templates/mcp/global.claude.json.snippet)).
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
[`../templates/agents/layer-specialist.md`](../templates/agents/layer-specialist.md).
This is the single most important adaptation — see
[12-adapting-to-your-stack.md](12-adapting-to-your-stack.md).

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
`reviewer`, `senior-reviewer`). Run it on a small real ticket. Once that's smooth, add
`/fix-ticket`, `/test-ticket`, `/end-of-day`, `/garden-memory` as the need arises.

---

## Minimum viable version

If you want the smallest useful thing first: **Steps 1–4 only.** Serena + Forgetful + the
CLAUDE.md layers already change how every session feels. Add flows and hooks when the
manual repetition starts to hurt.
