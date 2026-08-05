# Tracker adapters

**A skill never names a tracker.** It states an intent in the vocabulary below, and exactly
one adapter doc — installed at a fixed path — answers it. One tracker in context, never
four.

Copy the adapter you use to **`~/.claude/tracker.md`** and fill in its `<PLACEHOLDERS>`.
That path is fixed on purpose: it is what lets a skill write *"ask the adapter for the
frontier"* without knowing, or caring, which tracker is underneath.

```
   a skill                the one installed adapter            your tracker
   ───────                ─────────────────────────            ────────────
   "give me the      ──►  ~/.claude/tracker.md            ──►  gh / jira / files
    frontier"             (a copy of ONE file below)
```

## The set

| Adapter | File | solo | team |
|---|---|---|---|
| GitHub | [`github.md`](github.md) | ✓ | ✓ |
| Jira | [`jira.md`](jira.md) | | ✓ |
| Local markdown | [`local-markdown.md`](local-markdown.md) | ✓ | |
| GitLab | [`gitlab-shape.md`](gitlab-shape.md) — **a shape, not an adapter** | ✓ | ✓ |

GitLab ships as a documented *shape*: the verbs are stated, the commands are left to you.
Its API docs are demonstrably wrong about blocking, and nothing in it could be verified
live — shipping commands nobody has run is worse than shipping none. See that file for
what to watch for.

## The vocabulary

Every verb works on **every** adapter. Where a tracker lacks one natively, the adapter
fakes it and the calling skill is never told — so no skill ever branches on which tracker
it is running against.

| | Verbs |
|---|---|
| **Small** | create · read · list · comment · close · reopen · edit body · link child to parent · label · claim · mark blocked · *is this blocked?* |
| **Composed** | *the frontier* — the open, unblocked, unclaimed children of a parent<br>*the whole graph* — every child of a parent with its state, claim, blockers, body and comments |

Twelve small verbs and two composed verbs.

**A composed verb earns its place on one test:** the cheapest way to answer it genuinely
differs per tracker, and every caller wants the same answer. Both pass it. *The frontier*
is one API call on GitHub and a directory scan on local. *The whole graph* is one GraphQL
call on GitHub and one directory read on local — where the obvious client-side assembly is
a request per ticket, and a view too expensive to regenerate stops being regenerated and
quietly becomes a second store.

**An adapter must return the blockers themselves, not a count of them.** GitHub's REST
payload offers only a count, which is enough for *is this blocked?* and useless to anything
drawing the graph — so the two verbs need different endpoints on the same tracker. Whoever
writes an adapter answers *by what?*, never just *how many?*

### One definition — `read` means the ticket *and* its comments

**The answer to a closed ticket is not in its body.** The body holds the question; the
resolution comment holds the decision. A `read` that returns the body alone hands back the
question and silently drops the answer — and every *go and see what that ticket decided*
instruction in this playbook rests on this one verb.

Measured on a real map: reading ticket #12 returned **2,224 characters of question and 0 of
answer**, while its resolution comment held **14,193**.

So `read` is *defined* to include the comments. It is **not** a thirteenth verb: where a
tracker needs two calls to satisfy it, the adapter makes both and the caller never finds
out. Same faking-it rule as everything else here. This never surfaced on local markdown,
where the question and the comments live in one file and the defect is invisible.

### Three rules the vocabulary depends on

**Blocking is a question, not an edge.** The verb is *"can I start this right now?"*, and
the adapter goes and checks. A stored `Blocked by:` line is a claim about the past — it
still says *blocked* after the blocker closes. Demanding the edge accepts a rotten answer;
demanding the answer forces a check.

**The claim is advisory, not a mutex.** No tracker here can give you a lock. GitHub
silently no-ops an assignee write when the caller lacks push access *and still returns
success*; a local claim in one worktree is invisible from another. Claim, then **read the
claim back** — and treat a lost race as a nuisance to resolve out of band, not a
correctness bug.

**Identity is a stable id. Titles are decoration.** Retitling is normal and must never
break a link.

## Writing to a tracker: ask about the audience, not the tracker

`PHILOSOPHY.md` §5 used to say *never write to Jira without approval*. The real rule is
about **who can see it**:

> **Ask before writing anywhere other people can see it.**

Each adapter declares whether its tracker is a shared place. Three cases the old rule
could not tell apart:

| Situation | Shared? | Rule |
|---|---|---|
| Corporate Jira | yes | ask, with the exact payload shown first |
| Private personal repo | no | write freely |
| **Public personal repo** | **yes** | **ask** |

That third row is the one neither *"it's Jira"* nor *"it's GitHub"* could answer, and it is
the common case for a solo builder working in the open.

## Installing one

1. Copy one file above to `~/.claude/tracker.md`.
2. Fill in its placeholders.
3. Point your global `CLAUDE.md` at it, so it loads with every session.

Setup step 5 in [`../../docs/shared/03-setup.md`](../../docs/shared/03-setup.md) walks
through it.
