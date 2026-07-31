# 01 — The solo path, end to end

This playbook has **two entrances**. The agile path starts at a ticket somebody else
wrote and somebody else prioritised. The **solo path** starts a long way upstream of
that: a raw idea, no repo, nobody to hand you a spec.

It ends at the same place the agile path starts — a **backlog of work units on a
scaffolded, Serena-indexed repo** — and hands over to
[`/start-ticket`](../shared/08-ticket-pipeline.md). Everything downstream of that seam
is already written and is shared by both entrances.

This doc is the **spine**: the four stages, the question each one answers, and the exit
condition that says you are done with it. Each stage has its own doc; this one does not
repeat them.

---

## The four stages

| # | Stage | The question it answers | Exit condition | Doc |
|---|---|---|---|---|
| 1 | **The kill gate** | Is this worth building at all? | A verdict is recorded — **build**, **kill**, or **park**. On *build*: a **private repo exists** and the map is its issue #1. | [02-the-kill-gate.md](02-the-kill-gate.md) |
| 2 | **Charting** | What are we building, and on what? | Every ticket on the map closed, **the tail resolved last** — or the map is **abandoned**. | [03-charting.md](03-charting.md) |
| 3 | **The bootstrap** | Make the repo real. | The stack-specific checks written by the tail pass (items 1–5 and 7 of the seam). | [04-the-bootstrap.md](04-the-bootstrap.md) |
| 4 | **The backlog** | Cut the decisions into units the pipeline can run. | Work units exist in the tracker, ordered, and **you approved them**. | [05-the-backlog.md](05-the-backlog.md) |

The stage is **charting**; the artifact it produces is **the map**. They never share a
name — otherwise you can never say which one you mean.

> The four stage docs are still being written; `02`–`05` are reserved for them, in stage
> order. Every other solo doc takes `06` and up.

```
   1. THE KILL GATE ──► 2. CHARTING ──► 3. THE BOOTSTRAP ──► 4. THE BACKLOG ══╣ SEAM ╠══► /start-ticket
      is this worth       what are we      make the repo        cut it into                (the shared
      building?           building, and    real                 work units                  pipeline
           │              on what?              ▲                    │                      takes over)
           │                   │                │                    │
      verdict:            ends CLEARED     scaffolds,           ordered, and                    ▲
      build / kill        or ABANDONED     never creates        you approved                    │
      / park                   │                │               them                            │
           │                   │                │                    │                          │
      on BUILD the        the TAIL, last:  its exit test is     runs AFTER              seven checks,
      agent creates a     1. name the      the tail's           bootstrap, against      all must hold
      PRIVATE repo;          stack         stack-specific       a real indexed repo
      the map is its      2. write the     checks
      issue #1               bootstrap
                             checks

            ◄──────────── one backwards step allowed ────────────
```

---

## Three rules that cross stage boundaries

| Rule | What it means |
|---|---|
| **The repo is the gate's output** | Charting's artifact is an issue on a tracker, so the repo has to exist before charting, not after. A *build* verdict is what creates it — the agent creates it **private**, after confirming the name with you. Bootstrap therefore **scaffolds and never creates**. |
| **The tail goes last** | Choosing the stack is a decision, so it lives on the map as a ticket rather than as a stage of its own. Two tickets — *name the stack*, then *write the bootstrap checks* — and **neither is takeable while any other ticket is open**. This is a rule, not blocker wiring. When a product decision is genuinely stuck without the stack, take the stack early **and record why in its answer**. |
| **One backwards step** | If the bootstrap or the backlog breaks a decision, you reopen the map and add a ticket. You do not push forward on something you now know is wrong. One step back, not a spiral. |

**Charting can end in *abandon*.** The gate is deliberately cheap and decides on very
little information; charting is where the true size of the thing shows up. A path whose
only exit is the first gate forces every survivor of a five-minute judgement to be built.
Abandoning is a normal ending, not a failure.

---

## The seam — where the solo path stops

The seam is the one thing this doc states **in full**, because it is the only place
where both entrances are visible at once. When all seven hold, the front-end is done and
`/start-ticket` works.

| # | Check | How you know it holds |
|---|---|---|
| 1 | **The stack is named** | Written down, not in your head. |
| 2 | **The stub builds and runs** | Not the app — there is no app. The framework's skeleton compiles and starts. *A green test command is optional here; the tail's second ticket decides whether this stack gates on one.* |
| 3 | **The layer chain is declared** | It is in the repo's `CLAUDE.md`. See [06-claude-md-layers.md](../shared/06-claude-md-layers.md). |
| 4 | **Serena is indexed** | A symbol search returns **real results**, not empty. See [04-serena.md](../shared/04-serena.md) — and note that [12-when-not-to-use.md](../shared/12-when-not-to-use.md) already says a sparse index means *stop*. This is where that gets caught. |
| 5 | **The tracker adapter is installed** | Exactly one adapter, at the fixed path the global `CLAUDE.md` points at. |
| 6 | **The backlog exists** | Units are in the tracker, ordered, and **you approved them**. |
| 7 | **Two memories exist** | Exactly two: *what this project is and who it is for* (the one-paragraph version), and *the stack and the layer chain, and why*. |

**On item 7 — two named memories, not "some memories".** "Memories were seeded" is not
testable, and most day-zero facts are noise. But with none at all, `@context-gatherer`
sweeps a stub repo, finds nothing, and every early ticket starts blind on *why*. The
tracker holds both of these facts already — the tracker is not what the gatherer reads.

### What takes over on the other side

| You now have | Which is the input to |
|---|---|
| A backlog of ordered, approved work units | [`/start-ticket`](../shared/08-ticket-pipeline.md) — the flagship flow, ~95% of tickets |
| A unit too big for one sequential pass | [The decompose path](../shared/09-decompose-path.md) |
| A repo with Serena, memory, and hooks in place | [The flows](../shared/07-the-flows.md), unchanged from the agile path |

Nothing downstream of the seam is solo-specific. That is the point of the seam.

---

## Why this doc exists

The four stages each have their own doc, and each one is legible on its own. What is
*not* legible from any of them is the **shape of the whole**: that the repo appears at
stage 1 rather than stage 3, that stack choice hides inside charting as a tail rather
than standing as a stage, that abandoning is a legitimate ending, and that the path
deliberately **stops** at a checklist instead of running on into implementation.

Read this page first, then the stage you are actually standing in.

---
> **Last verified against:** Claude Code `2.1.220` — July 2026
