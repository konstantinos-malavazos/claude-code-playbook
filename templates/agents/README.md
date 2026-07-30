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
- **Replace `<memory-read-tools>` / `<tracker-read-tools>`** with your actual MCP tool
  names once you know them (e.g. Forgetful's `query_memory`).
- **Serena is NOT a placeholder.** Its tools are named outright in every code-touching
  agent, and each carries a *Code access protocol* block. See below.

## Serena is mandatory, not preferred

Every agent that touches code carries a **Code access protocol (MANDATORY)** block. The
rule, in one line: **Serena is the only sanctioned way an agent reads code, and the only
sanctioned way an agent changes it.**

- **Reading** — symbols, references, implementations, declarations and file shape come
  from `find_symbol`, `find_referencing_symbols`, `find_implementations`,
  `find_declaration`, `get_symbols_overview`. `Read`/`Grep`/`Glob` stay in the tool list
  because agents must read handoffs, docs and config — **not** as a code path.
- **Writing** — `replace_symbol_body`, `insert_after_symbol` / `insert_before_symbol`,
  `rename_symbol`, `safe_delete_symbol`, `create_text_file`, and `replace_content` for
  non-symbol text inside a code file. `Edit`/`Write` on code are a protocol violation
  outside the escapes below.
- **Verifying** — `get_diagnostics_for_file` on every file touched, before the build.
- **The only escapes**, and the agent must name which one it used: (a) the language/file
  isn't indexed by Serena, (b) the target is a non-symbol string (try `search_for_pattern`
  first), (c) Serena errors on the path. For a write, an unusable Serena means **STOP and
  surface it** — never a silent downgrade to `Edit`.
- **Evidence discipline** — a symbol in a plan, a finding in a review, or a cleared
  consumer in a blast-radius report must trace to a Serena result with `file:line`. "Grep
  found nothing" is not evidence of absence; `find_referencing_symbols` returning nothing
  is.

### Tool-name prefix

The templates use `mcp__serena__<tool>`. Your actual prefix depends on how Serena is
registered — a plugin install shows up as e.g. `mcp__plugin_serena_serena__find_symbol`.
Check with `/mcp`, then search-and-replace `mcp__serena__` across the agent files. A
prefix that doesn't resolve means the agent silently has **no** code tools and will fall
back to reading files — verify one agent before you trust the set.

## The set

| File | Role |
|---|---|
| `ticket-analyzer.md` | tracker → structured brief (read-only) |
| `context-gatherer.md` | heavy memory + Serena sweep in a throwaway context |
| `planner.md` | design + track allocation + branch (no memory writes, no code) |
| `layer-specialist.md` | **copy once per layer of your chain** — the implementer (Serena-only edits) |
| `repo-reviewer.md` | first-level in-repo review (comments only) |
| `release-reviewer.md` | cross-repo blast-radius review (comments only) |

Decompose-path agents (`aligner`, `integrator`, `integration-tester`, `slice-*`) follow
the same anatomy; add them only if you use the decompose path (docs/09).
