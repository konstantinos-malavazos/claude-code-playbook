---
name: tdd
description: >-
  Test-driven development with the red-green-refactor loop. Use when building a feature
  or fixing a bug test-first, when the user mentions "red-green-refactor" or "test
  first", or when a bug fix needs a reproducing test before the fix.
---

# TDD — red / green / refactor

## The loop
1. **Red** — write a test that expresses the desired behaviour and **fails** for the
   right reason. Run it. Confirm it fails.
2. **Green** — write the **minimum** code to make it pass. No more.
3. **Refactor** — clean up with the test as a safety net. Re-run. Stay green.

## For bug fixes specifically
- First write a test that **reproduces the bug** (fails on current code). This proves you
  understand the bug and prevents regression.
- Then make it pass with the smallest change.
- "Fix the bug" → "write a failing test that reproduces it, then make it pass."

## Rules
- Test **behaviour through public interfaces**, not private internals. Tests shouldn't
  break when you refactor without changing behaviour.
- One behaviour per test; a clear name that states the expectation.
- Don't test the framework, generated code, or impossible states.
- Keep the arrange/act/assert structure obvious.

## When NOT to force it
Exploratory spikes and throwaway prototypes don't need TDD, but the moment code is
meant to survive, back it with tests.
