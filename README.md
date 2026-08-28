# Claude Code Playbook

*A stack-agnostic blueprint for running Claude Code as a serious engineering teammate —
semantic code navigation, durable memory, and multi-agent flows behind slash commands.
For any engineer, any stack, any tracker, any company.*

**By [Konstantinos Malavazos](https://github.com/konstantinos-malavazos)** — extracted from
daily use, stripped of company internals, open-sourced as it stands.

**This is not theoretical.** I run a version of this pipeline on real Jira tickets at work.
Every flow here earned its place by surviving that, not by reading well.

> **License:** MIT — see [LICENSE](LICENSE).

---

## Two entrances — pick yours

This playbook has **two front doors**. Which one is yours depends on one thing: **does the
work already exist as a ticket somebody else wrote?**

| If you are… | You enter at | And you start with |
|---|---|---|
| On a team, holding a ticket you didn't write, in a repo that already exists | **the agile path** | [docs/shared/02-prerequisites.md](docs/shared/02-prerequisites.md) → [03-setup.md](docs/shared/03-setup.md), then `/start-ticket` |
| On your own, holding a **raw idea** — no repo, no spec, nobody to hand you one | **the solo path** | [docs/solo/01-the-solo-path.md](docs/solo/01-the-solo-path.md), then `/pitch` |

```
        WHAT YOU ARE HOLDING                        WHERE YOU ENTER

   a ticket someone else wrote  ─────────────────────────────────────────┐
   in a repo that exists              (the agile path)                   │
                                                                         ▼
   a raw idea, no repo,         ──►  THE SOLO PATH  ══╣ SEAM ╠══►  /start-ticket
   nobody to hand you a spec         pitch · chart ·               the shared pipeline,
                                     bootstrap · cut               identical either way
```

**The solo path is a front-end, not a second playbook.** It stops at a
[seam](docs/solo/01-the-solo-path.md#the-seam--where-the-solo-path-stops): eight checks
that say a repo is ready. Then it hands over to exactly the same pipeline the agile path
runs. Everything downstream of that seam is shared. If you arrive with a ticket, you were
already past the seam and never needed the front-end.

**One case reaches both doors: fog.** An effort on a codebase that already exists, whose
destination is clear but whose *route* is not. It is not a raw idea, and `/start-ticket`
cannot plan it in one pass. So it charts first and walks the resulting map over weeks.
The discriminator is fog, not size.

**Both doors chart it. Only one wraps a flow around the charting.** The skill is
[`charting`](templates/skills/charting/SKILL.md), and it is shared:

| | How you chart it |
|---|---|
| **Solo**, on a repo you already shipped | Run `/charting` against it directly, one ticket per session, and hand each make to `/start-ticket`. Nothing extra to install |
| **On a team**, on a ticket you didn't write, spanning repos none of which owns the effort | The same skill behind three commands — a chart folder outside any repo, a dispatch to the layer specialists, a per-repo closing review. [docs/team/03-massive-tickets.md](docs/team/03-massive-tickets.md) |

The flow is team-only. **Charting a codebase that already exists is not.**

> If you have 5 minutes and want the *why*: read [PHILOSOPHY.md](PHILOSOPHY.md).
> It is path-neutral: the mindset is the same through both doors.

---

## The one-paragraph version

Out of the box an AI coding agent is **file-blind** (re-reads whole files to find one
method), **amnesiac** (forgets everything at session end), and **unstructured** (one
giant chat doing everything, no guardrails). This playbook fixes all three:

1. **Eyes** — a semantic code-navigation MCP (Serena) so the agent reads *symbols*, not
   whole files.
2. **Memory** — a persistent semantic-memory MCP (Forgetful) so conclusions survive
   across sessions, machines, and weeks.
3. **Flows** — multi-agent pipelines behind slash commands that turn a tracker ticket into
   a reviewed, single-commit branch, with hook-enforced guardrails.

Eyes + memory are the *capabilities*. The flows are the *way of working* built on top.
The three compound: remember → locate → edit → remember.

**No flow ever names your tracker.** Each one states its intent in abstract verbs — *read
this ticket*, *what is on the frontier?* — and exactly one
[adapter](templates/trackers/README.md) answers them. GitHub, Jira and local markdown
files ship as working adapters. Swapping tracker is a one-file change.

---

## The three pillars

```
   PILLAR 1: EYES              PILLAR 2: MEMORY            PILLAR 3: FLOWS
   ────────────────           ────────────────            ────────────────
   Serena (code nav)          Forgetful (memory)          scoped-agent pipelines
   read symbols, not files    survives sessions           behind slash commands
        │                           │                           │
        └───────────────┬───────────┴───────────────┬───────────┘
                        │                           │
                 give the agent              wrap your workflow
                 capabilities               in structure + guardrails
```

See [docs/shared/04-serena.md](docs/shared/04-serena.md), [docs/shared/05-forgetful.md](docs/shared/05-forgetful.md),
and [docs/shared/07-the-flows.md](docs/shared/07-the-flows.md).

---

## Repo layout

`docs/` splits three ways. **`shared/`** is the trunk both entrances converge on.
**`solo/`** is the front-end. **`team/`** is what only makes sense with other people in
the room. Templates stay flat. Each `README.md` there says which path needs the file.

```
claude-code-playbook/
├── README.md                       ← you are here
├── PHILOSOPHY.md                   ← the mindset in one file (read this first)
├── install.sh                      Interactive install / upgrade / remove (unix, WSL, Git Bash)
├── install.ps1                     Windows preflight — checks bash + python, then delegates
├── install-lib.py                  Discovery, hashing, the additive JSON merge, wiring checks
├── docs/
│   ├── shared/                     BOTH PATHS
│   │   ├── 01-architecture.md      The four config layers: MCP · agents · skills · hooks
│   │   ├── 02-prerequisites.md     What to install before setup
│   │   ├── 03-setup.md             Clean-machine setup, step by step
│   │   ├── 04-serena.md            Pillar 1 — code navigation by symbol
│   │   ├── 05-forgetful.md         Pillar 2 — durable memory + the two-memory rule
│   │   ├── 06-claude-md-layers.md  The CLAUDE.md layers — and how repo count picks them
│   │   ├── 07-the-flows.md         Pillar 3 — the pipeline concept + the flow catalogue
│   │   ├── 08-ticket-pipeline.md   /start-ticket, step by step (generic)
│   │   ├── 09-decompose-path.md    Parallel slices for large tickets (git worktrees)
│   │   ├── 10-memory-hygiene.md    Deliberate memory: /end-of-day + /garden-memory
│   │   ├── 11-adapting-to-your-stack.md  Mapping the abstract layer-chain to YOUR layers
│   │   └── 12-when-not-to-use.md   Where the pattern loses — for both paths
│   ├── solo/                       THE SOLO PATH — idea to backlog
│   │   ├── 01-the-solo-path.md     The spine: four stages, and the seam they end at
│   │   ├── 02-the-kill-gate.md     Stage 1 — /pitch: is this worth building at all?
│   │   ├── 03-charting.md          Stage 2 — /charting: a map of tickets, one per session
│   │   ├── 04-the-bootstrap.md     Stage 3 — /bootstrap: make the repo real
│   │   ├── 05-cutting.md           Stage 4 — /cut-backlog: the first version into work units
│   │   ├── 06-choosing-the-stack.md  How the stack actually gets chosen (charting's tail)
│   │   ├── 07-guardrails-when-solo.md  Which guardrails hold when you own everything
│   │   └── 08-feeling-lucky.md     Walking a stage 2 map unattended, and what that costs
│   └── team/                       ONLY WITH OTHER PEOPLE
│       ├── 01-metrics.md           Costing a pipeline run against story points
│       ├── 02-team-adoption.md     Rolling this out to a team
│       └── 03-massive-tickets.md   The *-massive flow: a map over an existing codebase,
│                                   walked over weeks. Solo charts the same case with
│                                   /charting and none of these three commands
├── examples/                       Two worked walkthroughs, narrated end to end
│   ├── solo-path-walkthrough.md    An idea through all four solo stages to the seam
│   └── ticket-flow-walkthrough.md  One ticket through /start-ticket
└── templates/
    ├── claude-md/    global · workspace · per-repo CLAUDE.md skeletons
    ├── agents/       ticket-analyzer · context-gatherer · planner · layer-specialist · repo-reviewer · pitch-judge · map-reviewer · decision-steward · …
    ├── skills/       tdd · engineering-standards · grilling · pitch · charting · bootstrap · cut-backlog · …
    ├── commands/     start-ticket · fix-ticket · test-ticket · resume-ticket · end-of-day · garden-memory · start-massive · resume-massive · build-chart-ticket · feeling-lucky · feeling-very-lucky
    ├── hooks/        block-dangerous-git · block-infra-staging · block-secret-staging · block-mcp-writes · …
    ├── mcp/          MCP config snippets (global + project) + settings snippet
    ├── trackers/     one adapter, installed at ~/.claude/tracker.md
    └── views/        pages a skill fills with data and you open in a browser
```

---

## How to use this playbook

**Steps 1–3 are the same through both doors.** Everything machine-level is shared. Only
step 4 forks.

1. **Understand the mindset** — [PHILOSOPHY.md](PHILOSOPHY.md) +
   [docs/shared/01-architecture.md](docs/shared/01-architecture.md).
2. **Stand up the two capabilities** — Serena + Forgetful
   ([docs/shared/02-prerequisites.md](docs/shared/02-prerequisites.md) →
   [docs/shared/03-setup.md](docs/shared/03-setup.md), steps 1–3).
3. **Global `CLAUDE.md`, one tracker adapter, the guardrail hooks** — setup steps 4, 5
   and 7. The adapter stops every later flow from having to know which tracker you use.
   The hooks are wired globally, so they are per-machine rather than per-project.

   **`./install.sh` does this part for you** (`.\install.ps1` on Windows, which checks
   for Git Bash or WSL and hands off). It walks `templates/`, lets you pick, pulls in
   the agents a command needs, fills the placeholders, wires the hooks and then proves
   the wiring by re-reading `settings.json`. After a `git pull`, `./install.sh update`
   refreshes what you already have without asking anything and names what is new;
   `./install.sh list` shows what is installed, outdated or available, and
   `./install.sh remove` reverses the whole thing. **None of them overwrite or delete
   anything you have edited** — they report it and move on. Steps 1–3 are still by
   hand: the script cannot stand up Serena or Forgetful for you.
4. **Then take your door.**

   **The agile path** — you hold a ticket someone else wrote.

   - **Next:** fill in the `CLAUDE.md` layers your repo count calls for — the repo's own on
     one repo, plus the workspace atlas on siblings
     ([06](docs/shared/06-claude-md-layers.md)). Then adapt the layer-chain to your stack
     ([11](docs/shared/11-adapting-to-your-stack.md)). This is the single most important
     adaptation.
   - **Then:** copy the agents/skills/commands you want and add the flows one at a time.
     Start with `/start-ticket`.
   - **Done when:** `/start-ticket` runs cleanly on a small real ticket.

   **The solo path** — you hold a raw idea.

   - **Next:** read [the spine](docs/solo/01-the-solo-path.md), then run `/pitch` on the
     idea. Do **not** create a repo first. A *build* verdict creates it for you.
   - **Then:** work the map one ticket per session, then `/bootstrap`, then `/cut-backlog`.
     The stack, the layer chain, the repo's own `CLAUDE.md` and the specialists are all
     decided and generated on the way. You write none of them by hand.
   - **Done when:** all eight
     [seam checks](docs/solo/01-the-solo-path.md#the-seam--where-the-solo-path-stops) hold.
     Then you are standing where the agile path starts.

You do **not** need everything on day one.

- **Agile path minimum:** Serena + Forgetful + a global CLAUDE.md + one `/start-ticket`
  command. Everything else is additive.
- **Solo path minimum:** the same, plus `/pitch`. The gate runs before a repo exists, so
  it is the one thing you cannot defer. It is also the cheapest hour on the path.

---

## Keeping this playbook fresh

Claude Code ships frequently. Templates and docs encoding current behaviour can
rot silently. Each doc carries a "Last verified against" line at the end. When you
upgrade Claude Code, run:

```bash
claude --version   # check what you now have
grep -rn "Last verified" docs/ PHILOSOPHY.md
# Then update each file's marker and audit for behavioural drift
```

**Templates carry no footer, by design.** A template is copied and edited, so a footer
would date your copy rather than the claim. They are covered instead by the
[re-verification check](templates/README.md#the-re-verification-check), run against the
whole directory. **No count here.** The list grows every time something turns out to need
running rather than reading, and a number in the front door goes stale the moment it does.

**Things most likely to drift:** MCP server configuration format, hook API,
`settings.json` schema, agent/skill frontmatter fields, and the directory layout under
`~/.claude/`.

---

## ⚠️ Before you commit any of this to a real repo

Two different rules, often confused. One is about secrets. One is about provenance.

**Secrets — never, in any repo, on any path.**

- Personal access tokens (git-host PAT, tracker token, cloud secrets)
- DB connection strings / credentials
- Customer identifiers or any raw PII

Templates use placeholders (`${GIT_TOKEN}`, `${TRACKER_TOKEN}`, `<YOUR-TRACKER-URL>`,
`34xxxxxxx`). Keep it that way.
[`block-secret-staging.sh`](templates/hooks/block-secret-staging.sh) enforces it at the
tool layer, so the rule does not depend on anyone remembering it.

**AI-infra files — it depends, and the test is one question:**

> **If you cloned this repo fresh on a new laptop, would you need this file?**

The repo's own `CLAUDE.md` and the generated layer specialists pass it and are committed.
Your memory store, handoffs, Serena's index and generated views fail it and never are.
[`block-infra-staging.sh`](templates/hooks/block-infra-staging.sh) sorts them, and
`git add -A` stays blocked regardless. The reasoning is in
[PHILOSOPHY.md §5](PHILOSOPHY.md) and, for the solo case,
[docs/solo/07-guardrails-when-solo.md](docs/solo/07-guardrails-when-solo.md).

> **The hooks need python on `PATH`** (`python3` or `python`, standard library only) to
> parse their payload. Without it the four blocking hooks **exit `2` and block** rather
> than waving the call through. A guard that cannot read the command stops it. Loud beats
> silent. But a missing python does turn into blocked tool calls, so check it in the same
> shell Claude Code uses, not just your usual terminal.
