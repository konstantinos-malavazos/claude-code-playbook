---
name: dispatch-weight
description: >-
  The single classification rule for how heavy ONE implementation dispatch is, so the
  orchestrator can escalate the model for that run only. Emits `light` or `heavy` plus a
  one-line reason naming the criterion that fired. Auto-loads whenever an agent is about to
  hand work to an implementation specialist, or is writing the plan/verdict/fix-plan that
  another agent will dispatch from. Triggers on "weight", "which model", "escalate",
  "dispatch the specialist", "re-pass", "REQUEST CHANGES", "model escalation".
---

# Dispatch weight

You classify **the change that is about to be made**, on **one dispatch**, for **one
specialist**. You do not classify the ticket, and you never set anybody's `model:`.

The reasoning behind this rule — why step count and not token price sets the bill — is
[`docs/shared/07-the-flows.md`](../../../docs/shared/07-the-flows.md), *Model escalation*.
This file is the rule itself, so that every dispatch site runs the same one.

---

## The unit is a dispatch, not a ticket

A track is dispatched more than once: the first pass, a re-pass for every `REQUEST CHANGES`,
a drift fix after an alignment gate, a QA bounce-back weeks later. **Each of those is its own
classification**, made from what that dispatch has to do — not inherited from the last one.

A weight written once on a plan and reused is the common failure. It covers the first pass
and silently misses every re-dispatch, and the re-dispatch after a failed review is the one
that most needed it.

---

## The output

One line, wherever the dispatching agent will read it:

```
weight: light | heavy — <the criterion that fired, in one clause>
```

The reason is not decoration. It is what makes the thresholds auditable later, and a weight
nobody can audit drifts. Name the criterion, not the feeling: *"3 callers on a changed
signature"*, never *"this looks tricky"*.

---

## Classify `heavy` when the dispatch

- touches **more than 3 files** — 3 or fewer is `light`,
- spans **more than one repo**,
- changes a **shared contract or signature with multiple callers**,
- has to work around a **placeholder seam** left by a deferred decision.

Otherwise `light`. Tune the list to your team; it is a starting point, not scripture. Keep it
**here**, in this one file, when you do.

### Two more criteria that only exist on a fix pass

A re-pass, a drift fix and a QA bounce-back also read `heavy` when:

- the reviewer raised **several findings against one track**, or
- **any** finding says the **design** was wrong rather than the details.

The second one outranks file count. A one-file change that reopens a design decision is a
heavy dispatch; a twelve-file rename is not.

---

## Three invariants

**1. Asymmetry — raise on suspicion, lower only on evidence.** A weight is a guess made
before the work starts. Being wrong upward costs one expensive run. Being wrong downward
costs a run that thrashes, plus the review that catches it, plus the re-pass. Guess up.

> Skip this and the cheap direction starts winning ties, which is exactly the direction
> whose failures are invisible in the output.

**2. Ratchet — a re-dispatch never runs below the tier that track last ran at.** Classify
the re-pass on its own merits, then take the **higher** of that and what the track last ran
at.

> Skip this and a fresh classification sends a track that just failed review straight back
> to the model that failed it. The classification is not wrong; it is just answering a
> question about the fix while the evidence was about the model.

**3. The agent's own `model:` is a FLOOR.** A weight raises a specialist for one run. It
never lowers one below the tier pinned in its frontmatter.

> Skip this and a per-dispatch heuristic quietly overrules a decision somebody made who
> knew the agent — and it does it silently, once per dispatch, forever.

---

## You must NOT

- Set, suggest or write a `model:` value. You emit a weight. The orchestrator maps it.
- Classify the ticket, the track's history, or how hard the last pass was.
- Reuse a weight from a previous dispatch instead of making a new one.
- Emit a weight with no reason line.
