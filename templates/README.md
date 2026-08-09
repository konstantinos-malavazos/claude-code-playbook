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
| [`mcp/`](mcp/README.md) | MCP server config + settings snippets |
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
| 2b | **The two evidence-free agents still launch.** Spawn `pitch-judge` and `decision-steward` on a two-line case file and confirm each returns a verdict. Run them — their `tools:` line cannot tell you whether the tool behind it is switched on. **Substitute a real model id first**: both ship `model: <strong-model-id>`, and an unfilled one fails at dispatch with an API error, so the check would report a broken floor that is fine | the agents themselves |
| 3 | Every tool in a `tools:` list survives the **background subagent filter** — subagents run in the background by default and anything outside that subset is stripped with no error | [available tools](https://code.claude.com/docs/en/sub-agents#available-tools) |
| 4 | Any agent whose body says it **dispatches** another still has `Agent` in its `tools` list | [nesting](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents) |
| 5 | Hook **event names** are still real, and every blocking hook exits **exactly 2** | [hooks](https://code.claude.com/docs/en/hooks) |
| 6 | Hook **matchers** cover every tool that can do the thing being blocked — shell guardrails need `Bash\|PowerShell`, MCP matchers need the `.*` suffix | [hooks](https://code.claude.com/docs/en/hooks) |
| 6b | **`bash hooks/test-hooks.sh` passes.** Run it — do not read it. A green run only covers the cases it has: **every pattern in a hook's list needs its own case**, or the untested one is free to fail open | the suite itself |
| 7 | The **anatomy blocks** in `agents/README.md` and `skills/README.md` still list every documented field | both field tables |
| 8 | The `mcp__serena__` **prefix** still matches your install (`/mcp`) — a plugin install is `mcp__plugin_serena_serena__` | your machine |
| 9 | **Every snippet file parses as JSON, unmodified.** `python -c "import json,sys; [json.load(open(p)) for p in sys.argv[1:]]" mcp/*.snippet hooks/*.snippet.json` — a snippet is a body meant to be pasted, so anything a reader would have to strip first is a defect | the parser |
| 10 | **No *installed* agent or skill still has a `<placeholder>` in `name:`, `model:` or `tools:`.** `grep -rnE '^(name\|model\|tools):.*<[a-z][a-z-]*>' ~/.claude/agents/ ~/.claude/skills/ <repo>/.claude/` — the templates carry them on purpose, so run this against the copies, never against this directory | your install |
| 11 | **An auto-loading skill still fires on its own trigger, and still does not fire on an unrelated prompt.** `claude -p --output-format stream-json --verbose "<prompt>"`, then look for a `Skill` tool call. Both halves need a transcript, so **`--output-format json` cannot answer either** — it returns the final result and no tool calls, and a negative test read off a silent result proves nothing | the transcript |

Checks 3, 4 and 6 are the ones that fail silently and matter most. Check 8 is per-machine
rather than per-version and is worth doing on every fresh install; so is check 10, which
catches a filling-in mistake rather than a version drift.

**Check 10 is the only defect here a *reading* check can settle, and the three fields fail
three different ways.** An unfilled `tools:` name is **stripped at launch in silence** —
the agent runs, declares nothing wrong, and works without the tools its own body calls
mandatory. An unfilled `model:` registers and dies on first dispatch. An unfilled `name:`
registers, appears in the available-agents list, and then cannot be dispatched by the name
that list is printing. Only the second and third announce themselves; the first is the one
worth grepping for. Full table, with the transcripts:
[`agents/README.md`](agents/README.md#an-unfilled-placeholder-is-not-an-error). Note what
check 10 cannot see: a name that is filled in and still does not resolve — a
`mcp__serena__` prefix on a plugin install strips exactly the same way and reads clean.
That is check 8, and beyond it the agents' own halt rule.

**Checks 2b and 6b are the only ones that run the artifact itself rather than a tool over
it, and both are here because reading was not enough.** The first pass through this list verified every hook claim against the docs
and passed. Then the hooks were actually run, and both git guardrails turned out to ignore
`git push` on any line but the first — a multi-line command is the most common shape an
agent writes, and the most common shape a human writes by hand. Nothing in the docs was
wrong; the scripts simply did not do what they said. **Where a claim can be executed,
execute it.**

**A green suite is not a guarded repo, and #29 found the gap by running the hook rather than
the suite.** `block-secret-staging.sh` iterates a list of credential literals and greps for
each with `grep -Eq "$pat"`. One of those patterns — the PEM private-key header — starts with
`-`, so grep read it as options, exited on a usage error, and the caller's `if` took that for
*no match*. **The single most valuable credential a repo can leak was waved through for as
long as the pattern existed**, while the suite ran green: the suite reached `.pem` by *path*,
which a different rule catches, and never once put a key header on a command line. The list
had seven patterns and two cases. It now has one case per pattern, and every such loop passes
`-e`. **A loop over patterns is only as tested as its least-tested pattern** — the same defect
shape as the multi-line gap below, one level further in.

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
> per-install and was not run. Check 9 was run on 9 August 2026 — all four snippets parse,
> and `project.mcp.json.snippet` was additionally pasted into a scratch project and loaded
> by `claude mcp list` on `2.1.226`. Check 10 was added on 9 August 2026 from execution on
> `2.1.226`: eight agents were installed unfilled and dispatched, and all three placeholder
> fields were observed failing — separately, and none of them at install time.
