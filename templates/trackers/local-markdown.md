# Tracker adapter: local markdown

Install at `~/.claude/tracker.md`. Tickets are markdown files in the repo. No server, no
CLI, no account — and no UI, which is the one thing this adapter has to compensate for.

**Is this a shared place?** Same answer as the repo it lives in — these files are
committed, so a public repo makes them public. `<yes | no>`.

---

## Layout

```
tickets/
└── <effort-slug>/
    ├── map.md                    ← the map body
    ├── PROGRESS.md               ← generated; see below
    └── issues/
        ├── 01-name-the-stages.md
        ├── 02-tracker-primitives.md
        └── …
```

**The folder is `tickets/`, not `.scratch/`.** These files are committed project records —
the decisions an effort made and why. A dot-prefixed scratch folder says *throwaway*, which
is exactly wrong.

> **On `PHILOSOPHY.md` §5.** §5 sorts AI-infra files by *provenance*, not by path: **would
> a fresh clone need this file?** Ticket files pass it outright — they are records the
> project would want in its history even if every AI tool vanished tomorrow, not plumbing.
> Commit them. (The old wording was a path list, and ticket files were kept off it by hand;
> the test answers the question directly instead.)

## Ticket file

```markdown
# 07 — Tracker primitives across the three trackers

Type: research
State: open
Claim: —
Blocked by: 03, 04

## Question

<the decision or investigation this ticket resolves>

## Comments

<appended, newest last>
```

### Two status fields, not one

`Type:` and `State:` are independent, and `Claim:` is a third thing again.

| Field | Values | Means |
|---|---|---|
| `Type:` | `research` · `prototype` · `grilling` · `task` | the session shape |
| `State:` | `open` · `resolved` | whether the question is answered |
| `Claim:` | a name, or `—` | who is working it right now |

Older versions of this adapter overloaded one `Status:` line between `/triage`'s role
strings and charting's `claimed`/`resolved`, which made a ticket unable to be both
`ready-for-agent` **and** claimed. It has to be both. Keep them separate.

### Identity is the number

`07` is the ticket. The `-tracker-primitives` slug is decoration — **rename it freely; links
resolve on the number.** Never renumber a file: numbers are handed out once and never
reused, even after a ticket is deleted.

---

## The verbs

| Verb | How |
|---|---|
| create | new file at the next free number in `issues/` |
| read | read the file — **question and comments together**, which is what `read` means everywhere; see [`README.md`](README.md) |
| list | read `issues/` |
| comment | append under `## Comments` |
| close | `State: resolved` |
| reopen | `State: open` |
| edit body | edit the `## Question` section |
| link child to parent | the file's presence in `<effort-slug>/issues/` **is** the link |
| label | the `Type:` line |
| claim | set `Claim:` to your name, save before any work |
| mark blocked | add the number to `Blocked by:` |
| is this blocked? | **read each listed file and check its `State:`** — never trust the line alone |

**That last row is the whole reason blocking is a question.** `Blocked by: 03` is a claim
about the past; it still reads *blocked* long after `03` resolved. The answer requires
going and looking.

## The frontier

Scan `issues/` for files with `State: open`, an empty `Claim:`, and every number in
`Blocked by:` now `resolved`. First by number wins.

## The whole graph

Read every file in `issues/`. One directory read, and you already have the states, the
claims, the `Blocked by:` lines, the questions **and** the comments, because this adapter
keeps them all in one file per ticket.

**That is why the missing-comments defect never surfaced here.** On a hosted tracker the
body and the comments are separate fetches, and a `read` that made only the first one
looked like it worked. Cheapest adapter for this verb, and the one that hid the bug in it.

## Single-session by declaration

This adapter is for **one session at a time.** A claim written in one worktree is invisible
from another — there is no shared surface to publish it on — so the advisory claim is not
merely weak here, it is unobservable. If you want parallel sessions, use a hosted tracker.

## The generated progress file

Every hosted tracker gives you an at-a-glance view for free. Local markdown gives you a
directory listing. `PROGRESS.md` closes that gap: destination, counts, the frontier, what
is blocked, and the gotchas found so far.

**Generate it; never hand-maintain it.** It goes stale between sessions by design, so it
opens with its own warning:

```markdown
> **Snapshot taken:** <date>, after resolving <ticket>.
> Regenerate rather than trust — the frontier query is in the adapter.
```

**Carry both the number and the name of every ticket, always.** The number is what you type;
the name is what makes it legible six weeks later. Never one without the other — a page of
bare `07, 11, 22` is unreadable by the next session, which is usually you.
