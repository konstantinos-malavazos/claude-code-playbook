---
name: bootstrap
description: >-
  Scaffold a decided-but-empty repo until the implementation pipeline's preconditions are
  true — the stub, CLAUDE.md, Serena if the verdict calls for it, the layer specialists,
  the tracker adapter check, two memories — then run every check once and report. Use
  when charting has closed with a named stack, or the user says "bootstrap the repo" /
  "scaffold it" / "make the repo real". NOT for a repo that already builds, and NOT for
  choosing a stack.
disable-model-invocation: true
---

# Bootstrap — make the preconditions true, then report

This is **stage 3** of the solo path. Everything has been decided and nothing has been
built. You make it real, prove it, and hand over a report.

> The stage is **the bootstrap**. The output is a **report**. The stage can finish while
> the report is red.

**Decide nothing.** Every choice this stage needs was made one stage earlier. If you find
something that genuinely needs deciding, **stop and say so** — that is the backwards step,
and it is the human's to take.

## Before the first step

Five things must already exist. Check all five before touching anything.

| | Where it comes from | If it is missing |
|---|---|---|
| The repo, and it is empty | the kill gate created it | **You scaffold; you never create.** Stop. |
| The stack, named | charting's tail, ticket 1 | Stop. Charting is not finished. |
| The layer chain, named | charting's tail, ticket 1 | Stop. Same reason. |
| The Serena verdict | charting's tail, ticket 1 | Stop. Do not assume *yes*. |
| The bootstrap checks — build, run, test, symbol | charting's tail, ticket 2 | Stop. You have nothing to prove anything with. |

**Do not fill a gap by choosing.** A missing stack is not an invitation to suggest one; it
means the stage before this one has not finished. Say which of the five is missing and stop.

## The line — where you work alone, and where you stop

You work **alone inside the repo**. You **stop** for everything else.

> **Before every write, ask one question: does this land inside the repo you are
> bootstrapping?**
>
> - **Inside it** → do it. Do not ask, do not narrate, do not seek approval.
> - **Anywhere else** → **stop.** Show what you are about to write and where, and wait.

Apply the test to the path in front of you, every time. **Do not carry a list of known
crossings** — a list is right until something new starts writing somewhere new, and then it
is silently wrong.

Two clarifications that make the test decidable:

- **Reads are unrestricted.** The line is about writing. Reading a global config, a
  template, or the tracker adapter is free.
- **A write with no path is outside.** Memory has no path. Neither does a tracker comment.
  If you cannot answer *"is this inside the repo folder?"* with a path, the answer is
  **outside**, and you stop.

The reason, in one sentence: **everything inside a fresh git repo is undoable with
`git checkout .`, and nothing outside it is.**

## The eight steps

In order. Steps 2–8 each need something the one before them produced. Step 1 does not —
it is first because it is the only one that is not yours to do.

| # | Step |
|---|---|
| 1 | **Ask** the two allowlist questions, and wait |
| 2 | Scaffold the stub |
| 3 | Write the repo's `CLAUDE.md` |
| 4 | Index Serena — **only if the verdict says yes** |
| 5 | Generate the layer specialists and the stack skills |
| 6 | **Verify** the installed tracker adapter |
| 7 | Write the two memories |
| 8 | Run every check, report once, stop |

### 1 — Ask the two allowlist questions, and wait

`~/.claude/repo-allowlist` is outside the repo, so this is the line, and the line says
**stop**. Ask both questions, show the exact line you propose to add, and **wait for an
answer.** Do not add a line on their behalf, and do not read the file and assume.

| Ask | Because |
|---|---|
| **May I `git push` on this repo?** | Otherwise every push in this repo's life is blocked. |
| **Is this repo's `CLAUDE.md` its own — would a fresh clone need it?** | Step 3 writes that file and step 8's commit stages it. Unanswered, the stage cannot finish. |

**Ask before you scaffold, not when you hit the wall.** Everything after this step runs
unattended; stopping in the middle of it to ask is worse than asking first.

If the answers are *no*, that is a valid outcome, not a failure — you carry on and the
final commit stages neither `CLAUDE.md` nor the generated agents. Say so in the report.

### 2 — Scaffold the stub

Run the framework's own generator. Then create **one empty folder per layer of the chain**.

- **Write no application code.** There is no application. A generator skeleton that builds
  and starts is the whole deliverable of this step.
- The folders are placeholders that step 5 will point agent files at. Getting one wrong
  costs a `git mv`; leaving it out costs a specialist that names a path which does not exist.

### 3 — Write the repo's `CLAUDE.md`

From `templates/claude-md/repo.CLAUDE.md`. Six things must land in it:

| | |
|---|---|
| The stack | as named by the tail |
| Build / test / run commands | as written by the tail |
| **The branch this repo ships from** | **detect** it — `git symbolic-ref refs/remotes/origin/HEAD` — do not ask. This is the only place it lives; the global `CLAUDE.md` holds the workflow that reads it |
| The layer chain | you are **copying** it, not choosing it |
| **The Serena verdict**, and one line of why | this is the only place it lives |
| **The settled names** | **copy** them from the map's Notes, which charting pruned at the tail. This is the second and final home — see *One name per thing* in the `charting` skill. **None is a valid answer**: an effort that settled no names leaves the section empty, and the seam still passes |

Keep it lean — the facts that stop a wrong turn, not a description of the repo. Step 5
reads the chain back out of this file, and the seam reads the verdict out of it.

### 4 — Index Serena, if the verdict says yes

**Read the verdict from the `CLAUDE.md` you just wrote.** Do not decide it, and do not
default to indexing because indexing seems harmless.

| Verdict | What you do |
|---|---|
| **yes** | Index the repo, then run the tail's symbol check and confirm it returns **real results**, not empty. |
| **no** | Skip the step. Record it in the report as *skipped — verdict no*, which is a pass, not a gap. |

**A sparse index on a real stub is a red check, not a retry.** Report it and move on. Never
fall back to globbing the tree or reading whole files to compensate.

### 5 — Generate the layer specialists and the stack skills

One specialist agent per layer of the chain, plus the stack's skills. **Run
`/adapt-to-stack`**; it reads the `CLAUDE.md` step 3 just wrote and generates both, and
each specialist names the folder step 2 created for its layer.

- **Call the generation flow; do not reimplement it.** How these files are written is not
  this stage's business. This stage owns *when* — here, after the chain exists and the
  folders are on disk.
- **If the generated files land outside the repo, the line applies.** Show them and wait.

### 6 — Verify the tracker adapter

Read `~/.claude/tracker.md` and confirm it is the adapter for **this project's** tracker.

> **Verify, never install.** Installing an adapter is a global setup act, and it already
> happened — the kill gate wrote a map into a tracker a whole stage before you ran.

The failure this catches is silent and normal: work on one tracker, home projects on
another. If the installed adapter is the wrong one, or missing, that is a **red check**.
Report it. Do not install one to make the check pass.

### 7 — Write the two memories

| | |
|---|---|
| **Memory one** | *What this project is and who it is for.* **Charting already wrote it.** Confirm it exists; do not rewrite it. |
| **Memory two** | **Why this stack, why this chain, and what was ruled out.** |

**Memory two contains no facts.** Do not restate the stack name, the chain, or the
commands — all three are in `CLAUDE.md`, which is loaded every session, while a memory is
retrieved by meaning. Write only the reasoning, which lives nowhere else.

Memory is outside the line. **Show both memories before writing them, and wait.**

### 8 — Run every check, report once, stop

The last step is the exit test, below. **On an all-green report, and only then, make one
commit** — explicit paths, never `git add .`. Red commits nothing: on day one the recovery
is to delete the folder and start again, and there is nothing worth keeping in history.

## The exit test

Run **every** check the tail wrote. All of them. Every time.

> **Do not stop at the first red.** This is deliberate, not an oversight, and it is the one
> instruction here most likely to get "helpfully" corrected: **the human classifies the
> failure by counting the reds**, and they cannot count what you did not run.

Produce **one** report, in this shape:

```markdown
## Bootstrap report — <repo>

| # | Seam check | Result | Evidence |
|---|---|---|---|
| 1 | The stack is named | pass | `CLAUDE.md` line N |
| 2 | The stub builds and runs | pass / FAIL | the command, and its output |
| 3 | The layer chain and the settled names are declared | pass | `CLAUDE.md` line N, and the names on the map's Notes matched against it |
| 4 | Serena matches the verdict | pass / skipped — verdict no / FAIL | the symbol query, and what came back |
| 5 | The tracker adapter matches this project | pass / FAIL | which adapter is installed |
| 7 | Two memories exist | pass / FAIL | their titles |
| 8 | The layer specialists exist | pass / FAIL | one path per layer |

<N> of 7 pass.
```

**Seven rows, not eight. Item 6 — *the backlog exists* — is stage 4's**, and this report
cannot speak to it.

**Every row carries evidence.** A `pass` with nothing beside it is an opinion; the whole
value of the report is that the human can check it without re-running anything.

**Then classify nothing and stop.** A red check is either a wrong check or a wrong stack,
and which one it is decides whether the map gets reopened. That judgement is the human's,
it is the most expensive one on this path, and it is not yours to pre-empt — not even as a
suggestion at the bottom of the report.

## Where you stop

Five stops, and none of them is a failure of the stage:

| You stop when | And you say |
|---|---|
| **Step 1, before anything else** | the two allowlist questions, and the exact line you propose to add |
| A write lands outside the repo | what you are about to write, and where |
| One of the five inputs is missing | which one, and that charting is not finished |
| The report is done | nothing more — no classification, no fix, no re-run |
| Something genuinely needs deciding | what it is, and that it is a decision, not a step |

## Stop condition

**The stage is done when the report exists** — plus one commit if it is green. Not when
every check is green.

A red report is a *finished* stage. This stage's job is to produce the verdict, not to
guarantee it is a good one — and a stage that keeps working until everything passes is a
stage that will quietly change a decision to get there.

## Safe to re-run

**A session that dies partway is resumed by running `/bootstrap` again.** Each step checks
the disk and skips itself. Nothing records where you stopped; you re-derive it by looking.

| # | Step | What it leaves, so a re-run can skip it |
|---|---|---|
| 1 | Ask the allowlist questions | the lines in `~/.claude/repo-allowlist` |
| 2 | Scaffold the stub | the stub, and one folder per layer |
| 3 | Write `CLAUDE.md` | `CLAUDE.md` |
| 4 | Index Serena | the index — or *verdict no*, which `CLAUDE.md` records |
| 5 | Generate the specialists | the agent and skill files. **Already idempotent** — `/adapt-to-stack` creates what is missing and never overwrites |
| 6 | Verify the tracker adapter | **nothing** |
| 7 | Write the two memories | the two memories |
| 8 | Run every check, report | the commit — **green only** |

**Do not write a progress file.** Not `.claude/bootstrap-progress.md`, not a marker line in
`CLAUDE.md`, not anything else. It is a second copy of what the disk already says, and it
can be wrong while the disk is right.

**The report is not written anywhere either** — a file for it is the progress file under
another name. To find out whether stage 3 finished, run it again: every step skips itself,
every check runs, and the report prints.
