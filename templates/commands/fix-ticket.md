---
description: Fix a QA bounce-back on an existing ticket — diagnose root cause, fix, amend in place.
argument-hint: <TICKET-ID>
---

A previously-shipped ticket (`$ARGUMENTS`) came back from QA. Fix it **in place** so it
stays one ticket / one commit per repo / one metrics row.

## Sequence
1. **Load context** — read the consolidated memory for `$ARGUMENTS` and the merged code.
   Re-fetch the ticket + QA comments (read-only) for the reported failure.
2. **@fixer-planner** — using the `diagnose` skill,
   reproduce and root-cause the bug. **If it can't be reproduced or explained, STOP and ask
   the user for more info. Do not guess.** Write a fix plan with track allocation, and a
   weight per track classified with the `dispatch-weight` skill — a QA bounce-back is its own
   dispatch and gets its own classification, never the shipped ticket's.
3. **Fix** — dispatch the responsible layer specialist(s), **each on its track's weight**:
   `light` → no override, so the specialist runs on its own pinned model (normally
   `<MODEL-CHEAP-ID>`); `heavy` → the tier `<MODEL-STRONG-ID>` belongs to, for that run only.
   Never below the tier that track last ran at, and never below the specialist's pinned
   `model:`. Write a **failing test that
   reproduces the bug first** (`tdd` skill), then make it pass.
4. **Amend, don't add** — the fix amends the existing branch commit (amend-as-you-go).
   No `fix: address QA` follow-up commits.
5. **Review** — @repo-reviewer → @release-reviewer, same as /start-ticket.
6. **Land** — update the ticket's durable memory with the root cause + fix (append, don't
   duplicate). Push the branch where allowlisted; the user merges.

## Guardrails
Same as /start-ticket: push the branch where allowlisted but never merge, tracker
read-only, one commit per repo, no AI-infra
files committed.
