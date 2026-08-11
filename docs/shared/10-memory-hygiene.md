# 10 — Memory hygiene: deliberate memory

The memory pillar only stays valuable if it stays **signal-dense**. Two flows keep it
that way. The principle behind both: **nothing enters or survives in memory
un-reviewed.**

---

## `/end-of-day` — daily nomination

At the end of a working day, scan the day's session transcripts and extract **durable
conclusions** worth keeping:

- root causes,
- negative / staging findings ("X doesn't work because Y; here's what we ruled out"),
- cross-repo blast-radius facts,
- reusable recipes,
- settled decisions.

For each candidate: **dedupe against existing memory**, draft it to a review file, and
present it **one at a time** for explicit approval. Write to memory **only on per-item
approval**.

The bar is **high**: 0–5 candidates on a normal day, and **zero is a correct outcome**.
Most of what happens in a day is not durable knowledge. If everything gets nominated, the
memory becomes a junk drawer and retrieval quality collapses.

What *doesn't* go in:

- in-flight ticket state (that's what handoff files were for — and they've evaporated),
- anything already recorded in code, git history, or a CLAUDE.md,
- facts that only matter to today's conversation.

---

## `/garden-memory` — periodic hygiene

Run monthly (or when retrieval feels off). Two phases.

### Phase A — retrieval eval (golden queries)

Keep a version-controlled set of **golden queries** with **content assertions** — "this
question must retrieve a memory containing these facts." Assert on **content, never on
memory ids**, because ids churn and the knowledge should not. Run the queries, log
pass/fail, and surface **regressions vs last month** explicitly. Retrieval quality becomes
a tracked number, not a vibe.

### Phase B — sweep

Look for:

- near-duplicate memories → propose a merge,
- superseded-but-unmarked memories → mark obsolete with a `superseded_by` pointer,
- memories missing their project/scope tags,
- tag-vocabulary violations,
- low-confidence orphans (nothing links to them, low confidence).

Propose fixes. Apply **only what's approved**. **Never delete** silently, and never
auto-edit the golden set.

---

## Why this discipline pays off

An un-gardened memory decays two ways. It fills with noise, so retrieval returns junk. It
also goes stale, so it returns confidently-wrong old conclusions. The daily gate stops the
first. The periodic eval and sweep stop the second. Together they're the difference
between a memory you trust on ticket N+50 and one you've learned to ignore.
---
> **Last verified against:** Claude Code `2.1.226` — August 2026
