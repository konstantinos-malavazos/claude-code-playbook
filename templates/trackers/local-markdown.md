# Tracker adapter: local markdown

Install at `~/.claude/tracker.md`. Tickets are markdown files in the repo. No server, no
CLI, no account — and **no UI**, which is the one thing this adapter cannot supply itself.
It is answered outside the adapter, by the caller: the dependency-graph page if that template
is installed, and the whole graph printed as text if it is not. The adapter's job is to make
both cheap, which [the whole graph](#the-whole-graph) does in one directory read.

**Is this a shared place?** Same answer as the repo it lives in. These files are
committed, so a public repo makes them public. `<yes | no>`.

---

## Layout

```
tickets/
└── <effort-slug>/
    ├── map.md                    ← the map body
    └── issues/
        ├── 01-name-the-stages.md
        ├── 02-tracker-primitives.md
        └── …
```

**The folder is `tickets/`, not `.scratch/`.** These files are committed project records —
the decisions an effort made and why. A dot-prefixed scratch folder says *throwaway*, which
is exactly wrong.

### When the effort spans more than one repo

The layout above assumes one repo owns the effort. A map that spans several does not fit it:
no single repo owns the record, and committing it to one of them makes the other two look
like they were not involved. For that case, move the whole tree to the workspace instead:

```
<workspace>/.claude/charts/<KEY>/    ← <KEY> is the tracker id the map serves
    map.md, context.md, tickets/, research/, reviews/<repo>.md
```

**Workspace chart state is not committed**, so it trades the committed-record property for
being able to exist at all. Two rules come with it:

- **Never put it under the handoffs directory.** Those auto-delete at session end and a map
  runs for weeks. This is the single most expensive mistake available here.
- `<KEY>` is a folder name only. The tracker writes nothing back to the hosted tracker the
  key belongs to.

> **On `PHILOSOPHY.md` §5.** §5 sorts AI-infra files by *provenance*, not by path: **would
> a fresh clone need this file?** Ticket files pass it outright — they are records the
> project would want in its history even if every AI tool vanished tomorrow, not plumbing.
> Commit them. (The old wording was a path list, and ticket files were kept off it by hand.
> The test answers the question directly instead.)

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

### Three status fields, not one

`Type:`, `State:` and `Claim:` are independent.

| Field | Values | Means |
|---|---|---|
| `Type:` | see the charting skill's type table — that table is the source of truth, not this file | the session shape, and for `make:<layer>` also the dispatch |
| `State:` | `open` · `resolved` | whether the question is answered |
| `Claim:` | a name, or `—` | who is working it right now — **this session, a person outside it, or a background agent.** Not only you |

`Blocked by:` is a fourth line and is **not** a status — it is a claim about the past. See
*is this blocked?*.

**An em dash is how both lines say *nothing*.** `Claim: —` is unclaimed and `Blocked by: —`
is unblocked. Neither line is ever left blank and neither is ever omitted. Every field is
present on every ticket, so a scan reads the same four lines whatever state the ticket is
in. Say the dash, never *"empty"*. A scan written against an empty string matches nothing
and returns an empty frontier, which is indistinguishable from a stalled map.

Older versions of this adapter overloaded one `Status:` line between `/triage`'s role
strings and charting's `claimed`/`resolved`, which made a ticket unable to be both
`ready-for-agent` **and** claimed. It has to be both. Keep them separate.

### Identity is the number

`07` is the ticket. The `-tracker-primitives` slug is decoration — **blocking edges resolve
on the number, so renaming never breaks one.** Never renumber a file: numbers are handed out
once and never reused, even after a ticket is deleted.

The next free number is one past the highest that has **ever** existed, which equals one past
the highest on disk only when nothing has been deleted. When in doubt read `map.md`. A
deleted ticket leaves its number behind in the Decisions or Out-of-scope prose.

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
| claim | set `Claim:` to the holder's name — yours, a person's, an agent's — save, then **read it back**. A claim that silently failed to write looks exactly like one that worked |
| mark blocked | add the number to `Blocked by:` |
| is this blocked? | **read each listed file and check its `State:`** — never trust the line alone |
| retitle | edit the `# NN — <title>` heading. Optionally rename the slug. **Never touch the number.** Blocking edges resolve on the number and survive. **But `map.md`'s links are file paths carrying the slug, so renaming it kills them.** Regenerate `Decisions so far` (it rebuilds links from disk) and fix any hand-authored link under *Out of scope* |
| delete a ticket | `rm` the file. Leave one line in `map.md` — under *Out of scope*, or in the invalidating decision's gist — saying the number existed and why it is gone. The number is burned |

**`is this blocked?` is the whole reason blocking is a question.** `Blocked by: 03` is a
claim about the past. It still reads *blocked* long after `03` resolved. The answer requires
going and looking.

**On `delete a ticket` — this verb does not generalise, and that is the point of having
it.** Here it is literally `rm`. On Jira there is no delete at all. The nearest thing is a
close. The same charting sentence — *"delete or rewrite tickets the decision invalidated"* —
means two different operations depending on the adapter. That is exactly what a verb
contract exists to absorb.

## The frontier

Scan `issues/` for files with `State: open`, `Claim: —`, and every number in `Blocked by:`
now `resolved`. First by number wins.

**Frontier empty does not mean done.** It can go empty while tickets remain open and waiting
on someone outside this workspace. That is a distinct outcome — the charting skill names it
*stalled* — and it is not a finished map.

**A handed-off ticket carries its holder's name in `Claim:` and is off the frontier by
construction. That is the only way the frontier can empty.** A ticket waiting on a person or
a background agent has no `Blocked by:` edge to hide behind. Left unclaimed, it stays
takeable. Every later session picks it up again, and the frontier never empties. That
makes *stalled* unreachable and the map unfinishable.

## The whole graph

Read every file in `issues/` — **or just the ones named**, when the graph is a named set of
tickets rather than the children of a parent. Either way it is one directory read, and you
already have the states, the claims, the `Blocked by:` lines, the questions **and** the
comments, because this adapter keeps them all in one file per ticket.

**The named set is the cheapest scoping here, not a harder one.** A parentless graph — a
backlog of work units — names its tickets, and naming them only narrows the files you open.

**Return each blocker with its `State:`, not just its number — and on a named set that
means opening files outside the set.** `Blocked by: 03, 04` is the claim about the past
this adapter already warns you about, and handing it over unanswered pushes the same rotten
claim to the caller. So the whole graph resolves it the way *is this blocked?* does: read
each listed file and take its `State:`. Under the parent scoping those files are already
open — every blocker of a child is another child. Under a named set a blocker can be a
ticket nobody named, and it is the one that gets left `open` by default, which draws a
takeable ticket as blocked. **Open the named files, then any file they name as a blocker.**
Still one directory. The blockers you pull in this way are read for their `State:` line
alone — they are not members of the graph and get no box.

**That is why the missing-comments defect never surfaced here.** On a hosted tracker the
body and the comments are separate fetches, and a `read` that made only the first one
looked like it worked. Cheapest adapter for this verb, and the one that hid the bug in it.

## Single-session by declaration

This adapter is for **one session at a time.** A claim written in one worktree is invisible
from another — there is no shared surface to publish it on — so the advisory claim is not
merely weak here. It is unobservable. If you want parallel sessions, use a hosted tracker.
