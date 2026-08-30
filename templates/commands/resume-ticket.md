---
description: Reopen an in-flight ticket across sessions; if it had deferred decisions, collect answers and re-enter in delta mode.
argument-hint: <TICKET-ID>
---

Resume `$ARGUMENTS`. Its handoff files were wiped at session end (by design). Rehydrate
from durable state. Don't redo finished work.

## Sequence
1. **Rehydrate** — read the ticket's durable memory (including any `deferred-decisions`
   record) and the branch's current state (commits, TODOs). Re-fetch the ticket
   (read-only).
2. **Plain resume?** If nothing was deferred: load context, summarise where things stand,
   and STOP — hand control back to the user. **Handing control back is not a next step**, so
   end with the `next-steps` block: the branch, its sha and what is already done; the decision
   or the piece of work that is theirs; and the concrete re-entry point — the next layer in
   the chain, or review and land where the code is finished. This session, since it is
   already rehydrated.
3. **Deferred decisions pending?** Ask the user whether the open questions now have
   answers (from a tracker comment / a spec page / typed here / still open). Collect what
   you can, read-only. Partial answers are fine.
4. **Delta mode** — re-enter the pipeline for only what changed:
   - **@context-gatherer** resume-delta (explore only what the new answers or changed code
     scope — never a full re-sweep),
   - **@planner** RE-PLAN (lift placeholders, promote parked slices, surface new
     questions),
   - a fresh **grilling** round for anything still open.
   Loop until nothing's open, then end with the `next-steps` block naming the re-entry point
   the loop reached: back into the chain for the placeholders it lifted, or straight to review
   and land where nothing changed the code. This session — the delta is in context.
5. Merge metrics into the existing ledger row (don't create a new one).

## Guardrails
Never redo already-approved work. Tracker read-only. Push the branch where allowlisted;
never merge.
