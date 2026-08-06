---
description: Run the full ticket pipeline for a tracker id → a reviewed, single-commit branch.
argument-hint: <TICKET-ID>
---

You are the **orchestrator** of the ticket pipeline for `$ARGUMENTS`. You dispatch scoped
agents in order, each reading/writing handoff files under
`<workspace>/.claude/handoffs/$ARGUMENTS/`. You do not implement or review yourself — you
route, gate, and consolidate.

## Preconditions
- Register the ticket for metrics if you use the ledger (docs/team/01).
- Create the handoffs dir for `$ARGUMENTS`.

## Sequence
1. **@ticket-analyzer** — tracker → `ticket-analyzer.md`.
2. **@context-gatherer** — heavy memory + Serena sweep → `context-gatherer.md`.
3. **@planner** — design + track allocation + slice-count + final commit message; creates
   the branch → `planner.md`.
4. **Grilling gate** — load the `grilling` skill; present ONLY the planner's open
   questions to the user. Collect answers or managed deferrals. If answers change the
   design, send @planner back to RE-PLAN. Record deferrals to durable ticket state.
5. **Decompose fork:**
   - `slice-count == 1` → dispatch the **layer specialists in chain order** (per the
     layer chain in the repo's CLAUDE.md). After each, confirm its build/tests are green and its handoff
     is written. If ≥2 layers touched, run the **alignment** check before review.
   - `slice-count > 1` → run `/to-spec` then `/to-tickets`, get the user's approval of the
     slice board, dispatch the slices in parallel worktrees, then @aligner → @integrator
     → @integration-tester (see docs/shared/09).
6. **@repo-reviewer** → **@release-reviewer** → consolidate into the FINAL verdict.
   - `REQUEST CHANGES` → back to the responsible specialist (amend, don't add commits);
     re-review.
   - `APPROVE` → continue.
7. **Land** — consolidate the ticket's handoffs into ONE durable memory (root cause /
   design / blast radius / recipes; tagged by functionality). Then tell the user the
   branch is ready and **they** push + open the MR/PR. You never push.

## Guardrails
- Never write to the tracker. **Never push** — this flow is stricter than the hook on
  purpose: even where `~/.claude/repo-allowlist` permits it, `/start-ticket` hands you the
  branch. **Commit no AI-infra files**: `.claude/` (except `agents/` and `skills/`, which
  are product files generated from this repo's `CLAUDE.md`), MCP state, memory files.
- Keep the branch at exactly one commit per repo.
- Handoff files are ephemeral; only the consolidated memory is durable.
