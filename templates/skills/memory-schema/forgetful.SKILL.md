---
name: memory-schema
description: >-
  Forgetful MCP's exact call shape and rules — wrapper-trio dispatch, required fields,
  strict enums, hard char caps, the asymmetric linking API, the tools that do not exist,
  and project-scope discipline. Auto-loads before any memory WRITE (create_memory,
  create_entity, create_document, create_project, link_*, update_memory) so the model uses
  the right shape and stops inventing fields. Also load it whenever a Forgetful tool errors
  with `validation failure`, `unexpected keyword argument` or `Input should be …` — before
  retrying.
---

# Memory schema — Forgetful

> **This is the filled-in variant of `SKILL.md` for one memory server: Forgetful.**
> If Forgetful is what you run, `mv forgetful.SKILL.md SKILL.md` and delete the
> placeholder. If you run something else, keep the placeholder and fill it in from your
> own server — this file is then a worked example of the level of detail that pays off.
>
> **Verify before you trust it.** Caps and enums move between Forgetful releases. The
> server tells you the truth itself: `discover_forgetful_tools` lists what exists,
> `how_to_use_forgetful_tool` gives one tool's real signature. When this file and the
> server disagree, the server is right — fix this file in the same session.

## Call shape

Forgetful exposes a wrapper trio: `mcp__forgetful__execute_forgetful_tool`,
`discover_forgetful_tools`, `how_to_use_forgetful_tool`. **Every** operation dispatches
through `execute_forgetful_tool(tool_name, arguments)` — the two are **siblings**. Nesting
`tool_name` inside `arguments` is the single most common failure, and it fails validation
every time.

CORRECT:
```
mcp__forgetful__execute_forgetful_tool(
  tool_name="create_memory",
  arguments={"title": "...", "content": "...", "context": "...",
             "keywords": [...], "tags": [...], "importance": 7}
)
```

WRONG:
```
mcp__forgetful__execute_forgetful_tool(
  arguments={"tool_name": "create_memory", ...}
)
```

## Required fields per primitive

### `create_memory` — all six are required

| Field | Cap | Notes |
|---|---|---|
| `title` | 200 chars | |
| `content` | 2000 chars | **hard cap — split, never trim** |
| `context` | 500 chars | where this came from / when it applies |
| `keywords` | 10 items | list of strings |
| `tags` | 10 items | list of strings |
| `importance` | int 1–10 | an **int**, not a string. 3 = low · 5 = normal · 7 = high · 9 = critical |

Over 2000 chars, split into 2–3 atomic linked memories rather than cutting the reasoning
out. Each part stands alone and points at the others in `context` — *"Part 2 of 3 — see
also '\<title> Part 1'"*. A trimmed memory is worse than two memories: the half that got
cut is always the *why*.

### `create_document`

| Field | Cap |
|---|---|
| `title` | 500 |
| `description` | 5000 |
| `content` | 100000 |
| `tags` | 10 |

### `create_entity`

- `name` ≤ 200
- `entity_type` — strict enum, see below
- `tags` ≤ 10

### `create_project`

- `name` ≤ 500
- `project_type` — strict enum, see below
- `repo_name` — if present, MUST be `owner/repo`. A bare name fails: **omit it** instead.

### `create_code_artifact`

- `title` ≤ 500 · `description` ≤ 5000 · `code` ≤ 50000 · `language` ≤ 100 · `tags` ≤ 10

## Strict enums — case-sensitive, exact

`Entity.entity_type`: `Organization` | `Individual` | `Team` | `Device` | `Other`

- `Other` **requires** `custom_type` (≤ 100). That is where anything technical goes:
  `kafka-topic`, `sftp-server`, `scheduled-job`, `mcp-server`, `report-endpoint`,
  `sql-source-table`, `catalog-schema`.
- These all **fail**, however natural they read: `Service`, `Interface`, `Database`,
  `Catalog`, `Component`, `Repository`, `Project`.

`Project.project_type`: `personal` | `work` | `learning` | `development` |
`infrastructure` | `template` | `product` | `marketing` | `finance` | `documentation` |
`development-environment` | `third-party-library` | `open-source`

`Project.status` (default `active`): `active` | `archived` | `completed`

## The linking API is asymmetric — learn the table

| Link | Mechanism |
|---|---|
| Entity → Memory | `link_entity_to_memory` |
| Entity → Entity | `link_entities` |
| Memory → Memory | **automatic** — cosine similarity ≥ 0.7 at create time |
| Memory → Document | `update_memory` with `document_ids` |
| Entity → Document | **not supported** — bridge it |

**Entity → Document workaround:** name the entity in the document's content, share tags
between them, and bridge with a Memory linked to both (`link_entity_to_memory` +
`update_memory.document_ids`).

## Tools that do not exist

| Do NOT call | Use instead |
|---|---|
| `list_memories` | `get_recent_memories` or `query_memory` |
| `link_memory_to_document` | `update_memory` with `document_ids` |
| `link_entity_to_document` | not supported — bridge via a Memory |

## Quirks worth knowing before you hit them

- `query_memory` does **not** accept `limit`. Omit it.
- `query_memory` ranks by semantic similarity; it is **not exhaustive**. For anything that
  must enumerate completely — an inventory, a per-item sweep — write a Document and read
  the Document. Do not ask a similarity search for a complete list.
- `list_entities` takes `project_ids` (**plural**, `list[int]`) — not `project_id`, and
  not `limit`.
- `search_entities` *does* take `limit`. Don't conflate the two.
- `Project.repo_name` is format-checked (`owner/repo`). `Memory.source_repo`,
  `Document.source_repo` and `Entity.source_repo` are **not** — a bare name is fine there.

## Which primitive

- **Memory** — one atomic fact or conclusion, ≤ 2000 chars: a convention, a gotcha, a root
  cause, a job's behaviour.
- **Document** — long-form, ≤ 100K: an architecture write-up, an inventory, a codified set
  of rulings. Anything a query must return *completely*.
- **Entity** — real-world things only. A catalog/schema, a Kafka topic, a source table →
  `Other` + `custom_type`. Code, notebooks and jobs are **Memories**, not entities.
- **CodeArtifact** — reusable code that will actually be pasted somewhere. Not a
  description of code.

## Tagging rules

- Tag **by functionality** — topic, component, symbol — **never by ticket id**. You will
  search by topic later and never by ticket number. Put the ticket id in `content` if you
  want the provenance.
- Include your scope/project tag, so `/garden-memory` can find untagged strays.
- Ten tags is the cap. Respect your locked vocabulary if you have one
  (see [`../memory-tag-lint/SKILL.md`](../memory-tag-lint/SKILL.md)).

## Content rules

- One atomic fact or conclusion per memory. State **what** and **why**.
- Link related memories so one query returns the whole chain — root cause → fix → blast
  radius → recipe.
- For recipes and hypotheses, carry a **confidence** and a **validated** marker in the
  content. Flip `validated` only after a real (e.g. staging) run confirms it.

## When to write

Durable conclusions only, at ticket APPROVE or via `/end-of-day`. Never write in-flight
chatter — that is what handoff files are for. See
[`../../../docs/shared/10-memory-hygiene.md`](../../../docs/shared/10-memory-hygiene.md).

## Project-scope discipline

Always set `project_ids` on a new memory. A memory with `project_ids: []` is invisible to
every project-scoped query — it is not lost, it is worse: it is there and never returned.

**Do not hardcode project ids in this file.** They are per-instance and they drift. Resolve
them with `list_projects` at the start of a writing session and reuse the answer for that
session.

## On any validation error

Read the error. Fix the **exact** field it names. Retry once. **Never retry unchanged** —
Forgetful's errors are precise, so an unchanged retry is a guaranteed second failure.

| Error | What it means |
|---|---|
| `unexpected keyword argument 'tool_name'` | you nested it inside `arguments` |
| `Input should be 'Organization'…` | invalid `entity_type` |
| `String should have at most 2000 characters` | split the content, don't trim it |
| `custom_type is required when entity_type is 'Other'` | add `custom_type` |
| `repo_name must follow 'owner/repo' format` | fix it or omit it |
| `got an unexpected keyword argument 'limit'` on `list_entities` | drop `limit` |
| `tool link_memory_to_document not found` | use `update_memory.document_ids` |
| `missing 1 required positional argument: 'importance'` | add the int |
| `Input should be a valid integer` on `importance` | `7`, not `"high"` |
