# Hook templates

Hooks are scripts the **harness** runs on tool events — deterministic guardrails the
model cannot talk its way around. Copy into `~/.claude/hooks/`, make them executable, and
wire them in `~/.claude/settings.json` (see `settings-hooks.snippet.json`).

## How a hook works

- Claude Code invokes the hook on a matched event, passing a JSON payload on **stdin**
  (tool name, tool input, session info).
- A **PreToolUse** hook that exits **non-zero (2)** and prints a reason to **stderr**
  **blocks** the tool call and shows the reason to the model.
- Exit **0** allows the call.
- **SessionEnd** / **PostToolUse** hooks run for side effects (cleanup, formatting) and
  don't block.

> These templates are written for a POSIX shell (Git Bash on Windows works). Adjust the
> JSON parsing to your environment; `jq` is assumed. Test each hook in a scratch repo
> before trusting it.

## The set

| Hook | Event | Job | solo | team |
|---|---|---|---|---|
| `block-dangerous-git.sh` | PreToolUse · Bash | block push / reset --hard / force / --no-verify / branch -D / clean -fd | ✓ | ✓ |
| `block-mcp-writes.sh` | PreToolUse · mcp (tracker, git-host) | read-only veto — only get/list/search pass | ✓ | ✓ |
| `block-infra-staging.sh` | PreToolUse · Bash | block staging/committing `.claude/`, `CLAUDE.md`, MCP state | ✓ | ✓ |
| `cleanup-handoffs.sh` | SessionEnd | delete the ephemeral handoff dirs | ✓ | ✓ |
| `format-on-edit.sh` | PostToolUse · Write/Edit | auto-format the file that was just edited | ✓ | ✓ |

The **solo** / **team** columns say which entrance needs each template. Everything here is
shared today; the columns exist so path-specific templates can declare themselves as they
arrive.

Why a hook and not a CLAUDE.md line? A CLAUDE.md line is a *request* the model may
forget under load. A hook is a *guarantee* enforced by the harness. Anything you must
never allow belongs here.
