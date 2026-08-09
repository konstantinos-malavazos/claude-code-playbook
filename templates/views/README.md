# View templates

A **view** is a file the playbook ships, a skill fills with data, and a human opens. It is
not installed into the harness, it is not loaded into a context, and no agent ever reads
one back.

```
   the adapter          this page           the skill
   ───────────          ─────────           ─────────
   fetches the     ──►  draws it       ◄──  only moves the data
   whole graph          (ships empty)       from one to the other
```

## The set

| View | Install to | Generated into |
|---|---|---|
| [`dependency-graph.html`](dependency-graph.html) | `~/.claude/dependency-graph.html` | `.claude/dependency-graph.html`, in the repo being worked on |

**One repo is the default, not the only case.** An effort with no single owning repo — a map
spanning several, as in [03-massive-tickets.md](../../docs/team/03-massive-tickets.md) —
has no repo to write into and no `.gitignore` to edit. There the page lands beside the chart
wherever the [tracker adapter](../trackers/README.md) puts it, and the two `.gitignore` rules
below simply do not apply. Absent that, use the row above.

## Why this directory is called `views`

Every other directory here is named for **what the harness turns the file into** —
`agents/`, `hooks/`, `skills/`, `commands/`. Nothing turns a view into anything. It is
named for what it *is* to the reader, because that is the only role it has.

It is deliberately **not** in `skills/`. A skill is a recipe Claude loads; this is a
~550-line artifact a skill copies without reading. Filing it under `skills/` would put it
in the loading path of a context that has no use for it.

## The dependency graph

The tracker draws your dependencies for you — unless it does not. Native blocking is
GitHub-only, so on GitLab, Jira or local markdown a map is a list of issues with no shape,
and *what is takeable now* is a question you answer by hand. That is a property of the
**tracker**, not of the artifact, so one page serves both things that have a shape: a
charting **map** and a cut **backlog**.

**A shipped page with a data slot** — not freehand HTML written fresh each run. A view too
expensive to regenerate stops being regenerated and quietly becomes a second store. And not
a script, because a script has to *fetch*, and fetching is the one thing that differs per
tracker.

### What it draws

| State | Drawn as | Meaning |
|---|---|---|
| **Frontier** | thick solid green | open, unblocked, unclaimed — **the one the picture exists to surface** |
| **Claimed** | dotted amber | open and takeable, but someone is on it |
| **Blocked** | dashed red | open, but something before it is not done |
| **Closed** | thin grey, and smaller | done |

Four **outlines**, not four colours — thick / dotted / dashed / thin-and-small keeps the
states apart in greyscale and for a colourblind reader.

**Closed tickets stay on the picture.** A graph with the finished work deleted shows *that*
a ticket is takeable but not *why*, and the arrows that explain it point at nothing.

**Arrows run blocker → blocked**, so following one reads *"this first, then that."*
Columns are ranks: everything in the first column has nothing before it.

**A sidebar carries what has no box** — the ticket legend (number and name, so the boxes
stay small), then the map's non-graph parts, *Not yet specified* and *Out of scope*. A
backlog has no fog, so it gets the legend only. This is what makes a map's picture complete
rather than partial.

**Clicking a box opens the body and every comment**, embedded. On a closed ticket the body
is the *question* and the answer is in a comment — measured on one real ticket, 2,224
characters of question against 14,193 of answer — so a page that showed the body alone
would hand back the half you already had. Every comment, never a heuristic guess at which
one is the resolution.

### Where it lands, and when

**`.claude/` in the repo being worked on, at a fixed filename.** `block-infra-staging.sh`
refusing to stage it is the enforcement, not an obstacle — a generated view must never be
committed. **The reader is what settles that**: this page is for **you**, it needs a browser,
and an agent gains nothing from parsing HTML. Nothing downstream reads it, so a committed
copy would be stale weight in the history rather than a record anyone wanted.

**Whatever generates it also ensures `.claude/` is in the repo's `.gitignore` — with
`!.claude/agents/` and `!.claude/skills/` beside it.** The hook stops the file entering git;
nothing stops it showing as untracked noise, and **nothing else adds that line during
charting** — `/adapt-to-stack` patches the exceptions onto an existing line, but that runs at
the bootstrap. On the solo path this page cannot wait for it: the page runs during charting, a
full stage earlier, when the repo exists but has not been scaffolded. On a mature repo the
line is usually already there — *usually* is not *always*, so check rather than assume.

**The exceptions are not optional, and forgetting them is silent.** `block-infra-staging.sh`
lets `.claude/agents/` and `.claude/skills/` through because a fresh clone needs them; a
blanket ignore line hides those files from `git add` anyway. **Two mechanisms, one
directory** — the hook blocks the *command*, `.gitignore` makes the file invisible to it —
and moving one without the other buys nothing. See
[`docs/solo/07-guardrails-when-solo.md`](../../docs/solo/07-guardrails-when-solo.md).

**One command regenerates *and* opens.** There is no separate view step, so staleness stops
being something to manage — looking at it *is* regenerating it. Deliberately **not**
regenerated on ticket-close: auto-regeneration gives you a file that is *sometimes* fresh,
which you end up trusting neither way. One rule you can hold: **it is current if you just
ran it.** The visible *generated at* stamp closes the gap for a browser-refreshed copy.

## Filling the slot

The recipe lives in the comment at the top of `dependency-graph.html`, so it travels with
the installed copy — `templates/` is not installed anywhere. Two rules the generator must
follow, both of which fail silently:

- **Escape `</` as `<\/` in the JSON.** A ticket body containing the literal text
  `</script>` otherwise closes the slot early and blanks the page. The two are identical
  inside a JSON string, so the escape is always safe.
- **Emit every comment.** See above.

**Each blocker carries its own state — `{"number": 36, "state": "open"}`, not `36`.** The
page cannot look it up. It used to try, and on a **map** that worked by accident: every
blocker of a child is another child, so the blocker was always in the picture. A **backlog**
is a named set of tickets, its blockers can sit outside it, the lookup missed, and a
ticket whose last blocker had closed was drawn **blocked** — a red box on the very ticket
the picture exists to surface as takeable. So the edge now carries the answer, which is
what the [tracker contract](../trackers/README.md) demands of *is this blocked?* anyway. A
bare number stops the page with a message; it does not draw a wrong picture.

## What this directory claims

`templates/README.md` says every file there is a claim about the **harness**. This one is
not. It claims a **browser** will open a ~480 KB self-contained page and that four box
states stay apart at 35 boxes — which is checkable in the only way that counts: open it.
The harness re-verification checklist does not apply here; nothing in this file has
frontmatter, a matcher, or a tool name.

Verified live on a 35-ticket map: page 480 KB, 48 embedded comments, one `gh api graphql`
call to fetch and shape, no console errors, all four states legible.
