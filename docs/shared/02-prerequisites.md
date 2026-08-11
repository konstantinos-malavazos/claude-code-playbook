# 02 — Prerequisites

What you need before [03-setup.md](03-setup.md).

---

## Required

| Thing | Why | Notes |
|---|---|---|
| **Claude Code** (CLI, or desktop/IDE) | the harness that runs everything | authenticated with your Anthropic account |
| **git** | the whole workflow is git-based | any recent version |
| **A code-navigation MCP server** (Serena) | pillar 1 — eyes on the code | runs as a local server; needs the language toolchain for the languages you index |
| **A semantic-memory MCP server** (Forgetful) | pillar 2 — durable memory | self-hosted; needs a PostgreSQL + pgvector backend (Docker is the easy path) |
| **Node** | most MCP servers are Node processes | Node LTS, as required by the servers you pick |
| **Python** | **every hook parses its payload with it**, and most of the rest of the MCP servers are Python processes | on `PATH` for the shell the hooks run in, as `python3` or `python`. The hooks need only the standard library, so any Python 3 will do. **An MCP server may want 3.11+**, so check the ones you pick. Without a Python the four blocking hooks exit `2` and **block**. That is loud and safe rather than silent; see [`templates/hooks/README.md`](../../templates/hooks/README.md) |

---

## Optional but recommended

| Thing | Why |
|---|---|
| **A tracker MCP** | let the analyzer read tickets directly (read-only by policy) |
| **Git-host MCP** (GitHub or GitLab) | let reviewers read MRs/PRs, diffs, branches (writes vetoed by a hook) |
| **A DB MCP** (read-only, staging) | let the planner sample real data shapes without leaving the terminal |
| **A formatter/linter** for your stack | wired into a `format-on-edit` hook |

---

## Credentials you'll need (and must NOT commit)

- A **tracker API token**. Read scope is enough. A local markdown tracker needs none.
- A **git-host personal access token**, **read scope** only. `block-mcp-writes.sh` vetoes
  write-class MCP calls, so a wider token would buy nothing but risk.
- Any **DB connection string** for a *staging* read-only sample path.

Put these in environment variables and reference them from config as `${VAR}`, never
inline. The guardrail hooks assume this.

---

## Decide up front: your implementation chain

> **Only if you have a codebase.** If you arrive with a raw idea, you have no stack yet
> and cannot answer this. The chain is named alongside the stack in
> [charting's tail](../solo/06-choosing-the-stack.md), a stage later. Skip this section and
> never come back to it. The [bootstrap](../solo/04-the-bootstrap.md) writes the chain into
> the repo's `CLAUDE.md` and generates the specialists from it.

Before you write any agents, answer one question:

> When a change touches multiple layers of my stack, what order does it propagate in,
> and who's the specialist for each layer?

That ordered list (e.g. `schema → service → client`, or `migration → API → frontend`) is
the backbone of the whole pipeline. Write it down now. You encode it in the `CLAUDE.md`
that owns it — the repo's for one repo, the workspace's for sibling repos. The
specialists are generated from there. See
[11-adapting-to-your-stack.md](11-adapting-to-your-stack.md).
---
> **Last verified against:** Claude Code `2.1.226` — August 2026
