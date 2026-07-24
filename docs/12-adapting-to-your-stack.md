# 12 — Adapting the layer-chain to your stack

This is the **one adaptation you must get right**. Everything else is defaults you can
take as-is; this is the part that's specific to *your* codebase.

---

## The abstract idea

A non-trivial change rarely lives in one place. It propagates through your stack in a
**fixed order**, layer by layer, and each layer has a natural **specialist**. Name that
ordered chain once and the whole pipeline falls out of it.

```
   LAYER 1  ──►  LAYER 2  ──►  LAYER 3  ──►  …
   (the thing     (the thing     (the thing
    downstream     that reads     that reads
    depends on)    layer 1)       layer 2)
      │              │              │
   specialist     specialist     specialist
   agent 1        agent 2        agent 3
```

The rule: **each layer depends on the ones before it**, so you implement them in order,
and each layer hands the next a **contract** (the names/shapes it just created).

---

## Worked examples

You define your own; here are three shapes to calibrate against.

**Data-heavy backend** (the shape this playbook was distilled from):
```
database schema  ──►  service / API  ──►  downstream data & reporting
(migrations,          (backend code        (pipelines, warehouse,
 stored procs)         + tests)             analytics consumers)
```

**Product web app:**
```
data model / migration  ──►  backend API  ──►  frontend
```

**Event-driven / microservices:**
```
event contract / schema  ──►  producer service  ──►  consumer services
```

**Library / SDK:**
```
core types  ──►  public API surface  ──►  docs & examples
```

If your change usually lives in one layer, that's fine — you have a one-link chain and a
single specialist. The pipeline still works; it just skips the empty tracks.

---

## How to encode it

### 1. Write the chain into the workspace CLAUDE.md

Add a "sequential implementation chain (mandatory order)" section naming your layers and
their order, plus which repo/agent owns each. Template:
[`../templates/claude-md/workspace.CLAUDE.md`](../templates/claude-md/workspace.CLAUDE.md).

### 2. Create one specialist agent per layer

Copy [`../templates/agents/layer-specialist.md`](../templates/agents/layer-specialist.md)
once per layer and fill in:

- the **layer name** and the **repo(s)/paths** it owns,
- its **build/test commands**,
- the **contract** it must read from the previous layer and write for the next,
- the **engineering standards** skill it should load (see below),
- its **model** (mechanical layers → a faster model; design-heavy layers → a stronger one).

### 3. Give each specialist its standards skill

Split your engineering standards **by language/layer** so each specialist loads only what
it needs (a schema specialist shouldn't carry frontend rules). Copy
[`../templates/skills/engineering-standards/SKILL.md`](../templates/skills/engineering-standards/SKILL.md)
per layer.

### 4. Wire the order into `/start-ticket`

The planner allocates tracks and the orchestrator dispatches the specialists **in chain
order**. The template command already does this generically —
[`../templates/commands/start-ticket.md`](../templates/commands/start-ticket.md) — you
just list your layers.

---

## The alignment gate

When a change touches **two or more** layers, add a cheap consistency check before
review: do the layers agree on the shared names/types/contract? (The field the schema
added ↔ the property the service maps ↔ the member the consumer reads.) This is the
`@aligner` role generalized. For a single-layer change, skip it.

---

## Checklist

- [ ] I can state my chain as an ordered list of layers.
- [ ] Each layer has exactly one specialist agent, with its repo(s), build/test commands,
      and model set.
- [ ] Each specialist reads a contract from the previous layer and writes one for the next.
- [ ] Each specialist loads only its own standards skill.
- [ ] The workspace CLAUDE.md documents the chain and the new-branch workflow.
- [ ] `/start-ticket` dispatches the specialists in order.
-e 
---
> **Last verified against:** Claude Code `[run \`claude --version\` and insert here]` — July 2026
