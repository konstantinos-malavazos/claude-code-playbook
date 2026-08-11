---
name: diagnose
description: >-
  Disciplined diagnosis loop for hard bugs and performance regressions. Use when the user
  says "diagnose this" / "debug this", reports something broken/throwing/failing, or
  describes a performance regression.
---

# Diagnose — a disciplined loop

Don't guess-and-patch. Prove the cause, then fix the cause.

## The loop
1. **Reproduce.** Get a reliable, minimal repro. If you can't reproduce it, you can't
   claim to have fixed it. Say so, and gather more info instead of guessing.
2. **Minimise.** Strip the repro to the smallest input/state that still triggers it.
3. **Hypothesise.** State a specific, falsifiable hypothesis about the cause.
4. **Instrument.** Add logging/assertions/measurements that will confirm or refute the
   hypothesis. Let the data decide. Don't pattern-match to a "usual suspect".
5. **Fix the cause, not the symptom.** Once the data proves the cause, make the smallest
   change that addresses it.
6. **Regression-test.** Add a test that would have caught this (see the `tdd` skill).
   Confirm the repro is gone and nothing else broke.

## For performance regressions
- Measure first: find the actual hot path / bottleneck with data, not intuition.
- Compare against a known-good baseline (a prior commit / tag) where possible.
- Fix the dominant cost. Re-measure to confirm the win is real.

## Discipline
- Never assume. Prove from returned data / measurements.
- Never patch code you don't understand the failure of.
- If the evidence contradicts your first hypothesis, drop it. Don't defend it.
