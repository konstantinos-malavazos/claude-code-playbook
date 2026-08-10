# 12 — When NOT to use this playbook

Every other doc describes the happy path. This one describes where the pattern
loses: when the pipeline costs more than it saves, when it gives false confidence,
and when you should just open a chat.

**It covers both entrances.** The first five sections are about the shared pipeline and
apply whichever door you came through. The
[sixth](#when-the-solo-front-end-is-not-worth-it) is about the
[solo front-end](../solo/01-the-solo-path.md) specifically. Those four stages can cost
more than the thing they are judging.

---

## Tickets too small

The `/start-ticket` pipeline spins up 5–7 agents, runs a memory sweep, a code-nav
sweep, a design gate, a full review, and memory consolidation. That overhead is
worth it for a change that touches 2+ layers or needs design thinking. It is not
worth it for:

- A one-line string fix.
- Adding a null check.
- Changing a config value.
- Renaming a local variable.

**Rough heuristic:** if the fix takes you less than ~20 minutes to type and verify
manually, just open a chat. The pipeline earns its overhead somewhere above that,
or when the change touches 2+ files that aren't in the same method, or when it
requires a decision the codebase doesn't encode yet.

One exception: even a tiny ticket is worth the full pipeline **if it's a pattern
you expect to repeat**. The memory consolidation means you only solve it once.
But that's a judgement call, not an algorithm.

---

## Exploratory / spike work

When you don't know what the answer looks like, the pipeline's linear chain
(design → implement → review) fights against the actual shape of discovery:

- Spikes need freedom to follow dead ends, branch speculatively, and abandon
  whole approaches. The pipeline's sequential commit structure is the opposite
  of that.
- The grilling gate demands answers you don't have yet. The "defer" mechanism
  helps, but too many deferred decisions turn the plan into a list of unknowns
  and the pipeline into theatre.
- A spike's output is understanding, not code. The pipeline optimises for a
  reviewable single-commit branch. That's not what a spike produces.

**Use instead:** it depends which kind of not-knowing you have.

| The spike is | Use |
|---|---|
| **reading** — why is this happening, where does the data go wrong | an ad-hoc investigation agent (read-only, no commit structure, no review gates) |
| **building something to look at** — does this state model hold up, what should this look like | [`/prototype`](../../templates/skills/prototype/SKILL.md) — throwaway code, reacted to and deleted |

Either way the output is understanding, not a branch. But **where it lands differs.** An
investigation's findings are nominated into memory like any other durable conclusion
([10-memory-hygiene.md](10-memory-hygiene.md)). A prototype's verdict goes on the ticket and
banks nothing, because the unit it sits inside banks once, at its end. Then decide whether
the next ticket is pipeline-shaped.

**On the solo path this is already handled upstream.** The
[kill gate](../solo/02-the-kill-gate.md) ends by naming the idea's hard part, which is
exactly a spike. But it never reaches `/start-ticket` as one. It becomes a `research` or
`prototype` ticket on the map — the same two rows as the table above — and is burned off
during [charting](../solo/03-charting.md), before the backlog exists. The two docs also ask
different questions. This one asks whether the pipeline is the wrong *tool*. The gate asks
whether it is the wrong *idea*.

---

## Unfamiliar codebase

The pipeline assumes the planner's plan can be meaningfully reviewed. If neither
you nor the agent knows the code well enough to judge whether the plan is sound,
the pipeline gives false confidence. The design looks plausible but misses
hidden coupling, undocumented invariants, or tribal knowledge.

Signs you're here:
- The planner frequently writes "I'm assuming X" about things you know are wrong.
- The Serena sweep returns sparse results (few symbols indexed). Fix the index. This is
  never a reason to fall back to grep. It is a reason to stop. *Unless the project is
  symbol-poor by nature* (bash, Ansible, config-heavy): there sparse is the correct reading
  of a real index, and [seam check 4](../solo/01-the-solo-path.md#the-seam--where-the-solo-path-stops)
  has already recorded that verdict.
- Review comments correctly flag things but miss the *important* things.
- You can't tell whether a good plan is actually good, or just well-written.

**Do first:** manual discovery. Read key files, run the app, understand the
coupling. Bank what you learn in memory. When you can predict what the agent
should find, you're ready for the pipeline.

---

## Incidents / hotfixes

When prod is down, prioritise speed over structure. The pipeline's guardrails
**must NOT be bypassed** (especially the git guardrails and the read-first rule on
prod). Those are safety invariants. But the multi-agent flow
(analyzer → gatherer → planner → specialists → two-tier review) is too slow.

**Use instead:** a `/hotfix` pattern:
- One agent with Serena read + edit access in the affected repo. Speed does not relax the
  Serena rule, because symbol edits are *faster* than hunting line ranges under pressure.
- No gatherer step (skip the memory sweep if you know what's broken).
- No planner gate (you already know the fix).
- One reviewer pass, not two.
- **Still:** read-first on any production data, the git guardrails stay wired exactly as
  they are, memory write is still deliberate.

The guardrails are not optional. The agent orchestration is.

> **The push block is a per-repo answer now** ([PHILOSOPHY.md §5](../../PHILOSOPHY.md)), so
> "the hook blocks push" is no longer a flat fact. It does not weaken this section: a
> production repo is never on the allowlist, and **an incident is not a reason to add one.**
> The invariant was never *the hook happens to block*; it is *you do not loosen a guardrail
> because you are in a hurry.*

---

## Underspecified or unstable requirements

If the ticket's acceptance criteria change mid-flight, the pipeline's fixed
sequence fights you. Maybe the spec was a rough draft, maybe a stakeholder changed
their mind, maybe it is "we'll know it when we see it". A redesign invalidates the
gatherer's sweep and the planner's allocation. Rework propagates through the
specialists. The commit history gets messy despite the one-commit rule.

**Use when:** the spec is stable enough that you can write the final commit message
before you start working. If you can't, you're not ready for the pipeline.

---

## When the solo front-end is not worth it

Everything above judges the **pipeline**. This section judges the four stages *upstream*
of it: [`/pitch`](../solo/02-the-kill-gate.md),
[charting](../solo/03-charting.md), [the bootstrap](../solo/04-the-bootstrap.md),
[cutting](../solo/05-cutting.md).

They are not free. The gate costs about an hour. Charting resolves **one decision per
session** and can run for weeks. That price buys you the thing the agile path gets for
free: somebody else already decided what to build. There are four situations where it
buys nothing.

### The idea is smaller than the gate that judges it

A two-hour script. A single-file tool. A thing you could type faster than you could
explain it.

The gate alone is half the project, and it is the *cheap* stage. Charting has nothing to
chart: a decision only earns a ticket when getting it wrong costs more than the session
spent deciding, and at this size nothing does. Cutting has nothing to cut, because the
whole thing is one work unit.

**Use instead:** open a chat and write it. If it grows a second surface and a third
decision, it will still be there to run `/pitch` on, and the gate will be judging
something real by then rather than a guess.

### You can already name every decision

Charting exists for **fog** — the sense that a route to the destination exists but you
cannot see it. If you can already say what you are building, on what stack, in what shape,
there is no fog and a map has nothing to hold. Charting's own rule says so: a session that
fans out and finds no fog is told to stop rather than to invent tickets.

**This row does not send you away from the path. It removes one stage.** You skip *stage
2*, not the front-end. The repo still needs a stack written down, a layer chain, generated
specialists, an indexed codebase and two seeded memories. That is
[the bootstrap](../solo/04-the-bootstrap.md), and none of it becomes true by being
obvious to you. Run `/pitch`, skip charting, go straight to `/bootstrap`.

**Be honest about which one you are in**, because *knowing* and *not having looked* feel
identical from inside. The test is whether you can name the decision you would have made
differently after a week of building. If nothing comes to mind, you are probably right.

### You are learning a technology, not shipping a thing

The output you want is understanding. A working app is the pretext.

The [gate](../solo/02-the-kill-gate.md) handles this correctly and will not kill you for
it. *The building itself* is one of the three classes it recognises, and it arms only the
first hard kill for that class. **The stages after it are the problem.** Charting has no
product decisions to resolve, and stage 2's stack question is
[inverted](../solo/06-choosing-the-stack.md): it exists to talk you into the most boring
stack that does the job, and you picked an unfamiliar one *on purpose*. Running the
machine gives you an argument you are going to overrule, which is worse than not running
it.

**Use instead:** a scratch repo and a chat. Bank what you learn in memory. That part
compounds regardless. Come back to `/pitch` when there is a thing you want to exist rather
than a thing you want to have built.

### It isn't software

A spreadsheet model. A home-server build. A course, a book, a research effort.

**Stages 1 and 2 are general and will serve you.** The gate asks whether an idea is worth
the effort, which is not a code question. Charting takes the destination as an *input*.
This repo's own front-end was planned on a map with no stub, no build command and no
code index.

**Stages 3 and 4 are irreducibly code-shaped.** Of the eight
[seam checks](../solo/01-the-solo-path.md#the-seam--where-the-solo-path-stops), the first
four — stack, stub, layer chain, symbol index — have nothing to mean. And the seam is what
the path is aiming at. The hand-off is to `/start-ticket`, which is layer specialists,
symbol edits and two-tier review.

**Use instead:** run the gate, chart the map, and stop at the map. There is no documented
downstream here and this doc will not pretend otherwise.

---

## Heuristic summary

**You already have a ticket** — which pipeline, if any:

| Scenario | Default approach |
|---|---|
| One-line fix, 1 file | Chat |
| Small change, 1–2 files, no design | Chat |
| Multi-layer change, 2+ repos | `/start-ticket` |
| Exploratory / spike — **reading** | Investigation agent |
| Exploratory / spike — **building something to look at** | `/prototype` |
| First time in a new codebase | Manual discovery first |
| Prod incident | `/hotfix` (lighter pipeline, same guardrails) |
| Unstable requirements | Chat until the spec solidifies |
| Recurring pattern, even if small | `/start-ticket` (the memory payoff is real) |

**You have an idea and no ticket** — how much of the [front-end](../solo/01-the-solo-path.md)
to run:

| Scenario | Default approach |
|---|---|
| Raw idea, unjudged, no repo | The whole path — `/pitch` first, and do not create a repo |
| Two-hour script, single file | Chat. The gate alone would be half the project |
| Every decision already named | `/pitch` → **skip charting** → `/bootstrap`. The repo still needs making real |
| Learning the technology, not shipping | Scratch repo + chat. Bank the learning in memory |
| Not software at all | `/pitch` and charting only. Stop at the map — stages 3–4 assume code |
| Idea you keep coming back to but never start | `/pitch`. A recorded *kill* is a cheaper ending than another year of it |

---

## Why this doc exists

This playbook is a tool, not a religion. Every doc describes what the pattern
*can* do. This one describes where it shouldn't be applied. If you find yourself
fighting the pipeline — or fighting the four stages upstream of it — you're
probably in one of these buckets. Trust the heuristic, not the hype.

**Both entrances get an honest section, and the solo one needed it more.** A pipeline you
should not have run costs you one ticket. A front-end you should not have run costs you
weeks of sessions deciding things that did not need deciding, and it feels like progress
the whole time.
---
> **Last verified against:** Claude Code `2.1.226` — August 2026
