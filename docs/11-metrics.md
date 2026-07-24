# 11 — Measuring a pipeline run

If you can't measure it, you can't tell whether the setup is compounding or just feels
good. The goal is a **ledger**: one row per ticket, so "is the pipeline getting more
efficient?" is a number.

This is **optional** — skip it until the rest is smooth — but it's what turns anecdote
into evidence when you show the team.

---

## What to record per ticket

| Column | Why |
|---|---|
| **story points** (or your size unit) | the denominator — normalizes big vs small tickets |
| **tokens** (total, incl. all sub-agents) | the durable cost signal — survives model-price changes |
| **tokens per point** | the headline efficiency number |
| **cache-reuse ratio** | how much of the context was cheap cache vs fresh |
| **$ cost** (secondary) | derive from a price table, not hand-typed |

Token counts are the **ground truth** because they don't move when prices do. Treat
dollar columns as secondary and derive them from a price table you refresh when models or
prices change.

---

## The gotcha: sub-agent tokens

The pipeline's spend is mostly in **sub-agent** contexts (the gatherer, the specialists,
the reviewers) — often more than half of a run. A naive usage tool that only reads the
top-level session transcript will **undercount** badly. Your finalizer must walk the
sub-agent transcripts too and sum them. Get this right or the ledger lies.

---

## Where to keep it

- A **story-point estimator** agent reads the size from the tracker (or estimates from
  the plan + diff and asks you to confirm), and writes it to a per-ticket metrics file.
- **Session-start / finalize hooks** register a ticket and, at close, sum the tokens and
  write the ledger row.
- The **price table** lives in a data file you refresh from whatever usage tool you
  trust; the finalizer uses it purely as a price oracle for the secondary dollar columns.

---

## Measure the memory too

Retrieval quality is also a number: the `/garden-memory` golden-query eval
([10-memory-hygiene.md](10-memory-hygiene.md)) scores whether the canonical questions
still return the right answers, and flags regressions vs last month. A memory that
silently degrades is worse than no memory — so track it like you track the pipeline.
-e 
---
> **Last verified against:** Claude Code `[run \`claude --version\` and insert here]` — July 2026
