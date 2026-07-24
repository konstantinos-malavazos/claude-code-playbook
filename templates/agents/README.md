# Agent templates

Copy the ones you want into `~/.claude/agents/` and fill in the `<PLACEHOLDERS>`.

## Anatomy of an agent file

```markdown
---
name: my-agent                # kebab-case; how you @-mention it
description: >-               # WHEN to use it — the harness reads this to route work
  One or two sentences describing exactly when this agent should run and what it
  produces. Be specific about inputs (which handoff files it reads) and outputs.
tools: Read, Grep, Glob, Write, Edit, Bash   # ONLY the tools this agent needs
model: <fast-model-id> | <strong-model-id>   # pin an exact id, not an alias
---

<the system prompt: the agent's role, its scope, the exact steps it follows,
what it must NEVER do, and where it reads/writes handoff files.>
```

## Conventions used across these templates

- **Scope tools tightly.** An analyzer gets read-only tracker tools; a reviewer gets read
  + test-run but no edit. Least privilege makes agents cheap *and* safe.
- **Pin exact model ids.** Bare aliases can resolve to an older default. Use a
  fast/cheap model for mechanical, bounded work and a stronger model for design,
  judgement, and cross-repo reasoning.
- **Read/write handoffs, not chat.** Every pipeline agent's first action is to list and
  read the relevant prior handoff files under
  `<workspace>/.claude/handoffs/<TICKET-ID>/`; its last action is to write its own.
- **State what the agent must NOT do.** "Comments only, never edits code." "Design only,
  never writes to memory." These negative constraints are as important as the positive
  steps.
- **Replace `<memory tool>` / `<code-nav tool>`** with your actual MCP tool names once you
  know them (e.g. Forgetful's `query_memory`, Serena's `find_symbol`).

## The set

| File | Role |
|---|---|
| `ticket-analyzer.md` | tracker → structured brief (read-only) |
| `context-gatherer.md` | heavy memory + code-nav sweep in a throwaway context |
| `planner.md` | design + track allocation + branch (no memory writes, no code) |
| `layer-specialist.md` | **copy once per layer of your chain** — the implementer |
| `reviewer.md` | first-level in-repo review (comments only) |
| `senior-reviewer.md` | cross-repo blast-radius review (comments only) |

Decompose-path agents (`aligner`, `integrator`, `integration-tester`, `slice-*`) follow
the same anatomy; add them only if you use the decompose path (docs/09).
