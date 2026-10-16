---
description: Reopen an in-flight ticket across sessions; if it had deferred decisions, collect answers and re-enter in delta mode.
argument-hint: <TICKET-ID>
---

Resume `$ARGUMENTS`. Its handoff files may still be there, or you may have deleted
them; handoffs are never a durable store. Rehydrate from what is left. Don't redo finished work.

## Sequence
1. **Rehydrate** — read `<workspace>/.claude/handoffs/$ARGUMENTS/open-questions.md`: if it
   exists, the ticket is mid-flight and its open questions are there. Read the branch's
   current state (commits, TODOs). Re-fetch the ticket (read-only).
   If `<workspace>/.claude/handoffs/$ARGUMENTS/manual_handoffs/` exists, a gate checkpoint
   stopped the run: read the newest file in it, by the `<utc>` in its name, and parse its
   first line, `Resume: ticket=<TICKET-ID> gate=<gate> next=<re-entry step>`. Its `gate=` and
   `next=` values are the re-entry point, and the rest of the file is what that session
   carried forward. Check that gate against the disk first: a top-level handoff file in
   `<workspace>/.claude/handoffs/$ARGUMENTS/` written after that `<utc>`, or a branch commit
   after it, means the run went on past the gate. When they disagree, show the user the
   checkpoint's gate and what the disk shows, and ask which point to resume from. Never
   re-enter at a gate the disk has already passed.
2. **Plain resume?** If there is no `open-questions.md`, or nothing in it is open: load
   context, summarise where things stand, and STOP — hand control back to the user. **Handing control back is not a next step**, so
   end with the `next-steps` block: the branch, its sha and what is already done; the decision
   or the piece of work that is theirs; and the concrete re-entry point — the `next=` step of
   a gate checkpoint where step 1 found one, the next layer in the chain, or review (per-repo reviewers, then the judge, as `/start-ticket` step 6) and
   land where the code is finished. This session, since it is
   already rehydrated.
3. **Deferred decisions pending?** Ask the user whether the open questions now have
   answers (from a tracker comment / a spec page / typed here / still open). Collect what
   you can, read-only. Partial answers are fine.
4. **Delta mode** — re-enter the pipeline for only what changed:
   - **@context-gatherer** resume-delta (explore only what the new answers or changed code
     scope — never a full re-sweep); if its `## Stale memories` section is not `none`,
     relay its warning line to the user verbatim and carry on,
   - if that delta brief lists `## Missing repo coverage` — a repo the delta reaches that no
     baseline brief covers — dispatch one **@repo-gatherer** per listed repo, **all in one
     message**, each → `repo-gatherers/<key>.md`. On route C, start their servers first with
     `bash ~/.claude/serena/serena-up.sh <key...>`. Then **@context-gatherer** in **stitch
     mode** joins them into `context-gatherer.md`. One round only: what is still missing stays
     `[UNVERIFIED]` for the planner to raise. Relay the stitched brief's `## Stale memories`
     the same way,
   - **@planner** RE-PLAN (lift placeholders, promote parked slices, surface new
     questions),
   - a fresh **grilling** round for anything still open.
   Loop until nothing's open, then end with the `next-steps` block naming the re-entry point
   the loop reached: back into the chain for the placeholders it lifted, or straight to review
   and land where nothing changed the code. This session — the delta is in context. Back in
   the chain, every implementation dispatch carries the `## Dispatch paragraph` of the
   `code-access` skill, as `/start-ticket`'s dispatch rule says.
5. Merge metrics into the existing ledger row (don't create a new one).

## Guardrails
Never redo already-approved work. Tracker read-only. Push the branch where allowlisted;
never merge.
