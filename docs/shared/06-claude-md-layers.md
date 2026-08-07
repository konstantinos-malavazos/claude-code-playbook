# 06 — The CLAUDE.md layers

`CLAUDE.md` is the always-on instruction file Claude Code loads automatically. Its power
is that it comes in **layers** that stack via a parent-directory walk: Claude loads
*every* `CLAUDE.md` from your home directory down to the folder you are working in. Each
layer answers a different question — and **how many layers you get is not fixed**.

> This playbook gives you the **idea and structure** of each layer as templates in
> [`../../templates/claude-md/`](../../templates/claude-md/) — not one team's content. Fill in
> your own facts.

---

## How many layers you get

There is always a **top** layer (how you work) and a **bottom** layer (this codebase).
Whether there is a **middle** one depends on one question: **how many repos do you work
across at once?**

**One repo — two layers.** There is no atlas to write, because the map of the workspace
would read *"there is one repo, and it is this one"*:

```
~/.claude/CLAUDE.md            ← GLOBAL : how YOU work, on every project
        │  (loaded everywhere)
        ▼
<repo>/CLAUDE.md               ← REPO   : facts true only inside this repository —
           (loaded only in that repo)     including the branch it ships from
```

**Sibling repos checked out side by side — three layers.** The middle one is the atlas
they share:

```
~/.claude/CLAUDE.md            ← GLOBAL   : how YOU work, on every project
        │  (loaded everywhere)
        ▼
<workspace>/CLAUDE.md          ← WORKSPACE: the multi-repo atlas — which repos exist,
        │  (loaded for any repo    which branch each one ships from, the cross-repo
        │   under the workspace)    change pattern
        ▼
<workspace>/<repo>/CLAUDE.md   ← REPO     : facts true only inside this one repository
           (loaded only in that repo)
```

They **compose**. The global file never repeats a codebase fact; where a workspace file
exists, it never repeats a repo fact. Each fact lives in exactly one layer — the most
specific one that's still always true.

**The numbers below name the three files, not a count.** Layer 2 is the one that comes
and goes; layers 1 and 3 are always there. On the [solo path](../solo/01-the-solo-path.md)
you get the two-layer shape — [the bootstrap](../solo/04-the-bootstrap.md) writes exactly
one `CLAUDE.md`, the repo's own, and that is not an omission.

---

## Layer 1 — Global (`~/.claude/CLAUDE.md`)

**Question it answers:** *How do I work, regardless of project?*

This is your personal operating manual. It's the same whether you're in a work monorepo
or a weekend side project. Put here the things that are about **you and your process**,
not about any particular codebase:

- **Tooling policy** — which MCP servers are always-on, which are **mandatory with no
  opt-out** (Serena for all code reads *and* edits), and how to opt out of the rest
  per-turn.
- **First-action rules** — e.g. "before touching code, recall prior context from memory;
  all code access goes through Serena, by symbol — never grep or whole-file reads for a
  code-structure question, never `Edit` where `replace_symbol_body` applies."
- **Ticket / branch / commit conventions** — the format you always use, including the
  **new-branch workflow**: the exact fetch/checkout/rebase/branch sequence and its stop
  rules. The sequence is the same in every repo, so it is stated once, here. Only the
  branch *name* it checks out is a codebase fact, and that lives in layer 3.
- **Ticket-tracker policy** — which adapter is installed at `~/.claude/tracker.md`, and
  the write rule: "ask before writing anywhere other people can see it."
- **Handoff protocol** — where in-flight agent state lives and that it's ephemeral.
- **Communication style** — terse vs verbose, when to expand.
- **Coding-behaviour defaults** — think-before-coding, simplicity, surgical changes.

Template: [`../../templates/claude-md/global.CLAUDE.md`](../../templates/claude-md/global.CLAUDE.md)

---

## Layer 2 — Workspace / multi-repo atlas (`<workspace>/CLAUDE.md`) — *only with sibling repos*

**Question it answers:** *What lives in this workspace, and how do changes move through
it?*

**Skip this layer entirely if you have one repo.** Every item below is a fact *about the
plurality*: with one repo each one either evaporates or belongs to a neighbouring layer,
and a file that exists to say *"there is one repo"* is a file an agent loads for nothing.

If your work spans several repositories checked out side-by-side, this is the **map**.
It's auto-loaded for *any* repo under the workspace via the parent-directory walk, so
it's the natural home for cross-repo facts:

- **Repo map** — a table: path · stack · purpose · which specialist agent owns it.
- **Main-branch-per-repo table** — the branch each repo ships to production from. This is
  an **index, not the owner**: each repo also states its own in layer 3. It earns its
  place on a need one repo does not have — working in `recipes-api/`, you may need what
  `recipes-web/` ships from, and *that* repo's `CLAUDE.md` is not loaded.
- **The sequential implementation chain** — the canonical order a multi-repo change
  follows (your `schema → service → consumer` equivalent). With one repo the chain is
  still declared, but in the repo's own file — see
  [11-adapting-to-your-stack.md](11-adapting-to-your-stack.md).
- **Cross-repo rules** — when cross-repo edits are allowed, how to widen scope.

The **new-branch workflow** is not here. The sequence is identical in every repo, so it
lives once in layer 1; this file supplies only the branch name it checks out.

Template: [`../../templates/claude-md/workspace.CLAUDE.md`](../../templates/claude-md/workspace.CLAUDE.md)

---

## Layer 3 — Per-repo (`<repo>/CLAUDE.md`)

**Question it answers:** *What's true inside THIS repository specifically?*

Loaded only when you're working inside that repo. Home for facts that would be noise
anywhere else:

- The repo's stack, entry points, and build/test commands.
- **The branch this repo ships from** — the prod target you rebase onto before cutting a
  feature branch. It is a fact about this codebase, so this is where it lives, whichever
  shape you are in. (With sibling repos the workspace table indexes it too; see rule 5 —
  an index is not a second owner.)
- Local conventions that differ from the default.
- Repo-specific gotchas ("this service consumes topic X; don't change the payload
  without updating consumer Y").
- Where the important code lives (a pointer, not a paste — let Serena find the details).

Keep it **lean**. A per-repo CLAUDE.md that restates the whole architecture is a
maintenance liability; it should be the 20 facts that save the agent a wrong turn.

Template: [`../../templates/claude-md/repo.CLAUDE.md`](../../templates/claude-md/repo.CLAUDE.md)

---

## Rules that keep the layers healthy

1. **One fact, one layer.** Never paste the same rule into two files. If a repo's
   CLAUDE.md and the workspace CLAUDE.md disagree, you have a bug. (An *index* is the one
   exception, and it is bounded by rule 5.)
2. **Most-specific-that's-always-true.** A fact goes in the lowest layer where it's
   *always* true — and *lowest* depends on how many repos you have. "We rebase, never
   merge" is behaviour, so it is global in both shapes. "This repo ships from `develop`"
   is a fact about a codebase, so it is **per-repo** — on sibling repos the workspace
   atlas also indexes it, which is not the same as owning it. "This service's consumer is
   repo Y" is per-repo. "Which repos exist" only has a home when there is more than one.
3. **Point, don't paste.** CLAUDE.md is not documentation of the codebase — that's what
   Serena + Forgetful are for. It's the small set of always-true policies and pointers.
4. **Never commit personal AI-infra CLAUDE.md into a shared product repo** unless the
   team has agreed it's shared guidance. Your personal global file certainly doesn't
   belong there. (A guardrail hook enforces this — see
   [`../../templates/hooks/block-infra-staging.sh`](../../templates/hooks/block-infra-staging.sh).)
5. **Canonical mappings live once.** If you have a lookup table everything depends on
   (environments, service codes, an id↔name map), put it in exactly one layer and have
   the others reference it by name.
---
> **Last verified against:** Claude Code `2.1.219` — July 2026
