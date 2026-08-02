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

On for every non-trivial conversation; I should not have to ask. If the message mentions
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
raw tracker command — state the intent (*read this ticket*, *give me the frontier*, *is
this blocked?*) and let that file answer it.

**Ask before writing anywhere other people can see it.** The adapter declares whether its
tracker is a shared place. Where it is, every write (comments, transitions, field edits,
assignments) needs my **explicit** approval, with the exact payload shown first — also
enforced by the `block-mcp-writes` hook. Where it is not — a private repo nobody else
reads — write freely. A **public** personal repo counts as shared.

## Git rules

- **Never `git push`** — I push manually.
- Never `--force`, `--no-verify`, amend a pushed commit, `reset --hard`, or delete
  branches without asking.
- Before a new branch: fetch, checkout the repo's prod-target main branch, `pull
  --rebase` (never plain merge), then branch. (Per-repo main branch is in the workspace
  CLAUDE.md.)
- **Never stage/commit AI-infra files**: `CLAUDE.md` (any depth), `.claude/`, MCP-state
  dirs, memory files. Use explicit paths in `git add` — never `git add -A`/`.`.

## Handoff protocol (ephemeral pipeline state)

In-flight pipeline state lives in `<workspace>/.claude/handoffs/<TICKET-ID>/<agent>.md` —
`.gitignore`d and auto-cleared at session end. Durable knowledge goes to memory; ephemeral
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
- <Any other environment/credential policy.>
