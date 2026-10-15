---
description: Run the full ticket pipeline for a tracker id → a reviewed, single-commit branch.
argument-hint: <TICKET-ID>
---

You are the **orchestrator** of the ticket pipeline for `$ARGUMENTS`. You dispatch scoped
agents in order, each reading/writing handoff files under
`<workspace>/.claude/handoffs/$ARGUMENTS/`. You do not implement or review yourself. You
route, gate, and consolidate.

## Preconditions
- Register the ticket for metrics if you use the ledger (docs/team/01).
- Create the handoffs dir for `$ARGUMENTS`.

## The dispatch rule — applies at EVERY implementation dispatch below

Every time you hand work to an implementation specialist, that dispatch carries a weight,
classified by the `dispatch-weight` skill. **You never classify it yourself** — the agent
holding the evidence does, and you read its answer and route:

- `weight: light` → dispatch on the tier `<fast-model-id>` belongs to, and **set it
  explicitly** — the id-to-tier mapping is in the `dispatch-weight` skill. Setting nothing
  is not the same thing: a specialist with no pinned `model:` then inherits **your** model,
  the strong one.
- `weight: heavy` → dispatch on the tier `<strong-model-id>` belongs to, **for that run
  only** — same mapping.
- **Ratchet:** never dispatch a track below the tier it last ran at.
- **Floor:** never dispatch a specialist below its own pinned `model:`, whatever the weight
  says — where that pin is already higher, set nothing.
- **Serena paragraph:** paste the `## Dispatch paragraph` of the `code-access` skill into the
  prompt, with its `<live tools>` slot filled. Every dispatch carries it — the first one, a
  review fix, a drift fix, an `@integration-tester` route-back, an alignment return — and so
  does the dispatch of `@integration-tester` itself.

Record the dispatched model, the weight, the reason and the pass number in that track's
handoff. There are four dispatch sites below (steps 5 and 6); a weight read once from
`planner.md` and reused covers one of them.

## Sequence
1. **@ticket-analyzer** — tracker → `ticket-analyzer.md`.
2. **@context-gatherer** — heavy memory + Serena sweep → `context-gatherer.md`. If its
   `## Stale memories` section is not `none`, relay its warning line to the user verbatim
   and carry on; a stale memory does not stop the flow.
3. **@planner** — design + track allocation + slice-count + final commit message; creates
   the branch → `planner.md`.
4. **Grilling gate** — load the `grilling` skill; present ONLY the planner's open
   questions to the user. Collect answers or managed deferrals. If answers change the
   design, send @planner back to RE-PLAN. Record deferrals in
   `<workspace>/.claude/handoffs/$ARGUMENTS/open-questions.md`.
5. **Decompose fork:**
   - `slice-count == 1` → dispatch the **layer specialists in chain order** (per the
     layer chain in the repo's CLAUDE.md). **Dispatch site 1** — apply the dispatch rule
     above, reading each track's weight from `planner.md`. After each, confirm its
     build/tests are green and its handoff
     is written. If ≥2 layers touched, run the **alignment** check before review, and
     **dispatch site 2**: any drift fix `@aligner` routes back goes on the weight `@aligner`
     classified, not on the slice's original one.
   - `slice-count > 1` → run `/to-spec` then `/to-tickets`, get the user's approval of the
     slice board, then run the slices **one at a time, in the main checkout, in board order**
     (wave 1 first, then by slice number). Per slice, per repo it touches: check out
     `<TICKET-ID>_<slug>-slice-<N>`, cut from that repo's previous slice branch (or from the
     final branch for the first), confirm `git status` is clean, then dispatch its specialists
     in chain order — **dispatch site 3**, each slice on its own weight from the plan. Start
     the next slice only after the previous one's last specialist returns. Then @aligner →
     @integrator → @integration-tester (see docs/shared/09). @aligner's drift fixes are site 2
     above, and land on the chain tip.
6. **@repo-reviewer** → **@release-reviewer** → consolidate into the FINAL verdict.
   - `REQUEST CHANGES` → back to the responsible specialist (amend, don't add commits);
     re-review. **Dispatch site 4, and the one most setups miss:** dispatch on the **re-pass
     weight in the verdict**, which @repo-reviewer classified over its own findings. Not the
     first pass's weight, and not a blanket one-tier bump — a one-line rename and a broken
     contract with three untouched callers both come back as `REQUEST CHANGES`. The ratchet
     applies: never below the tier that track last ran at.
   - `APPROVE` → continue.
7. **Land** — harvest the ticket into memory from the handoff text only; never re-read code
   for it.
   1. **Visited code** = the files cited in the handoffs, minus the ticket's own diff.
   2. From what the handoffs say about that code, keep only traps, non-obvious whys,
      negative results, cross-repo contracts and per-config divergences. Zero gotchas is
      normal.
   3. Write at most five `gotcha` memories: importance 8, `source_files` = the visited
      file, owner = that file's repo. If more than five qualify, write the five whose
      visited file the most handoffs cite; the rest go in the hand-back as "not written".
   4. Then write one `feature` memory (root cause / design / blast radius): `source_files`
      = the diff, importance 6, one owner project.
   5. Link the feature memory to each gotcha.

   Then tell the user the branch is ready. **Push it** where the allowlist permits;
   **they** open the MR/PR.
8. **Say what they do now** — end with the `next-steps` block. On APPROVE: the branch, its
   single sha and the memory ids — the feature memory, and each gotcha with its id, plus
   any gotchas "not written". A gotcha the user vetoes is marked obsolete. Then the MR/PR
   description @repo-reviewer drafted, which is theirs to paste; then `/test-ticket $ARGUMENTS` where the ticket needs proving against a
   real environment, otherwise the next ticket — in a **fresh** session, because a ticket is
   sized to one context. **Where the allowlist did not permit the push**, say plainly that
   the branch is local and unpushed, and give them the one line to add to
   `~/.claude/repo-allowlist`. Never say merge.

## Guardrails
- Never write to the tracker. **Push the branch when `~/.claude/repo-allowlist` permits
  it, and not otherwise.** The hook is the authority. This flow no longer adds a
  second, invisible no. **Never push to the trunk, and never merge**: that is the step that
  makes a change the trunk's problem, and it stays yours. **Commit no AI-infra files**: `.claude/` (except `agents/` and `skills/`, which
  are product files generated from this repo's `CLAUDE.md`), MCP state, memory files.
- Keep the branch at exactly one commit per repo.
- Handoff files are ephemeral; only the Land memories (the gotchas and the feature memory)
  are durable. No in-flight state goes to memory.
