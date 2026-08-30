---
description: Periodic memory hygiene — golden-query retrieval eval + duplicate/stale/orphan sweep, with per-item approval.
---

Keep the memory signal-dense. There are two phases. Never delete or auto-edit silently.

## Phase A — retrieval eval (golden queries)
1. Load the version-controlled golden set (`<workspace>/.claude/memory-eval/golden-queries.yaml`).
   It holds canonical questions with **content assertions** (`must_contain_all` /
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
Retrieval quality is a tracked number. Treat a regression as a real defect.

## Then say what they do now

End with the `next-steps` block: the report's full path; the proposals still waiting on a
per-item approval, listed by what each one would do, because none of them happens without the
user; the regressions, if there are any, as the thing they decide about today; no next
command, because this runs on a period rather than on a queue; and nothing to commit — the
report lives under `.claude/`, which is never staged.
