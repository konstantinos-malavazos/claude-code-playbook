---
name: dispatch-weight
description: >-
  The single classification rule for how heavy ONE implementation dispatch is, so the
  orchestrator can escalate the model for that run only. Emits `light` or `heavy` plus a
  one-line reason naming the criterion that fired. Auto-loads whenever an agent is about to
  hand work to an implementation specialist, or is writing the plan/verdict/fix-plan that
  another agent will dispatch from. Triggers on "weight", "which model", "escalate",
  "dispatch the specialist", "re-pass", "REQUEST CHANGES", "model escalation", "no
  specialist", "fallback persona".
---

# Dispatch weight

You classify **the change that is about to be made**, on **one dispatch**, for **one
specialist**. You do not classify the ticket, and you never set anybody's `model:`.

The reasoning behind this rule — why step count and not token price sets the bill — is
[`docs/shared/07-the-flows.md`](../../../docs/shared/07-the-flows.md), *Model escalation*.
This file is the rule itself, so that every dispatch site runs the same one.

---

## The unit is a dispatch, not a ticket

A track is dispatched more than once: the first pass, a re-pass for every `REQUEST CHANGES`,
a drift fix after an alignment gate, a QA bounce-back weeks later. **Each of those is its own
classification**, made from what that dispatch has to do — not inherited from the last one.

A weight written once on a plan and reused is the common failure. It covers the first pass
and silently misses every re-dispatch, and the re-dispatch after a failed review is the one
that most needed it.

---

## The output

One line, wherever the dispatching agent will read it:

```
weight: light | heavy — <the criterion that fired, in one clause>
```

The reason is not decoration. It is what makes the thresholds auditable later, and a weight
nobody can audit drifts. Name the criterion, not the feeling: *"3 callers on a changed
signature"*, never *"this looks tricky"*.

---

## Classify `heavy` when the dispatch

- touches **more than 3 files** — 3 or fewer is `light`,
- spans **more than one repo**,
- changes a **shared contract or signature with multiple callers** — **2 or more**, counted
  with Serena's `find_referencing_symbols`, never a grep,
- has to work around a **placeholder seam** left by a deferred decision.

Otherwise `light`. Tune the list to your team; it is a starting point, not scripture. Keep it
**here**, in this one file, when you do.

### Three more criteria that only exist on a fix pass

A re-pass, a drift fix and a QA bounce-back also read `heavy` when:

- the reviewer raised several findings against one track — **3 or more**,
- **any** finding is at **contract/schema tier** — it changes a shape another track, repo
  or stored record depends on, or
- **any** finding says the **design** was wrong rather than the details.

The last one outranks file count. A one-file change that reopens a design decision is a
heavy dispatch; a twelve-file rename is not.

---

## Three invariants

**1. Asymmetry — raise on suspicion, lower only on evidence.** A weight is a guess made
before the work starts. Being wrong upward costs one expensive run. Being wrong downward
costs a run that thrashes, plus the review that catches it, plus the re-pass. Guess up.

> Skip this and the cheap direction starts winning ties, which is exactly the direction
> whose failures are invisible in the output.

**2. Ratchet — a re-dispatch never runs below the tier that track last ran at.** Classify
the re-pass on its own merits, then take the **higher** of that and what the track last ran
at.

> Skip this and a fresh classification sends a track that just failed review straight back
> to the model that failed it. The classification is not wrong; it is just answering a
> question about the fix while the evidence was about the model.

**3. The agent's own `model:` is a FLOOR.** A weight raises a specialist for one run. It
never lowers one below the tier pinned in its frontmatter.

> Skip this and a per-dispatch heuristic quietly overrules a decision somebody made who
> knew the agent — and it does it silently, once per dispatch, forever.

---

## For whoever dispatches — mapping an id to a tier alias

**This section is not addressed to the classifier.** The classifier emits a weight and
stops. It lives here because this file is the one thing already loaded at the moment a
dispatch is made, so it is the only place a dispatching agent is guaranteed to read.

The dispatch `model` field takes a **tier alias** — `sonnet`, `opus`, `haiku` or `fable` —
**never a full model id**. The ids recorded at install therefore *name* a tier; they are not
values you can pass. Map before you dispatch:

| the model id contains | dispatch alias |
|---|---|
| `opus` | `opus` |
| `sonnet` | `sonnet` |
| `haiku` | `haiku` |
| `fable` | `fable` |
| none of these | **no override** |

Two rules go with the table:

- **Match on the family word, not the whole id.** An exact-id table has no row for someone
  who answered `claude-sonnet-4-5` at install, and the installer accepts any string.
- **An unmappable id means no override — never a guess downward.** That is invariant 1
  applied: with no override that one setup runs on the orchestrator's model, which is
  expensive but never wrong.

The alias set is a property of the harness, not of this playbook.

**Why `light` sets a tier explicitly instead of overriding nothing.** The two layer
specialists are the only agent templates that pin no `model:` — which is exactly what makes
them weight-eligible — and an agent with no pin defaults to `inherit`, i.e. the
**orchestrator's** model, the strong one. So "no override" would silently hand every light
dispatch the expensive tier. `light` therefore sets the cheap tier outright, and invariant 3
still decides the rest: where the specialist pins something higher, set nothing.

### The `Dispatched:` line

Every implementation dispatch prompt carries one fixed line, and the dispatched agent copies
it verbatim as its handoff's **first line**:

```
Dispatched: <model> (weight: <light|heavy> — <reason>; pass: initial|review-fix N|drift-fix N)
```

- **`<model>`** is the tier alias you set on that dispatch, from the table above — or `none`
  where you set no override (an unmappable id, or a pinned floor that is already higher).
  It is never an exact model id: the dispatch `model` field takes only a tier name, and a
  specialist's frontmatter is the one place an exact id is written.
- **`<reason>`** is the criterion the classifier named.
- **`pass`** is `initial` on the first dispatch of a track, and `review-fix N` or
  `drift-fix N` on the Nth fix pass of that kind.

One fixed line, in one place, is what makes the weights auditable with a single grep across
handoffs.

---

## No specialist — the fallback dispatch

**This section is not addressed to the classifier either.** It is for whoever dispatches,
and it lives here for the same reason as the table above: this file is already loaded at the
moment a dispatch is made.

**When it applies.** The track's dedicated agent file does not exist in the target repo:
`<repo>/.claude/agents/<layer>-specialist.md`, or `slice-<layer>-specialist.md` for a slice.
That happens when no chain is declared, /adapt-to-stack never ran, the chain does not cover
the layer, or the change is a one-off outside the chain. **If the file exists, dispatch that
specialist as usual: an existing specialist always wins.** On a partial chain, only the
uncovered layers fall back.

> A file that is on disk but that the Agent tool reports "not found" is not a fallback case.
> It has one of two causes. It was generated after this session started, and agents load at
> session start: that is /adapt-to-stack's restart rule. Or its `name:` line still holds a
> placeholder, and a restart does not fix that. Either way, stop and say so.

**The persona.** Dispatch `general-purpose`. The **first line** of the prompt is a role
line, for example *"You are a senior <backend | frontend | database | …> engineer
specialised in <language / framework / layer>"*. Choose it **per dispatch**, from the
work-unit, the files it touches and the stack the repo's `CLAUDE.md` names. It is never a
fixed default and never left out. It is a line in the prompt only: write no agent file for
it.

**The `tdd` instruction.** The prompt says: *"Use the `tdd` skill: write the failing test
first. For a bug, that is the test that reproduces it. Then make it pass."* It applies to new
behaviour and to bug fixes. It is **not applicable** only to work with no testable
behaviour: docs, config, pure prose or templates, and generated files. The prompt always
names which case it is, as `tdd: applies` or `tdd: not applicable — <case>`, so a skip is a
stated decision and never a silent one.

**Everything a specialist dispatch carries, the fallback carries too:**

- **Its inputs, read first.** The plan file the planner wrote (`planner.md`): this track, the
  confirmed `## Testing seams` and the final commit message. The upstream layer's handoff:
  the contract the agent must honour. **On a slice**, the upstream handoffs are the ones
  already in this slice's directory, and the agent also reads its work-unit
  `slices/slice-<N>.md`: the slice's scope, acceptance criteria and verify seam.
- **The weight**, classified and routed exactly as for a specialist track. If the fallback
  agent pins a `model:` of its own, that pin is a floor (invariant 3). With no pin, `light`
  sets the cheap tier explicitly, for the same reason the layer specialists' `light` does.
- **The `Dispatched:` line**, from the section above.
- **Code access.** Tell the agent to load the `code-access` skill — a `general-purpose`
  agent has no `skills:` preload — and paste that skill's `## Dispatch paragraph` with
  `<live tools>` filled.
- **Build and verify.** The repo's `CLAUDE.md` build and test commands. The agent does not
  hand back until `get_diagnostics_for_file` is clean on every file it touched, the build is
  green and the tests pass.
- **The commit rules**, from `commit-conventions`: the planner's final commit message,
  amend-as-you-go, one commit per repo, explicit paths, never push, never commit AI-infra
  files. **On a slice**, carry the slice overrides instead: check the expected slice branch
  before the first write, commit freely, and leave the collapse to one commit to the
  integrator.
- **The handoff, at the path the missing specialist would have written:**
  `handoffs/<TICKET-ID>/<layer>-specialist.md`, or
  `handoffs/<TICKET-ID>/slices/slice-<N>/<layer>-specialist.md` on a slice. The next layer,
  the aligner and the reviewers then find it where they already look. The `Dispatched:` line
  is its first line and the `Serena calls:` line its last.
- **On a fix pass**, act only on the findings tagged `[<repo>/<track>]` for this track.
- **The efficient-reasoning paragraph**, verbatim.

---

## You must NOT

- Set, suggest or write a `model:` value — **as the classifier**. You emit a weight; the
  agent that dispatches maps it through the table above. The prohibition is on the
  classification step, not on that mapping: the table is for whoever dispatches, and this
  skill still never writes anybody's `model:` frontmatter.
- Classify the ticket, the track's history, or how hard the last pass was.
- Reuse a weight from a previous dispatch instead of making a new one.
- Emit a weight with no reason line.
