# 09 — The decompose path (large tickets)

Most tickets (~95%) run the sequential chain and produce one commit per repo. Some tickets
are genuinely large: one change rolled out across many independent units, or several
loosely-coupled features under one id. Split those into **independent vertical slices** and
build the slices in **parallel**.

This is a *fork inside* `/start-ticket`, not a separate command. The planner proposes it
by setting **slice-count > 1**. You confirm it.

**This path assumes you can already name the slices.** Sometimes you sit down to plan and
cannot: the destination is clear but the route is not. Slicing is the wrong tool then,
because there is nothing yet to slice. That ticket gets **charted** first, with
[`/charting`](../../templates/skills/charting/SKILL.md). On a team, three commands wrap that
charting for an effort spanning repos: [../team/03-massive-tickets.md](../team/03-massive-tickets.md).
Solo, you run the skill directly and hand each make back to `/start-ticket`. Either way the
discriminator against this page is **fog, not size** — both say "large ticket" and they solve
different problems.

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
        │              git worktrees so they don't collide — each dispatched on its
        │              own weight, per slice
        │
@aligner          cross-slice drift gate (read-only): do the slices agree on shared
        │          names/types/contracts/signatures? comments only — and it weighs
        │          any drift fix it sends back
@integrator       for each repo, bring every slice's commits onto the single final
        │          branch in dependency order, then collapse to ONE commit per repo
@integration-tester   tests the COMBINED behaviour no single slice proves alone;
        │              folds its tests into each repo's one commit
        │
        └──► rejoin the normal path at @repo-reviewer → @release-reviewer
```

The two steps that produce the board ship as skills:
[`to-spec`](../../templates/skills/to-spec/SKILL.md) and
[`to-tickets`](../../templates/skills/to-tickets/SKILL.md). `/start-ticket` dispatches both,
so neither sets `disable-model-invocation` — the field would stop the path at the dispatch.

Every agent named above ships as a template:
[`slice-layer-specialist`](../../templates/agents/slice-layer-specialist.md) (generated one
per layer of your chain by [`/adapt-to-stack`](11-adapting-to-your-stack.md), whether or not
you ever decompose), [`aligner`](../../templates/agents/aligner.md),
[`integrator`](../../templates/agents/integrator.md) and
[`integration-tester`](../../templates/agents/integration-tester.md). The other three are not
installed by the normal setup, because none of them runs on the sequential path.

---

## Why vertical slices, not horizontal layers

A **vertical** slice is a thin end-to-end path (a little schema + a little service + a
little client) that is **independently verifiable**. A **horizontal** split (all schema,
then all service) forces a barrier between phases, and nothing can be tested until the
end. Vertical slices can be built and validated in parallel, and integrated incrementally.

---

## Why git worktrees

Parallel agents editing the same working copy collide.

Two agents writing the same file at once **race**. The second write silently clobbers the
first, and neither agent sees an error. Shared git state makes it worse: one index, one
`HEAD`, one set of staged changes. A `git add` or `git checkout` from one agent can shift
what another agent is looking at mid-edit. The fix is **structural isolation**, not better
prompting. No instruction telling an agent "don't touch files another agent owns" prevents
a race the filesystem itself allows.

A **worktree** gives each slice its own checkout of the same repo on its own branch, so
slices run truly in parallel.
The `@integrator` tears the worktrees down after collapsing to one commit per repo.

Claude Code enforces this isolation. It is not just convention, and it has been hardened
recently. Subagents could redirect git into the shared checkout via `git -C`, `--git-dir`,
or `GIT_DIR`/`GIT_WORK_TREE`. v2.1.216 fixed that, and v2.1.203 and v2.1.210 fixed related
escapes. Treat v2.1.216 as the version floor for relying on worktree isolation, because it
hasn't always held.

Worktrees are the right tool *only* when agents mutate files in parallel. They cost setup
time and disk, so the single-slice path never uses them.

---

## The invariants that survive decomposition

- **One commit per repo** still holds. The integrator collapses each repo's slice
  commits into one, using the planner's final commit message.
- **Cross-slice consistency** is a gate (`@aligner`), not a hope. It diffs the shared field
  names, types, and contract members across slices before integration.
- **Combined acceptance criteria** get their own tests (`@integration-tester`) because a
  behaviour that emerges from two slices together isn't covered by either slice alone.
- **Every dispatch is weighed on its own**, this path's two included: each slice at its
  initial dispatch, and the **drift fix** after `@aligner` reports that slices disagree. The
  drift fix is the site to watch here — nothing upstream planned it, so there is no plan to
  inherit a weight from, and *"the slices disagree about a shared contract"* is close to the
  definition of a heavy change. The rule is the `dispatch-weight` skill
  ([`../../templates/skills/dispatch-weight/`](../../templates/skills/dispatch-weight/SKILL.md)),
  the same one the sequential path runs; the reasoning is
  [07](07-the-flows.md#model-escalation-cheap-by-default-escalated-by-weight). `@aligner`
  weighs the drift fix it routes. **`@integrator` and `@integration-tester` take no weight —
  but not because they do not edit.** Both do: the integrator collapses commits, and the
  integration tester writes cross-slice tests and amends them into each repo's commit. They
  take no weight because each already pins the **strong tier as its floor**, and a weight may
  only raise a floor. Check that before excluding an agent from this rule; *"it is not really
  an implementer"* is the wrong test, and it is wrong about both of these.

---

## When to reach for it

Reach for decompose when a ticket is too big for one sequential pass **and** it splits
cleanly into independent paths (the classic case: the same change applied across N
independent units). If the parts are tightly coupled, the sequential chain is simpler and
safer. Don't decompose for its own sake.
---
> **Last verified against:** Claude Code `2.1.226` — August 2026
