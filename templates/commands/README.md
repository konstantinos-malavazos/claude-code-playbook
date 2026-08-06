# Slash-command templates

Copy into `~/.claude/commands/`. Each file becomes `/<filename>`.

> **Custom commands have been merged into skills.** `~/.claude/commands/deploy.md` and
> `~/.claude/skills/deploy/SKILL.md` both produce `/deploy` and behave the same way, and
> `commands/` files keep working — this directory is a supported shape, not a deprecated
> one. But the skill shape is the one that grows: a directory for supporting files, and the
> [frontmatter fields](../skills/README.md) that control who may invoke it. **If a command
> and a skill share a name, the skill wins.** Move a command here into `skills/` the moment
> it needs bundled files or invocation control; leave it here while it is just a prompt.

## Anatomy of a command

```markdown
---
description: One line shown in the command list.
argument-hint: <TICKET-ID>        # optional — hints the expected argument
---

<the prompt the model runs when you type the command. Use $ARGUMENTS (or $1, $2…) to
reference what the user typed after the command.>
```

Because commands are skills, **the whole skill frontmatter set is available here too** —
`disable-model-invocation`, `allowed-tools`, `model`, `context: fork` and the rest. The two
fields above are simply the two these templates need. See the
[skills README](../skills/README.md) for the full table.

A command is just a saved prompt — usually one that **orchestrates agents in order**.
The orchestrator (the main session) dispatches each agent, waits for its handoff file,
and moves to the next.

## The set

| Command | Orchestrates | solo | team |
|---|---|---|---|
| `start-ticket` | the full pipeline (analyzer → gatherer → planner → grilling → specialists → review) | ✓ | ✓ |
| `fix-ticket` | QA bounce-back → diagnose → fix → amend in place | ✓ | ✓ |
| `test-ticket` | E2E staging test + bank/reuse a test recipe | ✓ | ✓ |
| `resume-ticket` | reopen an in-flight ticket across sessions (delta mode) | ✓ | ✓ |
| `end-of-day` | daily memory nomination | ✓ | ✓ |
| `garden-memory` | periodic memory hygiene | ✓ | ✓ |
| `start-massive` | chart a foggy effort into a map of small tickets, then stop | ✓ | ✓ |
| `resume-massive` | walk that map, one ticket per session; owns the three endings | ✓ | ✓ |
| `build-chart-ticket` | implement one `make:<layer>` ticket off a map | ✓ | ✓ |

The three `*-massive` templates are one flow and only work together — see
[13-massive-tickets.md](../../docs/shared/13-massive-tickets.md). They need the `charting`
skill and a tracker adapter installed; `build-chart-ticket` also needs the layer specialists
`/adapt-to-stack` generates.

The **solo** / **team** columns say which entrance needs each template. Everything here is
shared today; the columns exist so path-specific templates can declare themselves as they
arrive.

Add `/close-ticket` and `/confirm-deployment` from the same pattern when you need them.
