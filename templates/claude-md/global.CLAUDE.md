<!--
  TEMPLATE: global personal instructions.
  Copy to ~/.claude/CLAUDE.md and fill in every <PLACEHOLDER>.
  This is LAYER 1 — how YOU work, on every project. It must NOT contain facts about
  any specific codebase (those go in the workspace / per-repo layers).
  See docs/06-claude-md-layers.md.
-->

# <YOUR NAME> — global workspace rules

## MCP tools — always on by default

**Serena** (code navigation) and **Forgetful** (semantic memory) are **on by default**
for every non-trivial conversation. I should not have to ask for them.

### Opt-out (per turn, case-insensitive)
- `no serena` / `skip serena` → fall back to grep / file reads this turn
- `no forgetful` / `skip forgetful` → skip memory this turn
- `no mcp` / `skip mcp` → both off this turn

### Mandatory FIRST actions of any non-trivial conversation
1. If the message mentions code, a symbol, a ticket id, a service/component, an
   investigation, or anything beyond trivial chat → **first action is a memory query**
   for related prior context.
2. For ANY code-structure question (where is X, who calls Y, what does Z do, read before
   edit) → use Serena `find_symbol` / `find_referencing_symbols` / `get_symbols_overview`
   **before** grep or whole-file reads.

## Ticket / branch / commit conventions

- Ticket ids look like `<TICKET-PREFIX>-<NUMBER>` (e.g. `PROJ-1234`).
- Branch: `<TICKET-ID>_<short-kebab-description>`
- Commit: `<type>(<scope>): <imperative summary> [<TICKET-ID>]`
  - `<type>` ∈ `feat` | `fix` | `chore` (anything else → ASK)
  - `<scope>` = <YOUR SCOPE CONVENTION — e.g. the component/module touched>
- **One commit per branch per repo** — amend-as-you-go. (Details in the
  `commit-conventions` skill.)

## Tracker is READ-ONLY by default

Never write to the tracker (comments, transitions, field edits, assignments) without my
**explicit** approval, with the exact payload shown first. (Also enforced by the
`block-mcp-writes` hook.)

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
