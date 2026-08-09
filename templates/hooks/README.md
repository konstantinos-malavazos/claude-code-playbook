# Hook templates

Hooks are scripts the **harness** runs on tool events — deterministic guardrails the
model cannot talk its way around. Copy into `~/.claude/hooks/`, make them executable, and
wire them in `~/.claude/settings.json`.

[`settings-hooks.snippet.json`](settings-hooks.snippet.json) is that wiring — **valid JSON
with no comments in it**, so merge its `hooks` object into your settings file as-is. Two
things in it are yours to adjust: keep only the hooks you actually installed, and point the
`mcp__…` matchers at the servers you actually run.

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

> These templates are written for a POSIX shell (Git Bash on Windows works). They parse
> their payload with **python** (`python3`, then `python`) using only the standard
> library. Test each hook in a scratch repo before trusting it.

### Failing closed, and the three layers it is one of

**A guard cannot be its own witness.** Every mechanism that keeps these hooks honest is
blind to exactly one failure, so the answer is layered rather than picked:

| Layer | What it does | What it structurally cannot see |
|---|---|---|
| Pick the parser most likely to be present | python, not `jq` | a machine with no python either |
| **Fail closed** | the hook exits **2** when it cannot parse | the script never running at all |
| Check the wiring at setup | run a hook live and confirm it blocks | anything that changes afterwards |

**The four blocking hooks exit `2` when they cannot read their payload** — no parser on
`PATH`, or a payload that will not parse. This matters because of the box above: Claude
Code treats every exit code other than `2` as a *non-blocking* error and runs the tool
call anyway, so **`127` is not a near-miss of `2` — it is the same class as success.** A
hook that dies on its parse and exits `127` is a guardrail that has silently stopped
guarding, which is exactly what this directory used to ship.

**Why not a permission prompt.** The harness offers `permissionDecision: "ask"`, and it
needs no parser at all — it is a fixed string, so a blind hook could degrade to *"I can't
read this, you decide."* That is the **honest** verdict, and it is still rejected: the
prompt offers *"yes, and don't ask again"*, so one keystroke makes the approval **durable**
and turns the guard off for good, silently, wearing the appearance of a decision rather
than a bug. A prompt is not a guardrail; it is trust with an extra keystroke.

**`format-on-edit.sh` and `cleanup-handoffs.sh` cannot fail closed, and are not made to
try.** The split is the harness's, not a judgement about which guards deserve to be
strict: `PostToolUse` fires *after* the edit it would object to, and `SessionEnd` ignores
the exit code entirely. Both say so in the file. They fail **soft** instead — no parser
means they do nothing and print why on stderr, and `cleanup-handoffs.sh` fails in the
direction that keeps data, since without the reason it cannot tell a resume from a real
end.

**The dependency is swapped, not removed.** python is a dependency too. It wins on being
present where `jq` is not, on being a real JSON reader, and on precedent — the suite has
refused to run without it since it was written. `sed`/`grep` was rejected: a real command
arrives with its line breaks encoded as the two characters `\n`, and hand-decoding them
re-opens the multi-line flatten bug this directory has already shipped once.

## Run the suite

```bash
bash templates/hooks/test-hooks.sh
```

84 cases across all four blocking hooks: what must be blocked, what must be allowed, `Bash`
and `PowerShell` payloads, multi-line commands, and **both sides of every conditional
line** — a listed repo and an unlisted one, `.claude/agents/` and `.claude/handoffs/`.

**A green run now means two things, and it needs both:** the patterns match, **and** every
blocking hook fails closed. The second half is its own section — each blocking hook is
invoked once with a payload that will not parse, and once with a `PATH` that resolves no
python — because failing closed is new code in every one of those scripts, and this
directory has twice shipped a guardrail whose new code was never run. If the suite cannot
strip python off `PATH` it reports a **FAIL**, not a skip: a suite that quietly drops the
cases it could not set up is the green run that means less than it looks like.

Exit 0 means every case behaved; exit 1 means a guardrail is not guarding.

**The allowlist cases build their own scratch repo** with a known remote and two throwaway
`HOME`s, rather than keying on this repo's remote. A test that passes only in the clone it
was written in is a test that reports success somewhere it never ran.

**Run it after editing any hook.** These scripts cannot be verified by reading them — the
multi-line gap below survived a full audit that checked every claim against the official
docs, because the docs were not the thing that was wrong.

**What it still cannot tell you: whether the hooks are wired in.** The suite invokes the
scripts directly and never sees your `settings.json`, so a fully green run is compatible
with no hook firing on your machine at all. That is layer 3 in the table above, and it is
answered by the live check in [`docs/shared/03-setup.md`](../../docs/shared/03-setup.md) —
by that, and only by that.

### The multi-line gap, and why it is worth knowing

The three command-reading blocking hooks flatten the command before matching. They used to
turn newlines into **spaces**, and the patterns anchor on start-of-string or a `[;&|]`
separator — so in

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
| `block-dangerous-git.sh` | PreToolUse · Bash\|PowerShell | block reset --hard / force / --no-verify / branch -D / clean -fd, and push unless the repo is allowlisted | ✓ | ✓ |
| `block-mcp-writes.sh` | PreToolUse · mcp (tracker, git-host) | read-only veto — only get/list/search pass | ✓ | ✓ |
| `block-infra-staging.sh` | PreToolUse · Bash\|PowerShell | sort AI-infra paths: `.claude/agents\|skills` through, `CLAUDE.md` if allowlisted, the rest blocked | ✓ | ✓ |
| `block-secret-staging.sh` | PreToolUse · Bash\|PowerShell | block staging `.env`, key files and credential-shaped names; block token literals anywhere | ✓ | ✓ |
| `cleanup-handoffs.sh` | SessionEnd | delete the ephemeral handoff dirs | ✓ | ✓ |
| `format-on-edit.sh` | PostToolUse · Write/Edit | auto-format the file that was just edited | ✓ | ✓ |
| `repo-allowlist.sample` | — | the per-repo answers the two git hooks read; install **empty** at `~/.claude/repo-allowlist` | ✓ | |
| `test-hooks.sh` | — | regression suite for the four blocking hooks; run it, don't read it | ✓ | ✓ |

The **solo** / **team** columns say which entrance needs each template. The allowlist is the
first row to claim one column: on the team path the driver does not own the repo, so both
of its questions have one permanent answer and there is nothing to list.

## The allowlist — one file, outside every repo

Two of the hooks above ask a question a bash script cannot answer: **is this repo mine?**
`~/.claude/repo-allowlist` holds the answers — one line per repo, keyed by **remote URL**,
two answers per entry, **both defaulting to no**.

| Question | Read by |
|---|---|
| May the agent `git push` here? | `block-dangerous-git.sh` |
| Is this repo's `CLAUDE.md` its own — would a fresh clone need it? | `block-infra-staging.sh` |

Three properties, all of them the point:

- **Not listed means no.** A new repo is safe with **no action from you**, and the live
  project stays safe by omission rather than by being remembered. With no file at all, both
  hooks behave exactly as they did before the allowlist existed.
- **It lives outside every repo.** Inside the project the agent could write it and unblock
  itself, and §5's headline is *enforced by the harness, not by trust*.
- **Some things it never unlocks.** `git add -A` / `git add .`, and everything under
  `.claude/` that is not `agents/` or `skills/`, plus `.serena`, `.forgetful`, `MEMORY.md`.

**A bash script cannot judge provenance; you can.** The human declares it once and the hook
obeys — worth stating plainly rather than pretending the script got smarter. The reasoning
behind each answer is in
[`docs/solo/07-guardrails-when-solo.md`](../../docs/solo/07-guardrails-when-solo.md).

> **The lookup is duplicated in both hooks, deliberately.** A shared file you can forget to
> copy turns a guardrail into one that silently stops guarding — the exact failure this
> directory exists to prevent. Duplication is loud; a missing include is not.

**The hook and `.gitignore` have to sort the same way.** The hook blocks the *command*;
`.gitignore` makes the file invisible to it. A blanket `.claude/` ignore line hides the
generated specialists that are supposed to be committed, so whatever writes that line
writes the `!.claude/agents/` and `!.claude/skills/` exceptions with it. Two mechanisms, one
directory — moving one and not the other buys nothing.

## `Bash` is not the only shell

**`PowerShell` is a separate tool from `Bash`**, and a matcher of `Bash` does not see it.
On Windows it can be enabled automatically (no Git Bash) or arrive through a progressive
rollout (with Git Bash); elsewhere it is opt-in via `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`. A
git guardrail matched only on `Bash` therefore stops nothing the moment the model reaches
for PowerShell — the worst failure shape a guardrail has, since it keeps reporting success.
The shipped matcher is `Bash|PowerShell` for that reason.

The three blocking scripts parse `.tool_input.command`, which both tools populate, so they
work unchanged for either. **Their command patterns are POSIX-flavoured**, though: verify
the PowerShell path in a scratch repo rather than assuming, since `git push` reads the same
but a piped or `&&`-chained invocation may not.

Why a hook and not a CLAUDE.md line? A CLAUDE.md line is a *request* the model may
forget under load. A hook is a *guarantee* enforced by the harness. Anything you must
never allow belongs here.
