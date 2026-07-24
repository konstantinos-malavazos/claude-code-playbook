---
description: Periodic memory hygiene — golden-query retrieval eval + duplicate/stale/orphan sweep, with per-item approval.
---

Keep the memory signal-dense. Two phases; never delete or auto-edit silently.

## Phase A — retrieval eval (golden queries)
1. Load the version-controlled golden set (`<workspace>/.claude/memory-eval/golden-queries.yaml`)
   — canonical questions with **content assertions** (`must_contain_all` /
   `must_match_any`). Assert on **content, never memory ids**.
2. Run each query against memory; record pass/fail.
3. Append results to `<workspace>/.claude/memory-eval/results/<YYYY-MM>.md` and surface
   **regressions vs last month** (and recoveries) explicitly.

## Phase B — sweep
Look for and PROPOSE (apply only what's approved):
- near-duplicate memories → merge,
- superseded-but-unmarked memories → `mark_obsolete` + `superseded_by` pointer,
- memories missing their project/scope tags,
- tag-vocabulary violations,
- low-confidence orphans (nothing links to them).

## Output
Write the monthly report to `<workspace>/.claude/memory-eval/garden-report-<YYYY-MM>.md`:
eval results + regressions + sweep proposals + applied changes.

## Rules
Never delete a memory silently. Never auto-edit the golden set (it's human-owned).
Retrieval quality is a tracked number — treat a regression as a real defect.
