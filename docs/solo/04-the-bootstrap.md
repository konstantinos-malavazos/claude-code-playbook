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

## The eight steps

In this order. For steps 2–8 the order is not taste — **each one needs something the one
before it produced.** Step 1 is the exception, and it is placed by a different rule.

| # | Step | Why it is here |
|---|---|---|
| 1 | **Answer the two allowlist questions** — may the agent push here, and is this repo's `CLAUDE.md` its own | The only part of the stage that is **yours**. It goes first so everything after it runs unattended — and step 3's output cannot be committed until it is answered. |
| 2 | **Scaffold the stub** — the framework's own generator, **plus one empty folder per layer in the chain** | Nothing can be indexed, or pointed at, until code exists. |
| 3 | **Write the repo's `CLAUDE.md`** — stack, build/test/run commands, the branch this repo ships from, layer chain, Serena verdict | Step 5 reads the chain from it; the seam reads the verdict from it. The branch is **detected**, not asked for — this stage runs inside a repo that already exists, so `git symbolic-ref refs/remotes/origin/HEAD` answers it. No extra step, no extra question. |
| 4 | **Index Serena** — *only if the verdict says yes* | Needs step 2's code. An index of an empty folder proves nothing. |
| 5 | **Generate the layer specialists and the stack skills** | Needs the chain from step 3 and the folders from step 2. |
| 6 | **Check the installed tracker adapter matches this project's tracker** | **Verify, never install.** Installing is a global setup act. |
| 7 | **Write the two memories** | Memory two names the layer chain, so the chain has to be declared first. |
| 8 | **Run every check, produce one report, stop** | The checks are the tail's, and this is the first repo they can run against. |

### Step 1 — the two questions that are not yours to skip

Two answers, both about **this repo**, both going into
[`~/.claude/repo-allowlist`](../../templates/hooks/repo-allowlist.sample):

| Question | What it unlocks |
|---|---|
| **May the agent push here?** | `git push` on this remote. Unanswered, it stays blocked. |
| **Is this repo's `CLAUDE.md` its own?** | Staging the `CLAUDE.md` step 3 is about to write. |

**This step is not forced into position by a dependency, and every other step is.** It is
placed first for a different reason: it is the **one crossing outside the repo folder** in
the whole stage, and the rest of the checklist runs unattended. Asking first means the
unattended part starts after you have finished being involved, rather than stopping in the
middle to ask. See [07-guardrails-when-solo.md](07-guardrails-when-solo.md) for why the
answers live outside the repo and default to no.

**A bash script cannot judge provenance. You can.** That is the whole reason this is a step
rather than something the hook works out.

### Step 2 — the stub is generator output *plus one empty folder per layer*

The generator gives you a skeleton that builds and runs. It does not give you the shape of
your chain, and step 5 needs that shape: every specialist agent is handed
*"the area this repo is usually changed in: `<path>`"*, and with no folders on disk that
path is a guess.

So the stub is the generator's output **plus one empty folder per layer**. The first real
ticket will reshape them, and that is fine — **a folder is cheap to move, a wrong path
baked into an agent file is not.**

### Step 4 — Serena is conditional, and the verdict is looked up

You do not decide here whether Serena applies. The tail decided it, step 3 wrote it into
`CLAUDE.md`, and step 4 reads it back.

| Verdict | Step 4 |
|---|---|
| **Yes** | Index the repo, then confirm a symbol search returns **real results**, not empty. |
| **No** | Skip. `CLAUDE.md` already says why, and [seam check 4](01-the-solo-path.md#the-seam--where-the-solo-path-stops) reads the same line. |

A **sparse** index on a real stub — verdict *yes*, and the symbols do not come back — is
not a step to retry. It is the backwards step: the stack cannot be read the way the
project assumed. See [04-serena.md](../shared/04-serena.md).

### Step 5 — stage 3 is where the layer specialists get made

This is the step the seam was missing. [`/start-ticket`](../shared/08-ticket-pipeline.md)
dispatches its implement step to **layer specialists**, and until now nothing on this path
guaranteed those agent files existed. Every other check could hold and the pipeline would
have nothing to dispatch to.

Three different things own three different questions, and none of them restates another:

| Question | Owner |
|---|---|
| **How** the specialists and stack skills get generated | `/adapt-to-stack` — [11-adapting-to-your-stack.md](../shared/11-adapting-to-your-stack.md) and [`templates/skills/adapt-to-stack/SKILL.md`](../../templates/skills/adapt-to-stack/SKILL.md) |
| **When** it happens | this stage, at step 5 |
| **Whether** it happened | [seam check 8](01-the-solo-path.md#the-seam--where-the-solo-path-stops) |

Step 5 does not reimplement any of that. It **runs `/adapt-to-stack`**, which reads the
`CLAUDE.md` step 3 just wrote and generates one specialist and one standards skill per
layer into the repo's own `.claude/`. Read
[11-adapting-to-your-stack.md](../shared/11-adapting-to-your-stack.md) for what it makes,
what it refuses to make, and why a re-run never overwrites what you have written.

### Step 6 — verify, never install

Installing a tracker adapter is a **global** act, done once at
[setup step 5](../shared/03-setup.md), not per project. It also cannot be otherwise: the
kill gate wrote the map into a tracker one whole stage before the bootstrap runs, so an
adapter was already installed and already working.

What step 6 checks is narrower and easy to get wrong — that the **one installed adapter is
the right one for this project's tracker**. Home projects on GitHub and work on Jira is the
normal case, and the failure is silent.

### Step 7 — memory two holds only the *why*

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

Three things cross the line, and **one of them is a step**:

| What crosses | Why it is fine |
|---|---|
| **Step 1, the allowlist answers** | The file is in `~/.claude/` precisely so the agent cannot write it. **You** answer; it only reads. |
| **The tracker adapter's global path** | Step 6 only **reads** it. Nothing is written outside the repo. |
| **The two memories** | Memory is not a folder you can revert. [05-forgetful.md](../shared/05-forgetful.md) already gates this: nothing enters memory un-reviewed. |

**Step 5's output does not cross it.** The generated specialists and standards skills land
in the repo's own `.claude/agents/` and `.claude/skills/` — they are facts about *this*
codebase, not your machine's configuration — which is what lets step 5 run unattended like
every other step.

**Stage 3 ends with one commit, and only on an all-green report.** Something has to commit
the `CLAUDE.md` step 3 writes, and the generated agent files with it — and **explicit
paths, never `git add .`**, which the hook blocks whatever step 1 answered.
[07-guardrails-when-solo.md](07-guardrails-when-solo.md) has the reasoning: the hook that
blocks AI-infra staging expresses a rule about **provenance** as a rule about **paths**,
and the fix is a test — *would a fresh clone need this file?* — rather than another path
exception. Red means the stack or the setup is wrong, and on day one there is nothing worth
preserving in history, so a red report commits nothing.

---

## The exit test

The last step runs **every** check the tail wrote, produces **one** report, and stops.

**It reports on seven of the seam's eight items, not all eight.** Items 1–5, 7 and 8 are
stage 3's to make true. Item 6 — *the backlog exists* — belongs to stage 4 and is the one
thing the report cannot speak to.

```
       1. the two allowlist questions ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─► ~/.claude/repo-allowlist
              YOU answer; the agent only reads                       (you answer, once)
                     │
   ┌─ THE REPO FOLDER┼─ Claude works alone from here on ───────┐
   │                 ▼                                         │
   │   2. scaffold the stub ────┐                              │
   │      + one folder / layer  │                              │
   │            │               │                              │
   │            ▼               │                              │
   │   3. write CLAUDE.md ──────┼──► the chain ──► step 5      │
   │      stack · commands      │    the verdict ──► step 4    │
   │      chain · verdict       │    · · · · · · ·► the seam   │
   │            │               │                              │
   │            ▼               ▼                              │
   │   4. index Serena     5. generate the                     │
   │      (if verdict yes)    layer specialists                │
   │            │                  │  → .claude/agents/ (here) │
   │            └────────┬─────────┘                           │
   │                     ▼                                     │
   │   6. verify the adapter ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │─ ─► reads ~/.claude/tracker.md
   │                     │                                     │
   │                     ▼                                     │
   │   7. write memory two ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │─ ─► memory (you review)
   │                     │                                     │
   │                     ▼                                     │
   │   8. RUN EVERY CHECK ──► ONE REPORT ──► STOP              │
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
            one commit, then
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

So step 8 **reports and stops. It does not classify.** Classifying is a decision, and stage
3 is a checklist — the same reason the layer chain is named in stage 2 and not here.

---

## If the session dies partway

Nothing records how far you got, **on purpose**. You type **`/bootstrap`** again, and each
step checks the disk and skips itself.

Seven of the eight steps leave something you can go and look at — the allowlist lines, the
stub, `CLAUDE.md`, the index, the agent files, the two memories, the commit. **Step 6 is the
only one that writes nothing**, and it is a single read of the installed tracker adapter, so
redoing it is free. Step 5 was already safe before this rule existed:
[`/adapt-to-stack`](../shared/11-adapting-to-your-stack.md) creates what is missing and
never overwrites what you have written.

A **progress file** is the obvious alternative and it is the wrong one. It is a second copy
of what the disk already says, and the two can disagree — at which point the copy is what
you read and the disk is what is true. That is the spine's
[*re-derive, never store*](01-the-solo-path.md#which-stage-are-you-standing-in) rule, and
stage 3 is where following it costs the least: eight steps, seven footprints, one free redo.

### Where the report lives — nowhere

The template says the stage is done **when the report exists**, and then says nothing about
where it exists. That is not an omission:

| The report was | What survives the session |
|---|---|
| **Green** | The **commit**. That is the durable tell that stage 3 finished. |
| **Red** | **Nothing.** A red report commits nothing, and the report goes with the session. |

So *did stage 3 finish?* has the same answer as *how far did it get?* — **run it again.**
The skipping is what makes that cheap, and a re-run against a finished repo prints the
report you lost.

---

## What was decided in stage 2, not here

**The layer chain is named with the stack**, by the tail's first ticket, one stage
upstream. Stage 3 only copies it into `CLAUDE.md`.

A reader standing in stage 3 will expect to be asked, because this is the first point where
the chain becomes visible — folders on disk at step 2, agent files at step 5. It was
settled before you got here, for two reasons:

- **A checklist is the wrong place for an architecture decision.** You are executing, not
  deliberating, and a real decision dropped into a checklist gets rubber-stamped.
- **Stage 3 *consumes* the chain at step 5.** Deciding it here would mean deciding and
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
| **A `CLAUDE.md`** | Stack, commands, the branch this repo ships from, layer chain, Serena verdict. The permanent home for all five — and the only `CLAUDE.md` a one-repo project has below the global one. |
| **Layer specialists on disk** | Which is what makes [`/start-ticket`](../shared/08-ticket-pipeline.md) able to dispatch at all. |
| **Two memories** | The seam's arithmetic comes out at exactly two, with no special-casing. |
| **One report** | Seven of the seam's eight items. [Cutting](05-cutting.md) makes the remaining one — item 6, *the backlog exists* — true, against a repo that is real, so its tickets can name paths that exist. |

---

## Why this doc exists

The seam tells you *what must be true*. The tail's checks tell you *how to prove it*.
Neither answers the questions a reader has while standing **in** the stage:

- **The order of the eight steps is forced for seven of them**, not stylistic — each
  needs the one before it, and re-ordering them quietly breaks something two steps later.
  **Step 1 is the odd one out**, placed by where the line is rather than by a dependency.
- **The stub is not just generator output.** The empty folders exist because an agent file
  is about to name them.
- **This is where the layer specialists come from** — the gap that made the seam eight
  checks instead of seven.
- **The repo folder is a blast-radius boundary**, which is a different rule from the
  audience rule the rest of the playbook uses, and it is the one that is right here.
- **A red check is not automatically a failure of the stack**, and the whole point of
  reporting all seven at once is to let you tell which kind you are looking at.
- **Nothing records how far the stage got** — running it again is the entire recovery, and
  it is also how you find out whether it finished at all.

Read this before your first bootstrap. Read [01-the-solo-path.md](01-the-solo-path.md) for
the seam it is proving, and [03-charting.md](03-charting.md) for where the stack, the chain
and these checks came from.

---
> **Last verified against:** Claude Code `2.1.226` — August 2026
