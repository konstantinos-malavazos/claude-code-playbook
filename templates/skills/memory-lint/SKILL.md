---
name: memory-lint
description: >-
  The rules every memory write must pass — one type tag, the type's importance band,
  repo-relative source_files, one owning project, the tag vocabulary, and no line refs,
  branch state or flow-state words — kept as data in vocab.json and checked by lint.py.
  A hook runs it before every Forgetful write and blocks a write that fails. Load it when a
  memory write was blocked with a `FAIL <rule>:` line, when a `WARN` line comes back, when
  filling or editing vocab.json, or before running garden_check.py by hand. Triggers on
  "memory-lint", "vocab.json", "repo_tags is empty", "write blocked", "type tag".
---

# Memory lint

One vocabulary for every memory, so the staleness checks have something stable to check.
The rules are data: every list, band and pattern lives in `vocab.json` beside `lint.py`.
Change the file, not the script. `memory-schema` carries the server's call shape; this skill
carries what a write must say.

---

## When it runs

| Where | What runs | What happens on a FAIL |
|---|---|---|
| Hook, before `mcp__forgetful__execute_forgetful_tool` | `lint.py` on the call's `tool_input` | the write is blocked; the FAIL lines are the reason |
| `/garden-memory` | `garden_check.py`, which re-runs the lint on every stored memory as a create | a `c-lint` row in the report |
| By hand | either script | nothing; it only prints |

The hook lints `create_memory` in full and `update_memory` on the fields it supplies. Any
other tool passes once the hook can read it. The hook **fails closed**: a missing or broken
hook library, no python, or a payload it cannot parse (or one with no inner `tool_name`)
blocks **every** Forgetful call, reads included. A missing `lint.py` or a broken
`vocab.json` blocks the write.

By hand, from anywhere (the lint finds `vocab.json` from its own folder):

```bash
printf '%s' '{"tool_name": "create_memory", "arguments": {...}}' \
  | python ~/.claude/skills/memory-lint/lint.py
echo "exit $?"
```

stdin is the hook's `tool_input` only — `{"tool_name": "<inner tool>", "arguments": {...}}`.
Pass the whole hook payload and the lint refuses it: `FAIL payload: got the whole hook
payload — pass its tool_input`.

---

## Reading the output

One line per finding, LF only:

```
FAIL <rule>: <reason>
WARN <rule>: <reason>
```

| Exit | Means |
|---|---|
| `0` | no FAIL. WARN lines may still be printed, and the write goes through |
| `3` | at least one FAIL, or input the lint cannot read (`payload`, `vocab`, `internal`) |
| anything else | the interpreter broke; the hook blocks |

Key on the exit code, never on empty output: a passing write can still print WARN lines.

| Rule | What fails |
|---|---|
| `payload` | invalid JSON, empty stdin, no `tool_name`, `arguments` not an object, the whole hook payload |
| `vocab` | `vocab.json` missing, not an object, missing a key, or an empty `types` table |
| `internal` | the lint itself crashed |
| `required` | a create lacks a field in `required_create_fields` |
| `type` | not exactly one tag from `types` |
| `importance` | not an int from 1 to 10, or outside the type's band ± `importance_tolerance` |
| `source_files` | not a list; an empty, absolute, drive-letter, backslashed or `..` path; missing or too short on a type that requires it |
| `project_ids` | not a list of exactly one int |
| `keywords`, `tags` | not a list, or over `max_keywords` / `max_tags` |
| `tag-case` | a tag with an uppercase letter |
| `tag-rename` | a tag listed in `renames`; the reason names its replacement |
| `tag-retired` | a tag listed in `retired`; the reason gives why |
| `tag-ticket-id` | a tag matching `ticket_id_pattern`. Tag by functionality; put the id in content |
| `repo-tag` | no repo/project tag (see below) |
| `functional-tag` | a tag outside `functional_tags`, once that list is filled |
| `line_refs`, `branch_state`, `flow_state` | a `content_reject` pattern matched `title`, `content` or `context` |
| `hard_counts` | a `content_warn` pattern matched — WARN only. Counts go stale; say "the flags", not "5 flags" |

On an update, `required` is skipped, the importance band is checked only when `tags` is also
supplied, and `source_files` only when supplied.

### `WARN repo-tag: repo_tags is empty — repo-tag rule not checked`

`repo_tags` ships empty, so the lint cannot tell a repo tag from any other tag. Until it is
filled, every write prints this WARN and passes, as long as it carries at least one tag
besides the type tag; a type tag alone is a `FAIL repo-tag`.

It closes when you list your repo/project tags in `repo_tags`. From then on, every write
needs at least one of them, and the WARN stops.

---

## The create payload the lint passes

```json
{"title": "...", "content": "...", "context": "...",
 "keywords": ["..."],
 "tags": ["gotcha", "<repo-tag>"],
 "importance": 8,
 "project_ids": [<owner-id>],
 "source_files": ["path/in/repo.py"],
 "source_repo": "<repo-folder-name>"}
```

- **One type tag** in `tags`, and the importance within its band.
- **`project_ids` of length 1**: the owning project, never a list of everyone it touches.
- **`source_files` as repo-relative paths**, forward slashes, from the repo root.
- **`source_repo`** is optional for the lint. `/garden-memory` uses it to find the repo in a
  multi-repo workspace; without it the workspace itself must be the repo.

---

## `vocab.json`, key by key

JSON cannot carry comments, so the meanings live here.

| Key | Holds | Ships as |
|---|---|---|
| `types` | the memory types: each maps to `importance` (the band centre), `source_files` (`"required"` or `"optional"`) and, optionally, `min_source_files` | seven types; `contract` needs 2 files (both sides) |
| `importance_tolerance` | how far importance may sit from the band centre | `1` |
| `required_create_fields` | fields a create must supply | the six server-required fields plus `project_ids` |
| `max_tags`, `max_keywords` | list caps | `10`, `10` |
| `repo_tags` | your repo/project tags; every write needs at least one | **empty** |
| `functional_tags` | the allowed functional tags; once filled, any other tag fails | **empty** |
| `renames` | `{"old": "new"}`; the old tag fails and names the new one | **empty** |
| `retired` | `{"tag": "why"}`; the tag fails with the why | **empty** |
| `ticket_id_pattern` | `{"pattern", "ignore_case"}` for tags shaped like a ticket id | `PROJ-123` style |
| `content_fields` | the fields the content patterns scan | `title`, `content`, `context` |
| `content_reject` | `{rule: [{"pattern", "ignore_case"}, ...]}`; a match FAILs under that rule name | `line_refs`, `branch_state`, `flow_state` |
| `content_warn` | the same shape; a match only WARNs | `hard_counts` |
| `garden` | read by `garden_check.py` only: `duplicate_title_ratio` and `code_symbol_pattern` | `0.85`, an identifier pattern |

Every key except `garden` must be present, and `types` must not be empty, or every write
fails with `FAIL vocab`; `garden_check.py` also needs `garden`. Patterns are Python regular expressions, escaped for JSON
(`\\b`, `\\d`). The first match per rule per field is reported.

**Filling the empty ones:**

1. **`repo_tags` first** — one tag per repo or project you write memories about, lowercase.
   This closes the WARN.
2. **`functional_tags` second, or never.** Filled, it turns every tag that is not a type or
   repo tag into a FAIL unless listed, so filling it before `repo_tags` blocks every repo tag.
3. **`renames` and `retired`** as the vocabulary changes. Rename rather than retire when a
   successor exists, so the FAIL tells the writer what to use.
4. **`types`** — edit the bands or add a type. Every type needs `importance`; a type
   without `source_files` treats it as optional.

Run `/garden-memory` after a vocabulary change: its `c-lint` rows are the stored memories the
new vocabulary no longer passes.

---

## `garden_check.py`

```bash
python ~/.claude/skills/memory-lint/garden_check.py <memories.json> --workspace <dir>
```

- **Input:** a JSON array of stored memories, each with `id`, `title`, `content`, `context`,
  `keywords`, `tags`, `importance`, `project_ids`, `source_files` and, in a multi-repo
  workspace, `source_repo` (the repo folder's name under `<dir>`).
- **Main branch** per repo: the `Main branch per repo` table in `<dir>/CLAUDE.md`, else
  `refs/remotes/origin/HEAD`. Neither gives a `setup` row, never a guess.
- **Output:** one row per finding, tab-separated, LF only, no header:
  `memory_id <TAB> check <TAB> finding <TAB> proposed_action`. `check` is `a-source-files`,
  `b-code-symbol`, `c-lint`, `d-duplicate` or `setup`. A `b-code-symbol` row's action is
  `confirm-via-serena`.
- **Exit:** `0` when the run completes, whatever it found; `2` on a dump, workspace, lint or
  vocab it cannot read (the reason is on stderr).
- **Read-only:** git reads only. It never writes to git or to memory, and never calls the
  memory server.
