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
| **A runtime for your MCP servers** | most MCP servers are Node or Python processes | Node LTS and/or Python 3.11+ as required by the servers you pick |

---

## Optional but recommended

| Thing | Why |
|---|---|
| **Jira/tracker MCP** | let the analyzer read tickets directly (read-only by policy) |
| **Git-host MCP** (GitHub or GitLab) | let reviewers read MRs/PRs, diffs, branches (writes vetoed by a hook) |
| **A DB MCP** (read-only, staging) | let the planner sample real data shapes without leaving the terminal |
| **A formatter/linter** for your stack | wired into a `format-on-edit` hook |

---

## Credentials you'll need (and must NOT commit)

- A **Jira/tracker API token** (read scope is enough).
- A **git-host personal access token** (read scope; you push manually anyway).
- Any **DB connection string** for a *staging* read-only sample path.

Put these in environment variables and reference them from config as `${VAR}` — never
inline. The guardrail hooks assume this.

---

## Decide up front: your implementation chain

Before you write any agents, answer one question:

> When a change touches multiple layers of my stack, what order does it propagate in,
> and who's the specialist for each layer?

That ordered list (e.g. `schema → service → client`, or `migration → API → frontend`) is
the backbone of the whole pipeline. Write it down now; you'll encode it in the workspace
CLAUDE.md and one specialist agent per layer. See
[12-adapting-to-your-stack.md](12-adapting-to-your-stack.md).
