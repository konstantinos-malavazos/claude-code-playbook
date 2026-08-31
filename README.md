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
├── LICENSE                         MIT
├── NOTICE                          third-party content shipped inside the templates
├── install.sh                      Interactive install / upgrade / remove (unix, WSL, Git Bash)
├── install.ps1                     Windows preflight — checks bash + python, then delegates
├── install-lib.py                  Discovery, hashing, the additive JSON merge, wiring checks
├── .gitattributes                  *.sh and *.py check out LF everywhere — a CRLF hook cannot run
├── .gitignore                      keeps local AI-infra out: .claude/ · .serena/ · CLAUDE.md · MEMORY.md
├── .github/
│   └── workflows/tests.yml         every suite below, on Linux and Windows, on push + PR
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
├── templates/
│   ├── claude-md/    global · workspace · per-repo CLAUDE.md skeletons
│   ├── agents/       ticket-analyzer · context-gatherer · planner · layer-specialist · repo-reviewer · pitch-judge · map-reviewer · decision-steward · …
│   ├── skills/       tdd · engineering-standards · grilling · pitch · charting · bootstrap · cut-backlog · next-steps · …
│   ├── commands/     start-ticket · fix-ticket · test-ticket · resume-ticket · end-of-day · garden-memory · start-massive · resume-massive · build-chart-ticket · encode-codebase · feeling-lucky · feeling-very-lucky
│   ├── hooks/        block-dangerous-git · block-infra-staging · block-secret-staging · block-mcp-writes · …
│   ├── mcp/          MCP config snippets (global + project) + settings snippet
│   ├── trackers/     one adapter, installed at ~/.claude/tracker.md
│   └── views/        pages a skill fills with data and you open in a browser
└── tests/                           offline, no model, no network — `bash tests/<name>`
    ├── test-wiring.sh               wiring that fails open: dispatch weight · next-steps · halt blocks
    ├── test-docs.sh                 the docs' own claims: links · counts · commands · layout tree
    ├── test-installer.sh            real installs into a sandboxed HOME, plus the static checks
    └── test-install-ps1.ps1         install.ps1's preflight, under PowerShell 5.1 and 7
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

   **`./install.sh` does this part for you** — see
   [Install, step by step for your OS](#install--step-by-step-for-your-os) below,
   which has the exact commands for Linux, macOS and Windows.
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

## Install — step by step for your OS

Pick your system. Every path ends at the same interactive installer.

**The installer covers setup steps 4–8 only.** It cannot install Claude Code, Serena or
Forgetful for you — those are steps 1–3, and **it will stop and tell you** if Serena is
missing rather than write an install that cannot run.

There is no `curl | sh` one-liner and there will not be one. `git clone` already *is* the
command that fetches everything from git; a bootstrap script would only wrap the same
lines in something you would have to download and read first.

---

### Linux

```bash
# 1. prerequisites — pick the line for your distro
sudo apt install git python3          # Debian, Ubuntu
sudo dnf install git python3          # Fedora, RHEL
sudo pacman -S git python             # Arch

# 2. Claude Code — see https://claude.com/claude-code, then authenticate
# 3. Serena — docs/shared/03-setup.md step 2. The installer refuses without it.

# 4. install the playbook
git clone https://github.com/konstantinos-malavazos/claude-code-playbook.git
cd claude-code-playbook
./install.sh
```

---

### macOS

```bash
# 1. prerequisites
xcode-select --install                 # git
brew install python3                   # or python.org; any Python 3.7+

# 2. Claude Code — see https://claude.com/claude-code, then authenticate
# 3. Serena — docs/shared/03-setup.md step 2. The installer refuses without it.

# 4. install the playbook
git clone https://github.com/konstantinos-malavazos/claude-code-playbook.git
cd claude-code-playbook
./install.sh
```

macOS still ships bash 3.2 as `/bin/bash`. The installer is written for it deliberately,
so there is nothing to upgrade.

---

### Windows

Windows needs one extra thing first, and it is not optional: **the six guardrail hooks
are bash scripts, and every one of them parses its input with Python.** A
native-PowerShell install would place hooks that cannot execute — and a hook that cannot
execute fails *closed*, jamming every command instead of guarding it. So Windows runs
them through Git Bash or WSL.

**1. Install bash.** Either one works:

- **Git for Windows** — <https://git-scm.com/download/win>. Includes Git Bash. Simplest.
- **WSL** — `wsl --install` in an admin PowerShell, then reboot.

**2. Install Python 3.7+, and make sure bash can see it.**

Python that works in PowerShell is **not** enough — the hooks run inside bash. The
Microsoft Store stub is the classic trap: it resolves in PowerShell and is missing in Git
Bash. Install from <https://www.python.org/downloads/> and tick **"Add python.exe to
PATH"**, then confirm in **Git Bash** (not PowerShell):

```bash
python3 --version
```

On WSL instead: `sudo apt install python3`.

**3. Install Claude Code** — <https://claude.com/claude-code> — and authenticate.

**4. Set up Serena** — [docs/shared/03-setup.md](docs/shared/03-setup.md) step 2.
The installer refuses without it.

**5. Install the playbook.** In **PowerShell** (not `cmd`), from where you keep your repos:

```powershell
git clone https://github.com/konstantinos-malavazos/claude-code-playbook.git
cd claude-code-playbook
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**Why not just `.\install.ps1`?** Because on a stock Windows machine that fails before
the installer runs at all:

```
.\install.ps1 : File ...\install.ps1 cannot be loaded because running scripts is disabled on this system.
```

Windows PowerShell ships set to `Restricted`, which blocks every `.ps1` file — yours,
ours, anyone's. `-ExecutionPolicy Bypass` lifts it **for that one command only** and
changes nothing on your machine. Nothing is installed differently; it is how the script
gets to start.

If you would rather type `.\install.ps1` here and from now on, allow local scripts for
your own account once — no admin needed, and it is the setting Microsoft recommends for
a development machine:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

One more, only if you downloaded a **ZIP** instead of using `git clone`: Windows marks
files from the internet, and `RemoteSigned` blocks those even after the change above.
Clear the mark with `Unblock-File .\install.ps1`.

`install.ps1` is a preflight, not a port. It checks that bash and Python are both really
there, then hands off to the same `install.sh` everyone else runs. If it cannot find
either, it tells you exactly what to install and changes nothing.

---

### What the installer does, on every OS

It walks `templates/`, lets you pick, pulls in the agents a command needs, fills the
placeholders, wires the hooks, and then proves the wiring by re-reading `settings.json`.

Five things worth knowing before you run it:

- **It stops if Serena is not set up**, before writing anything, and prints the steps.
  16 of the 20 agents halt and produce nothing without Serena, so a no-Serena install
  would be a success message over a setup that refuses to work.
- **`update` also stops if a recorded answer no longer means what it meant.** It replays
  what you answered at first install without asking again — correct only as long as those
  answers still hold. A recorded delete of `<memory-read-tools>` or `<memory-write-tools>`,
  which pressing Enter used to mean, no longer qualifies: it refuses before writing
  anything, names the token, and tells you to run `./install.sh` again to answer it fresh.
- **It shows you every file it is about to write**, and every `settings.json` key the
  hooks add, and asks. Answering no writes nothing at all.
- **It makes you choose a tracker adapter**, or say out loud that you are leaving it for
  later. `/start-ticket`'s first step reads the ticket through that adapter, so without
  one the flagship command stops on its first line.
- **If you already set this up by hand**, it finds your files and offers to adopt them so
  `update` can keep them current. Adopted files are never deleted by `remove` — the
  script did not write them.

### The other three commands

| Command | What it does |
|---|---|
| `./install.sh update` | after a `git pull` — refresh what you have, ask nothing, name what is new — though it can refuse outright |
| `./install.sh list` | what is installed, outdated, edited, missing, orphaned or available. Changes nothing |
| `./install.sh remove` | take back what it installed |

On Windows the same four words go to `install.ps1`, launched the same way as above:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 update
```

(Plain `.\install.ps1 update` works too, once you have run the one-time
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` from step 5.)

**None of them overwrite or delete anything you have edited** — they report it and move on.

`install` and `remove` are interactive and will refuse to run with no terminal attached.
`list` changes nothing and is always safe. `update` asks nothing either — but it can still
refuse: when one of the answers it recorded no longer means what it meant, it stops without
writing, and clearing that needs `./install.sh` from a real terminal. So an unattended
`update` can fail, and that is deliberate. Replaying a stale answer with nobody watching is
the worse outcome.

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
