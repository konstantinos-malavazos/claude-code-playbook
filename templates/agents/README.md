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
| `maxTurns` | Caps agentic turns. The way to make an agent that weighs but cannot act | ✓ `pitch-judge`, `decision-steward` |
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
anywhere, up to the nesting depth limit.) A second, narrower filter runs on *every* subagent
foreground or background, removing `AskUserQuestion`, `EndConversation`, `EnterPlanMode`,
`ExitPlanMode`, `ScheduleWakeup`, `TaskOutput`, `WaitForMcpServers` and `Workflow` even when
they are listed. Every list in this directory has been checked against both and is clean —
but a tool you add later may not be.

**Appearing in that list is not proof the tool resolves** — `TodoWrite` is in it and is
disabled by default. Spawn the agent; see [`../README.md`](../README.md), check 2b.

## Conventions used across these templates

- **Scope tools tightly.** An analyzer gets read-only tracker tools; a reviewer gets read
  + test-run but no edit. Least privilege makes agents cheap *and* safe.
- **Least privilege has a floor, and the floor is one tool.** You cannot scope an agent to
  zero: Claude Code **refuses to launch** one whose `tools` list resolves to nothing
  (*"would be spawned with zero tools — refusing"*), and omitting `tools` does the
  opposite — it inherits **everything**, MCP servers included. So `tools: []` is not "no
  tools", it is one of those two failures depending on your version.
- **For an agent that must only weigh, never fetch, the floor is a test, not a tool name.**
  Take the **one tool in the background subset above that gathers no evidence** — cannot
  read, fetch, write or execute — and pair it with `maxTurns: 1`, so that no tool result can
  be acted on whatever ends up in the pool. **Today that tool is `TaskStop`**, and it is the
  only candidate: everything else in the subset reads, fetches, writes to disk, publishes, or
  reaches another session. Run the test again after a release rather than trusting this
  sentence: the previous answer stopped resolving without a single file in this directory
  changing. `pitch-judge` and `decision-steward` are the worked examples — and the reason
  their prose says *gathers no evidence* rather than *has no tools*.
- **Pin exact model ids.** The `model` field accepts an alias, a full id, or `inherit`, and
  **defaults to `inherit`** — so leaving it off is a real choice, not an oversight, and it
  is the right one when an agent should track whatever the session is on. These templates
  pin instead, deliberately: a pipeline agent's cost and judgement should not swing with the
  session's model. Use a fast/cheap model for mechanical, bounded work and a stronger model
  for design, judgement, and cross-repo reasoning.
  **The one exception is the layer specialist** — the template and every file generated from
  it omit the field unless the repo's `CLAUDE.md` names one per layer, because pinning is
  advice to a human who knows the agent and not advice a generator can follow. Why, in full:
  [`../../docs/shared/11-adapting-to-your-stack.md`](../../docs/shared/11-adapting-to-your-stack.md).
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
  names once you know them (e.g. Forgetful's `query_memory`) — but **Serena is not a
  placeholder**, see below.

## Serena is mandatory, not preferred

Every agent that touches code carries a **Code access protocol (MANDATORY)** block stating
the reading, writing, verifying and escape rules for that agent's own job. **Do not strip
it when you copy the file**, and do not treat `Read`/`Grep`/`Glob` in a `tools:` list as
permission to read code with them. The doctrine those blocks encode:
[`../../docs/shared/04-serena.md`](../../docs/shared/04-serena.md).

### Tool-name prefix

The templates use `mcp__serena__<tool>`, which is a **literal, not a placeholder** — but a
plugin install registers as `mcp__plugin_serena_serena__` instead, and a name that doesn't
resolve leaves the agent silently with no code tools. Check with `/mcp` and rewrite the
prefix across the agent files before you trust any of them:
[`../../docs/shared/03-setup.md`](../../docs/shared/03-setup.md#then-find-your-tool-prefix--this-bites).

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
| `map-reviewer.md` | final judge of a charted map, once, at close — Destination reached? criteria met? (comments only) | | ✓ |
| `decision-steward.md` | one grilling question on an unattended walk → an answer **plus a basis** (**gathers no evidence**) | ✓ | |

The **solo** / **team** columns say which entrance needs each template. The three that claim
a single column each have exactly one flow that dispatches them, and are dead weight without
it: `pitch-judge` by the [`pitch` skill](../skills/README.md), `decision-steward` by
[`/feeling-lucky`](../commands/feeling-lucky.md), `map-reviewer` by
[`/resume-massive`](../commands/README.md) — that last one team-only
([03-massive-tickets.md](../../docs/team/03-massive-tickets.md)), so a solo builder charting
an existing repo with `/charting` closes the map without it.

`pitch-judge` and `decision-steward` are the two that read no handoff file and touch no
code — the floor rule above is written for them. Each file argues its own starvation in its
own terms; do not widen either `tools` list on the way past.

Decompose-path agents (`aligner`, `integrator`, `integration-tester`, `slice-*`) follow
the same anatomy; add them only if you use the decompose path (docs/shared/09).
