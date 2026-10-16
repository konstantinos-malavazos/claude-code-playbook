---
name: <layer>-write-core
description: >-
  GENERATED ONCE PER LAYER of your chain by /adapt-to-stack, into the repo's own
  .claude/skills/ beside <layer>-standards. The short write-time rule set for <LAYER/LANGUAGE>:
  only the rules that are expensive to get wrong once the code compiles. Preloaded by
  <layer>-specialist and slice-<layer>-specialist through their skills: line, so it is in
  context for every edit. The full <layer>-standards is for review, not for writing.
user-invocable: false
---

# <LAYER/LANGUAGE> write core

These are the rules you hold while you write. Each one is cheap to follow at the keyboard
and expensive to find after the build is green. Review checks the full `<layer>-standards`
on the diff; you do not load it while writing.

## Boundaries

1. **Stay inside your layer.** No logic that belongs to another layer of the chain, and no
   edit outside the paths this layer owns.
2. **Honour the contract either side.** Consume the upstream handoff's names and shapes
   exactly as written, and hand on exactly what you built.
3. **Validate input at the boundary** where it enters this layer, and nowhere deeper.

## Correctness

4. **Async and cancellation are honoured** wherever IO happens: no sync-over-async, and a
   cancellation signal you receive is passed on, never dropped.
5. **Dependency lifetimes and disposal are correct.** Nothing outlives its scope, and
   everything you open is closed on every path.
6. **No swallowed errors.** An error is handled, or it propagates; it is never caught and
   ignored.
7. **No new dependency the plan did not name.**
8. **Schema changes go through the migration tool**, never raw DDL.

## Security

9. **No secrets in code, and no secrets or personal data in logs.** Mask identifiers you
   must log.

## Serena

10. **Resolve every member with Serena `find_symbol`; never assume** it exists or what it
    takes.
11. **A changed signature means checking its callers** with `find_referencing_symbols`
    before the build.
12. **Run `get_diagnostics_for_file`** on every file you touched, before the build.

## Tests and evidence

13. **Every behaviour change ships with a test** that proves it, through the public
    interface.
14. **A bug fix starts with a test that fails** on the unfixed code.
15. **Never claim a green build or a passing test you did not see.** Quote the command and
    its result.

Not here on purpose: style, naming, readability, comments and documentation. Review catches those through `<layer>-standards`, and carrying them here would make this file as long as the one it replaces.
