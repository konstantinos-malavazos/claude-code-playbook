# 02 — Adopting this playbook as a team

Both [entrances](../../README.md#two-entrances--pick-yours) describe a **one-person
install** — clone the templates, fill in your placeholders, go. This doc fills the gap:
what changes when a second engineer adopts it, who owns the templates, how conventions
stay in sync, and what breaks when they don't.

> **"Solo" means something specific elsewhere in this repo** — the
> [solo path](../solo/01-the-solo-path.md), the front-end that turns a raw idea into a
> backlog. That is not what this doc is contrasting against. The thing that scales badly
> to a second person is the *install*, and it does so identically whichever entrance you
> came through.

---

## Onboarding a second engineer

The one-person install is "clone the templates, fill in your placeholders, and go."
For a second person, the same templates need to produce the **same workflow**
without assuming they share your editor, your shell config, or your patience.

**Minimum viable onboarding:**

1. **The shared, version-controlled CLAUDE.md is the source of truth** for
   everything that touches shared repos: the implementation chain, and — on
   sibling repos — which repos exist and which branch each ships from. On
   several repos that file is the **workspace** atlas; on one it is the repo's
   own, and there is no workspace layer at all (see
   [06](../shared/06-claude-md-layers.md)). Either way it is the first thing a
   new engineer reads. The *branch workflow* is not in it — that is behaviour,
   so it sits in each person's global CLAUDE.md, which is item 2's point.
2. **Personal global CLAUDE.md is theirs** — they write their own. Don't share
   the personal file; the whole point of the global layer is that it captures
   *your* process. Templates become a conversation starter, not a mandate.
3. **MCP servers are per-person** — each engineer stands up their own Serena
   and Forgetful. A shared memory server is possible (see
   [05-forgetful.md](../shared/05-forgetful.md) for the governance caveats) but start
   independent.
4. **The hook set is standardised.** Hooks are deterministic guardrails — they
   must fire the same way for everyone. Put the hook scripts in a shared
   repository and document the install path. If hooks diverge, the team loses
   the guarantee that "push is blocked" means push is blocked for everyone.

---

## Who owns the templates

Templates are the shared vocabulary of the pipeline — agents, skills, commands,
hooks, CLAUDE.md layers. They need an owner, because:

- **Nobody owns it = nobody updates it.** The implementation chain drifts as
  the stack evolves; the templates still reference a layer that was renamed
  six months ago.
- **Everyone owns it = nobody agrees.** Everyone has opinions on how a
  reviewer agent should behave. Without a decision-maker, the template stalls
  or forks.

**Recommendation:** one person is the maintainer (the person most invested in
the setup, probably who sets it up first). They review and merge changes to
the shared template repo. Other team members propose changes, fork locally, or
override in their personal `~/.claude/` — but the canonical templates are
decided by one person, openly.

---

## Keeping conventions in sync

### Version-control the templates

The templates should live in their own repository (or a dedicated location
that every team member can clone). This repo:

- Is **not** a product repo — it's the team's shared AI-infra configuration.
- Uses its own PR process for changes (see below).
- Tags releases or uses a changelog so team members can see what changed
  between pulls.

### How sync breaks

| Situation | What breaks |
|---|---|
| Two engineers run different `/start-ticket` agent definitions | Different prompts → different output quality. One gets reviewed branches; the other gets un-reviewable mess. Hard to debug because the pipeline "works" for both. |
| One engineer updates a hook, another doesn't | The hook guarantee is lost. Engineer A can't push; Engineer B can. The safety invariant becomes a "works on my machine." |
| The implementation chain gets an extra layer | Engineer A's planner allocates tracks for 4 layers; Engineer B's planner still uses 3. Cross-layer work from B skips a layer and produces broken handoffs. |
| One person customises a skill and the template diverges | The customised version works better, but nobody knows about it → knowledge silo. The team loses the compounding benefit. |

### Mitigations

- **PR to templates is the only way to add a new agent or flow.** No local
  customisations without a corresponding template change (or a documented
  override with a reason).
- **`git pull` in the template repo is a recurring reminder.** Add it to the
  team's regular sync, or the onboarding checklist for new sprints.
- **Pin template versions in the workspace CLAUDE.md.** A short table:
  `| template-agent-name | version | last synced |`. When versions diverge,
  it's visible.

---

## Review process for a new agent or flow

Templates shape how every engineer interacts with the codebase. A new agent
is a new capability with its own tool scope and prompt — it should be reviewed
like any other meaningful change.

**Checklist for a new agent template (`templates/agents/<name>.md`):**

- [ ] Does one existing agent overlap with this one? If yes, can they be
      merged or should the existing one be deprecated?
- [ ] Is the tool scope tight enough? (No agent should have every tool by
      default — an analyzer that can write code is a footgun.)
- [ ] Is the prompt specific enough to produce consistent output, but generic
      enough to survive project changes?
- [ ] Does the agent produce a handoff file? What's its schema and where does
      it go?
- [ ] Does the new agent need a corresponding skill or hook change?
- [ ] Is there an integration test — a minimal run against a scratch repo —
      that proves the agent does what it claims? (A one-off manual test counts.)

**Checklist for a new command/flow:**

- [ ] Does it duplicate or partially overlap an existing flow?
- [ ] Which agents does it orchestrate, and in what order?
- [ ] What is the entry condition (requires a ticket id? a branch? a clean
      working tree?) — and what happens if the precondition isn't met?
- [ ] What guardrails does the new flow inherit, bypass, or add? Bypassing an
      existing guardrail needs explicit justification.
- [ ] Can it be tested in isolation before the team adopts it?

---

## Two people, two versions

When two engineers run different template versions, the most likely breakage
is in **handoff compatibility**. If A's `context-gatherer` writes a different
handoff schema than B's `planner` expects, the pipeline silently degrades —
B's planner gets an incomplete brief.

**Solution:** version-stamp the handoff files. Each handoff includes a
`template-version: X.Y` field at the top. A consumer agent checks the version
before reading and warns on mismatch. This turns a silent semantics break
into a visible warning that the team can fix.

---

## Shared memory governance

If the team graduates to a shared Forgetful instance (see
[05-forgetful.md](../shared/05-forgetful.md)), three rules prevent chaos:

1. **No secrets, no PII** — enforced by a hook on the write path, not by
   policy alone.
2. **Write access is gated** — only the template maintainer (or a small
   trusted set) can write to shared memory. Everyone reads; write nominations
   go through the maintainer.
3. **Golden queries are shared and version-controlled** — the
   `/garden-memory` eval uses the same queries for everyone, so retrieval
   quality is a team metric, not an individual one.

---

## Summary

| Concern | Approach |
|---|---|
| Onboarding | Workspace CLAUDE.md first; personal global is theirs; MCP per-person; hooks standardised |
| Template ownership | One maintainer, open PRs, everyone can propose |
| Sync | Version-controlled template repo, PR-only changes, pinned versions in workspace CLAUDE.md |
| New agent review | Tool scope, handoff schema, overlap check, integration test |
| Version mismatch | Version-stamped handoff files, consumer warns on mismatch |
| Shared memory | No-PII hook, gated writes, shared golden queries |
