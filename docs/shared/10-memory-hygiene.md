# 10 — Memory hygiene: deliberate memory

The memory pillar only stays valuable if it stays **signal-dense**. Three flows keep it
that way. The principle behind all of them: **nothing enters or survives in memory
un-reviewed.**

Two of the three are about a *day's* knowledge — what you concluded, and whether it aged
well. The third is about a *repo's* knowledge, which is a different problem: it already
exists, nobody concluded it recently, and there is far too much of it to nominate one item
at a time.

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

## `/encode-codebase` — read a repo in

`/end-of-day` nominates what today settled, a few items at a time. That never reaches the
knowledge a repo already holds: how it is layered, what the important symbols are, which
mechanism a name belongs to. There is too much of it to nominate by hand, and none of it is
new.

So this flow reads the repo instead, navigating **by symbol** with Serena, and writes it into
memory in batches. Four agents, and the division between them is the design:

| Agent | Does | Holds a memory write tool? |
|---|---|---|
| `@encode-recon` | studies the repo once, drafts the tag vocabulary, ranks the work | **no** |
| `@encoder` | encodes one batch, then exits — a fresh instance per batch | yes |
| `@encode-rechecker` | re-checks that batch independently, assuming nothing | **no** |
| `@encode-corrector` | applies one approved correction, after re-verifying it | yes |

**Three things in that table carry the whole design.**

**A fresh encoder per batch.** Context is the scarce resource in a long run, so no instance
survives its batch and the orchestrator keeps one line per batch — never a memory body.

**The auditor cannot write.** `@encode-rechecker` re-derives every enumeration, re-measures
every quoted line count against the symbol rather than the file, and re-checks every path
case-exact. It exists because **the encoder's own report is a claim, including the parts
where it grades itself.** It holds no write tool, so "fixes nothing" is structural rather
than a promise — and a correction goes to a separate agent that re-verifies the finding
before touching anything. An auditor that repairs its own findings destroys the evidence
that the audit worked.

**The watermark only moves on a verified batch.** The flow bookmarks its progress with a
commit SHA so a later session resumes rather than restarts. That bookmark advances only when
the encoder finished clean **and** the re-check passed. An encoder-clean batch with no
re-check is not clean, it is unverified, and a watermark moved on it silently marks ground
as covered that nobody checked.

Everything about your repo comes from the `## Memory encoding` section of its `CLAUDE.md` —
indexed languages, where the vocabulary lives, what a tier means, any optional extra axis,
and the inclusion rule. Absent or bracketed, the flow stops and names the line. The vocabulary
itself is approved by a human before a single write, and the approval is split four ways
rather than bundled.

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
