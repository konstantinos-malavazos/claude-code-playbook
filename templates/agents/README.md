# Agent templates

Copy the ones you want into `~/.claude/agents/` and fill in the `<PLACEHOLDERS>`.

## Anatomy of an agent file

```markdown
---
name: my-agent                # kebab-case; how you @-mention it. No ":" — reserved
description: >-               # WHEN to use it — the harness reads this to route work
  One or two sentences describing exactly when this agent should run and what it
  produces. Be specific about inputs (which handoff files it reads) and outputs.
tools: Read, Grep, Glob, Write, Edit, Bash   # ONLY the tools this agent needs
model: <fast-model-id> | <strong-model-id>   # pin an exact id, not an alias
---

<the system prompt: the agent's role, its scope, the exact steps it follows,
what it must NEVER do, and where it reads/writes handoff files.>
```

**Only `name` and `description` are required.** Every other field is optional — but the
harness supports far more than the four above, and a field you cannot see is a field you
cannot choose. The full set:

| Field | What it does | Used here? |
|---|---|---|
| `name` | Identity; hooks receive it as `agent_type`. The filename need not match | ✓ all |
| `description` | When Claude should delegate to it | ✓ all |
| `tools` | Allowlist. **Inherits every tool if omitted** — including every MCP server | ✓ all |
| `disallowedTools` | Denylist. Applied **first**, then `tools` resolves against the remainder | — |
| `model` | `sonnet` / `opus` / `haiku` / `fable`, a full id, or `inherit`. **Defaults to `inherit`** | ✓ all but `layer-specialist` |
| `permissionMode` | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan` | — |
| `maxTurns` | Caps agentic turns. The way to make an agent that weighs but cannot act | ✓ `pitch-judge` |
| `skills` | Skills preloaded into its context at startup — full content, not just the description | — |
| `mcpServers` | Which MCP servers it gets | — |
| `hooks` | Lifecycle hooks scoped to this agent | — |
| `memory` | `user` / `project` / `local` — persistent cross-session memory | — |
| `background` | Force background. **Unset already means background by default** — see below | — |
| `effort` | `low` … `max`; overrides the session effort level | — |
| `isolation` | `worktree` — runs in a throwaway git worktree | — |
| `color` | Display colour in the task list | — |
| `initialPrompt` | Only when the agent runs as the *main* session agent | — |

**`background` deserves a second look even though nothing here sets it.** Subagents run in
the background by default, and a background subagent keeps every MCP tool but **only these
built-ins**: `Read`, `Grep`, `Glob`, `Bash`, `PowerShell`, `Edit`, `Write`, `NotebookEdit`,
`WebFetch`, `WebSearch`, `TodoWrite`, `Skill`, `ToolSearch`, `EnterWorktree`, `ExitWorktree`,
`Monitor`, `TaskStop`, `SendMessage`, `Artifact`. Anything else in a `tools:` list is
**stripped at runtime with no error**. (`Agent` is exempt from this filter and survives
anywhere, up to the nesting depth limit.) Every list in this directory has been checked
against that set and is clean — but a tool you add later may not be.

## Conventions used across these templates

- **Scope tools tightly.** An analyzer gets read-only tracker tools; a reviewer gets read
  + test-run but no edit. Least privilege makes agents cheap *and* safe.
- **Least privilege has a floor, and the floor is one tool.** You cannot scope an agent to
  zero: Claude Code **refuses to launch** one whose `tools` list resolves to nothing
  (*"subagents require at least one tool to function"*), and omitting `tools` does the
  opposite — it inherits **everything**, MCP servers included. So `tools: []` is not "no
  tools", it is one of those two failures depending on your version. For an agent that must
  only **weigh**, never fetch, the idiom is `tools: TodoWrite` plus `maxTurns: 1`:
  `TodoWrite` cannot read, fetch or execute, and a single agentic turn means no tool result
  can be acted on. `pitch-judge` is the worked example.
- **Describe an agent by what it must not *accomplish*, not by the frontmatter you think
  expresses it.** "Gathers no evidence" stays true across harness versions; "has no tools"
  was a mechanism claim, and it silently became false. Write the capability in the prose and
  let the frontmatter be the mechanism that happens to enforce it today.
- **Pin exact model ids.** The `model` field accepts an alias, a full id, or `inherit`, and
  **defaults to `inherit`** — so leaving it off is a real choice, not an oversight, and it
  is the right one when an agent should track whatever the session is on. These templates
  pin instead, deliberately: a pipeline agent's cost and judgement should not swing with the
  session's model. Use a fast/cheap model for mechanical, bounded work and a stronger model
  for design, judgement, and cross-repo reasoning.
  **The one exception is the layer specialist** — the template and every file generated from
  it omit the field, unless the
  repo's `CLAUDE.md` names one per layer — on a day-one repo nobody knows yet which layer is
  mechanical, deriving it from the layer's *name* is the artifact guessing, and a pinned id
  written into N generated files is N files to change the day it rots. Pinning is advice to
  a human who knows the agent; it is not advice a generator can follow.
  See [`../../docs/shared/11-adapting-to-your-stack.md`](../../docs/shared/11-adapting-to-your-stack.md).
- **An agent that dispatches another agent needs `Agent` in its `tools` list.** Nesting is
  on by default (three layers below the main conversation), but an explicit allowlist still
  wins: leave `Agent` out and the dispatch simply cannot happen. `repo-reviewer` is the one
  agent here that dispatches another.
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

| File | Role | solo | team |
|---|---|---|---|
| `ticket-analyzer.md` | tracker → structured brief (read-only) | ✓ | ✓ |
| `context-gatherer.md` | heavy memory + Serena sweep in a throwaway context | ✓ | ✓ |
| `planner.md` | design + track allocation + branch (no memory writes, no code) | ✓ | ✓ |
| `layer-specialist.md` | **generated once per layer of your chain** by `/adapt-to-stack`, into that repo's own `.claude/agents/` — the implementer (Serena-only edits) | ✓ | ✓ |
| `repo-reviewer.md` | first-level in-repo review (comments only) | ✓ | ✓ |
| `release-reviewer.md` | cross-repo blast-radius review (comments only) | ✓ | ✓ |
| `pitch-judge.md` | anonymised case file → an independent build/kill/park verdict (**gathers no evidence**) | ✓ | |
| `map-reviewer.md` | final judge of a charted map, once, at close — Destination reached? criteria met? (comments only) | ✓ | ✓ |

The **solo** / **team** columns say which entrance needs each template. `pitch-judge` is the
first to claim a single column — it belongs to the solo path's kill gate, which the agile
path does not have.

**`pitch-judge` is the one agent here that reads no handoff file and touches no code.** It
**gathers no evidence**: its entire input arrives in its prompt, and giving it search tools
would turn it into a third search pass. Mechanically that is `tools: TodoWrite` plus
`maxTurns: 1` — the floor rule above, and the reason that rule exists. It is dispatched by
the [`pitch` skill](../skills/README.md) and is meaningless without it.

Decompose-path agents (`aligner`, `integrator`, `integration-tester`, `slice-*`) follow
the same anatomy; add them only if you use the decompose path (docs/shared/09).
