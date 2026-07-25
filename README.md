# Claude Code Playbook — a way of working for agile teams

*A stack-agnostic blueprint for running Claude Code as an engineering teammate on a
Jira/agile workflow — semantic code navigation, durable memory, and multi-agent flows
behind slash commands.*

> **License:** MIT — see [LICENSE](LICENSE).


A **generic, adaptable blueprint** for running Claude Code as a serious engineering
teammate on a Jira + agile workflow — for any engineer, any stack, any company.

It is deliberately **not** tied to one team's tech. It captures a *pattern* and gives
you the *scaffolding* to drop into your own `~/.claude`:

- **Docs** (`docs/`) explain the philosophy and the flows.
- **Templates** (`templates/`) are copy-paste skeletons — agents, skills, slash
  commands, hooks, CLAUDE.md files, MCP config — with `<PLACEHOLDERS>` you fill in for
  your stack.

> If you have 5 minutes: read [PHILOSOPHY.md](PHILOSOPHY.md).
> If you want to build it: [docs/02-prerequisites.md](docs/02-prerequisites.md) →
> [docs/03-setup.md](docs/03-setup.md).

---

## The one-paragraph version

Out of the box an AI coding agent is **file-blind** (re-reads whole files to find one
method), **amnesiac** (forgets everything at session end), and **unstructured** (one
giant chat doing everything, no guardrails). This playbook fixes all three:

1. **Eyes** — a semantic code-navigation MCP (Serena) so the agent reads *symbols*, not
   whole files.
2. **Memory** — a persistent semantic-memory MCP (Forgetful) so conclusions survive
   across sessions, machines, and weeks.
3. **Flows** — multi-agent pipelines behind slash commands that turn a Jira ticket into
   a reviewed, single-commit branch, with hook-enforced guardrails.

Eyes + memory are the *capabilities*; the flows are the *way of working* built on top.
The three **compound**: remember → locate → edit → remember.

---

## The three pillars

```
   PILLAR 1: EYES              PILLAR 2: MEMORY            PILLAR 3: FLOWS
   ────────────────           ────────────────            ────────────────
   Serena (code nav)          Forgetful (memory)          scoped-agent pipelines
   read symbols, not files    survives sessions           behind slash commands
        │                           │                           │
        └───────────────┬───────────┴───────────────┬───────────┘
                        │                           │
                 give the agent              wrap your workflow
                 capabilities               in structure + guardrails
```

See [docs/04-serena.md](docs/04-serena.md), [docs/05-forgetful.md](docs/05-forgetful.md),
and [docs/07-the-flows.md](docs/07-the-flows.md).

---

## Repo layout

```
claude-code-playbook/
├── README.md                       ← you are here
├── PHILOSOPHY.md                   ← the mindset in one file (read this first)
├── docs/
│   ├── 01-architecture.md          The four config layers: MCP · agents · skills · hooks
│   ├── 02-prerequisites.md         What to install before setup
│   ├── 03-setup.md                 Clean-machine setup, step by step
│   ├── 04-serena.md                Pillar 1 — code navigation by symbol
│   ├── 05-forgetful.md             Pillar 2 — durable memory + the two-memory rule
│   ├── 06-claude-md-layers.md      The CLAUDE.md idea: global · workspace(multi-repo) · per-repo
│   ├── 07-the-flows.md             Pillar 3 — the pipeline concept + the flow catalogue
│   ├── 08-ticket-pipeline.md       /start-ticket, step by step (generic)
│   ├── 09-decompose-path.md        Parallel slices for large tickets (git worktrees)
│   ├── 10-memory-hygiene.md        Deliberate memory: /end-of-day + /garden-memory
│   ├── 11-metrics.md               Costing a pipeline run (tokens/points)
│   └── 12-adapting-to-your-stack.md  How to map the abstract layer-chain to YOUR layers
└── templates/
    ├── claude-md/     global · workspace · per-repo CLAUDE.md skeletons
    ├── agents/        ticket-analyzer · context-gatherer · planner · layer-specialist · reviewer · …
    ├── skills/        commit-conventions · engineering-standards · tdd · diagnose · grilling
    ├── commands/      start-ticket · fix-ticket · test-ticket · resume-ticket · end-of-day · garden-memory
    ├── hooks/         block-dangerous-git · block-mcp-writes · block-infra-staging · cleanup-handoffs
    └── mcp/           MCP config snippets (global + project) + settings snippet
```

---

## How to use this playbook

1. **Understand the mindset** — [PHILOSOPHY.md](PHILOSOPHY.md) +
   [docs/01-architecture.md](docs/01-architecture.md).
2. **Stand up the two capabilities** — Serena + Forgetful
   ([docs/02-prerequisites.md](docs/02-prerequisites.md) →
   [docs/03-setup.md](docs/03-setup.md)).
3. **Lay down the CLAUDE.md layers** — copy `templates/claude-md/*` and fill in your
   repos/conventions ([docs/06-claude-md-layers.md](docs/06-claude-md-layers.md)).
4. **Adapt the layer-chain to your stack** — the single most important adaptation
   ([docs/12-adapting-to-your-stack.md](docs/12-adapting-to-your-stack.md)).
5. **Copy the agents/skills/commands/hooks you want**, fill in the placeholders, and
   add the flows one at a time — start with `/start-ticket`.

You do **not** need everything on day one. The minimum viable version is:
**Serena + Forgetful + a global CLAUDE.md + one `/start-ticket` command**. Everything
else is additive.

---


## Keeping this playbook fresh

Claude Code ships frequently. Templates and docs encoding current behaviour can
rot silently. Each file in this repo carries a "Last verified against" line at
the end — when you upgrade Claude Code, run:

```bash
claude --version   # check what you now have
grep -r "Last verified" docs/ PHILOSOPHY.md
# Then update each file's marker and audit for behavioural drift
```

**Things most likely to drift:** MCP server configuration format, hook API,
`settings.json` schema, and the directory layout under `~/.claude/`. Pay close
attention to those files in templates/.

## ⚠️ Before you commit any of this to a real repo

This playbook is documentation + templates — **no secrets by design**. When you
adapt it, never commit:

- Personal access tokens (git-host PAT, Jira token, cloud secrets)
- DB connection strings / credentials
- Customer identifiers or any raw PII

Templates use placeholders (`${GIT_TOKEN}`, `<YOUR-JIRA-URL>`, `34xxxxxxx`). Keep it
that way. See the guardrail hooks in `templates/hooks/` — they exist to enforce this.
