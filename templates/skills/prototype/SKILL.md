---
name: prototype
description: >-
  Answer a design question with throwaway code built to be reacted to and then deleted —
  a tiny interactive harness when the question is "does this logic hold up", several rough
  variants on one screen when it is "what should this look like". Use when a decision is
  stuck on something nobody can judge on paper, or the user says "prototype it" / "spike
  it" / "let me see it first". NOT for building the real thing, and NOT for a decision the
  code or the docs can already settle.
---

# Prototype — throwaway code that answers a question

A prototype is **code written to be deleted**. Its only output is a reaction. It exists
because some decisions cannot be argued to a conclusion. They have to be looked at.

> Prior art: Matt Pocock's `prototype` skill (MIT). This is a re-derivation, not a copy.
> It collapses the upstream's three files into one, reads the run command off the repo
> instead of a placeholder, and lands the verdict on the ticket rather than in memory.

**Before you build anything, check that the question needs a prototype at all.** It is only
for the question that gets answered by seeing it run.

## The question picks the shape

| The question | What you build |
|---|---|
| *Does this logic / state model hold up?* | one interactive harness that drives the state machine **by hand** through the cases that are hard to hold in your head |
| *What should this look like?* | three or four **radically different** takes on one screen, switchable without a restart — a URL param, a keypress, an env var, whatever the stack makes cheap |

**Getting the branch wrong wastes the whole prototype**, so pick it first and out loud.
The two produce different artifacts and answer different objections. One variant of a state
machine teaches nothing, and a single interactive harness for a screen is just the screen.

If the question is genuinely ambiguous, ask. If the human is not reachable, take the branch
that matches what surrounds the question — a module or a service is logic, a page or a
component is looks. **Write the assumption at the top of the prototype**, where the
human meets it while reacting rather than after.

## It is an instrument, not a deliverable

> A prototype ticket is a **decision** ticket that happens to write code.

Throwaway code on a throwaway branch adds nothing to the thing you are building. It is the
transcript of the decision, the same way a grilling's questions are. The prototype quietly
becoming the implementation is the failure.

**The test: if you would be sad to delete it, you built the wrong thing.**

## The human reacts, or nothing was answered

This is a **human-in-the-loop** shape. The agent never supplies the human's half. An
agent that builds three variants and then picks one has not resolved the question. It has
spent the budget and left it open, exactly as a grilling agent that answers its own
questions has.

Build it, run it, show it, and stop. If the human is not around, say the prototype is ready
and name what to look at, then leave a progress note on the ticket and keep the claim. A
prototype nobody looked at settles nothing, however good it is.

**There is no unattended exception here, on any path.** The reaction **is** the ticket, and
there is nothing that can stand in for it.

## Rules that hold for both branches

1. **Throwaway from day one, and named so.** Put it beside what it prototypes, so the
   context is obvious. Name it so a passing reader can see it is not production.
2. **One command to run.** The human must be able to start it without thinking.
3. **No persistence.** State lives in memory. Persistence is usually the thing the
   prototype is *checking*, not something it may depend on. If the question is genuinely
   about storage, use a scratch store with a name that says *PROTOTYPE — wipe me*.
4. **Skip the polish.** No tests, no abstractions, no error handling beyond what makes it
   run. Every minute spent on quality is spent on code you are about to delete.
5. **Surface the whole state.** Print or render everything relevant after each action, or
   on each variant switch. A prototype that hides its state is asking the human to guess.

## Read the run command off the repo, not off a placeholder

The task runner is not a `<PLACEHOLDER>`. A placeholder holds what is constant for the
*reader*, while a run command is constant for the *repo*. So a reader who works in two
repos fills it in wrong for one of them, permanently and invisibly. Read it where it is
already written: the repo's own `CLAUDE.md` and whatever the tree already runs.

Same for a UI variant's route: **obey the convention the repo already uses.** Never invent a
new top-level structure to hold something you are about to delete.

## Where the prototype lives — including when there is no repo

| Situation | Where it goes |
|---|---|
| **A repo exists** | beside what it prototypes, on a **throwaway branch**, never on the main line |
| **No repo yet** | wherever it can run. There is no branch, and nothing to sit beside |

The second row is not an edge case. Mapping an effort runs ahead of scaffolding one. **Do
not create the repo to hold the prototype:** scaffolding is its own stage with its own
report, and a repo conjured early makes that report lie about what it found. Only the answer
has to survive, and the answer lives on the ticket.

## Landing the answer

1. **Fold the validated decision into the real code** — or, where there is no real code yet,
   into the ticket's answer. Same act, one stage earlier.
2. **Post the verdict on the ticket**: the question, what the human saw, what it settled,
   and what it ruled out. Speak the tracker adapter's verbs — the one installed adapter doc
   at `~/.claude/tracker.md` answers them — never a raw CLI call.
3. **Point at the prototype. Do not paste it.** Where a repo exists, commit it to the
   throwaway branch and leave a context pointer to that branch on the ticket. The main line
   keeps only the validated decision.
4. **Write no memory.** A prototype verdict is a step inside a larger unit, and the unit
   banks once at its end. Banking here gives you a second copy, free to drift from the
   first and reversible besides.

## Stop condition

Stop when the human has reacted and the verdict is on the ticket, or when the prototype is
running, has been shown, and the human is not available, in which case the progress note and
the retained claim are the stop.

**"It builds" is not a stop condition.** The prototype is not the output; the reaction is.
