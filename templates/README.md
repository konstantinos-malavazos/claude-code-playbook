# Templates

Copy-paste skeletons for the harness: agents, skills, commands, hooks, MCP config,
`CLAUDE.md` layers, and tracker adapters — plus one directory of pages the harness never
touches. Each subdirectory has its own README covering what it holds and how to install it.

| Directory | What it holds |
|---|---|
| [`claude-md/`](claude-md/) | global · workspace · per-repo `CLAUDE.md` skeletons |
| [`agents/`](agents/README.md) | the pipeline's subagents, plus the two judges — `pitch-judge` and `map-reviewer` |
| [`skills/`](skills/README.md) | auto-loading knowledge and user-invoked procedures |
| [`commands/`](commands/README.md) | slash commands that orchestrate agents in order |
| [`hooks/`](hooks/README.md) | harness-enforced guardrails |
| [`mcp/`](mcp/) | MCP server config + settings snippets |
| [`trackers/`](trackers/README.md) | one adapter installed at `~/.claude/tracker.md` |
| [`views/`](views/README.md) | pages a skill fills with data and **you** open in a browser |

## Every file here is a claim about the harness

A doc describes how to work. **A template asserts what Claude Code will accept and do** —
that a frontmatter field exists, that a tool is named what you think, that a matcher fires,
that an exit code blocks. Those claims are checkable against the official docs, and when one
is wrong it usually fails **silently**: the field is ignored, the tool is stripped, the hook
does not match. Nothing errors. You find out when the guardrail you relied on turns out not
to have been there.

**One directory is exempt, and says so itself.** [`views/`](views/README.md) holds a page a
browser renders — no frontmatter, no matcher, no tool name, nothing the harness reads. Its
claims are checked by opening it, not by the list below.

Two consequences shape everything below.

**Verify against the docs, not against what looks reasonable.** `tools: []` was written
because it is the obvious YAML for "no tools", and it is not a thing the harness supports.
Obvious and correct are different properties.

**And the docs are not the last word.** `tools: TodoWrite` replaced it, checked clean against
the tools reference *and* the background-subset list — both of which still name `TodoWrite`
today — and the agent refused to launch anyway, because the tool is **disabled by default**.
The docs answer *is this name real?* A reader needs *is it switched on in my install?*, and
only spawning the agent answers that. Hence check 2b below.

**Prefer claims that survive a version bump.** Describe an agent by what it must not
*accomplish*, and let the frontmatter be the mechanism that enforces it today. "Gathers no
evidence" stayed true; "has no tools" quietly became a lie.

## The re-verification check

Run this when you bump the version in a doc footer, or after any Claude Code release that
touches agents, skills, hooks or tools. It is deliberately short — the point is that it
actually gets run.

| # | Check | Against |
|---|---|---|
| 1 | Every frontmatter **key** in `agents/*.md` and `skills/*/SKILL.md` still appears in the field table | [sub-agents](https://code.claude.com/docs/en/sub-agents#supported-frontmatter-fields) · [skills](https://code.claude.com/docs/en/skills#frontmatter-reference) |
| 2 | Every **tool name** inside a `tools:` list still **resolves** — the name exists *and* the tool is enabled by default. The same row that proves the name is real is where a switched-off default is recorded | [tools reference](https://code.claude.com/docs/en/tools-reference) |
| 2b | **The two evidence-free agents still launch.** Spawn `pitch-judge` and `decision-steward` on a two-line case file and confirm each returns a verdict. Run them — their `tools:` line cannot tell you whether the tool behind it is switched on | the agents themselves |
| 3 | Every tool in a `tools:` list survives the **background subagent filter** — subagents run in the background by default and anything outside that subset is stripped with no error | [available tools](https://code.claude.com/docs/en/sub-agents#available-tools) |
| 4 | Any agent whose body says it **dispatches** another still has `Agent` in its `tools` list | [nesting](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents) |
| 5 | Hook **event names** are still real, and every blocking hook exits **exactly 2** | [hooks](https://code.claude.com/docs/en/hooks) |
| 6 | Hook **matchers** cover every tool that can do the thing being blocked — shell guardrails need `Bash\|PowerShell`, MCP matchers need the `.*` suffix | [hooks](https://code.claude.com/docs/en/hooks) |
| 6b | **`bash hooks/test-hooks.sh` passes.** Run it — do not read it | the suite itself |
| 7 | The **anatomy blocks** in `agents/README.md` and `skills/README.md` still list every documented field | both field tables |
| 8 | The `mcp__serena__` **prefix** still matches your install (`/mcp`) — a plugin install is `mcp__plugin_serena_serena__` | your machine |

Checks 3, 4 and 6 are the ones that fail silently and matter most. Check 8 is per-machine
rather than per-version and is worth doing on every fresh install.

**Checks 2b and 6b are the only ones that execute anything, and both are here because reading
was not enough.** The first pass through this list verified every hook claim against the docs
and passed. Then the hooks were actually run, and both git guardrails turned out to ignore
`git push` on any line but the first — a multi-line command is the most common shape an
agent writes, and the most common shape a human writes by hand. Nothing in the docs was
wrong; the scripts simply did not do what they said. **Where a claim can be executed,
execute it.**

**2b was added the same way, one release later, and it is the harder case.** `pitch-judge`
passed checks 2 and 3 as written — its one tool was a real name and it was inside the
background subset — and the agent still could not launch, because that tool is disabled by
default. The docs were not wrong and the file was not wrong; the check was. **A check that
reads a list can only tell you a name is spellable.** Spawning the agent is two minutes and
it is the only thing that distinguishes a tool that exists from a tool you have.

**A note on scope.** These are claims about the *harness*. Claims about the *prose* — stale
footer values, dead links, drift between a doc and what it describes — are a different sweep
and live with the docs, not here.

## What this directory does not assert

**No template carries a `Last verified against` footer, and that is deliberate.** The docs
carry one because a doc is a statement about a version. A template is copied into a live
install and edited, so a footer on it would date the *copy* the moment it is filled in, and
the reader has no way to know whether a stale footer means the template drifted or their
edits did. The check above is the contract instead: it lives in one place, and it is run
against the whole directory rather than asserted per file.

---
> **Last verified against:** Claude Code `2.1.220` — August 2026
> Checks 1–7 were run against the live published docs on 2 August 2026. Check 8 is
> per-install and was not run.
