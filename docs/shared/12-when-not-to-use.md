# 13 — When NOT to use this playbook

Every other doc describes the happy path. This one describes where the pattern
loses — when the pipeline costs more than it saves, when it gives false confidence,
and when you should just open a chat.

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
you expect to repeat** — because the memory consolidation means you only solve it
once. But that's a judgement call, not an algorithm.

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
  reviewable single-commit branch; that's not what a spike produces.

**Use instead:** an ad-hoc investigation agent (read-only, no commit structure,
no review gates). Write the findings directly to memory, then decide whether
the next ticket is pipeline-shaped.

**On the solo path this is already handled upstream.** The
[kill gate](../solo/02-the-kill-gate.md) ends by naming the idea's hard part, which is
exactly a spike — but it never reaches `/start-ticket` as one. It becomes a `research`
ticket on the map and is burned off during [charting](../solo/03-charting.md), before
the backlog exists. The two docs also ask different questions: this one asks whether the
pipeline is the wrong *tool*, the gate asks whether it is the wrong *idea*.

---

## Unfamiliar codebase

The pipeline assumes the planner's plan can be meaningfully reviewed. If neither
you nor the agent knows the code well enough to judge whether the plan is sound,
the pipeline gives false confidence — the design looks plausible but misses
hidden coupling, undocumented invariants, or tribal knowledge.

Signs you're here:
- The planner frequently writes "I'm assuming X" about things you know are wrong.
- The Serena sweep returns sparse results (few symbols indexed). Fix the index — this is
  never a reason to fall back to grep, it's a reason to stop.
- Review comments correctly flag things but miss the *important* things.
- You can't tell whether a good plan is actually good, or just well-written.

**Do first:** manual discovery. Read key files, run the app, understand the
coupling. Bank what you learn in memory. When you can predict what the agent
should find, you're ready for the pipeline.

---

## Incidents / hotfixes

When prod is down, prioritise speed over structure. The pipeline's guardrails
**must NOT be bypassed** (especially the git hooks that block `push` and the
read-first rule on prod) — those are safety invariants. But the multi-agent flow
(analyzer → gatherer → planner → specialists → two-tier review) is too slow.

**Use instead:** a `/hotfix` pattern:
- One agent with Serena read + edit access in the affected repo. Speed does not relax the
  Serena rule — symbol edits are *faster* than hunting line ranges under pressure.
- No gatherer step (skip the memory sweep if you know what's broken).
- No planner gate (you already know the fix).
- One reviewer pass, not two.
- **Still:** read-first on any production data, git hooks still block push,
  memory write is still deliberate.

The guardrails are not optional. The agent orchestration is.

---

## Underspecified or unstable requirements

If the ticket's acceptance criteria change mid-flight — because the spec was a
rough draft, because a stakeholder changed their mind, because "we'll know it
when we see it" — the pipeline's fixed sequence fights you. A redesign invalidates
the gatherer's sweep and the planner's allocation; rework propagates through the
specialists; the commit history gets messy despite the one-commit rule.

**Use when:** the spec is stable enough that you can write the final commit message
before you start working. If you can't, you're not ready for the pipeline.

---

## Heuristic summary

| Scenario | Default approach |
|---|---|
| One-line fix, 1 file | Chat |
| Small change, 1–2 files, no design | Chat |
| Multi-layer change, 2+ repos | `/start-ticket` |
| Exploratory / spike | Investigation agent |
| First time in a new codebase | Manual discovery first |
| Prod incident | `/hotfix` (lighter pipeline, same guardrails) |
| Unstable requirements | Chat until the spec solidifies |
| Recurring pattern, even if small | `/start-ticket` (the memory payoff is real) |

---

## Why this doc exists

This playbook is a tool, not a religion. Every doc describes what the pattern
*can* do; this one describes where it shouldn't be applied. If you find yourself
fighting the pipeline, you're probably in one of these buckets. Trust the
heuristic, not the hype.
-e 
---
> **Last verified against:** Claude Code `2.1.219` — July 2026
