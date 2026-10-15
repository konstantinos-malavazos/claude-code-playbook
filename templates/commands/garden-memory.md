---
description: Periodic memory staleness report — checks every memory against its repo's main branch and the lint, writes a dated report, and changes nothing without a per-row approval.
argument-hint: "[apply <YYYY-MM-DD>]"
---

Find the memories that have gone stale. The report run is **read-only**. Memory changes
only in `apply` mode, one approved row at a time. Never delete a memory.

## Report (`$ARGUMENTS` empty)
1. **List every memory.** Load `memory-schema` first. There is no list-all tool: use
   `get_recent_memories`, then query per project for any project it left out. Dump them to
   `<workspace>/.claude/memory-garden/<YYYY-MM-DD>.json` as one JSON array, one object per
   memory as the server returns it: `id`, `title`, `content`, `context`, `keywords`, `tags`,
   `importance`, `project_ids`, `source_files` and, in a multi-repo workspace, `source_repo`
   (the repo's folder name under the workspace).
2. **Run the `memory-lint` skill's `garden_check.py`** on the dump:
   ```bash
   python ~/.claude/skills/memory-lint/garden_check.py \
     <workspace>/.claude/memory-garden/<YYYY-MM-DD>.json --workspace <workspace>
   ```
   Exit `2` means it could not read the dump, the workspace or its vocabulary: stop and
   show its stderr. It never calls the memory server. It finds each repo's main branch in
   the workspace `CLAUDE.md` `Main branch per repo` table, else `refs/remotes/origin/HEAD`;
   neither gives a `setup` row, never a guess. Ask the user for that repo's main branch.
3. **Read its rows**, one per finding, tab-separated, no header:
   `memory_id <TAB> check <TAB> finding <TAB> proposed_action`. `check` is `setup` or one
   of four checks:
   - `a-source-files`: every `source_files` path exists, case-exact, on the repo's main branch
     (`git ls-tree`). A miss is explained as a case mismatch, a rename
     (`git log --follow -M`), or deleted;
   - `b-code-symbol`: every backticked code symbol in the content still exists on main;
   - `c-lint`: the lint, re-run on the stored memory, catches vocabulary drift;
   - `d-duplicate`: near-duplicates: the same type, plus a similar title or overlapping `source_files`.
4. **Confirm the `b-code-symbol` rows (action `confirm-via-serena`) in one Serena pass** — `find_symbol` on the missed symbols only.
   A symbol Serena finds is not stale: drop its row.
5. **Write the report** to `<workspace>/.claude/memory-garden/<YYYY-MM-DD>.md`: one table
   row per finding — memory id, title, check, why, the proposed action, and an empty
   **Decision** column.

A proposed action is one of: fix the path or symbol (`update_memory`); fix the tags; merge
a duplicate (update the survivor, mark the other obsolete with `superseded_by` pointing at
it); mark obsolete with `superseded_by` when another memory replaced it; or leave it.
**Usage alone never justifies obsolete.** A memory nobody has queried can still be the one
that saves the next investigation.

## Apply (`$ARGUMENTS` = `apply <YYYY-MM-DD>`)
Open that day's report and walk its rows one at a time. For each row, show the exact memory
call it would make and make it only on an explicit yes. Write the answer, yes, no or skip,
into the row's Decision column. One yes covers one row, never a batch. Never delete.

## Then say what they do now

End with the `next-steps` block: the report's full path; the rows still without a Decision,
listed by what each would do, because none of them happens without the user; the next
command — `/garden-memory apply <YYYY-MM-DD>` while any row is undecided, none once every row
has one, because this runs on a period rather than on a queue; and nothing to commit — the
report lives under `.claude/`, which is never staged.
