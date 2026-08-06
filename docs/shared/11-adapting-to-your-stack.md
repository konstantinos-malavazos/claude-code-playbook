# 11 — Adapting the layer-chain to your stack

This is the **one adaptation you must get right**. Everything else is defaults you can
take as-is; this is the part that's specific to *your* codebase.

You do **one** thing by hand — name the chain. `/adapt-to-stack` generates the rest from
it. This doc is the *why* behind that flow: what it makes, what it refuses to make, and
why it works that way.

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

## How it gets encoded

### 1. Write the chain into the `CLAUDE.md` that owns it — this is the hand-written part

**`/adapt-to-stack` reads the repo's `CLAUDE.md` and nothing else.** No arguments, no
prompts. That is deliberate: a prompt would state the stack a second time, and two copies
can disagree — [06-claude-md-layers.md](06-claude-md-layers.md#rules-that-keep-the-layers-healthy)'s
first rule, *one fact, one layer*, with the prompt as the second copy.

Which file carries the chain depends on how many repos you have, and
[`../../templates/claude-md/repo.CLAUDE.md`](../../templates/claude-md/repo.CLAUDE.md)
ships **both shapes** — keep one, delete the other:

| Your situation | Shape | What the repo's `CLAUDE.md` says |
|---|---|---|
| **One repo, every layer** (the usual solo shape) | **A** | the whole chain, in order, plus where each layer lives |
| **One repo per layer, sibling repos** | **B** | this repo's *one* layer, and the contract it reads and writes |

On shape B the cross-repo order also belongs in the workspace `CLAUDE.md`
([`../../templates/claude-md/workspace.CLAUDE.md`](../../templates/claude-md/workspace.CLAUDE.md)),
under a *"sequential implementation chain (mandatory order)"* section — that is the file a
human reads to see the whole picture. The flow never reads it: run inside a repo, it
generates that repo's layer, from that repo's own file.

**Optionally, name a model per layer.** The chain section takes an optional model id
against each layer. If you state one, the flow writes it into that specialist's `model:`.
If you leave it out — **the normal day-one answer** — the field is omitted entirely and
the specialist inherits whatever you picked for the session. Three reasons to leave it out
on a new repo:

- On day one the repo is a stub. Knowing a layer is mechanical means having worked in it.
- Deriving *schema is mechanical, frontend is design-heavy* from a layer's **name** is the
  artifact guessing.
- **Model ids rot.** A written-in id is N files to update the day it changes; inheriting is
  zero.

State one when you genuinely know — which is usually months later, or on an existing
codebase whose layers you have lived in.

### 2. One specialist agent per layer — generated

The flow copies
[`../../templates/agents/layer-specialist.md`](../../templates/agents/layer-specialist.md)
once per layer and fills in what `CLAUDE.md` already knows:

| Filled in | Where it comes from |
|---|---|
| the **layer name** and the **repo(s)/paths** it owns | the chain section |
| its **build/test commands** | the *build / test / run* section |
| the **contract** it reads from the previous layer and writes for the next | chain **order** — the neighbours either side |
| the **engineering standards** skill it loads | the skill generated in step 3, named for the layer |
| its **model** | the optional per-layer id, or omitted so it inherits |

**Why generated rather than copied by hand:** a specialist file is *facts about this
codebase* — its paths, its build command, its layer — and every one of those facts is
already written down one file away. Copying is transcription, and transcription drifts.

They land in the **repo's own `.claude/agents/`, and they are committed.** Facts about the
codebase are project-scoped ([01-architecture.md](01-architecture.md)); on a team, files in
`~/.claude/` mean every engineer hand-copies them and they drift apart — which is the
manual labour this flow exists to kill.

### 3. One engineering-standards skill per layer — generated

Split your engineering standards **by language/layer** so each specialist loads only what
it needs (a schema specialist shouldn't carry frontend rules). The flow copies
[`../../templates/skills/engineering-standards/SKILL.md`](../../templates/skills/engineering-standards/SKILL.md)
per layer, into the repo's **`.claude/skills/`**, named for the layer so the specialist in
step 2 can name the file it loads.

**On day one these are mostly placeholders, and you should expect that.** The flow can fill
in the language and the layer name and no more — the actual rules are yours to write as you
learn what this codebase gets wrong. They are generated anyway, because the specialist
loads that file and the alternative is pointing it at one that does not exist.

### What the flow will not generate

| Not generated | Why |
|---|---|
| `CLAUDE.md` | It is the flow's **input**. A flow that generates its own input generates from itself. If it is missing or short a section, the flow **stops**, names what it needs, and points you at [`repo.CLAUDE.md`](../../templates/claude-md/repo.CLAUDE.md) — it does not write the file for you. |
| Serena setup | Owned by [the bootstrap](../solo/04-the-bootstrap.md), which has its own conditional verdict. Two steps owning one act is one too many. |
| `commit-conventions` | **Not per-stack.** The branch format, the type/scope rule and the amend-as-you-go loop are identical whatever the language is — one `<scope>` placeholder and a main-branch name. It is a setup-time copy; generating it per repo makes N copies of a workspace-wide convention. |

### It never overwrites, and it tells you what it did

A re-run creates what is missing and **leaves everything existing alone**. Add a fifth
layer and you get one specialist and one standards skill; change the test command in
`CLAUDE.md` and nothing changes automatically.

Diff-and-patch was rejected on purpose. Once real rules are written by hand there is no
reliable boundary between the template's lines and yours, so a patcher that guesses wrong
**destroys hand-written standards silently** — the worst failure available here, because
standards are the thing you would least notice going missing.

The honest cost is drift the flow will never fix. So it ends with a report of four rows,
and — like [the bootstrap's exit test](../solo/04-the-bootstrap.md#the-exit-test) — it
**reports every row and classifies nothing**:

| Row | What it means |
|---|---|
| **created** | generated this run |
| **skipped** | already existed, untouched |
| **disagrees with `CLAUDE.md`** | the file names a path, command or layer the chain no longer says. Yours to reconcile |
| **still a scaffold** | the file is still carrying the template's `<PLACEHOLDER>` angle brackets |

That last row costs no state at all — no timestamps, no ledger. **The convention that makes
a template fillable is what makes un-filled-ness detectable.**

> **The `/adapt-to-stack` skill template is still being written.** Until it lands, steps 2
> and 3 are the same act done by hand: copy
> [`../../templates/agents/layer-specialist.md`](../../templates/agents/layer-specialist.md)
> and
> [`../../templates/skills/engineering-standards/SKILL.md`](../../templates/skills/engineering-standards/SKILL.md)
> once per layer and fill in **step 2's table** out of `CLAUDE.md` yourself. Everything on
> this page is what the output should look like either way — what changes is who does the
> typing.

### 4. Wire the order into `/start-ticket`

The planner allocates tracks and the orchestrator dispatches the specialists **in chain
order**. The template command already does this generically —
[`../../templates/commands/start-ticket.md`](../../templates/commands/start-ticket.md) — you
just list your layers.

---

## The alignment gate

When a change touches **two or more** layers, add a cheap consistency check before
review: do the layers agree on the shared names/types/contract? (The field the schema
added ↔ the property the service maps ↔ the member the consumer reads.) This is the
`@aligner` role generalized. For a single-layer change, skip it.

---

## Checklist

The first item is yours. The rest are read off the flow's report.

- [ ] The repo's `CLAUDE.md` states my chain as an ordered list of layers — shape A or
      shape B, and on shape B the workspace `CLAUDE.md` carries the cross-repo order and
      the new-branch workflow.
- [ ] The report shows **one specialist created per layer** in `.claude/agents/`, each with
      its paths and build/test commands filled in from that file.
- [ ] The report shows **one standards skill per layer** in `.claude/skills/`.
- [ ] Nothing came back as **disagrees with `CLAUDE.md`** — or if it did, I reconciled it
      by hand.
- [ ] I know which files are **still a scaffold**, and that filling them in is mine and not
      the flow's.
- [ ] `/start-ticket` dispatches the specialists in order.

---

## Why this doc exists

The flow tells you *what to run*. This tells you *why the output looks like that* — why
`CLAUDE.md` is the only input, why `model:` is usually absent, why a re-run refuses to
touch what you have written, and why the day-one standards skills are almost empty.

You need that the first time the report says **disagrees with `CLAUDE.md`** and you have to
decide which of the two is wrong.

---
> **Last verified against:** Claude Code `2.1.219` — July 2026
