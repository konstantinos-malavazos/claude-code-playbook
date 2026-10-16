---
name: tdd
description: >-
  Test-driven development with the red-green-refactor loop. Use when building a feature
  or fixing a bug test-first, when the user mentions "red-green-refactor" or "test
  first", or when a bug fix needs a reproducing test before the fix.
---

# TDD — red / green / refactor

> Prior art: mattpocock/skills@49dd158 `tdd` (MIT) — the two anti-patterns below.

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
- **Test at the seam the plan names.** Where `planner.md` has a `## Testing seams` section,
  test only at those seams. Where the plan names one test instead — a fix plan's "the test
  that catches THIS bug" — that is the seam. Where nothing names one, test at the public
  boundary the change crosses and name it in your handoff, so review can judge it. Run
  standalone, agree the seams with the user before the first test.
- Test **behaviour through public interfaces**, not private internals. Tests shouldn't
  break when you refactor without changing behaviour.
- One behaviour per test; a clear name that states the expectation.
- Don't test the framework, generated code, or impossible states.
- Keep the arrange/act/assert structure obvious.
- Find the public interface with `find_symbol` before you write the test against it, and run
  `get_diagnostics_for_file` on the test file before you run it: a test that does not compile
  is not a failing test.

## Anti-patterns
- **Tautological** — the assertion computes the expected value the way the code does, so the
  test passes by construction and can never disagree with the code. Take expected values from
  an independent source: a known-good literal, a worked example, the spec.
- **Horizontal slicing** — all the tests first, then all the code. The tests pin an imagined
  shape before you understand the implementation. Instead: one test, then the code that
  passes it, then the next test.

## When NOT to force it
Exploratory spikes and throwaway prototypes don't need TDD, but the moment code is
meant to survive, back it with tests.
