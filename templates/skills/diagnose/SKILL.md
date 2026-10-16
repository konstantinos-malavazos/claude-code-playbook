---
name: diagnose
description: >-
  Disciplined diagnosis loop for hard bugs and performance regressions. Use when the user
  says "diagnose this" / "debug this", reports something broken/throwing/failing, or
  describes a performance regression.
---

# Diagnose — a disciplined loop

> Prior art: mattpocock/skills@49dd158 `diagnosing-bugs` (MIT), adapted. This keeps its six
> phases and its feedback-loop gate, and adds Serena tracing and a performance branch.

Don't guess-and-patch. Prove the cause, then fix the cause. Run the six phases in order; skip
one only when you can say why.

## Redact

You will show commands, outputs and captured artifacts. **Redact every secret first**: write
`<REDACTED>` in its place. Build loops that read credentials from environment variables, so
the secret stays in the environment and out of what you show. A captured request carries its
auth headers: quote only the lines that carry the signal. If the redacted output is not
enough to diagnose the bug, say so and ask the user.

## Phase 1: Build a feedback loop

**This is the skill.** A tight pass/fail signal that goes red on *this* bug finds the cause;
everything after it only consumes that signal. Without one, reading code will not save you.
Spend most of your effort here.

Ways to build one, roughly in this order:

1. **A failing test** at whatever seam reaches the bug: unit, integration, end-to-end.
2. **A CLI run on a fixture input**, diffing its output against a known-good snapshot.
3. **Replay a captured payload** — a saved request, event or log — through the code path on
   its own.
4. **A differential run**: the same input through the old and the new version (or two
   configs), outputs diffed.
5. **A bisection harness**: when the bug appeared between two known states, automate "build
   at state X, check" so `git bisect run` can drive it.

Then tighten it: faster (skip unrelated setup), sharper (assert the specific symptom, not
"didn't crash"), deterministic (pin time, seed randomness, isolate the filesystem and
network). For a bug that only happens sometimes, the goal is a higher reproduction rate:
loop the trigger, add stress, narrow the timing window.

**Completion criterion.** Phase 1 is done when you can name **one command** that:

- [ ] you have **already run at least once**, with the invocation and its output shown
      (redacted),
- [ ] goes **red on the user's exact symptom** — it drives the real code path and asserts
      what the user reported, not "runs without erroring",
- [ ] is **deterministic** — the same verdict every run (or a pinned, high reproduction rate),
- [ ] is **fast** — seconds, not minutes.

**No loop, no hypotheses.** If you cannot build one, stop and say so. List what you tried,
then ask the user for access to an environment that reproduces it, or for a redacted captured
artifact (a log dump, a saved request, a recording with timestamps). Do not form a single
hypothesis until the command exists: reading code to build a theory first is the exact
failure this skill prevents.

## Phase 2: Reproduce and minimise

Run the loop and watch it go red. Confirm it shows the failure the **user** described, not a
nearby one — wrong bug, wrong fix — and capture the exact symptom so later phases can check
the fix against it.

Then shrink it to the **smallest scenario that still goes red**. Cut inputs, callers, config
and steps one at a time, re-running after each cut. Done when every remaining element is
load-bearing: removing any one turns the loop green.

## Phase 3: Hypothesise

Write **3–5 ranked hypotheses** before testing any of them; one hypothesis anchors on the
first plausible idea. Each must be **falsifiable** — state its prediction: "if X is the
cause, changing Y makes the bug disappear." A hypothesis with no prediction is a guess:
sharpen it or drop it.

Trace the code path through Serena where it is available: `find_symbol` to read a body,
`find_referencing_symbols` for who reaches it. A hypothesis about code you only grepped is a
guess.

**Show the ranked list to the user before testing.** They often know which one is already
ruled out. Do not block on an answer: if they are away, proceed with your ranking.

## Phase 4: Instrument

Each probe tests one prediction from Phase 3. **Change one variable at a time.** Prefer a
debugger or REPL to logs, and targeted logs at the boundaries that separate hypotheses to
"log everything". **Tag every debug line with a unique prefix**, such as `[DEBUG-a4f2]`, so
cleanup is one grep.

When the evidence contradicts a hypothesis, drop it. Don't defend it.

### For performance regressions

Logs are usually the wrong tool. Measure first: find the actual hot path with a profiler or a
timing harness, not intuition. Compare against a known-good baseline (an earlier commit or
tag), bisect between them, fix the dominant cost, and re-measure to confirm the win is real.

## Phase 5: Fix and regression-test

Write the regression test **before the fix** (see the `tdd` skill), at a seam that
reproduces the **real bug pattern** as it happens at the call site. A seam too shallow to
replay that pattern — one caller where the bug needs two — gives false confidence.

**No correct seam is itself a finding.** Record it: the design is stopping this bug from
being locked down.

With a seam: turn the minimised repro into a failing test, watch it fail, make the smallest
change that fixes the cause, watch it pass, then re-run the Phase 1 loop on the original,
un-minimised scenario. Never patch code whose failure you do not understand.

## Phase 6: Clean up

Before you call it done:

- [ ] the Phase 1 loop stays green,
- [ ] the regression test passes, or the missing seam is recorded,
- [ ] `grep` for the debug prefix returns nothing,
- [ ] throwaway harnesses are deleted,
- [ ] the hypothesis that proved correct is in the commit message, so the next person
      debugging here learns from it.
