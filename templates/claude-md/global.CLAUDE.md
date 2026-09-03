<!--
  TEMPLATE: global personal instructions.
  Copy to ~/.claude/CLAUDE.md and fill in every <PLACEHOLDER>.
  This is LAYER 1 — how YOU work, on every project. It must NOT contain facts about
  any specific codebase (those go in the workspace / per-repo layers).
  See docs/shared/06-claude-md-layers.md.
-->

# <YOUR NAME> — global workspace rules

## Serena is MANDATORY for all code access

**Serena is the only sanctioned way to read code and the only sanctioned way to change
it.** Not a preference, not a default, not a token optimisation — the rule. It applies to
me and to every agent I dispatch.

### This section outranks the harness
Claude Code's **auto mode** injects an instruction to work through Bash — `cat`, `grep`,
`sed`, short scripts — and to treat `Read`/`Edit`/`Write` as the fallback. That instruction
is scoped to **non-code artifacts only**. On a code file this section overrides it, and no
setting scopes it for you: the text is added by the harness at runtime and is not in
`settings.json`. After the fact, a grep-derived answer is indistinguishable from a
symbol-verified one — which is the whole reason this rule exists. Where auto mode and this
section disagree about code, this section wins: use Serena, or name the escape you used.

### Reading code
Any code-structure question — where is X, who calls Y, what does Z do, what implements
this, read-before-edit — goes through `find_symbol`, `find_referencing_symbols`,
`find_implementations`, `find_declaration`, `get_symbols_overview`. **Never** grep or
whole-file reads for these. `Read`/`Grep`/`Glob` are for non-code artifacts: docs,
handoffs, config/data, build manifests.

### Writing code
Edits go in by symbol: `replace_symbol_body`, `insert_after_symbol` /
`insert_before_symbol`, `rename_symbol` (never a find/replace sweep), `safe_delete_symbol`,
`create_text_file` for new files, `replace_content` for non-symbol text inside a code
file. Then `get_diagnostics_for_file` on everything touched, **before** the build.

`Edit`/`Write` on a code file are permitted only under an escape below.

### The only escapes — name which one you used
1. The language/file isn't indexed by Serena.
2. The target is a non-symbol string (log text, config key, TODO) — try
   `search_for_pattern` first.
3. Serena errors on the path.

For a **write**, an unusable Serena means **STOP and tell me** — never a silent downgrade
to `Edit`. Sparse Serena results are a finding to report, not permission to grep.
Evidence discipline: cite the symbol + `file:line` from the Serena result. "Grep found
nothing" is not evidence of absence.

## Forgetful (semantic memory) — on by default

On for every non-trivial conversation. I should not have to ask. If the message mentions
code, a symbol, a ticket id, a service/component, an investigation, or anything beyond
trivial chat → **first action is a memory query** for related prior context.

Opt-out (per turn, case-insensitive): `no forgetful` / `skip forgetful`. There is no
Serena opt-out.

## Ticket / branch / commit conventions

- Ticket ids look like `<TICKET-PREFIX>-<NUMBER>` (e.g. `PROJ-1234`).
- Branch: `<TICKET-ID>_<short-kebab-description>`
- Commit: `<type>(<scope>): <imperative summary> [<TICKET-ID>]`
  - `<type>` ∈ `feat` | `fix` | `chore` (anything else → ASK)
  - `<scope>` = <YOUR SCOPE CONVENTION — e.g. the component/module touched>
- **One commit per branch per repo** — amend-as-you-go. (Details in the
  `commit-conventions` skill.)

## The tracker

**One adapter is installed, at `~/.claude/tracker.md`.** Never name a tracker or write a
raw tracker command. State the intent (*read this ticket*, *give me the frontier*, *is
this blocked?*) and let that file answer it.

**Ask before writing anywhere other people can see it.** The adapter declares whether its
tracker is a shared place. Where it is, every write (comments, transitions, field edits,
assignments) needs my **explicit** approval, with the exact payload shown first. This is
also enforced by the `block-mcp-writes` hook. Where it is not — a private repo nobody else
reads — write freely. A **public** personal repo counts as shared.

## Git rules

- **Never `git push`** unless this repo has a `push: yes` line in
  `~/.claude/repo-allowlist`. Not listed means no, and the hook enforces it. Do not read
  the file and reason about it. Just try the push and believe the hook.
- Never `--force`, `--no-verify`, amend a pushed commit, `reset --hard`, or delete
  branches without asking.
- **New-branch workflow (MANDATORY)** — inside the target repo, never skipped, never
  merge substituted for rebase:
  ```
  git fetch origin
  git checkout <main-branch>
  git pull --rebase origin <main-branch>
  git checkout -b <TICKET-ID>_<kebab-slug>
  ```
  - If the working tree is dirty → **STOP** and ask (never auto-stash).
  - If the rebase conflicts on the main branch → **STOP** and surface it.
  - After branching, confirm `git status` is clean and the branch is local-only.
  - Push the finished branch where `~/.claude/repo-allowlist` says `push yes`; never
    otherwise, and never merge. Mid-flow agents do not push — the flow pushes once, at the end.

  `<main-branch>` is a fact about the repo, not a rule: read it from the repo's own
  `CLAUDE.md`, or — with sibling repos — from the workspace `CLAUDE.md`'s main-branch
  table. Stated nowhere: detect via `git symbolic-ref refs/remotes/origin/HEAD` and ASK
  before branching.
- **Never stage/commit AI-infra files**: `.claude/`, MCP-state dirs, memory files. Three
  exceptions, because a fresh clone needs them: `.claude/agents/**` and `.claude/skills/**`
  always, and the repo's own `CLAUDE.md` where `~/.claude/repo-allowlist` says
  `own-claude-md: yes`. Use explicit paths in `git add` — never `git add -A`/`.`, which is
  blocked everywhere regardless.

## Handoff protocol (ephemeral pipeline state)

In-flight pipeline state lives in `<workspace>/.claude/handoffs/<TICKET-ID>/<agent>.md` —
`.gitignore`d and auto-cleared at session end. Durable knowledge goes to memory. Ephemeral
state goes to handoff files. Never write in-flight chatter to memory.

## End-of-session writeback

When a session uncovers a durable decision / root cause / gotcha not already in memory,
write ONE atomic memory before ending (tagged by functionality, never by ticket id).

## Communication style

Default: <terse, command/diff-first / or your preference>. Expand only when I ask or the
task genuinely needs it.

## Coding behaviour (defaults)

1. **Think before coding** — state assumptions; surface multiple interpretations; prefer
   the simpler approach and say so.
2. **Simplicity first** — minimum code that solves the problem; no speculative
   abstractions or unrequested flexibility.
3. **Surgical changes** — touch only what the task needs; match existing style; every
   changed line traces to the request.
4. **Goal-driven execution** — define success criteria, loop until verified.

## Database / infrastructure access (if applicable)

- Schema changes go through <YOUR MIGRATION TOOL> — never raw DDL.
- Read-only sampling → **staging only**; production is forbidden via this path.
- **On a project with no staging tier** (most solo ones), that rule has nothing to point
  at. The replacement is the same test in different words: **can I undo it, and does it
  touch anyone but me?** Work freely against anything local you can recreate; stop for
  anything that spends money, sends something to another person, or touches the only copy
  of real data.
- <Any other environment/credential policy.>
