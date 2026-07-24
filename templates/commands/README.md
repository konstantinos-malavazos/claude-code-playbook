# Slash-command templates

Copy into `~/.claude/commands/`. Each file becomes `/<filename>`.

## Anatomy of a command

```markdown
---
description: One line shown in the command list.
argument-hint: <TICKET-ID>        # optional — hints the expected argument
---

<the prompt the model runs when you type the command. Use $ARGUMENTS (or $1, $2…) to
reference what the user typed after the command.>
```

A command is just a saved prompt — usually one that **orchestrates agents in order**.
The orchestrator (the main session) dispatches each agent, waits for its handoff file,
and moves to the next.

## The set

| Command | Orchestrates |
|---|---|
| `start-ticket` | the full pipeline (analyzer → gatherer → planner → grilling → specialists → review) |
| `fix-ticket` | QA bounce-back → diagnose → fix → amend in place |
| `test-ticket` | E2E staging test + bank/reuse a test recipe |
| `resume-ticket` | reopen an in-flight ticket across sessions (delta mode) |
| `end-of-day` | daily memory nomination |
| `garden-memory` | periodic memory hygiene |

Add `/close-ticket` and `/confirm-deployment` from the same pattern when you need them.
