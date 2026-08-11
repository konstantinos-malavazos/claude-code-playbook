---
description: End-to-end staging integration test — produce the real event, reconcile the result, bank/reuse a test recipe.
argument-hint: <TICKET-ID>
---

Prove `$ARGUMENTS` works against **staging** by producing the real domain event and
reconciling the resulting row/state. Also **learn the produce recipe** so future tests
of the same scenario reuse it.

## Sequence
1. **@ticket-analyzer** (+ **@context-gatherer** in test mode) — build an
   **acceptance-criteria checklist** and identify each domain event the ACs need
   produced.
2. **@test-planner** — for each `(scenario × event)`:
   - **Memory-first**: query for an existing `test-pattern` recipe.
     - **HIT** → re-pull the source (e.g. the acceptance-test flow) and **diff the stored
       fingerprint**. Unchanged → reuse. Changed → mark stale, re-derive, update.
     - **MISS** → trace the produce path once (which message / API call, in what order,
       for that scenario) + the verify target, and **bank a PROVISIONAL recipe**
       (confidence ~0.6, `validated: pending`) with a flow fingerprint.
   - Write the staging test plan (produce steps + reconciliation queries + pass/fail) and
     STOP for approval.
3. **@tester** — on approval, run it on **staging** — or **against local** on a project
   that has no staging tier:
   - **produce** the real event (the one allowed write path),
   - **reconcile** — poll the DB/store until the correctly-shaped row/state lands, with a
     timeout + stability check,
   - assign PASS / FAIL / INCONCLUSIVE per AC,
   - **confirm or correct the recipe** in memory (flip to `validated: <date>`, higher
     confidence — or fix a wrong step; never silently leave a wrong recipe validated).
4. Write `test-report.md`.

## Guardrails
Production forbidden. Read-first. **Staging where there is one; local where there is not.**
What does not change is that the event is produced **for real** and the resulting row is
**reconciled**. That is the whole value of the flow. Asserting against a mock proves the
mock works. Producing the event is the ONLY allowed write path; every other write-class
action needs explicit approval.
