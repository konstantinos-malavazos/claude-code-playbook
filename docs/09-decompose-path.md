# 09 — The decompose path (large tickets)

Most tickets (~95%) run the sequential chain and produce one commit per repo. A
genuinely large ticket — say a change rolled out across many independent units, or
several loosely-coupled features under one id — is better split into **independent
vertical slices** built in **parallel**.

This is a *fork inside* `/start-ticket`, not a separate command. The planner proposes it
by setting **slice-count > 1**; you confirm it.

---

## Shape

```
@planner (slice-count > 1)
        │
   /to-spec        restate the plan as a slice-ready spec: name the testing seams
        │          and the behaviour boundaries to slice along
   /to-tickets     split into independent vertical slices; render a SLICE BOARD
        │          (dependency waves + a DAG) → YOU approve or edit
        │
   parallel slices     each slice = a thin COMPLETE path through the layers it needs
   (git worktrees)     (layer-1 → layer-2 → …), built by @slice-* agents in ISOLATED
        │              git worktrees so they don't collide
        │
@aligner          cross-slice drift gate (read-only): do the slices agree on shared
        │          names/types/contracts/signatures? comments only
@integrator       for each repo, bring every slice's commits onto the single final
        │          branch in dependency order, then collapse to ONE commit per repo
@integration-tester   tests the COMBINED behaviour no single slice proves alone;
        │              folds its tests into each repo's one commit
        │
        └──► rejoin the normal path at @reviewer → @senior-reviewer
```

---

## Why vertical slices, not horizontal layers

A **vertical** slice is a thin end-to-end path (a little schema + a little service + a
little client) that is **independently verifiable**. A **horizontal** split (all schema,
then all service) forces a barrier between phases and can't be tested until the end.
Vertical slices can be built and validated in parallel and integrated incrementally.

---

## Why git worktrees

Parallel agents editing the same working copy collide. A **worktree** gives each slice
its own checkout of the same repo on its own branch, so slices run truly in parallel.
The `@integrator` tears the worktrees down after collapsing to one commit per repo.

Worktrees are the right tool *only* when agents mutate files in parallel — they cost
setup time and disk, so the single-slice path never uses them.

---

## The invariants that survive decomposition

- **One commit per repo** still holds — the integrator collapses each repo's slice
  commits into one, using the planner's final commit message.
- **Cross-slice consistency** is a gate (`@aligner`), not a hope: shared field names,
  types, and contract members are diffed across slices before integration.
- **Combined acceptance criteria** get their own tests (`@integration-tester`) because a
  behaviour that emerges from two slices together isn't covered by either slice alone.

---

## When to reach for it

Reach for decompose when a ticket is too big for one sequential pass **and** it splits
cleanly into independent paths (the classic case: the same change applied across N
independent units). If the parts are tightly coupled, the sequential chain is simpler and
safer — don't decompose for its own sake.
