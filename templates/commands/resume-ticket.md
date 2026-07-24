---
description: Reopen an in-flight ticket across sessions; if it had deferred decisions, collect answers and re-enter in delta mode.
argument-hint: <TICKET-ID>
---

Resume `$ARGUMENTS`. Its handoff files were wiped at session end (by design) — rehydrate
from durable state, don't redo finished work.

## Sequence
1. **Rehydrate** — read the ticket's durable memory (including any `deferred-decisions`
   record) and the branch's current state (commits, TODOs). Re-fetch the ticket
   (read-only).
2. **Plain resume?** If nothing was deferred: load context, summarise where things stand,
   and STOP — hand control back to the user.
3. **Deferred decisions pending?** Ask the user whether the open questions now have
   answers (from a tracker comment / a spec page / typed here / still open). Collect what
   you can, read-only. Partial answers are fine.
4. **Delta mode** — re-enter the pipeline for only what changed:
   - **@context-gatherer** resume-delta (explore only what the new answers or changed code
     scope — never a full re-sweep),
   - **@planner** RE-PLAN (lift placeholders, promote parked slices, surface new
     questions),
   - a fresh **grilling** round for anything still open.
   Loop until nothing's open.
5. Merge metrics into the existing ledger row (don't create a new one).

## Guardrails
Never redo already-approved work. Tracker read-only. Never push.
