# 01 — Architecture

## The mental model

```
                    ┌─────────────────────────────────────────────┐
                    │              Claude Code (CLI)               │
                    │        your model · effort · theme           │
                    └───────────────────┬─────────────────────────┘
                                        │
        ┌───────────────────────────────┼───────────────────────────────┐
        │                               │                               │
   ┌────▼─────┐                   ┌──────▼──────┐                  ┌──────▼──────┐
   │  SKILLS  │                   │   AGENTS    │                  │   HOOKS     │
   │ (how-to  │                   │ (delegated  │                  │ (guardrails │
   │  recipes)│                   │  contexts)  │                  │ + metrics)  │
   └──────────┘                   └─────────────┘                  └─────────────┘
                                        │
                    ┌───────────────────┴───────────────────┐
                    │              MCP SERVERS               │
                    ├────────────┬───────────┬───────────────┤
                    │  SERENA    │ FORGETFUL │ tracker / git- │
                    │ (code nav) │ (memory)  │  host / db     │
                    └────────────┴───────────┴───────────────┘
                                        │
                    ┌───────────────────┴───────────────────┐
                    │      your workspace (one or many       │
                    │            git repositories)           │
                    └────────────────────────────────────────┘
```

There are **four layers** of configuration, each with one clear job:

| Layer | Lives in | Job |
|---|---|---|
| **MCP servers** | `~/.claude.json` (global) + `<workspace>/.mcp.json` (project) | Give Claude *capabilities*: navigate code (Serena), remember (Forgetful), talk to your tracker / your git host / your DB. |
| **Agents** | `~/.claude/agents/**/*.md` | Delegated sub-contexts with scoped tool access. Each does one job and hands off. |
| **Skills** | `~/.claude/skills/**/SKILL.md` | Progressive-disclosure recipes. Auto-load on intent (e.g. "commit" → your commit-convention skill). |
| **Hooks** | `~/.claude/settings.json` + `~/.claude/hooks/*` | Deterministic guardrails (block dangerous git) + metrics + cleanup. The *harness* runs these, not the model. |

Skills and agents are just markdown. Hooks are just scripts. MCP config is just JSON.
Nothing here is magic. It is a disciplined layout of plain files.

---

## Where each layer earns its keep

- **MCP = capability.** Without Serena, the agent reads whole files. Without Forgetful,
  it forgets. These two are the foundation. The git-host / tracker / DB servers are
  conveniences on top.
- **Agents = separation of concerns + cost control.** A scoped agent runs in its own
  context window, so a heavy read sweep doesn't pollute the planner's context. Give each
  agent only the tools it needs. An analyzer that can't edit code cannot accidentally
  edit code.
- **Skills = reusable judgement.** A skill is a recipe you'd otherwise re-explain every
  session ("here's how we write commit messages", "here's the review standard"). It
  loads *on intent*, so it costs nothing until it's relevant.
- **Hooks = guarantees.** Anything you must *never* allow (a `git push`, a write to the
  ticket tracker) belongs in a hook, because the harness enforces it deterministically.
  A CLAUDE.md line is a request. A hook is a guarantee.

---

## Global vs project scope

Almost everything can live at **global** (`~/.claude/`) or **project**
(`<workspace>/.claude/`, `<workspace>/.mcp.json`) scope.

- **Global** — your personal way of working, shared across every project: your agents,
  skills, guardrail hooks, and personal CLAUDE.md.
- **Project** — facts specific to the codebase you're in: which branch ships to
  production, project-scoped MCP servers (Serena is per-project because it indexes a
  working copy), project permissions. Where that scope's `CLAUDE.md` sits depends on how
  many repos you have. One repo uses the repo's own file. Sibling repos add a workspace
  file above it, and that is where *which repos exist* then lives. See
  [06-claude-md-layers.md](06-claude-md-layers.md).

Rule of thumb: *behaviour* is global, *facts about this codebase* are project-scoped.

---

## The dominant change pattern: a sequential chain

Most real changes propagate through your stack in a fixed order. In a data-heavy
backend that is often `schema → service → downstream/consumers`. In a product app it
might be `API → backend → frontend`. Whatever yours is, name it once. The ticket
pipeline is built around executing that chain in order, one specialist per layer.

This chain is the single thing you **must** adapt to your own stack. See
[11-adapting-to-your-stack.md](11-adapting-to-your-stack.md).

---

## Two kinds of memory, deliberately separated

(Repeated from [PHILOSOPHY.md](../../PHILOSOPHY.md) because it drives the whole design.)

| Kind | Mechanism | Lifetime |
|---|---|---|
| **Ephemeral pipeline state** | filesystem handoff files under `<workspace>/.claude/handoffs/<TICKET>/` | auto-deleted at `SessionEnd` |
| **Durable knowledge** | a persistent memory store (Forgetful) | permanent, cross-session, cross-machine |

Only the distilled conclusion of a ticket becomes a durable memory. Everything in-flight
lives on disk and evaporates. See [05-forgetful.md](05-forgetful.md) and
[10-memory-hygiene.md](10-memory-hygiene.md).
---
> **Last verified against:** Claude Code `2.1.226` — August 2026
