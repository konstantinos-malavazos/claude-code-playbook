# Progress — the solo builder's path

Local tracking file for the wayfinder effort on
[#1 MAP: the solo builder's path](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/1).
**Committed and pushed**, so the effort can be resumed from any machine. The tracker is
still the source of truth; this is a reading convenience that goes stale between sessions.

> **Snapshot taken:** 2 August 2026, after resolving
> [#22 Write the charting stage doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/22).
> Regenerate rather than trust — the one-call frontier query is:
> ```
> gh api repos/konstantinos-malavazos/claude-code-playbook/issues/1/sub_issues --paginate \
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
| Tickets closed | 10 |
| Tickets open | 12 |
| On the frontier (takeable now) | 11 |
| Blocked | 1 — only the capstone |
| Repo files changed since the effort began | 32 + this file |
| Branches | none — findings live in ticket comments, not in the repo |
| Working tree | clean — #22's two files are committed and pushed |

**Every gate is open** and has been since #5. The map is no longer a dependency graph but a
**work queue** — session choice is about attention and appetite, not about what is unlocked.
Nothing waits on anything except
[#16 Two-entrance front door](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/16),
which waits on everything.

**The charting pair is complete.** #11 wrote the skill; #22 wrote the stage doc that points
at it and supplies the solo destination the skill deliberately does not know. Two makes in
a row, both ending where a make should — file written, nothing new decided.

**`docs/solo/` is now 2 of 5.** `01` the spine and `03` charting. The three remaining stage
docs each ride on their design ticket.

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
| [#6 What Claude Code already does natively](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/6) | Lean on the harness for `/init`, plan mode, the task list, background sessions, worktrees, `/goal`. The playbook must supply its own durable map artifact, its own backlog, and every judgement stage of the front-end. `/effort ultracode` is the *worst* default for a solo builder. |
| [#2 Where the solo path lives](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/2) | `docs/` splits three ways (below). Templates stay flat with a path column in their READMEs. Moved docs keep their `2.1.219` footer. |
| [#19 Reorg docs into shared/ team/ solo/](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/19) | **Done — the layout below now exists.** 14 docs moved as git renames, 54 relative links resolve and 0 dead. |
| [#7 Tracker primitives](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/7) | **The floor is narrower than charting assumed.** Native blocking is not universal; the claim **cannot be a mutex**; nothing has optimistic concurrency, so the map body should be regenerable. Handed four judgement calls to #4. |
| [#3 The stages and the seam](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/3) | **Four stages: kill gate → charting → bootstrap → backlog.** The repo is the gate's output, so bootstrap *scaffolds* and never *creates*. Bootstrap runs **before** the backlog. Stack choice is a **ticket on the map**, in a two-ticket tail not takeable while anything else is open. Charting can end in **abandon**. One backwards step allowed. Seam = the seven checks above. |
| [#4 The tracker-adapter contract](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/4) | **A skill never names a tracker.** Ten decisions — see the table below. |
| [#20 Write the solo path overview doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/20) | **Done — `docs/solo/01-the-solo-path.md` is on master.** An index, not a summary. **Sets the `docs/solo/` numbering** (below). |
| [#5 The charting skill's contract](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/5) | **The skill is `charting`, and it is general.** Eight decisions — see the section below. |
| [#11 Write the charting skill template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/11) | **Done — `templates/skills/charting/SKILL.md` is written.** All eight of #5's decisions carried; nothing reopened. Three `<PLACEHOLDER>`s, two of which are waiting on other tickets. |
| [#22 Write the charting stage doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/22) | **Done — `docs/solo/03-charting.md` is written.** States the solo destination and the trap beside it (that is where the *path* ends, not where *charting* ends). Authored two things nothing had settled: the **cleared-vs-abandoned test**, and that **charting cannot reopen the kill gate**. Found a wrinkle in #3's tail — see below. |

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
| `03-charting.md` | charting — **written** | #22 |
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

Eleven tickets. Nothing gates anything but the capstone.

| Ticket | Type | Note |
|---|---|---|
| [#13 Tracker adapter templates + the Jira retrofit](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/13) | make | **Take this next.** Fully settled — execution, not judgement. Owns `<TRACKER-ADAPTER-PATH>`, which both charting files now point at. |
| [#9 The kill gate](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/9) | grilling | writes `docs/solo/02` |
| [#10 The bootstrap](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/10) | grilling | writes `docs/solo/04`. Consumes #21's answer on the tail wrinkle; does not settle it. |
| [#12 Cleared map to backlog of work units](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/12) | grilling | writes `docs/solo/05` |
| [#14 Which guardrails hold when you are solo](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/14) | grilling | — |
| [#15 Tech stack into working agents and skills](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/15) | grilling | starts from a stack already chosen |
| [#18 How progress is measured on the solo path](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/18) | grilling | — |
| [#8 Resuming an effort across dozens of sessions](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/8) | grilling | **must check #5's §8 boundary first** |
| [#21 How the tech stack actually gets chosen](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/21) | grilling | freed by #5. The tail is now written reader-facing in `03-charting.md` — **extend it, do not re-derive it**. **Owns the tail wrinkle.** |
| [#23 Write the prototype skill template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/23) | make | side quest — but it now owns a live `<PLACEHOLDER>` in the charting template |
| [#24 The playbook's own domain-modeling skill](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/24) | grilling | side quest, blocks nothing |

## Blocked

| Ticket | Waiting on |
|---|---|
| [#16 Two-entrance front door](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/16) | 9 open blockers — the capstone |

```
   DONE ── #3 stages+seam · #4 tracker contract · #5 charting contract
        ── #6 native capabilities · #7 tracker primitives
        ── #19 the reorg · #20 the solo path overview
        ── #11 the charting skill template  ┐ the charting pair —
        ── #22 the charting stage doc       ┘ skill + the doc pointing at it

   #11 left three placeholders, still open:
        <TRACKER-ADAPTER-PATH>       ──► #13   (#22 deliberately did not name it)
        <PROTOTYPE-SKILL-OR-NONE>    ──► #23
        <LABEL-PREFIX>               ──► never, reader's own convention

   docs/solo/  01 ✓ spine   02 #9   03 ✓ charting   04 #10   05 #12

   all 11 open tickets ──────────►  #16 TWO-ENTRANCE FRONT DOOR  (capstone)
```

---

## Suggested session order

Wayfinder resolves **one ticket per session**, and tickets are sized to a fresh context window.

1. ~~#19 reorg · #7 tracker primitives · #3 stages and seam · #4 tracker contract ·
   #20 overview doc · #5 charting contract · #11 the charting template ·
   #22 the charting stage doc~~ **Done.**
2. `/wayfinder 1 13` — **the adapter templates and the Jira retrofit. Take this next.**
   Settled content, execution not judgement — good for a session with less attention to
   spare, and the only make left that nothing else is waiting behind. It resolves
   `<TRACKER-ADAPTER-PATH>`, which **both** charting files now point at, so it is the last
   thing keeping the charting pair from being fully wired.
3. Then the stage conversations — #9 kill gate, #10 bootstrap, #12 backlog, #14 guardrails,
   #15 stack→agents, #18 progress, #21 stack choice — in any order. Each writes its own
   `docs/solo/` doc at the number reserved above. **#10 and #21 should both read
   `03-charting.md` first** — the tail is written reader-facing there, and both inherit the
   wrinkle below.
4. #8 resume whenever you like, but **read #5's §8 first** — the boundary is already fixed
   and #8 must respect it. `03-charting.md` closes with a deliberate hook for its doc.
5. #23 and #24 are side quests. They block nothing and are on nobody's critical path.

Plain `/wayfinder 1` takes the first frontier ticket in map order — currently
#8 *Resuming an effort that spans dozens of sessions*, which is **not** what I would take.
Name the ticket.

---

## Gotchas found so far

- **#3's tail has an ambiguous sentence, and decide-or-make made it matter.** On whether a
  stack gates on a green test command, #3 says *"the test half is optional, and **the stack
  ticket** decides"* — then immediately *"which is what **the tail's second ticket** is
  for."* Those are two different tickets. Under #5's decide-or-make the second reading makes
  the tail's second ticket both a decision and a make, which is the exact collision the rule
  forbids. **#22 took the first reading** (ticket 1 decides the stack *and* the test gate;
  ticket 2 writes the commands down) and wrote `03-charting.md` to it without adjudicating
  in prose. **#21 owns settling it** — the question is *what the stack ticket decides*,
  which is #21's subject; **#10 only consumes the answer.** Assigned deliberately, because
  a question two tickets each assume the other will answer is a question nobody answers.
- **There is an open housekeeping ticket outside this map.**
  [#17 Docs housekeeping](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/17)
  is **not** a child of #1 — it is pre-existing rot in the agile path. It owns the stray
  `-e ` lines (14 left; #11's commit took the 15th), the stale `2.1.219` footers, and
  suspected factual drift in `07-the-flows.md`. **Check it before editing any shared doc**,
  or you will duplicate its work. Its own file list is pre-reorg and has been corrected in a
  comment.
- **The flow catalogue's own definition no longer matches its contents.**
  `docs/shared/07-the-flows.md` opens by defining a flow as *"a slash command that
  orchestrates a chain of scoped specialist agents."* `/charting` is a user-invoked skill,
  not an agent chain — and `ad-hoc: investigation` was already in the table without being a
  command at all. So the drift predates #11; #11 just made it visible. **Handed to #17**,
  which already owns that file. A one-line widening of the definition fixes it.
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

## What #22 handed forward

- **`docs/solo/03-charting.md` exists.** It is the reader-facing home for the charting
  stage. Anything wanting to explain the destination-vs-stopping-point distinction, the
  tail and its escape, the two endings, or what a charting session feels like should
  **link to it, not restate it.**
- **Two things were authored there that no ticket had settled.** The **cleared-vs-abandoned
  test** — *"would this fact have changed the gate's verdict, if you had known it at the
  gate?"*, explicitly not *"is this hard"* — and that **charting cannot reopen the kill
  gate**; the way to un-decide *build* is to abandon. Both are reader-facing guidance, not
  contract, and both are open to being pushed back on.
- **#10** gets a promise it must keep: the doc tells readers the tail's checks are *what
  stage 3 runs to prove it is done.*
- **#21** must extend the tail rather than re-derive it — the rule, the reason product
  decisions go first, and the offline-question escape are all written out already.
- **#8** has a hook: the doc says a dying session posts a progress comment and keeps the
  claim, then defers resuming to "its own doc".
- **`<TRACKER-ADAPTER-PATH>` was deliberately left unnamed**, against what this file
  previously said #22 would supply. #13 owns the installed path; the doc speaks only the
  abstract verbs, so nothing breaks when #13 sets the value. **`<LABEL-PREFIX>` was left out
  entirely** — reader's own convention, and label naming is skill internals, out of place in
  a stage doc.
- **No memory written.** Same as #11 — #5's one-per-map rule, and the map is still open.

## What #11 handed forward

- **`templates/skills/charting/SKILL.md` exists.** Any later ticket that wants to explain
  fog of war, decide-or-make, the leading-gist rule, the ticket types, or the tracker verbs
  should **link to it, not restate it.** That is now the single source for the mechanics.
- ~~**#22** supplies the destination (`backlog + scaffolded + indexed`) and the solo-path
  values for `<TRACKER-ADAPTER-PATH>` and `<LABEL-PREFIX>`.~~ **Done, but only half of it.**
  #22 supplied the destination; it left both placeholders alone. See *What #22 handed
  forward* above for why.
- **#13** owns `<TRACKER-ADAPTER-PATH>` and every verb name. If a verb is renamed there,
  the charting template is the file that breaks.
- **#23** owns `<PROTOTYPE-SKILL-OR-NONE>`. When the prototype template ships, the whole
  change is swapping that one cell in the types table.
- **No memory was written, on purpose.** #5 decided memory is one per map, at close. The
  map is open, so this ticket banks nothing. Expect the same for every remaining ticket.

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
