# Progress — the solo builder's path

Local tracking file for the wayfinder effort on
[#1 MAP: the solo builder's path](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/1).
**Committed and pushed**, so the effort can be resumed from any machine. The tracker is
still the source of truth; this is a reading convenience that goes stale between sessions.

> **Snapshot taken:** 1 August 2026, after resolving
> [#5 The contract of the playbook's own map-charting skill](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/5).
> Regenerate rather than trust — the one-call frontier query is:
> ```
> gh api repos/ZhiKaanZhi/claude-code-playbook/issues/1/sub_issues --paginate \
>   --jq '.[] | select(.state=="open") | select(.assignees|length==0)
>             | select(.issue_dependencies_summary.blocked_by==0) | "#\(.number)\t\(.title)"'
> ```
>
> **Tickets carry both number and name throughout.** The number is what you type at
> `/wayfinder`; the name is what makes it legible six weeks later. Never one without the other.

---

## Destination

A **second entrance** to this repo: a documented path taking a solo builder from a raw idea
to *a backlog of work units on a scaffolded, Serena-indexed repo*, where it hands off to the
existing implementation pipeline. Delivered as docs + templates in the house style.

Done when a reader with an idea and no repo can follow the path end to end.

---

## Status at a glance

| | Count |
|---|---|
| Tickets closed | 8 |
| Tickets open | 14 |
| On the frontier (takeable now) | 13 |
| Blocked | 1 — only the capstone |
| Repo files changed since the effort began | 29 + this file |
| Branches | none — findings live in ticket comments, not in the repo |
| Working tree | clean |

**Every gate is now open.** #5 was the last ticket blocking anything other than the capstone.
Closing it released **#11**, **#21** and **#22** at once. Nothing on the map now waits on
anything except [#16 Two-entrance front door](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/16),
which waits on everything.

The map has stopped being a dependency graph and become a **work queue**. That is a change of
mode, not just of count — session choice is now about attention and appetite, not about what
is unlocked.

---

## The path #3 settled

```
   THE KILL GATE  ──►  CHARTING  ──►  THE BOOTSTRAP  ──►  THE BACKLOG  ──►  /start-ticket
   is this worth      what are we      make the repo      cut it into        (the existing
   building?          building, and    real               pipeline-sized     pipeline takes
        │             on what?              ▲             tickets                over here)
        │                  │                │                  │
   verdict:          ends CLEARED      scaffolds,         ordered +          ▲
   build/kill/park   or ABANDONED      never creates      you approve        │
        │                  │                                                │
   on "build" the     the TAIL, last:                                   THE SEAM
   agent creates a    1. name the stack                              (7 checks below)
   PRIVATE repo,      2. write the bootstrap checks
   map = issue #1     not takeable while anything else is open

            ◄──── one backwards step allowed ────
```

**The seam — all seven must hold:**

1. The stack is named and written down.
2. The stub builds and runs. *(A green test command is optional — the stack ticket decides.)*
3. The layer chain is declared in `CLAUDE.md`.
4. Serena is indexed — a symbol search returns real results.
5. The tracker adapter is installed.
6. The backlog exists, ordered, and you approved it.
7. Two memories exist: what the project is and why; the stack and layer chain and why.

Written down in full in
[`docs/solo/01-the-solo-path.md`](docs/solo/01-the-solo-path.md) — the only place both
entrances are visible at once.

---

## Decisions locked

| Ticket | Decision |
|---|---|
| [#6 What Claude Code already does natively](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/6) | Lean on the harness for `/init`, plan mode, the task list, background sessions, worktrees, `/goal`. The playbook must supply its own durable map artifact, its own backlog, and every judgement stage of the front-end. `/effort ultracode` is the *worst* default for a solo builder. |
| [#2 Where the solo path lives](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/2) | `docs/` splits three ways (below). Templates stay flat with a path column in their READMEs. Moved docs keep their `2.1.219` footer. |
| [#19 Reorg docs into shared/ team/ solo/](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/19) | **Done — the layout below now exists.** 14 docs moved as git renames, 54 relative links resolve and 0 dead. |
| [#7 Tracker primitives](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/7) | **The floor is narrower than charting assumed.** Native blocking is not universal; the claim **cannot be a mutex**; nothing has optimistic concurrency, so the map body should be regenerable. Handed four judgement calls to #4. |
| [#3 The stages and the seam](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/3) | **Four stages: kill gate → charting → bootstrap → backlog.** The repo is the gate's output, so bootstrap *scaffolds* and never *creates*. Bootstrap runs **before** the backlog. Stack choice is a **ticket on the map**, in a two-ticket tail not takeable while anything else is open. Charting can end in **abandon**. One backwards step allowed. Seam = the seven checks above. |
| [#4 The tracker-adapter contract](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/4) | **A skill never names a tracker.** Ten decisions — see the table below. |
| [#20 Write the solo path overview doc](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/20) | **Done — `docs/solo/01-the-solo-path.md` is on master.** An index, not a summary. **Sets the `docs/solo/` numbering** (below). |
| [#5 The charting skill's contract](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/5) | **The skill is `charting`, and it is general.** Eight decisions — see the section below. |

### The layout #2 decided — now live

```
docs/
├── shared/          ← the trunk BOTH entrances converge on   (01–12)
├── team/            ← the agile front-end                    (01 metrics, 02 adoption)
└── solo/            ← the solo front-end (01 written, 02–05 reserved)
```

Numbering restarts at `01` per directory.

### The `docs/solo/` numbering #20 set

| Number | Doc | Owner |
|---|---|---|
| `01-the-solo-path.md` | the overview — **written** | #20 |
| `02-the-kill-gate.md` | the kill gate | #9 |
| `03-charting.md` | charting | #22 |
| `04-the-bootstrap.md` | the bootstrap | #10 |
| `05-the-backlog.md` | the backlog | #12 |
| `06+` | everything else solo — guardrails, progress, resuming, stack→agents | in the order they are written |

The stage block is reserved in **stage order**, so a stage doc never collides with a
non-stage one.

### The tracker contract, in ten lines

| | Decided |
|---|---|
| Adapters shipping | Jira, GitHub, local markdown. **GitLab is a *shape*, not an adapter.** |
| The floor | **Every verb works on every adapter.** Where a tracker lacks it natively, the adapter fakes it and the skill is never told. |
| Vocabulary | Small verbs **plus exactly one composed verb, the frontier**. |
| Blocking | The predicate *"can I start this right now?"* — **not** a native edge. |
| Claim | **Advisory, not a mutex.** Local declares itself single-session. |
| Map body | **A generated view, not a store.** Rebuild from the closed children. |
| Local ticket files | **Committed** — and the folder is renamed away from `.scratch/`. |
| Read-only rule | Restated as **"ask before writing anywhere other people can see it"** — audience, not tracker. |
| Adapter location | `templates/trackers/`, flat. **Exactly one installed at a fixed path.** |
| Identity | **A stable id; titles are decoration.** Retitling must never break a link. |

---

## The charting contract #5 settled

The skill is called **`charting`** — `/charting`, a sibling of `/grilling`. Not `wayfinder`
(collides with the driver's global skill). It matches the word already on master in
`01-the-solo-path.md`, and preserves the rule that **the stage is charting, the artifact is
the map, and they never share a name.**

| # | Decision | The reason that settled it |
|---|---|---|
| 1 | **General, not solo-specific.** The destination is an **input**. | This map is a *docs* effort. A skill with `backlog + scaffolded + indexed` baked in could not have run the playbook's own map. The solo path supplies the destination from outside, in `03-charting.md`. |
| 2 | **Named `charting`.** | Matches master; rhymes with `/grilling`; keeps stage and artifact distinct. |
| 3 | **Decide-or-make — one or the other, never both.** | This map's own escape valve fired twice (#3→#20, #20→#22). Deciding ends when humans agree; making ends when the file lands. Mixed, the unpredictable half eats the context. |
| 4 | **Points at skills, never absorbs them.** No `/domain-modeling` reference. | Context-window-first. And `CONTEXT.md`/ADR storage would be a **third** home for durable knowledge alongside memory and the layer chain. A two-line vocabulary rule covers charting instead. |
| 5 | **Memory: one per map, not one per ticket.** | `PHILOSOPHY.md` §3 is right about the shape, wrong about the unit. In charting the unit of work is the *whole map*. This makes seam item 7's *exactly two* arithmetic work with no special-casing. |
| 6 | **Serena, with the greenfield exception adjacent.** | An empty index on a day-one repo is **correct**, not broken. Without the exception, an agent burns a third of its context globbing an empty tree to prove Serena is down. |
| 7 | **Only Decisions-so-far is generated.** | The map's four sections behave differently; only one is derivable. Authored sections are protected by *re-read immediately before writing*, not by a lock no tracker can honour. |
| 8 | **Mid-ticket death: post a progress comment, keep the claim.** | Charting is the only thing that knows the session is ending, and handoff files auto-delete. Everything after the map closes belongs to #8. |

**The most load-bearing line in the whole contract:**

> **Every resolution comment opens with a one-line gist.**

Without it, #4's *"rebuild Decisions-so-far from the closed children"* means re-reading twenty
long comments and re-summarising each — expensive *and* non-deterministic. With it,
regeneration is a concatenation of first lines: free, and identical every run.

**Four ticket types, two of which name a skill.** A type is a *session shape*, not a pointer
to a skill: `research` → `/research`, `grilling` → `/grilling`, `prototype` → nothing yet
(#23), `task` → needs none by design.

---

## The frontier — takeable right now

Thirteen tickets. Nothing gates anything but the capstone.

| Ticket | Type | Note |
|---|---|---|
| [#11 Write the charting skill template](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/11) | make | **Take this next.** The contract is one session old. |
| [#13 Tracker adapter templates + the Jira retrofit](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/13) | make | Fully settled — execution, not judgement. |
| [#9 The kill gate](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/9) | grilling | writes `docs/solo/02` |
| [#10 The bootstrap](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/10) | grilling | writes `docs/solo/04` |
| [#12 Cleared map to backlog of work units](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/12) | grilling | writes `docs/solo/05` |
| [#14 Which guardrails hold when you are solo](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/14) | grilling | — |
| [#15 Tech stack into working agents and skills](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/15) | grilling | starts from a stack already chosen |
| [#18 How progress is measured on the solo path](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/18) | grilling | — |
| [#8 Resuming an effort across dozens of sessions](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/8) | grilling | **must check #5's §8 boundary first** |
| [#21 How the tech stack actually gets chosen](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/21) | grilling | freed by #5 |
| [#22 Write the charting stage doc](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/22) | make | freed by #5 |
| [#23 Write the prototype skill template](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/23) | make | **new** — side quest, blocks nothing |
| [#24 The playbook's own domain-modeling skill](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/24) | grilling | **new** — side quest, blocks nothing |

## Blocked

| Ticket | Waiting on |
|---|---|
| [#16 Two-entrance front door](https://github.com/ZhiKaanZhi/claude-code-playbook/issues/16) | 10 open blockers — the capstone |

```
   DONE ── #3 stages+seam · #4 tracker contract · #5 charting contract
        ── #6 native capabilities · #7 tracker primitives
        ── #19 the reorg · #20 the solo path overview

   #5 freed ──┬──► #11 write the charting template
              ├──► #21 how the stack gets chosen
              └──► #22 write the charting doc

   all 13 open tickets ──────────►  #16 TWO-ENTRANCE FRONT DOOR  (capstone)
```

---

## Suggested session order

Wayfinder resolves **one ticket per session**, and tickets are sized to a fresh context window.

1. ~~#19 reorg · #7 tracker primitives · #3 stages and seam · #4 tracker contract ·
   #20 overview doc · #5 charting contract~~ **Done.**
2. `/wayfinder 1 11` — **write the charting skill template.** Take this next, and take it
   soon. Its contract was decided one session ago and the body has been rewritten to carry
   all eight decisions inline. The longer you leave it, the more of #5 has to be re-read
   from the ticket rather than recalled. It is a **make** ticket, so it should end with the
   file on disk.
3. `/wayfinder 1 13` — the adapter templates and the Jira retrofit. Settled content,
   execution not judgement. Good for a session with less attention to spare.
4. Then the stage conversations — #9 kill gate, #10 bootstrap, #12 backlog, #14 guardrails,
   #15 stack→agents, #18 progress, #21 stack choice — in any order. Each writes its own
   `docs/solo/` doc at the number reserved above.
5. #8 resume whenever you like, but **read #5's §8 first** — the boundary is already fixed
   and #8 must respect it.
6. #23 and #24 are side quests. They block nothing and are on nobody's critical path.

Plain `/wayfinder 1` takes the first frontier ticket in map order — currently
#8 *Resuming an effort that spans dozens of sessions*, which is **not** what I would take.
Name the ticket.

---

## Gotchas found so far

- **The leading-gist rule is not retroactive.** #5 requires every resolution comment to open
  with a one-line gist so Decisions-so-far can be regenerated mechanically. The **seven
  comments closed before #5 have no gist**, so a full regeneration today still means
  re-reading and re-summarising those seven. Either accept the map's current
  Decisions-so-far as the canonical text for them, or retrofit gists as a chore. Not worth a
  ticket; worth knowing before someone tries to regenerate and finds it is not mechanical.
- **`gh api` sub-issue and dependency writes need `-F`, not `-f`.** `-f` sends the id as a
  string and the API rejects it with `is not of type integer`. Both take the issue's
  **database id** (`.id`), never its number.
- **`gh issue view <n>` prints nothing on this machine** — no error, no body, exit 0, from
  both Git Bash and PowerShell. **Read tickets with
  `gh api repos/<owner>/<repo>/issues/<n> --jq ...`** and do not waste a retry on `view`.
- **`issue_dependencies_summary.blocked_by` is open blockers only**; `total_blocked_by`
  includes closed ones and never decreases. **Use `blocked_by == 0`.**
- **The GitHub adapter's frontier query does not work as written.** `gh issue list --json`
  **cannot see hierarchy at all** — `parent` or `subIssues` error with `Unknown JSON field`.
  The working form is the single `gh api …/sub_issues` call at the top of this file. Fix is
  in #13's scope.
- **`gh issue list --limit` defaults to 30.** Silent truncation. This map now has 22
  children.
- **`gh` will not auto-create labels.** Create before applying.
- **`gh api` breaks on Git Bash for Windows with a leading-slash path.** `/repos/…` gets
  rewritten to `C:/Program Files/Git/repos/…`. Always omit the leading slash.
- **Ticket bodies carry pre-reorg doc paths.** #9, #10 and #12 still say
  `docs/07-the-flows.md`, `docs/13-when-not-to-use.md`, `docs/12-adapting-to-your-stack.md`.
  Post-#19 those are `docs/shared/07-the-flows.md`, `docs/shared/12-when-not-to-use.md` and
  `docs/shared/11-adapting-to-your-stack.md` — **two changed number as well as directory**.
  **#11 has been fixed**; the other three have not. Re-resolve every path in a ticket body
  before acting on it.
- **GitLab's API docs are wrong about blocking.** Blanket Free/Premium/Ultimate badge, but
  `blocks` links actually 403 on Free. This is why GitLab ships as a shape, not an adapter.
- **The local adapter's `Status:` line is overloaded** between `/triage`'s role strings and
  wayfinding's `claimed`/`resolved`. Two independent fields are needed.
- **The map's licensing premise was wrong.** `mattpocock/skills` *does* ship a LICENSE (MIT,
  © 2026 Matt Pocock). The decision to re-derive stands on the quality ground alone.
- **README's repo-layout block is stale, doubly so** — it lists `01`–`12`, omits `13`/`14`,
  and shows the old *flat* layout. #16 owns the rewrite.
- **The renumbering trap in #19.** Two classes did the damage: **numeric shorthand with no
  slug** (`docs/09`, `docs/11`), invisible to any filename search, where `docs/11` *silently
  changed meaning*; and **the depth change**, where every link pointing *out* of `docs/`
  needed `../../` — 19 links across 6 files. The check that caught both: resolve every
  `[text](target)` against the filesystem.

---

## What #5 handed forward

- **#11** was rewritten, relabelled and retitled. It is now *Write the charting skill
  template*, labelled `wayfinder:task` (a **make**, not a grilling — the first application of
  decide-or-make to the existing map), and its body carries all eight contract decisions
  inline so the writing session does not have to re-derive them. Its stale flow-catalogue
  path was corrected to `docs/shared/07-the-flows.md`.
- **#8** must read #5's §8 before resolving. Charting owns the progress comment and the
  retained claim; everything after the map closes is #8's.
- **#22** must take the destination *from the solo path*, not from the skill. `03-charting.md`
  is where `backlog + scaffolded + indexed` gets stated, and it must not restate the seam.
- **Two new tickets, both side quests.** #23 *Write the prototype skill template* closes the
  one ticket type charting names with an empty shelf. #24 *The playbook's own
  domain-modeling skill* decides where a settled term lives — memory, `CLAUDE.md`, or the
  map's Notes — given the repo has no `CONTEXT.md` or ADR concept and already has two homes
  for durable knowledge.
- **A scope call left open for the driver.** #23 and #24 are arguably *tools the path uses*
  rather than the path itself. They were kept in scope on the ground that a reader hitting an
  empty shelf is a real defect — but ruling them out and spinning them into a separate effort
  is a legitimate call that has not been foreclosed.

## What #20 handed forward

- **#22 must not restate the seam** — `01-the-solo-path.md` owns it in full.
- **The stage docs inherit a house-style precedent**: table of question + exit condition, one
  ASCII diagram, a "why this doc exists" closer, `2.1.220` footer, and links out of
  `docs/solo/` written as `../shared/…`.

## What #4 handed forward

- **#13 the adapter templates** grew: a GitLab *shape* doc, a generated progress file for the
  local adapter, the `.scratch/` rename plus a `PHILOSOPHY.md` note about committing ticket
  files, the two-fields fix for `Status:`, and the GitHub command traps above. **Surgical
  means names and verbs, not voice.** One pass across the list, not one ticket per doc.
- **#12 the backlog ticket** creates work units through the contract's verbs only.

## What #3 handed forward

- **#8** has four named phases — and the backwards step means "which phase am I in" is not
  monotonic.
- **#9**'s build artifact is a **private repo with the map as issue #1**, agent-created.
- **#10** **scaffolds, never creates**; its exit test is the tail's stack-specific checks.
- **#12** runs **after** bootstrap, against a real indexed repo.
- **#14** — the `PHILOSOPHY.md` §5 exception granted at the gate is **one instance, not a
  precedent**. Interacts with #4's restatement of §5 as *"is anyone watching?"*.
- **#15** still starts from a stack already chosen; the choosing is #21.

---

## Standing context

`PHILOSOPHY.md` was written out of a workflow at a company where the driver does **not** own
the code or the projects — which is why it is so cautious. Its rules are **defaults with a
reason, not laws**. On a personal project, ask what a rule was protecting (usually *"other
people are watching"* or *"someone else owns this"*) and re-derive rather than obeying blindly
or deleting it. Note that this repo itself is **public**, so *"nobody is watching"* is not true
even here.

---

## Out of scope (settled — do not relitigate)

- Deployment / hosting / CI / release.
- Idea generation — helping you *find* what to build.
- Vendoring third-party skills into `templates/` (quality, not licensing).
