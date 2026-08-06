# 04 — The bootstrap

The bootstrap is **stage 3** of the [solo path](01-the-solo-path.md). You arrive holding a
cleared map, a named stack, a layer chain, and a set of checks written against that stack —
and a repo that has been sitting empty since the [kill gate](02-the-kill-gate.md) created
it.

The stage answers **make the repo real.** It ends with **one pass/fail report** against
[the seam](01-the-solo-path.md#the-seam--where-the-solo-path-stops), and hands over to
[cutting](05-cutting.md).

The stage is **the bootstrap**. The output is a **report**. Two names, kept distinct —
the stage can finish while the report is red.

You run it with **`/bootstrap`**, from
[`templates/skills/bootstrap/SKILL.md`](../../templates/skills/bootstrap/SKILL.md). That
template owns the mechanics and this doc does not repeat them. This doc owns *why the steps
are in this order*; the template owns *how to run them*.

---

## What you arrive with

| | Where it came from |
|---|---|
| **A private repo, empty** | The gate created it. Stage 3 **scaffolds and never creates** — see the spine's *repo is the gate's output* rule. |
| **A cleared map** | Every decision closed, each one recoverable from its own ticket. |
| **The stack, and the layer chain** | Named **together**, by the tail's first ticket in [charting](03-charting.md#the-tail) — by the method in [06-choosing-the-stack.md](06-choosing-the-stack.md). |
| **The Serena verdict** | Decided with the stack, on the test *will you ever need to ask who calls this?* |
| **The bootstrap checks** | The tail's second ticket wrote them, against the stack. Stage 3 is the first place they can run. |
| **One memory** | *What this project is and why*, written when the map closed. Stage 3 writes the second. |

**Nothing here is re-opened.** Stage 3 is a checklist you execute. If it turns out a
decision was wrong, that is [the backwards step](03-charting.md#one-backwards-step), not a
judgement call you make inside the checklist.

---

## The seven steps

In this order. The order is not taste — **each step needs something the one before it
produced.**

| # | Step | Why it is here |
|---|---|---|
| 1 | **Scaffold the stub** — the framework's own generator, **plus one empty folder per layer in the chain** | Nothing can be indexed, or pointed at, until code exists. |
| 2 | **Write the repo's `CLAUDE.md`** — stack, build/test/run commands, layer chain, Serena verdict | Step 4 reads the chain from it; the seam reads the verdict from it. |
| 3 | **Index Serena** — *only if the verdict says yes* | Needs step 1's code. An index of an empty folder proves nothing. |
| 4 | **Generate the layer specialists and the stack skills** | Needs the chain from step 2 and the folders from step 1. |
| 5 | **Check the installed tracker adapter matches this project's tracker** | **Verify, never install.** Installing is a global setup act. |
| 6 | **Write the two memories** | Memory two names the layer chain, so the chain has to be declared first. |
| 7 | **Run every check, produce one report, stop** | The checks are the tail's, and this is the first repo they can run against. |

### Step 1 — the stub is generator output *plus one empty folder per layer*

The generator gives you a skeleton that builds and runs. It does not give you the shape of
your chain, and step 4 needs that shape: every specialist agent is handed
*"the area this repo is usually changed in: `<path>`"*, and with no folders on disk that
path is a guess.

So the stub is the generator's output **plus one empty folder per layer**. The first real
ticket will reshape them, and that is fine — **a folder is cheap to move, a wrong path
baked into an agent file is not.**

### Step 3 — Serena is conditional, and the verdict is looked up

You do not decide here whether Serena applies. The tail decided it, step 2 wrote it into
`CLAUDE.md`, and step 3 reads it back.

| Verdict | Step 3 |
|---|---|
| **Yes** | Index the repo, then confirm a symbol search returns **real results**, not empty. |
| **No** | Skip. `CLAUDE.md` already says why, and [seam check 4](01-the-solo-path.md#the-seam--where-the-solo-path-stops) reads the same line. |

A **sparse** index on a real stub — verdict *yes*, and the symbols do not come back — is
not a step to retry. It is the backwards step: the stack cannot be read the way the
project assumed. See [04-serena.md](../shared/04-serena.md).

### Step 4 — stage 3 is where the layer specialists get made

This is the step the seam was missing. [`/start-ticket`](../shared/08-ticket-pipeline.md)
dispatches its implement step to **layer specialists**, and until now nothing on this path
guaranteed those agent files existed. Every other check could hold and the pipeline would
have nothing to dispatch to.

Three different things own three different questions, and none of them restates another:

| Question | Owner |
|---|---|
| **How** the specialists and stack skills get generated | the stack-adaptation flow — [11-adapting-to-your-stack.md](../shared/11-adapting-to-your-stack.md) and [`templates/agents/layer-specialist.md`](../../templates/agents/layer-specialist.md) |
| **When** it happens | this stage, at step 4 |
| **Whether** it happened | [seam check 8](01-the-solo-path.md#the-seam--where-the-solo-path-stops) |

> Turning a named stack into generated agents is still being designed as a flow of its own;
> today `11-adapting-to-your-stack.md` describes it as manual work. Step 4 is the same act
> either way — what changes is who does the typing.

### Step 5 — verify, never install

Installing a tracker adapter is a **global** act, done once at
[setup step 5](../shared/03-setup.md), not per project. It also cannot be otherwise: the
kill gate wrote the map into a tracker one whole stage before the bootstrap runs, so an
adapter was already installed and already working.

What step 5 checks is narrower and easy to get wrong — that the **one installed adapter is
the right one for this project's tracker**. Home projects on GitHub and work on Jira is the
normal case, and the failure is silent.

### Step 6 — memory two holds only the *why*

| | |
|---|---|
| **Memory one** | *What this project is and who it is for.* Written by **charting**, when the map closed. Not stage 3's. |
| **Memory two** | **Why this stack, why this chain, and what was ruled out.** |

Memory two does **not** restate the stack or the chain. `CLAUDE.md` is loaded every
session; a memory is retrieved by meaning. The facts are already in front of every agent,
and only `CLAUDE.md` can contradict `CLAUDE.md` — so nothing that belongs there gets a
second home.

The *why* is the one part that fits nowhere else, and it is exactly what
`@context-gatherer` cannot find on its own: the reasoning lives in a closed ticket on a map
it never reads. See [05-forgetful.md](../shared/05-forgetful.md).

---

## The repo folder is the line

Inside the new repo, Claude works alone, start to finish. Anything written **outside** it,
you see first.

The reason is one sentence: **everything inside a fresh git repo is undoable with
`git checkout .`, and nothing outside it is.**

This is **blast radius, not audience** — and the distinction matters, because the audience
rule returns the wrong answer here. [`PHILOSOPHY.md`](../../PHILOSOPHY.md) §5 says *ask
before writing anywhere other people can see it*, which for a solo builder on a private
repo means **never ask**. Their machine has no other people on it. It does have other
projects.

Two things cross the line:

| What crosses | Why it is fine |
|---|---|
| **The tracker adapter's global path** | Step 5 only **reads** it. Nothing is written outside the repo. |
| **The two memories** | Memory is not a folder you can revert. [05-forgetful.md](../shared/05-forgetful.md) already gates this: nothing enters memory un-reviewed. |

**Step 4's output does not cross it.** The generated specialists and standards skills land
in the repo's own `.claude/agents/` and `.claude/skills/` — they are facts about *this*
codebase, not your machine's configuration — which is what lets step 4 run unattended like
every other step.

**Stage 3 ends with one commit, and only on an all-green report.** Something has to commit
the `CLAUDE.md` step 2 writes, and the generated agent files with it.
[07-guardrails-when-solo.md](07-guardrails-when-solo.md) has the reasoning: the hook that
blocks AI-infra staging expresses a rule about **provenance** as a rule about **paths**,
and the fix is a test — *would a fresh clone need this file?* — rather than another path
exception. Red means the stack or the setup is wrong, and on day one there is nothing worth
preserving in history.

---

## The exit test

The last step runs **every** check the tail wrote, produces **one** report, and stops.

**It reports on seven of the seam's eight items, not all eight.** Items 1–5, 7 and 8 are
stage 3's to make true. Item 6 — *the backlog exists* — belongs to stage 4 and is the one
thing the report cannot speak to.

```
   ┌─ THE REPO FOLDER ─ Claude works alone in here ────────────┐
   │                                                           │
   │   1. scaffold the stub ────┐                              │
   │      + one folder / layer  │                              │
   │            │               │                              │
   │            ▼               │                              │
   │   2. write CLAUDE.md ──────┼──► the chain ──► step 4      │
   │      stack · commands      │    the verdict ──► step 3    │
   │      chain · verdict       │    · · · · · · ·► the seam   │
   │            │               │                              │
   │            ▼               ▼                              │
   │   3. index Serena     4. generate the                     │
   │      (if verdict yes)    layer specialists ─ ─ ─ ─ ─ ─ ─ ─│─ ─► ~/.claude/ ?
   │            │                  │                           │
   │            └────────┬─────────┘                           │
   │                     ▼                                     │
   │   5. verify the adapter ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │─ ─► reads ~/.claude/tracker.md
   │                     │                                     │
   │                     ▼                                     │
   │   6. write memory two ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │─ ─► memory (you review)
   │                     │                                     │
   │                     ▼                                     │
   │   7. RUN EVERY CHECK ──► ONE REPORT ──► STOP              │
   │                              │                            │
   └──────────────────────────────┼────────────────────────────┘
                                  │      ─ ─ ►  crosses the line: you see it first
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
           all seven hold                something is red
        (items 1-5, 7, 8 —                     │
         item 6 is stage 4's)            YOU classify it:
                    │                    a typo, or a wrong stack
                    ▼
               4. CUTTING
```

**Some checks will fail, and that is expected** — the tail wrote them blind, against an
empty repo, in a stack nobody had run yet.

Two failures look identical on the line and are completely different in kind:

| The failure | What it is | What you do |
|---|---|---|
| **The check is wrong** | A typo, a renamed flag, a command that was right in the docs and wrong in this version | Fix it in place and re-run. Not a backwards step. |
| **The decision is wrong** | The stack cannot actually do this | [The backwards step](03-charting.md#one-backwards-step). Reopen the map. |

**The full list is what tells them apart.** One red among seven reads as a typo. Four reds
read as a wrong stack. Stopping at the first failure hides which one you are in, at
precisely the moment of this stage's most expensive judgement.

So step 7 **reports and stops. It does not classify.** Classifying is a decision, and stage
3 is a checklist — the same reason the layer chain is named in stage 2 and not here.

---

## What was decided in stage 2, not here

**The layer chain is named with the stack**, by the tail's first ticket, one stage
upstream. Stage 3 only copies it into `CLAUDE.md`.

A reader standing in stage 3 will expect to be asked, because this is the first point where
the chain becomes visible — folders on disk at step 1, agent files at step 4. It was
settled before you got here, for two reasons:

- **A checklist is the wrong place for an architecture decision.** You are executing, not
  deliberating, and a real decision dropped into a checklist gets rubber-stamped.
- **Stage 3 *consumes* the chain at step 4.** Deciding it here would mean deciding and
  building from it in the same breath, with nothing in between to catch a bad answer.

The tail's placement and its ordering rule are in
[03-charting.md](03-charting.md#the-tail); the *method* — how one candidate stack gets
proposed and killed, and why the chain is one of the three things ticket 1 decides — is in
[06-choosing-the-stack.md](06-choosing-the-stack.md).

---

## What the bootstrap hands to cutting

| | |
|---|---|
| **A repo that builds and runs** | The stub, plus one folder per layer. |
| **A `CLAUDE.md`** | Stack, commands, layer chain, Serena verdict. The permanent home for all four. |
| **Layer specialists on disk** | Which is what makes [`/start-ticket`](../shared/08-ticket-pipeline.md) able to dispatch at all. |
| **Two memories** | The seam's arithmetic comes out at exactly two, with no special-casing. |
| **One report** | Seven of the seam's eight items. [Cutting](05-cutting.md) makes the remaining one — item 6, *the backlog exists* — true, against a repo that is real, so its tickets can name paths that exist. |

---

## Why this doc exists

The seam tells you *what must be true*. The tail's checks tell you *how to prove it*.
Neither answers the questions a reader has while standing **in** the stage:

- **The order of the seven steps is forced**, not stylistic — every step needs the one
  before it, and re-ordering them quietly breaks something two steps later.
- **The stub is not just generator output.** The empty folders exist because an agent file
  is about to name them.
- **This is where the layer specialists come from** — the gap that made the seam eight
  checks instead of seven.
- **The repo folder is a blast-radius boundary**, which is a different rule from the
  audience rule the rest of the playbook uses, and it is the one that is right here.
- **A red check is not automatically a failure of the stack**, and the whole point of
  reporting all seven at once is to let you tell which kind you are looking at.

Read this before your first bootstrap. Read [01-the-solo-path.md](01-the-solo-path.md) for
the seam it is proving, and [03-charting.md](03-charting.md) for where the stack, the chain
and these checks came from.

---
> **Last verified against:** Claude Code `2.1.220` — July 2026
