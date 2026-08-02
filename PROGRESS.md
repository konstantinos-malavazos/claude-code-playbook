# Progress — the solo builder's path

Local tracking file for the wayfinder effort on
[#1 MAP: the solo builder's path](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/1).
**Committed and pushed**, so the effort can be resumed from any machine. The tracker is
still the source of truth; this is a reading convenience that goes stale between sessions.

> **Snapshot taken:** 2 August 2026, after resolving
> [#27 pitch-judge cannot have zero tools](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/27)
> and, off-map, [#28 the template frontmatter audit](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/28).
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
| Tickets closed | 15 of 25 |
| Tickets open | 10 |
| On the frontier (takeable now) | 9 |
| Blocked | 1 — only the capstone, on 6 open edges (14 wired, 8 now closed) |
| Repo files changed since the effort began | 50 by the map’s own tickets, + 15 by #28 off-map |
| Branches | none — findings live in ticket comments, not in the repo |
| Working tree | clean — #27 wrote no repo files; #28 applied its edits and closed |

**Every gate is open** and has been since #5. The map is no longer a dependency graph but a
**work queue** — session choice is about attention and appetite, not about what is unlocked.
Nothing waits on anything except
[#16 Two-entrance front door](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/16).

**The map grew, then closed the hole it grew for.** #25 and #26 both wrote their files and
decided nothing — but verifying one of #26's claims turned up a real problem, so it spun
#27, which is now resolved. That is the decide-or-make rule working in the direction it is
usually quiet about: a make found a decision and stopped instead of quietly deciding it.

**Nothing on disk is knowingly wrong any more.** `pitch-judge.md` now says
`tools: TodoWrite` + `maxTurns: 1`, applied by #28 along with the rest of the audit.

**#28 found four silent failures, and two were guardrails that were not guarding.**
`repo-reviewer` promised to dispatch `@release-reviewer` and had no `Agent` tool, so the
pipeline's cross-repo review could never run. The git hooks matched only `Bash`, so
**`PowerShell` walked straight past them** — on Windows, which is where this repo is
driven. Both are fixed. See the gotchas below; both generalise well beyond this repo.

**Then the hooks were actually run, and a fifth failure appeared that reading could not
have found.** Both git guardrails ignored `git push` on any line but the first, because
they flattened newlines to spaces and their patterns anchor on a separator. `cd /tmp &&
git push` was caught; the ordinary multi-line form was not. **The audit's method was the
limit, not its diligence** — every documentation claim it checked was correct. The repo now
has its first executable test, `templates/hooks/test-hooks.sh`, and a standing rule: **where
a claim can be executed, execute it.**

**Both stage pairs are now fully wired.** Charting — #11 the skill, #22 the doc, #13 the
path they pointed at. The kill gate — #25 the doc, #26 the skill and the judge. The two
pairs were built in **opposite orders**, and it made a visible difference: charting's
template landed first, so its doc never shipped a dead link, while `02-the-kill-gate.md`
carried a *still being written* marker for one commit. #26 deleted it.

**The remaining makes are #23 and #24's outcome.** Everything else open is a grilling — the
four stage and cross-cutting conversations plus #8.

**`docs/solo/` is 3 of 5.** `01` the spine, `02` the kill gate, `03` charting. `04` and `05`
still ride on their design tickets — #10 and #12.

**Templates now carry three solo-only entries** — the `charting` and `pitch` skills, and the
`pitch-judge` agent. The solo/team columns #2 added are doing real work rather than sitting
all-✓.

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
| [#13 Tracker adapter templates + the Jira retrofit](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/13) | **Done — `templates/trackers/` exists and the playbook no longer assumes Atlassian.** The fixed path is **`~/.claude/tracker.md`**. The MCP key becomes **`tracker`, not `jira`** — a breaking change for an existing install. §5 becomes the audience rule. Setup gained **step 5**. README deliberately excluded — see below. |
| [#9 The kill gate](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/9) | **The gate is `/pitch` — a skill plus a doc.** Six questions, ~1 hour, three hard kills whose teeth depend on a **question zero** that classifies what the idea's value rests on. Sycophancy beaten structurally, not by instructing harshness. A fourth agent, **`pitch-judge`**, reads an **anonymised case file** and can fire a hard kill but never un-fire one. See the section below. |
| [#25 Write the kill gate stage doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/25) | **Done — `docs/solo/02-the-kill-gate.md` is written.** A make that decided nothing; every claim traces to #9. The `12-when-not-to-use.md` cross-reference is **live in both directions**, and the **spike clash is named as a hole and then closed** rather than left to be found. |
| [#26 Write the `/pitch` skill + `pitch-judge` agent](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/26) | **Done — `templates/skills/pitch/SKILL.md` and `templates/agents/pitch-judge.md` are written**, with the flow catalogue entry and both README rows. A make that decided nothing. Made explicit three mechanics #9 only implied: the **case file rides in the dispatch prompt** (no tools means no `Read`), the hard kills need an **arming table transposed by class**, and verdict resolution needs an **explicit precedence order**. |
| [#27 `pitch-judge` cannot have zero tools](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/27) | **`tools: TodoWrite` plus `maxTurns: 1`.** Zero tools is impossible **by design** — the harness refuses to spawn an agent that would hold none — so `tools: []` never launches. Two guarantees on different axes: the allowlist means it holds nothing that finds, the single turn means it cannot act on a result. The agents README gains a **least privilege has a floor** convention and a **complete sixteen-field anatomy block**. **"No tools" is retired as vocabulary** in favour of **"gathers no evidence"**. Decided only; **#28 applied it**. |

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
| `02-the-kill-gate.md` | the kill gate — **written** | #25 |
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
| Adapter location | `templates/trackers/`, flat. **Exactly one installed at a fixed path** — #13 set it to **`~/.claude/tracker.md`**. |
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

Nine tickets. Nothing gates anything but the capstone.

**Nothing is queued that has its decisions already banked.** Every remaining ticket except
#23 is a real conversation — worth knowing before you open one expecting a writing job.

| Ticket | Type | Note |
|---|---|---|
| [#10 The bootstrap](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/10) | grilling | writes `docs/solo/04`. Consumes #21's answer on the tail wrinkle; does not settle it. **#13 pre-answered seam item 5** — see below. **It also owns the last dead link** in `02-the-kill-gate.md` and `03-charting.md`. |
| [#12 Cleared map to backlog of work units](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/12) | grilling | writes `docs/solo/05` |
| [#14 Which guardrails hold when you are solo](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/14) | grilling | — |
| [#15 Tech stack into working agents and skills](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/15) | grilling | starts from a stack already chosen |
| [#18 How progress is measured on the solo path](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/18) | grilling | — |
| [#8 Resuming an effort across dozens of sessions](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/8) | grilling | **must check #5's §8 boundary first** |
| [#21 How the tech stack actually gets chosen](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/21) | grilling | freed by #5. The tail is now written reader-facing in `03-charting.md` — **extend it, do not re-derive it**. **Owns the tail wrinkle.** |
| [#23 Write the prototype skill template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/23) | make | side quest — but it now owns the **last** live `<PLACEHOLDER>` in the charting template |
| [#24 The playbook's own domain-modeling skill](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/24) | grilling | side quest, blocks nothing |

## Blocked

| Ticket | Waiting on |
|---|---|
| [#16 Two-entrance front door](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/16) | 6 open blockers — the capstone; #25 and #26 took two off. **#13 sharpened it**: the README is now the only file left claiming Jira is assumed. **#26 added a pattern it should expect** — three templates now claim the solo column only, and that will keep growing. |

```
   DONE ── #3 stages+seam · #4 tracker contract · #5 charting contract
        ── #6 native capabilities · #7 tracker primitives
        ── #19 the reorg · #20 the solo path overview
        ── #11 the charting skill template  ┐ the charting pair —
        ── #22 the charting stage doc       ┘ skill FIRST, then the doc
        ── #13 the tracker adapters + retrofit  ── wires the pair to a real path
        ── #9  the kill gate design    ──► spun #25 (doc) + #26 (skill + judge)
        ── #25 the kill gate stage doc  ┐ the kill gate pair —
        ── #26 the /pitch skill + judge ┘ doc FIRST this time, template second
                    │
                    └──► spun #27 — the judge's `tools: []` is not a thing
                         the harness supports. A make catching itself.
        ── #27 tools: TodoWrite + maxTurns: 1 ──► applied by #28 (off-map), closed

   #11 left three placeholders. One is left:
        <TRACKER-ADAPTER-PATH>       ──► RESOLVED by #13 = ~/.claude/tracker.md
        <PROTOTYPE-SKILL-OR-NONE>    ──► #23   (the last one open)
        <LABEL-PREFIX>               ──► never, reader's own convention

   #26 added one that is meant to stay open:
        <IDEAS-FILE-PATH>            ──► never, reader picks. Private + backed up.

   docs/solo/  01 ✓ spine   02 ✓ kill gate   03 ✓ charting   04 #10   05 #12

   10 open tickets ── 6 wired ────►  #16 TWO-ENTRANCE FRONT DOOR  (capstone)
```

---

## Suggested session order

Wayfinder resolves **one ticket per session**, and tickets are sized to a fresh context window.

1. ~~#19 reorg · #7 tracker primitives · #3 stages and seam · #4 tracker contract ·
   #20 overview doc · #5 charting contract · #11 the charting template ·
   #22 the charting stage doc · #13 the adapters and the retrofit ·
   #9 the kill gate design · #25 the kill gate stage doc ·
   #26 the /pitch skill and the judge · #27 the judge's zero-tools defect~~ **Done.**
2. **The easy sessions are over.** Everything left is a grilling except #23's make. There
   is no ticket whose decisions are already banked, so expect a real conversation rather
   than a writing job.
3. ~~#28, the template audit.~~ **Done, off-map.** It also closed the last thing on
   `master` that was knowingly broken.
4. `/wayfinder 1 21` — **stack choice.** It is the only open ticket
   that another open ticket is waiting on: **#10 cannot settle the tail wrinkle** and #21
   owns it. Taking #21 first means #10 gets a clean answer instead of inheriting an
   ambiguity. **Read `03-charting.md` first** — the tail is already written reader-facing
   there, and #21 extends it rather than re-deriving it.
5. `/wayfinder 1 10` — the bootstrap, after #21. Writes `docs/solo/04` and clears the last
   dead link in two stage docs. **#13 pre-answered seam item 5** — state it, do not
   re-derive it.
6. Then the rest — #12 backlog, #14 guardrails, #15 stack→agents, #18 progress — in any
   order. Each writes its own `docs/solo/` doc at the number reserved above.
7. #8 resume whenever you like, but **read #5's §8 first** — the boundary is already fixed
   and #8 must respect it. `03-charting.md` closes with a deliberate hook for its doc.
8. #23 and #24 are side quests. They block nothing and are on nobody's critical path.

Plain `/wayfinder 1` takes the first frontier ticket in map order — still
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
- **A stage doc that lands before its template ships dead links, and it cost a marker.**
  The charting pair went template-first (#11 then #22), so `03-charting.md` never had the
  problem. The kill gate pair went the other way — #25 before #26 — so `02-the-kill-gate.md`
  shipped with two dead template links and a *still being written* blockquote, which #26
  then deleted. It worked, but it cost an extra edit and a commit that published a doc
  pointing at nothing. **Template-first is the better order** where a pair has a free
  choice. #10 and #12 both face it.
- **A subagent cannot have zero tools, and this is deliberate.** The errors page is
  explicit: *"Subagents require at least one tool to function, so Claude Code refuses to
  spawn an agent that would have no tools available."* So `tools: []` **refuses to launch** —
  that is the branch #26 could not determine. There is a version boundary: **before
  v2.1.208 the same YAML launched the agent toolless** and it "could return an empty or
  confusing result", so one file fails two different ways depending on the reader's install.
  **`TodoWrite` is the inert floor** — it is on the background-safe built-in list and cannot
  read, fetch or run anything. #27 settled `tools: TodoWrite` + `maxTurns: 1`.
- **Subagents run in the background by default, and that silently changes their tools.**
  Since v2.1.198 background is the default, and a background subagent keeps **every MCP
  tool** but only a fixed subset of built-ins: `Read`, `Grep`, `Glob`, `Bash`, `PowerShell`,
  `Edit`, `Write`, `NotebookEdit`, `WebFetch`, `WebSearch`, `TodoWrite`, `Skill`,
  `ToolSearch`, `EnterWorktree`, `ExitWorktree`, `Monitor`, `TaskStop`, `SendMessage`,
  `Artifact`. **Anything else in a `tools:` list is stripped with no error** — unless
  stripping empties the list, at which point the agent refuses to launch. So a template can
  name a tool that exists, is spelled correctly, and still is not there at runtime. Also
  worth knowing for the *inherit* case: an agent with `tools` omitted holds every MCP server
  you have configured, which is usually far more reach than the author pictured.
- **An agent that dispatches another agent needs `Agent` in its `tools` list, and nothing
  warns you.** `repo-reviewer` said *dispatch `@release-reviewer`* in its description and in
  its steps, and could not: nesting is on by default, but **an explicit allowlist still
  wins**. The first-level review would have finished and reported a verdict with the
  cross-repo half silently absent. **Check every agent whose body names another agent.**
- **Flattening input before matching erases the boundaries the pattern depends on.** Both
  git guardrails turned newlines into **spaces**, then matched `git push` anchored on
  start-of-string or `[;&|]`. So in an ordinary multi-line command every line after the
  first was invisible to them — `cd /tmp && git push` blocked, the three-line version did
  not. Newlines are now `;`. **Suspect this in any guardrail that normalises before it
  greps**: the normalisation looks like tidying and is load-bearing.
- **Auditing claims against documentation verifies the claims, not the code.** #28 checked
  every hook claim against the official docs and passed, because nothing in the docs was
  wrong — the playbook's own regex was. Configuration defects (a missing `Agent` tool, a
  matcher naming one shell) *do* fall out of reading. Behavioural ones do not.
  **`templates/hooks/test-hooks.sh` is the repo's first executable test** — 29 cases, and
  it was mutation-tested by reverting the fix and confirming it fails on exactly the four
  multi-line cases. A suite never seen to fail is not evidence.
- **A guardrail that stops guarding reports success — three instances now, one week.**
  #13's MCP key rename, #28's `Bash`-only matcher, and this. **Anything whose failure mode
  is silence needs a test, not a review.**
- **`PowerShell` is a separate tool from `Bash`, and a `"matcher": "Bash"` hook does not
  see it.** It is enabled automatically on Windows without Git Bash, rolling out
  progressively on Windows *with* Git Bash, and opt-in elsewhere. So the git guardrails were
  wide open on the platform this repo is actually driven from. Use `Bash|PowerShell`.
  **Second instance of the same failure shape #13 found** — a guardrail that stops matching
  keeps reporting success. Worth a standing suspicion: whenever a matcher names one way of
  doing a thing, ask what the other ways are.
- **Only `exit 2` blocks a hook. Every other non-zero code is non-blocking** — the
  transcript shows an error notice and the tool call proceeds anyway. The shipped scripts
  were right; the README taught *"non-zero (2)"*, which is the natural thing to get wrong,
  and `exit 1` in a guardrail guards nothing while looking like it does.
- **A skill's directory name is what you type; `name` is only a display label.** It defaults
  to the directory name and changing it does not change the command. Bites
  `engineering-standards`, which is copied per layer — rename the *directory*, not just the
  placeholder, or three skills answer to `/engineering-standards`.
- **Custom commands have been merged into skills**, and where they collide **the skill
  wins**. `templates/commands/` is still supported, not deprecated — but the whole skill
  frontmatter set works there too, and the skill shape is the one that grows.
- **No template carries a `Last verified against` footer, and that is now deliberate.** #28
  assumed the footers were over-claiming for templates; in fact templates never claimed
  anything. Adding one per file would have been worse — a template is copied and edited, so
  a stale footer is indistinguishable from the reader's own edits. **The check lives in
  `templates/README.md` instead**, as eight named checks against the doc pages that settle
  them. Checks 3, 4 and 6 are the ones that fail silently; three of #28's four findings came
  from them.
- **This playbook writes frontmatter the harness has to accept, and nobody was checking.**
  `tools: []` was written because it was the obvious YAML for "no tools". Every file in
  `templates/` is a **claim about what the harness will do**, and claims need verifying
  against the docs, not against what looks reasonable. The `2.1.220` footer implies exactly
  this checking has happened. **Check the field table in the subagent docs before inventing
  a frontmatter value**, especially for anything expressing an absence — absences are where
  "unset" and "empty" get conflated.
  **Now ticketed as [#28 Audit every template's frontmatter and harness claims against the
  official docs](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/28)**,
  standalone rather than a child of #1 — it covers all templates, most of them agile-path,
  so it sat outside this map's destination. Same shape as #17. **Both #27 and #28 are now
  closed.** #28 applied #27's edits and swept the rest: four silent failures found, both
  anatomy blocks widened to every documented field, and `templates/README.md` created to
  hold the re-verification check. **An incomplete anatomy block does not just omit options;
  it makes real solutions invisible** — `maxTurns` was not rejected by #26, it was never
  seen.
- **You cannot dry-run a new agent in the session that wrote it.** Agent definitions load
  at session start, so a file written to `.claude/agents/` mid-session is not registered and
  `Agent` rejects it as an unknown type. Probing a new agent template needs a fresh session.
  Worth knowing before planning any verification that depends on spawning one.
- **Decide-or-make is 15 for 15, and #27 was the first real pressure on it.** Every closed
  ticket so far is either a grilling/research that wrote no files or a `wayfinder:task` that
  wrote them — never both. #27 is the first decision whose entire output is a **two-line
  frontmatter edit**, which the rule's own justification does not cover: #5 justifies the
  split *only* by context budget (*"the unpredictable half eats the context the predictable
  half needed"*), and two lines cost no context. **The rule was kept anyway, with no size
  exception**, on the grounds that it has cost nothing so far, that *"small enough to just
  do"* is self-assessed at the start of a session — exactly when it is judged worst — and
  that #9 looked like one grilling and produced two makes. **#27 decides and #28 applies**,
  since #28 has those files open regardless. No exception, and no extra session either.
  Worth remembering the next time a decision has a trivial tail: look for a make already
  passing through the same files before carving an exception into the rule. **The rule paid
  for itself immediately**: #27 was supposed to be a two-line frontmatter change and it
  turned into a sixteen-field README rewrite, a retired vocabulary word, a correction on a
  closed ticket and two new gotchas. "Small enough to just do" would have been wrong.
- **A design ticket cannot settle mechanics it never has to execute.** #9 designed the gate
  completely and still left three things that only became questions when someone wrote the
  skill: the case file's *location* (no tools means no `Read`, so it must ride in the
  prompt), the hard-kill table's *direction* (the skill asks "given this class, which kills
  are live?", the reverse of how #9 listed them), and the *precedence* between rules that
  can fire at once. None was a new decision — each was forced. Expect the same from #10 and
  #12: the design ticket is not wrong, it just never had to run the thing.
- **Four docs have H1 headings that no longer match their filenames.** `shared/11-adapting-to-your-stack.md`
  says `# 12`, `shared/12-when-not-to-use.md` says `# 13`, `team/01-metrics.md` says `# 11`,
  `team/02-team-adoption.md` says `# 14` — exactly the four #19 renumbered, since #19
  deliberately left prose alone. The other ten match. **Found by #9 and handed to #17**, whose
  list did not cover it. The check is comparing `head -1` to the filename across `docs/**`.
- **One open housekeeping ticket outside this map, down from two.**
  [#28](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/28) owned
  machine-readable correctness in `templates/` and is **closed**; **#17 still owns
  prose-level rot in `docs/`**. The footer question that connected them is settled in
  #28's direction: templates carry no footer and get a single re-verification check
  instead, so #17's remaining footer work is purely the stale `2.1.219` *values* in `docs/`.
  Neither was ever a child of #1.
  [#17 Docs housekeeping](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/17)
  is **not** a child of #1 — it is pre-existing rot in the agile path. It owns the stray
  `-e ` lines (14 left; #11's commit took the 15th), the stale `2.1.219` footers, and
  suspected factual drift in `07-the-flows.md`. **Check it before editing any shared doc**,
  or you will duplicate its work. Its own file list is pre-reorg and has been corrected in a
  comment. **Two shared docs have been edited around it since.** #25 added one paragraph to
  `12-when-not-to-use.md` (the reverse half of a required cross-reference) and #26 added one
  row to `07-the-flows.md`. Both deliberately left the strays, the mismatched H1s and the
  stale footers alone. All of those are still #17's.
- **The flow catalogue's own definition no longer matches its contents.**
  `docs/shared/07-the-flows.md` opens by defining a flow as *"a slash command that
  orchestrates a chain of scoped specialist agents."* `/charting` is a user-invoked skill,
  not an agent chain — and `ad-hoc: investigation` was already in the table without being a
  command at all. So the drift predates #11; #11 just made it visible. **Handed to #17**,
  which already owns that file. A one-line widening of the definition fixes it. **#26 added
  `/pitch` to the same table and left the definition alone** — `/pitch` genuinely does
  orchestrate three subagents, so it fits the narrow definition better than `/charting`
  does. Nothing worsened, nothing fixed.
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
- ~~**The GitHub adapter's frontier query does not work as written.**~~ **Fixed by #13** —
  `templates/trackers/github.md` now ships the working `gh api …/sub_issues` form, plus the
  other six traps, in a table. `gh issue list --json` still cannot see hierarchy at all
  (`parent` / `subIssues` error with `Unknown JSON field`); there is no flag that fixes it.
- **Renaming the tracker MCP key to `tracker` is a silent breaking change.** #13 moved the
  server key from `jira` to `tracker` and the hook matchers from `mcp__jira__.*` to
  `mcp__tracker__.*`. All four files moved together — but **anyone who already installed the
  old snippets must rename their own server key**, or the read-only veto stops matching and
  fails open with no error. A guardrail that silently stops guarding is the worst failure
  shape there is; it is worth checking `/mcp` after upgrading.
- **The local adapter's ticket folder is `tickets/`.** #4 said *rename it away from
  `.scratch/`* without naming the replacement; #13 chose `tickets/`, visible and committed,
  because the files are project records and a dot-prefixed name says throwaway.
- **`gh issue list --limit` defaults to 30.** Silent truncation. This map now has 22
  children.
- **`gh` will not auto-create labels.** Create before applying.
- **`gh api` breaks on Git Bash for Windows with a leading-slash path.** `/repos/…` gets
  rewritten to `C:/Program Files/Git/repos/…`. Always omit the leading slash.
- **Ticket bodies carry pre-reorg doc paths.** #10 and #12 still say
  `docs/07-the-flows.md`, `docs/13-when-not-to-use.md`, `docs/12-adapting-to-your-stack.md`.
  Post-#19 those are `docs/shared/07-the-flows.md`, `docs/shared/12-when-not-to-use.md` and
  `docs/shared/11-adapting-to-your-stack.md` — **two changed number as well as directory**.
  **#11 was fixed, and #9 hit this live** — its body said `docs/13-when-not-to-use.md`, which
  is now `docs/shared/12-…`; #25 and #26 carry corrected paths. #10 and #12 have not been
  fixed. Re-resolve every path in a ticket body before acting on it.
- **GitLab's API docs are wrong about blocking.** Blanket Free/Premium/Ultimate badge, but
  `blocks` links actually 403 on Free. This is why GitLab ships as a shape, not an adapter.
- ~~**The local adapter's `Status:` line is overloaded**~~ — **moot, and worth knowing why.**
  The overload was between `/triage`'s role strings and wayfinding's `claimed`/`resolved`,
  but **the playbook ships no `/triage`** — that command is prior art from the skill set
  this repo re-derives. #13's adapter has three clean fields instead: `Type:`, `State:`,
  `Claim:`. A defect inherited from prior art can vanish rather than need fixing.
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

## What #28 handed forward (off-map)

- **`templates/README.md` exists** and is the directory's contract: what a template asserts,
  and the **nine-check re-verification list** with the doc page that settles each one. Run
  it when a footer version is bumped or after a release touching agents, skills, hooks or
  tools. Anything wanting to explain how templates are held to the harness should **link
  there, not restate it.**
- **Check 6b is the only one that executes anything**, and it exists because the other eight
  all passed while both git guardrails were open. `bash templates/hooks/test-hooks.sh` —
  run it, do not read it.
- **Two guardrails were not guarding, and both are worth a standing suspicion.** Whenever a
  matcher names one way of doing a thing, ask what the other ways are (`Bash` →
  `PowerShell`). Whenever an agent's prose names another agent, check `Agent` is in its
  tools. Neither failure produces an error.
- **The clean results are recorded too**, in the resolution comment — every agent/skill/
  command frontmatter key, every tool name, the MCP config shape, the Serena prefix warning.
  "We checked" is only useful if it says what was checked.
- **`README.md`'s repo-layout block is now stale in three ways**: pre-reorg flat docs, no
  `templates/trackers/`, no `templates/README.md`. Still **#16's**, deliberately untouched.
- **#17's footer work narrowed.** The templates-vs-docs footer question is settled in #28's
  direction, so what is left for #17 is purely the stale `2.1.219` *values* in `docs/`.
- **No memory written.** #5's one-per-map rule does not strictly bind an off-map ticket, but
  the map is open and nothing here is worth banking separately.

## What #27 handed forward

- **The mechanism is `tools: TodoWrite` + `maxTurns: 1`**, and it is **two guarantees on
  different axes** rather than one with a backup. The allowlist means the judge holds
  nothing that can find; the turn budget means it cannot act on a result whatever it holds.
  Neither depends on the other, which is the property `tools: []` was reaching for.
- **`disallowedTools` was considered and rejected here, not overlooked.** It is applied
  *first*, then `tools` resolves against what remains — so an allowlist of one already
  excludes everything and a denylist beside it narrows the same axis twice. It stays correct
  for the opposite shape: inherit broadly, subtract a few.
- **The residual risk is named.** A turn is one assistant message, so if the judge spends
  its single turn calling `TodoWrite` it returns no verdict. Unlikely — the prose forbids it
  and the one tool is not tempting — but **if it is ever seen, the fix is `maxTurns: 2`, not
  removing the field.** Two turns still cannot become a search pass, because the allowlist
  is doing that half.
- **"No tools" is retired from the playbook's vocabulary.** It appears in #9, in the agents
  README twice and in the template itself, and it was never what #9 meant. The replacement is
  **"gathers no evidence"** / **"weighs only"**. The rule underneath: **describe an agent by
  what it must not accomplish, not by the frontmatter you think expresses it** — a capability
  description survives a harness change, a mechanism description rots into a lie.
- **#9 carries a correction comment.** Its resolution comment is what Decisions-so-far
  regenerates from, so an uncorrected one would reprint the error on every rebuild. The
  intent is untouched and was never reopened; only the phrase changed.
- ~~**#28's scope moved in both directions.**~~ **#28 is closed** — it applied the
  transcription list, took the new background-subset suspect seriously enough to make it
  check 3, and inherited the agents anatomy block rather than re-deriving it.
- **Nothing is verified live.** Agent files load at session start, so the mechanism is
  correct-by-reading, not correct-by-running. **The next fresh session should spawn
  `pitch-judge` on a two-line case file** and confirm it launches and returns a verdict.
  Two minutes, and it is the only step that tests the harness rather than the docs. **This
  is the one open item left from both tickets.**
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #26 handed forward

- **The kill gate is complete** — stage doc, skill, agent, catalogue entry, both README
  rows. Nothing about the gate is outstanding.
- ~~**`tools: []` is wrong, and the branch it takes is undetermined.**~~ **Settled by #27** —
  it is the **refuse-to-launch** branch, stated outright on the errors page: subagents
  require at least one tool. **#28 applied `tools: TodoWrite` + `maxTurns: 1`**, so the file
  on disk is correct. #26 was right that both branches were unacceptable and right to
  withdraw the *fails safe* claim.
- **`<IDEAS-FILE-PATH>` is a placeholder that never resolves**, unlike
  `<TRACKER-ADAPTER-PATH>`. It is *supposed* to vary — #9's point was that the reader picks
  somewhere private they already back up. Nobody should ticket it.
- **#16 should expect the solo-only column to keep growing.** Three templates now claim it —
  the `charting` and `pitch` skills, and the `pitch-judge` agent. That is the pattern, not an
  exception.
- **It spun [#27](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/27)
  after closing**, when its own *verify this later* note was verified immediately and turned
  out to be a defect. The decide-or-make rule held: the make stopped rather than deciding
  the fix. `maxTurns: 1` was the leading candidate and **#27 kept it, but not alone** — the
  allowlist half was the part #26 could not have guessed.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #25 handed forward

- **`docs/solo/02-the-kill-gate.md` exists.** Anything wanting to explain question zero, the
  three hard kills, the four anti-sycophancy mechanisms, the park trigger, the ideas file, or
  the spike clash should **link to it, not restate it.**
- **#26 has two obligations.** Delete the doc's *still being written* blockquote when the
  templates land, and do **not** restate the doc — same split as `03-charting.md` and the
  charting template. Everything #26 needs is in its own body plus #9's comment.
- **The anti-sycophancy four are now reader-facing in one place.** #9 asked that later
  tickets designing an honesty mechanism link rather than re-derive. That lands on **#14
  guardrails** and **#18 progress** in particular — both touch honesty on a path with no
  reviewer.
- **The doc decided nothing.** Where #9 left a reader-facing choice open — section order,
  what earns a table — the doc made the call without adjudicating in prose.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #9 handed forward

- **The gate is `/pitch`, and it is a skill plus a doc.** A doc alone cannot stop you nodding
  at your own checklist, and the gate has real AFK work a reader cannot do quickly. `/idea`
  was **rejected on principle** — this map ruled idea *generation* out of scope and that name
  promises exactly the thing the playbook refuses to do.
- **Question zero is the piece nothing on the map had.** *What does this idea's value rest
  on* — novelty, execution, or the building itself. It decides which later questions are
  allowed to kill **and** how the search agents are briefed, and it is asked **first** so you
  commit before you know which question is loaded. Without it the gate is uniformly harsh,
  which means it is uniformly ignored.
- **Sycophancy is beaten structurally.** Instructing a model to be harsh produces performative
  meanness that readers learn to ignore. What works: cold subagents that never heard your
  enthusiasm, the agent committing to its verdict **before** you give yours, a mandatory
  case-for-killing, and `pitch-judge` on an **anonymised case file**. Any later ticket
  designing an honesty mechanism should **link here, not re-derive it.**
- **A transcript cannot be anonymised** — one side asks every question and one side says *let
  me go and search*, so the judge identifies who is who in two lines. Hence a **case file**:
  no dialogue, verdicts labelled 1 and 2 in random order. Worth remembering for any future
  blind-review design.
- **The asymmetry that keeps the teeth:** the judge counts in **both** directions and breaks
  ties, but a hard kill that has fired **cannot be un-fired by anyone**. It can fire one the
  other two missed.
- **#25 and #26 carry every decision inline**, the same way #5 rewrote #11. Neither writing
  session has to re-derive anything, and neither may decide anything new.
- **The two cold searches are `/research` subagents**, not new agent templates — #5's
  points-at-skills rule. Only `pitch-judge` needed inventing.
- **A patch of fog closed without a ticket.** *Where ideas wait before the gate* is answered by
  the ideas file: unjudged entries are the inbox. Removed from **Not yet specified**.
- **#10 inherits nothing new**, but it should know the gate now produces a **seeded** issue #1
  — Destination, the premise, the smallest version, and the hard part as the first `research`
  ticket. Bootstrap still scaffolds and never creates.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #13 handed forward

- **`templates/trackers/` exists** — a contract README, three working adapters (GitHub,
  Jira, local markdown) and GitLab as a documented *shape*. Anything needing the verb list,
  the audience rule, or a tracker's traps should **link there, not restate them.**
- **The fixed path is `~/.claude/tracker.md`.** `<TRACKER-ADAPTER-PATH>` is resolved and
  concrete in the charting template; `03-charting.md` gained a link to the adapter README
  but still speaks only abstract verbs, which was #22's call and still holds.
- **#16's scope sharpened, and it is now a factual defect.** The README is the only file in
  the repo still saying the playbook assumes Jira — its tagline and opening sentence both
  do. #13 left them deliberately (positioning, not a noun swap, and #16 owns the rewrite)
  and **posted the specific line numbers and the reasoning as a comment on #16.**
- **#10 gets seam item 5 pre-answered.** *"The tracker adapter is installed"* means **verify
  this project's tracker matches the installed adapter**, not *go and install one* —
  installing is global, happens once at setup step 5, and the gate necessarily used a
  tracker to create the map before bootstrap ever runs. **State it; do not re-derive it.**
- **#23 now owns the only placeholder left** in the charting template.
- **The ticket's own file list was wrong twice, both times in the safe direction.**
  `ticket-analyzer.md` was already tracker-agnostic and `templates/commands/` never
  mentioned Jira. Worth remembering that a ticket body written weeks earlier describes the
  repo as it *was* — **re-grep before trusting a file list**, the same way every path in a
  ticket body needs re-resolving after the reorg.
- **No memory written**, per #5's one-per-map rule. The map is still open.

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
- ~~**#13** owns `<TRACKER-ADAPTER-PATH>` and every verb name.~~ **Done** — the path is
  `~/.claude/tracker.md` and no verb was renamed, so the charting template needed only the
  one placeholder swapped.
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
