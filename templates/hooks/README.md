# Hook templates

Hooks are scripts the **harness** runs on tool events — deterministic guardrails the
model cannot talk its way around. Copy into `~/.claude/hooks/`, make them executable, and
wire them in `~/.claude/settings.json` (see `settings-hooks.snippet.json`).

## How a hook works

- Claude Code invokes the hook on a matched event, passing a JSON payload on **stdin**
  (tool name, tool input, session info).
- A **PreToolUse** hook that exits **exactly 2** and prints a reason to **stderr**
  **blocks** the tool call and shows the reason to the model.
- Exit **0** allows the call.
- **SessionEnd** / **PostToolUse** hooks run for side effects (cleanup, formatting) and
  don't block. `SessionEnd` ignores the exit code entirely.

> **Only exit 2 blocks. Every other non-zero code is a *non-blocking* error** — the
> transcript shows a hook-error notice and **the tool call proceeds anyway**. So a guardrail
> that ends in `exit 1` looks like it is guarding, logs like it is guarding, and guards
> nothing. Every blocking hook here exits `2` on purpose; keep it that way if you edit one.
> (`WorktreeCreate` is the lone exception where any non-zero code aborts.)

**Matchers** are exact strings when they contain only letters, digits, `_`, `-`, spaces,
`,` and `|` — with `|` or `,` separating alternatives — and a **JavaScript regex,
unanchored**, the moment any other character appears. So `Bash` matches only `Bash`, while
`mcp__tracker__.*` is a regex. Matching every tool from an MCP server **requires** the `.*`
suffix; the bare server prefix matches nothing.

> These templates are written for a POSIX shell (Git Bash on Windows works). Adjust the
> JSON parsing to your environment; `jq` is assumed. Test each hook in a scratch repo
> before trusting it.

## Run the suite

```bash
bash templates/hooks/test-hooks.sh
```

29 cases across both blocking hooks: what must be blocked, what must be allowed, `Bash` and
`PowerShell` payloads, and multi-line commands. Exit 0 means every case behaved; exit 1
means a guardrail is not guarding. It shims the JSON parse if `jq` is missing, and says so
rather than skipping quietly.

**Run it after editing any hook.** These scripts cannot be verified by reading them — the
multi-line gap below survived a full audit that checked every claim against the official
docs, because the docs were not the thing that was wrong.

### The multi-line gap, and why it is worth knowing

Both blocking hooks flatten the command before matching. They used to turn newlines into
**spaces**, and the patterns anchor on start-of-string or a `[;&|]` separator — so in

```
git add -p
git commit -m x
git push origin main
```

the `git push` was preceded by a space, matched nothing, and **sailed through**. `cd /tmp &&
git push` was caught; the far more common multi-line form was not. Newlines now become `;`,
because a separate line is a separate command. `\r` maps too, so a CRLF payload behaves the
same.

The general shape: **when you flatten input before matching, you erase the very boundaries
the pattern depends on.** Worth checking in any guardrail that normalises before it greps.

## The set

| Hook | Event | Job | solo | team |
|---|---|---|---|---|
| `block-dangerous-git.sh` | PreToolUse · Bash\|PowerShell | block push / reset --hard / force / --no-verify / branch -D / clean -fd | ✓ | ✓ |
| `block-mcp-writes.sh` | PreToolUse · mcp (tracker, git-host) | read-only veto — only get/list/search pass | ✓ | ✓ |
| `block-infra-staging.sh` | PreToolUse · Bash\|PowerShell | block staging/committing `.claude/`, `CLAUDE.md`, MCP state | ✓ | ✓ |
| `cleanup-handoffs.sh` | SessionEnd | delete the ephemeral handoff dirs | ✓ | ✓ |
| `format-on-edit.sh` | PostToolUse · Write/Edit | auto-format the file that was just edited | ✓ | ✓ |
| `test-hooks.sh` | — | regression suite for the two blocking hooks; run it, don't read it | ✓ | ✓ |

The **solo** / **team** columns say which entrance needs each template. Everything here is
shared today; the columns exist so path-specific templates can declare themselves as they
arrive.

## `Bash` is not the only shell

**`PowerShell` is a separate tool from `Bash`**, and a matcher of `Bash` does not see it.
On Windows it can be enabled automatically (no Git Bash) or arrive through a progressive
rollout (with Git Bash); elsewhere it is opt-in via `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`. A
git guardrail matched only on `Bash` therefore stops nothing the moment the model reaches
for PowerShell — the worst failure shape a guardrail has, since it keeps reporting success.
The shipped matcher is `Bash|PowerShell` for that reason.

The two blocking scripts parse `.tool_input.command`, which both tools populate, so they
work unchanged for either. **Their command patterns are POSIX-flavoured**, though: verify
the PowerShell path in a scratch repo rather than assuming, since `git push` reads the same
but a piped or `&&`-chained invocation may not.

Why a hook and not a CLAUDE.md line? A CLAUDE.md line is a *request* the model may
forget under load. A hook is a *guarantee* enforced by the harness. Anything you must
never allow belongs here.
