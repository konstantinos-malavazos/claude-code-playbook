---
name: <layer>-engineering-standards
description: >-
  GENERATED ONCE PER LAYER/LANGUAGE of your chain by /adapt-to-stack, into the repo's own
  .claude/skills/ under a per-layer directory name (e.g. schema-standards,
  backend-standards, frontend-standards). The coding + review standard for
  <LAYER/LANGUAGE>. Loaded when
  writing or reviewing <LANGUAGE> code, or when running as the <layer>-specialist agent.
  Deliberately carries NO rules for other layers so it stays cheap to load.
---

# <LAYER/LANGUAGE> engineering standards

> Keep each layer's standards scoped to that layer only. A schema specialist should not
> carry frontend rules; a frontend specialist should not carry SQL index rules. Scope by
> language/layer — do not trim content, split it.

## Severity model (shared across all layers)
- `[BLOCKER]` — must fix before merge (correctness, security, data loss).
- `[MAJOR]` — should fix (design, maintainability, missing tests).
- `[MINOR]` — worth fixing (readability, small inefficiency).
- `[NIT]` — optional (style, naming).

## Correctness & design
- <e.g. layer boundaries respected; no business logic in the wrong layer>
- <e.g. inputs validated at the boundary; failure modes handled>

## <Language-specific rules>
- <e.g. async everywhere IO happens; cancellation honoured; no sync-over-async>
- <e.g. nullability handled; disposal correct>
- <e.g. for SQL: index coverage & selectivity; SARGable predicates; no N+1>

## Testing
- <what must be tested at this layer, and how (unit / integration / behaviour)>
- Test behaviour through public interfaces, not internals.

## Security & logging
- No hardcoded secrets. Mask/pseudonymize sensitive identifiers in logs.
- No logging of credentials, tokens, or raw PII.

## Compile/build correctness
- The change must build and the relevant tests must pass before hand-off.

## Vendoring note
If you have an authoritative in-house standard, vendor it here **verbatim** and pin it to
a specific commit, so the skill matches the source of truth exactly.
