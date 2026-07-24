# 06 — The CLAUDE.md layers

`CLAUDE.md` is the always-on instruction file Claude Code loads automatically. Its power
is that it comes in **layers** that stack via a parent-directory walk: when you work in
`workspace/repo-a/`, Claude loads *every* `CLAUDE.md` from your home directory down to
that folder. Each layer answers a different question.

> This playbook gives you the **idea and structure** of each layer as templates in
> [`../templates/claude-md/`](../templates/claude-md/) — not one team's content. Fill in
> your own facts.

---

## The three layers

```
~/.claude/CLAUDE.md            ← GLOBAL   : how YOU work, on every project
        │  (loaded everywhere)
        ▼
<workspace>/CLAUDE.md          ← WORKSPACE: the multi-repo atlas — the map of this
        │  (loaded for any repo    workspace: which repos exist, which branch ships,
        │   under the workspace)    the cross-repo change pattern
        ▼
<workspace>/<repo>/CLAUDE.md   ← REPO     : facts true only inside this one repository
           (loaded only in that repo)
```

They **compose**. The global file never repeats a workspace fact; the workspace file
never repeats a repo fact. Each fact lives in exactly one layer — the most specific one
that's still always true.

---

## Layer 1 — Global (`~/.claude/CLAUDE.md`)

**Question it answers:** *How do I work, regardless of project?*

This is your personal operating manual. It's the same whether you're in a work monorepo
or a weekend side project. Put here the things that are about **you and your process**,
not about any particular codebase:

- **Tooling policy** — which MCP servers are always-on, and how to opt out per-turn.
- **First-action rules** — e.g. "before touching code, recall prior context from memory;
  navigate by symbol before reading whole files."
- **Ticket / branch / commit conventions** — the format you always use.
- **Ticket-tracker policy** — e.g. "Jira is read-only unless I explicitly approve a
  write."
- **Handoff protocol** — where in-flight agent state lives and that it's ephemeral.
- **Communication style** — terse vs verbose, when to expand.
- **Coding-behaviour defaults** — think-before-coding, simplicity, surgical changes.

Template: [`../templates/claude-md/global.CLAUDE.md`](../templates/claude-md/global.CLAUDE.md)

---

## Layer 2 — Workspace / multi-repo atlas (`<workspace>/CLAUDE.md`)

**Question it answers:** *What lives in this workspace, and how do changes move through
it?*

If your work spans several repositories checked out side-by-side (a very common shape),
this is the **map**. It's auto-loaded for *any* repo under the workspace via the
parent-directory walk, so it's the natural home for cross-repo facts:

- **Repo map** — a table: path · stack · purpose · which specialist agent owns it.
- **Main-branch-per-repo table** — the branch that ships to production for each repo
  (you rebase onto this before cutting a feature branch). Repos differ; write them down.
- **The new-branch workflow** — the exact fetch/checkout/rebase/branch sequence, so every
  agent cuts branches the same way.
- **The sequential implementation chain** — the canonical order a multi-repo change
  follows (your `schema → service → consumer` equivalent).
- **Cross-repo rules** — when cross-repo edits are allowed, how to widen scope.

Even if you have a **single** repo today, this layer is still useful as the "workspace
policy" file; it just has a one-row repo map.

Template: [`../templates/claude-md/workspace.CLAUDE.md`](../templates/claude-md/workspace.CLAUDE.md)

---

## Layer 3 — Per-repo (`<workspace>/<repo>/CLAUDE.md`)

**Question it answers:** *What's true inside THIS repository specifically?*

Loaded only when you're working inside that repo. Home for facts that would be noise
anywhere else:

- The repo's stack, entry points, and build/test commands.
- Local conventions that differ from the workspace default.
- Repo-specific gotchas ("this service consumes topic X; don't change the payload
  without updating consumer Y").
- Where the important code lives (a pointer, not a paste — let Serena find the details).

Keep it **lean**. A per-repo CLAUDE.md that restates the whole architecture is a
maintenance liability; it should be the 20 facts that save the agent a wrong turn.

Template: [`../templates/claude-md/repo.CLAUDE.md`](../templates/claude-md/repo.CLAUDE.md)

---

## Rules that keep the layers healthy

1. **One fact, one layer.** Never paste the same table into two files. If a repo's
   CLAUDE.md and the workspace CLAUDE.md disagree, you have a bug.
2. **Most-specific-that's-always-true.** A fact goes in the lowest layer where it's
   *always* true. "We rebase, never merge" is global. "This repo ships from `develop`"
   is workspace. "This service's consumer is repo Y" is per-repo.
3. **Point, don't paste.** CLAUDE.md is not documentation of the codebase — that's what
   Serena + Forgetful are for. It's the small set of always-true policies and pointers.
4. **Never commit personal AI-infra CLAUDE.md into a shared product repo** unless the
   team has agreed it's shared guidance. Your personal global file certainly doesn't
   belong there. (A guardrail hook enforces this — see
   [`../templates/hooks/block-infra-staging.sh`](../templates/hooks/block-infra-staging.sh).)
5. **Canonical mappings live once.** If you have a lookup table everything depends on
   (environments, service codes, an id↔name map), put it in exactly one layer and have
   the others reference it by name.
-e 
---
> **Last verified against:** Claude Code `2.1.219` — July 2026
