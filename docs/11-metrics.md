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

---

## Measuring output quality

Token-per-point tells you the pipeline is *efficient*. It doesn't tell you
it's producing *good work*. Quality is harder to measure than cost, but it's
more important — a pipeline that produces fast, confident wrong answers is
worse than a slow human. Here are low-effort proxies that catch degradation
early.

### Review comments per PR

A rising trend in review comments (normalised by changed lines) usually means
the plan or implementation is missing things the reviewer has to catch. It's
the earliest signal — you see it before anything ships.

**What it misses:** thorough reviews produce more comments than shallow ones.
A spike might mean the reviewers got better, not the pipeline got worse.
Correlate with time-to-merge (below) to disambiguate.

### Revert / hotfix rate

A change that ships, ships broken, and gets reverted or hotfixed is the
clearest quality failure. Track per-ticket: was there a post-merge revert or
hotfix within 14 days? If that rate climbs, something in the pipeline is
systematically wrong — likely the acceptance criteria coverage or the test
step.

**What it misses:** low-frequency events need a long window to be meaningful.
On a small team you might go months between reverts; an empty revert log
doesn't prove quality is good, just that nothing was bad enough to undo.

### Time-to-merge

From the first commit on the branch to merge. A widening gap (controlled
for ticket size) suggests the review cycle is getting longer — specialists
aren't converging, or the plan needs more revision passes. A shrinking gap
combined with rising revert rate suggests quality is being sacrificed for
speed.

**What it misses:** heavily confounded by human availability. A ticket that
sits for three days waiting for you to review it isn't the pipeline's fault.
Filter out stalls (no human action > 24h) before trending.

### Rework commits (amend count)

Each `/start-ticket` branch should have exactly one commit per repo. If the
bash history shows an amend happening multiple times per specialist, the
specialists aren't getting the handoff right — the contract between layers
is wrong or incomplete. A spike in amend count per ticket is a leading
indicator of design-stage weakness.

**What it misses:** one specialist may legitimately need to amend to fix a
build break. Track the *reason* for the amend, not just the count. A
dedicated "amend reason" label in the metrics ledger helps here.

### When to worry

Any single proxy trending bad is a prompt to look closer. Two or more
trending bad at once is a signal the pipeline needs a design-stage audit —
likely the planners' handoffs are underspecified or the gatherer's sweep
is missing coupling.

**The hard truth:** none of these proxies cleanly separate "the pipeline
produced bad work" from "the ticket was hard" from "the human was
distracted". They're leading indicators, not diagnoses. But a team that
watches them and discusses the outliers will catch degradation months
before a team that doesn't.
