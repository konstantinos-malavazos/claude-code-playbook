# 01 — The solo path, end to end

This playbook has **two entrances**. The agile path starts at a ticket somebody else
wrote and somebody else prioritised. The **solo path** starts a long way upstream of
that: a raw idea, no repo, nobody to hand you a spec.

It ends where the agile path starts: a **backlog of work units on a scaffolded repo that
passes [the seam](#the-seam--where-the-solo-path-stops)**. It then hands over to
[`/start-ticket`](../shared/08-ticket-pipeline.md). Everything downstream of that seam is
already written, and both entrances share it.

This doc is the **spine**: the four stages, the question each one answers, and the exit
condition that says you are done with it. Each stage has its own doc. This one does not
repeat them.

---

## The four stages

| # | Stage | The question it answers | Exit condition | Doc |
|---|---|---|---|---|
| 1 | **The kill gate** | Is this worth building at all? | A verdict is recorded — **build**, **kill**, or **park**. On *build*: a **private repo exists** and the map is its issue #1. | [02-the-kill-gate.md](02-the-kill-gate.md) |
| 2 | **Charting** | What are we building, and on what? | Every ticket on the map closed, **the tail resolved last**. Or the map is **abandoned**. | [03-charting.md](03-charting.md) |
| 3 | **The bootstrap** | Make the repo real. | The stack-specific checks written by the tail pass (items 1–5, 7 and 8 of the seam). | [04-the-bootstrap.md](04-the-bootstrap.md) |
| 4 | **Cutting** | Cut the first version into units the pipeline can run. | Work units exist in the tracker, ordered, and **you approved them**. | [05-cutting.md](05-cutting.md) |

The stage is **charting**. The artifact it produces is **the map**. They never share a
name — otherwise you can never say which one you mean. The same holds one row down: the
stage is **cutting**, and the artifact it produces is **the backlog**.

> `02`–`05` are reserved for the four stage docs, in stage order. Every other solo doc
> takes `06` and up.

```
   1. THE KILL GATE ──► 2. CHARTING ──► 3. THE BOOTSTRAP ──► 4. CUTTING ══════╣ SEAM ╠══► /start-ticket
      is this worth       what are we      make the repo        cut it into                (the shared
      building?           building, and    real                 work units                  pipeline
           │              on what?              ▲                    │                      takes over)
           │                   │                │                    │
      verdict:            ends CLEARED     scaffolds,           ordered, and                    ▲
      build / kill        or ABANDONED     never creates        you approved                    │
      / park                   │                │               them                            │
           │                   │                │                    │                          │
      on BUILD the        the TAIL, last:  its exit test is     runs AFTER              eight checks,
      agent creates a     1. name the      the tail's           bootstrap, against      all must hold
      PRIVATE repo;          stack         stack-specific       a real indexed repo
      the map is its      2. write the     checks
      issue #1               bootstrap
                             checks

            ◄──────────── one backwards step allowed ────────────
```

---

## Which stage are you standing in?

**Nothing stores the answer.** You go and look. Every stage leaves a tell in the repo or
the tracker. Read these top to bottom and stop at the first that matches.

| Where you are | The tell |
|---|---|
| **Not started, or still in the gate** | No repo. |
| **Stage 2 — charting** | The repo exists, and issue **#1 is open**. |
| **Stage 3 — the bootstrap** | Issue **#1 is closed**, and the repo has **no `CLAUDE.md`**. |
| **Stage 4 — cutting** | `CLAUDE.md` and the layer specialists are on disk, and there are **no work tickets**. |
| **Past the seam** | Work tickets exist, each carrying **`From map #1`**. |

**Stage 1 has no row of its own.** That falls out of the first rule below. The repo is the
gate's output, so *no repo* means you have not started, or you are still in the gate. The
gate is one sitting, so you will not lose track of being in it.

> ### Re-derive, never store
>
> There is no phase marker file, no *stage:* line in `CLAUDE.md`, and no progress file
> anywhere on this path. Each of them would be **a fact about the repo written down beside
> the repo**. It can be wrong, and nothing would catch it. The tells above *are* the repo,
> so they cannot disagree with it.

The same rule answers the resume question one level down, and both stage docs say so. A
bootstrap that died partway is resumed by
[running it again](04-the-bootstrap.md#if-the-session-dies-partway). A cut that died
mid-board is resumed by [running it again](05-cutting.md#if-the-session-dies-mid-board).
Charting differs only in shape, not in rule. Its progress lives as **a comment on the
ticket**, on the tracker, where the rest of charting already lives.

---

## Three rules that cross stage boundaries

| Rule | What it means |
|---|---|
| **The repo is the gate's output** | Charting's artifact is an issue on a tracker, so the repo has to exist before charting, not after. A *build* verdict is what creates it. The agent creates it **private**, after confirming the name with you. Bootstrap therefore **scaffolds and never creates**. |
| **The tail goes last** | Choosing the stack is a decision, so it lives on the map as a ticket rather than as a stage of its own. It is two tickets: *name the stack*, then *write the bootstrap checks*. **Neither is takeable while any other ticket is open.** This is a rule, not blocker wiring. When a product decision is genuinely stuck without the stack, take the stack early **and record why in its answer**. |
| **One backwards step** | If the bootstrap or cutting breaks a decision, you reopen the map and add a ticket. You do not push forward on something you now know is wrong. One step back, not a spiral. |

**Charting can end in *abandon*.** The gate is deliberately cheap and decides on very
little information. Charting is where the true size of the thing shows up. A path whose
only exit is the first gate forces every survivor of a five-minute judgement to be built.
Abandoning is a normal ending, not a failure.

---

## The seam — where the solo path stops

The seam is the one thing this doc states **in full**, because it is the only place
where both entrances are visible at once. When all eight hold, the front-end is done and
`/start-ticket` works.

| # | Check | How you know it holds |
|---|---|---|
| 1 | **The stack is named** | Written down, not in your head. |
| 2 | **The stub builds and runs** | Not the app — there is no app. The framework's skeleton compiles and starts. *A green test command is optional here. The tail's **first** ticket decides whether this stack gates on one, because it is a stack question. See [06-choosing-the-stack.md](06-choosing-the-stack.md#what-ticket-1-decides--and-what-it-writes).* |
| 3 | **The layer chain and the settled names are declared** | Both are in the repo's `CLAUDE.md`. The names are a **comparison**: every name left on the map's `Notes` appears in `CLAUDE.md`. An effort that settled none passes, because zero matches zero. See [06-claude-md-layers.md](../shared/06-claude-md-layers.md). |
| 4 | **Serena matches the verdict** | You look this up. You do not decide it here. The tail decided it, and the repo's `CLAUDE.md` records it. *Verdict **yes**: Serena is indexed. A symbol search returns **real results**, not empty. Verdict **no**: Serena is not required here, and `CLAUDE.md` says why.* See [04-serena.md](../shared/04-serena.md), and [12-when-not-to-use.md](../shared/12-when-not-to-use.md#unfamiliar-codebase) for the one case where a sparse index is not a *stop*. |
| 5 | **The tracker adapter is installed** | Exactly one adapter, at the fixed path the global `CLAUDE.md` points at. |
| 6 | **The backlog exists** | Units are in the tracker, ordered, and **you approved them**. |
| 7 | **Two memories exist** | Exactly two: *what this project is and who it is for* (the one-paragraph version), and *the stack and the layer chain, and why*. |
| 8 | **The layer specialists exist** | The base `<layer>-specialist` for every layer of the chain, **on disk**. Item 3 says the chain is declared; this says something can act on it. The slice-mode variants sit beside them and are not what this item checks — nothing dispatches one on the sequential path. See [11-adapting-to-your-stack.md](../shared/11-adapting-to-your-stack.md). |

**On item 8 — declared is not the same as built.** Step 4 of
[`/start-ticket`](../shared/08-ticket-pipeline.md) dispatches the implement step to layer
specialists. Without item 8, every other check can hold and the pipeline still has nothing
to dispatch to. That one gap made this seam eight checks rather than seven. The
[bootstrap](04-the-bootstrap.md) generates them.

**On item 7 — two named memories, not "some memories".** "Memories were seeded" is not
testable, and most day-zero facts are noise. But with none at all, `@context-gatherer`
sweeps a stub repo and finds nothing. Every early ticket then starts blind on *why*. The
tracker holds both of these facts already, but the tracker is not what the gatherer reads.

### What takes over on the other side

| You now have | Which is the input to |
|---|---|
| A backlog of ordered, approved work units | [`/start-ticket`](../shared/08-ticket-pipeline.md) — the flagship flow, ~95% of tickets |
| A unit too big for one sequential pass | [The decompose path](../shared/09-decompose-path.md) |
| A repo with Serena, memory, and hooks in place | [The flows](../shared/07-the-flows.md), unchanged from the agile path |

Nothing downstream of the seam is solo-specific. That is the point of the seam.

---

## Why this doc exists

The four stages each have their own doc, and each one is legible on its own. What none of
them shows is the **shape of the whole**. The repo appears at stage 1 rather than stage 3.
Stack choice hides inside charting as a tail rather than standing as a stage. Abandoning is
a legitimate ending. The path deliberately **stops** at a checklist instead of running on
into implementation. And **which stage you are in is never recorded anywhere** — every stage
leaves a tell, and you go and read it.

Read this page first, then
[the stage you are actually standing in](#which-stage-are-you-standing-in).

If you would rather watch it happen than read about it,
[`examples/solo-path-walkthrough.md`](../../examples/solo-path-walkthrough.md) narrates two
invented ideas through the gate. One of them is killed. It then narrates the survivor through
all four stages to the seam.

---
> **Last verified against:** Claude Code `2.1.226` — August 2026
