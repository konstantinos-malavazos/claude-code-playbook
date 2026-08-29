---
name: memory-schema
description: >-
  Your memory server's exact call shape and rules. Auto-loads before any memory WRITE
  (create/update/link a memory) so the model uses the correct tool shape, required
  fields, enums, char caps, and linking API — and stops inventing fields. Also load it
  whenever a memory tool errors with a validation failure before retrying.
---

# Memory schema (fill in for YOUR memory server)

> Replace every `<PLACEHOLDER>` with your actual memory MCP's tool names and constraints.
> The point of this skill is to make memory writes correct on the first try.
>
> **Running Forgetful?** [`forgetful.SKILL.md`](forgetful.SKILL.md) next to this file is
> this skill already filled in for it — call shape, caps, enums, the asymmetric linking
> table and the tools that don't exist. `mv forgetful.SKILL.md SKILL.md` and delete this
> placeholder. On any other server, read it as a worked example of how much detail earns
> its place here, then write your own.

## Call shape
- Create: `<create-memory-tool>` with fields `<title>`, `<content>`, `<tags>`, `<...>`.
- Update: `<update-memory-tool>` ...
- Link: `<link-tool>` — note the argument order/direction if it's asymmetric.
- Obsolete: `<mark-obsolete-tool>` with a `<superseded_by>` pointer.

## Required fields & caps
- `<field>` — required; max `<N>` chars.
- `<field>` — enum, one of `<...>`. Do NOT invent values.

## Tagging rules
- Tag **by functionality** (topic / component / symbol), **never by ticket id**.
  (Put the ticket id in the content for provenance if you want it.)
- Include your scope/project tag so `/garden-memory` can find untagged strays.
- Respect the tag cap (`<N>` tags max) and the locked vocabulary if you have one.

## Content rules
- One atomic fact/conclusion per memory. State **what** and **why**.
- Link related memories so one query returns the whole chain
  (root cause → fix → blast radius → recipe).
- For recipes/hypotheses, set a **confidence** and a **validated** marker. Flip
  `validated` only after a real (e.g. staging) run confirms it.

## When to write
- Durable conclusions only, at ticket APPROVE or via `/end-of-day`. Never write in-flight
  chatter. That's what handoff files are for.
