# 07 — Guardrails when you are solo

The playbook's guardrails were written for a driver who does **not** own the code, the
repo, or the tracker. On the solo path you own all three.

[`PHILOSOPHY.md` §5](../../PHILOSOPHY.md) says so itself:

> *These are defaults with a reason, not laws. … On a project you own outright, ask what
> the rule was protecting and re-derive the right answer, rather than either obeying it
> blindly or deleting it.*

This doc is that re-derivation. Three of the four guardrails hold. Their **reason** is
rewritten, not their rule relaxed. One is replaced outright. And the guardrail that loosens
creates the need for a new one that the agile path never needed.

It says **why**. The hook scripts, the allowlist file and the bootstrap step that fills it
in belong to the sibling make. See [what this doc does not own](#what-this-doc-does-not-own).

---

## The finding all four verdicts hang off

§5 closes with a single rule of thumb:

> *if it's hard to reverse **or** leaves your machine, a human confirms it.*

**That is two tests, and nobody had noticed it was two.**

| Clause | What it actually tests | Solo |
|---|---|---|
| *hard to reverse* | **Reversibility.** Can I undo this? | **Untouched.** Owning the project does not make anything easier to undo. |
| *leaves your machine* | **Audience and reach.** Does this land where someone else can see it? | **The audience half goes.** It was doing all its work because the driver did not own the repo. |

**Reversibility was the real invariant. Audience was the context-dependent half all
along.** That finding produces every verdict below with no special-casing, which is the
test that it is the right finding rather than a convenient one.

It also dissolves an apparent contradiction §5 was about to acquire. The section now tests
two adjacent bullets **two different ways**: the tracker by *audience*
([#4/#13](../../templates/trackers/README.md)), push by *reach*. Read cold, that looks
confused. It is not. They are the two clauses of the rule of thumb, and each bullet is
governed by the one that still bites.

---

## The four guardrails

| # | Guardrail | Verdict |
|---|---|---|
| 1 | **You push; the agent doesn't** | **Holds**, reason rewritten, and it becomes a per-repo answer. |
| 2 | **Ask before writing where others can see** | **Holds as restated.** Already renegotiated; nothing reopened. |
| 3 | **§6 read-first, staging-only** | **Does not apply.** Replaced, not modified. |
| 4 | **AI-infra files are never committed** | **Holds**, with the path list replaced by a test. |

### 1. You push; the agent doesn't — holds, and becomes a per-repo answer

The **review** half is genuinely gone. Solo, nobody reads the PR and no CI gates a shared
main. The other half is untouched:

> **Push is where reversible becomes irreversible.**

A private repo is not a private disk. It sits on someone else's servers, in their backups,
and it can be made public in two clicks *with its whole history*.

**Where the audience rule and the blast-radius rule disagree, blast radius wins.** The
audience rule returns *write freely* for a private solo repo. The
[repo-folder line](04-the-bootstrap.md#the-repo-folder-is-the-line) says the repo folder
is the boundary, and push leaves it. That rule was already settled as the right one for a
solo builder, and this is the same case arriving again.

**But it is not one answer for the machine, and that is the whole reason for the
mechanism below.** The obvious move is *these are my repos, delete the hook*. It fails on a
concrete fact: the hooks are wired in `~/.claude/settings.json`, so they are **global. One
install, every repo.** Deleting the push block to unblock a weekend project also unblocks
the live project sitting two folders over. One machine, several projects, one of them
live. So the hook stays installed and **asks, per repo**.

#### And when the answer is *yes*, the agent pushes

The allowlist has always had a `push` column, and until now every flow declined anyway:
*"a flow that declines to push on a repo the hook would permit is not a contradiction"*
([below](#what-this-doc-does-not-own)). That was a defensible default. It is no longer the
one this playbook takes.

> **On an allowlisted repo, an agent that finishes work commits and pushes its branch.**
> Not listed still means no, and that is unchanged.

**Nothing about the guardrail moved. The flows stopped adding a second, invisible no.** Two
answers to one question is how you get a rule nobody can find the source of. You allowlist
a repo, nothing pushes, and there is no way to tell whether the hook refused or a prompt
did. The hook is the authority, and now it is the only one.

**What is still yours** is the merge. On the shared pipeline the agent pushes the branch and
you open and merge the PR. The review half of this guardrail was already gone solo. But
*merge* is the step that makes a change the trunk's problem rather than a branch's.

**The one flow that goes further is [I'm feeling lucky](08-feeling-lucky.md)**, which pushes
to `main` directly. It earns that by where it runs and nowhere else: stage 2 is a private
stub with no deployment, no consumers and no other contributors. So its `main` is not a
shared trunk. It is the only branch of a repo nobody else has. **That reasoning expires the
moment the repo has a consumer**, which is also the moment charting is over.

### 2. Ask before writing where others can see it — holds as restated

Already decided, already landed, and deliberately not re-argued here. §5 reads *ask before
writing anywhere other people can see it*. The test is **audience, not tracker**. Private
solo repo: write freely. **Public** repo: ask, because "nobody is watching" stopped being true.

It survives the reversibility frame too: **a tracker comment is editable and deletable.**
Each adapter declares which kind of place it is. See
[`templates/trackers/README.md`](../../templates/trackers/README.md).

### 3. §6 read-first, staging-only — does not apply; replaced, not modified

A weekend project has **no staging tier**, so the rule as written has nothing to point at.

The danger does not go away. It moves **off the environment axis entirely**. Four things a
solo project actually touches:

| What it touches | Undoable? |
|---|---|
| Your local database | **yes** — wipe it and start over |
| A real email service | **no** — it landed in someone's inbox |
| A payment API in live mode | **no** — a real card was charged |
| Your own real files (the photo organiser renaming your actual photos) | **no** — that was the only copy |

**Two of those four are third-party services where a staging tier never existed**, and one
is your own hard drive. A staging/production distinction cannot express the rule even in
principle. That is why §6 is replaced rather than adjusted.

The replacement is the same test as everything else on this page, which is the rule of
thumb with both clauses intact:

> **Can I undo it, and does it touch anyone but me?**

The agent works freely against anything local it can recreate. You confirm anything that
**spends money**, **sends something to another person**, or **touches your only copy of
real data**. The MCP half already has teeth:
[`block-mcp-writes.sh`](../../templates/hooks/block-mcp-writes.sh) exists and is unchanged.

**Knock-on for [`/test-ticket`](../shared/07-the-flows.md#the-standout-feature-test-ticket-learns):
on the solo path it runs against local.** Only *staging only* has nothing to mean. The
valuable half survives intact: **produce the event for real, then go and check the row
actually changed**. So does the recipe it banks in memory. A test that asserts on a
mock proves the mock works. That was never the point of the flow.

### 4. AI-infra files are never committed — holds, with the path list replaced by a test

This is the guardrail that broke, and it broke in **both directions at once**:

| | The hook says | Correct? |
|---|---|---|
| The bootstrap's `CLAUDE.md` (written by [step 3](04-the-bootstrap.md#the-eight-steps)) | never stage | **wrong** — a fresh clone needs it |
| The [dependency viewer's](../../templates/views/README.md) page in `.claude/` | never stage | **right** — one command regenerates it |

Same hook, same rule, opposite verdicts. So **the defect is not the path list. Carving out
an exception for `CLAUDE.md` would repeat the original mistake one level down.**

> **The class, not the instance: a rule about *provenance* was expressed as a rule about
> *paths*.** `.claude/` and `CLAUDE.md` are usually AI plumbing, so paths were a good
> proxy, right up until a stage started legitimately producing files at those paths. Any
> guardrail that names locations instead of origins has this failure waiting in it.

**The test that replaces the path list:**

> **If you cloned this repo fresh on a new laptop, would you need this file?**

| File | Fresh clone needs it? | Verdict |
|---|---|---|
| The repo's own `CLAUDE.md` | **yes** — otherwise you re-derive the stack, the chain and the Serena verdict from nothing | commit it |
| The generated **layer specialists** and per-layer **standards skills** | **yes** — they are facts about *this* codebase | commit them |
| The dependency viewer's page | no — one command regenerates it | never |
| `MEMORY.md`, `.forgetful/`, `.serena/`, handoffs | no — that is your machine, not the project | never |

**So "is `.claude/` part of the product?" has no per-directory answer.** The question is
per **file**, and the test above answers it. The viewer is not part of the
product, and the hook refusing to stage it is
[the enforcement, not the obstacle](../../templates/views/README.md). The viewer's
placement rests on that part, and it is untouched. What is **not** true is the wider
claim that everything under `.claude/` is plumbing: the
[layer specialists](04-the-bootstrap.md#step-5--stage-3-is-where-the-layer-specialists-get-made)
live there and are committed.

> **This exception was predicted before it existed.** The rule was written down as *never
> commit `.claude/` — **while `.claude/` contains nothing a fresh clone needs.*** The very
> next ticket put something there that a fresh clone needs. A path rule that has to state
> its own escape condition is telling you it is the wrong shape.

**`.gitignore` has to sort the same way the hook does, or the flip buys nothing.** Two
independent things stop a file entering git. The hook blocks the *command*. `.gitignore`
makes the file invisible to it. The dependency viewer's page needs the second one. The hook
stops it being committed, but nothing stops it showing as untracked noise. A blanket
`.claude/` ignore line would silence that, but it would also hide the specialists that are
supposed to be committed. **Whatever writes that line writes the exceptions with it.** Two
guardrails on one directory, living in different files, is how a rule ends up half-enforced
without anyone deciding it should be.

> **This playbook did it to itself, in the commit that added the credential hook.** This
> repo's `.gitignore` carries `*secret*`. So `block-secret-staging.sh`, a template *about*
> credentials, was invisible to `git add` from the moment it was written. It failed
> silently, with no error. **A pattern that matches on the name cannot tell a secret from a
> file about secrets**, which is the same sentence as *a rule about provenance expressed as
> a rule about paths*, one directory over.

**Does the bootstrap commit, then? Yes, and only on an all-green report.** Something has
to commit that `CLAUDE.md`. [`/start-ticket`](../shared/08-ticket-pipeline.md) is told
never to commit AI-infra files. So with no commit at stage 3 the file stays untracked
forever, which is the exact thing it exists to prevent. Green means the stub builds, the
chain is declared and the specialists exist. That is a real starting point worth having in
history. **Red means the stack or the setup is wrong**, and on day one the recovery is to
delete the folder and start again. There is nothing worth preserving. See
[the exit test](04-the-bootstrap.md#the-exit-test).

---

## The mechanism: one allowlist, outside every repo

Three of the four verdicts above end in *"the answer is per repo"*. That answer has to live
somewhere, and **where** is the whole design.

**It lives in `~/.claude/`, not in the project.** Put it inside the repo — a marker file,
or the repo's own `.claude/settings.json` — and **the agent could write it and unblock
itself**. §5's headline is *enforced by the harness, not by trust*. A guardrail the
model can switch off is a suggestion with extra steps.

One file. One entry per repo, keyed by **remote URL rather than folder path**. What push
risks is *where the content goes*, and keying on a folder path is the same rule-about-paths
mistake the section above just retired. Two answers per entry, **both defaulting to no**:

1. **May the agent push here?**
2. **Is this repo's `CLAUDE.md` its own?**

```
   ~/.claude/  ─── outside every repo, so the agent cannot write it ────────┐
   ┌──────────────────────────────────────────────────────────────┐        │
   │  THE ALLOWLIST — keyed by remote URL                          │        │
   │    …/weekend-project      push: yes    CLAUDE.md: yes         │        │
   │    …/photo-organiser      push: yes    CLAUDE.md: yes         │        │
   │    (the live project — not listed, therefore blocked)         │        │
   └──────────────────────────────────────────────────────────────┘        │
        ▲                                    │                             │
        │ YOU answer, once, during           │ the hooks read it           │
        │ the bootstrap                      ▼                             │
        │                        ┌───────────────────────────┐             │
        │                        │  agent runs git push      │             │
        │                        │  agent stages CLAUDE.md   │             │
        │                        └───────────┬───────────────┘             │
        │                                    ▼                             │
        │                        listed, with a yes? ── no ──► BLOCKED     │
        │                                    │                             │
        │                                   yes                            │
        │                                    ▼                             │
        │                                 allowed                          │
        └──────────────────────────────────────────────────────────────────┘
              git add -A / git add .  ──►  BLOCKED, always, everywhere
```

Three properties fall out, all of them wanted:

| Property | Why it matters |
|---|---|
| **A repo you never listed is blocked** | New repos are safe with **no action from you**, and the live project stays safe **by omission rather than by being remembered**. |
| **The agent adding a line is a crossing you see** | The [repo folder is the line](04-the-bootstrap.md#the-repo-folder-is-the-line) and this file sits outside it. The bootstrap **asks**, and you answer. |
| **`git add -A` / `git add .` stays blocked regardless** | The accidental sweep — the case §5 was really written for — is untouched by any of this. |

**A bash script cannot judge provenance. You can.** So the human declares it once and the
hook obeys. That is worth saying plainly rather than pretending the script got smarter.
Every guardrail on this page is still enforced by the harness. The only thing that
moved is **who supplies the one fact the harness cannot work out for itself**.

> **The seam stays eight checks.** The allowlist question is a **bootstrap step**, not a
> seam item, because it makes nothing true that the seam is testing for. See
> [the seam](01-the-solo-path.md#the-seam--where-the-solo-path-stops).

---

## The guardrail this created

**Secrets.** Nothing in the playbook blocks committing a credential. The hooks guard
AI-infra paths only.

That was survivable **because the human did every push, and you see the diff**. Loosening
the push block took that away. So the push block was quietly doing **secret-leak
protection**. Removing it leaves a hole with a concrete shape:

> The agent writes `.env` with a live key, commits, pushes. The repo is private, so it
> feels fine. **Six months later you make it public to show someone, and the key is in the
> history.**

Hence one new hook, in the same shape as
[`block-infra-staging.sh`](../../templates/hooks/block-infra-staging.sh) with a different
list: `.env`, key files, and obvious token patterns.

**This exists because this path loosened push, not as general hygiene.** Worth recording,
because a guardrail whose reason is forgotten is the next one somebody deletes.

---

## Two things that are habits, not guardrails

The ticket that produced this doc named two more candidates. Both are **real problems**.
Neither is a guardrail. So this doc writes them down as habits **and labels them as such**:

| | Why it is not a guardrail |
|---|---|
| **Cost** — no employer is paying, and a background agent burns your own money | **A hook cannot see token spend.** The useful half is already done by choosing a sane default effort level rather than the most expensive one. |
| **Skipping review** — solo, you can just not run the reviewers | **You can always decline to type the command.** Nothing at the tool layer can make you read the diff. |

**This is the one section whose entire premise is that guardrails are the things trust is
not required for.** Calling these two guardrails would be dressing up wishes, in the
section least able to afford it.

### If you want to measure the cost habit

**Optional, and yours to shape.** Pick numbers that would change what you *do*. A metric
nobody acts on is overhead. What survives from `PHILOSOPHY.md` §8 is its point: *"is
this getting more efficient?"* deserves a number rather than a feeling. What does not
survive is the team ledger's units. Story points need an estimating ceremony you do not
have, and tokens-per-point is priced for a team justifying tooling spend to someone else.

**The unit is one shipped work unit**, which is one thing the app can now do
([05-cutting.md](05-cutting.md)). So nothing is ever estimated. Not a **session**: a
session runs until the context window fills, so it costs about the same every time and
cannot show an improvement. Not a **stage** either, because each runs once per project, and
a number you only ever see once has no trend. You can only measure something that repeats.

Two that are worth having, chosen because they cost nothing to collect:

| Number | What it looks like | What you do when it moves |
|---|---|---|
| **Sessions per work unit** | `login 5 · search 2 · export 2 · password reset 4` | Climbing means the units are too big, or the stack was wrong — the backwards step |
| **Kill-gate outcomes** | `9 ideas — 6 killed, 1 parked, 2 built` | All-build means [`/pitch`](02-the-kill-gate.md) has become a rubber stamp |

**Tokens are deliberately not a headline.** Solo they are close to a restatement of
sessions-per-unit, and they are the expensive one to gather. `/goal` reports turns and
tokens, but it resets its baseline on every `--resume`, so you have to sum a multi-session
unit by hand. Add them the day you start hitting usage limits. At that point they stop
being a copy and start being the thing that bites.

**Nothing collects any of this, and that is not a gap.**

- The kill-gate count **cannot** be automated. The ideas file lives outside every repo on
  purpose ([02-the-kill-gate.md](02-the-kill-gate.md)), so no hook and no command in a
  repo can see it. Half-automated metrics are worse than none. They look complete, so
  you stop checking the half they missed.
- A hook here would be **global**. It is wired in `~/.claude/settings.json`, so a metrics
  hook for a weekend project runs on the paying work too. That is the same reasoning as
  the allowlist above.
- A ledger would be a **second copy**. The tracker keeps every ticket and comment, and a
  kill is a recorded no rather than a deletion, so both sources are already permanent.
  Regenerating beats storing. A stored copy only adds something to drift.

So you ask, in a normal session, when you want to know. The **feeling is allowed to be the
trigger, never the answer**. Feeling slow is what sends you to look. The number is what
tells you whether you were right. §8 forbids skipping the second step, not the first.

**The memory eval is the one worth keeping even here.** `/garden-memory`'s golden-query
pass ([10-memory-hygiene.md](../shared/10-memory-hygiene.md)) survives solo for a reason
none of the above have: **you cannot notice a memory that never came back.** A wrong
answer you catch yourself, because you are the only reader. Silence you do not. You banked
why library X went badly. Nothing retrieves it when you pick a library, and you quietly
repeat a decision you already paid for. Being solo is no help against that at all.

It does not start on day one. The bootstrap seeds **two** memories, and you cannot write
golden queries for two things you know by heart. Start when the memory index no longer
fits on one screen. Below that you read the whole thing in ten seconds and you *are* the
eval. How often to run it after that is memory hygiene's question, not this page's.

---

## What this doc does not own

| Owned elsewhere | Where |
|---|---|
| The hook scripts, the allowlist file, the new secrets hook | [`templates/hooks/`](../../templates/hooks/README.md) and its test suite, the sibling make. **You cannot verify these scripts by reading them. Run `test-hooks.sh`.** |
| The bootstrap's step list and step count | [04-the-bootstrap.md](04-the-bootstrap.md) |
| §5 and §6 themselves | [`PHILOSOPHY.md`](../../PHILOSOPHY.md) — pointed at from here, never restated there |
| The per-ticket metrics ledger, story points, cost columns | [01-metrics.md](../team/01-metrics.md) — **the team instance**, not the general rule. Its machinery exists to serve points and dollars, and solo has neither. |
| How often to run the memory eval | [10-memory-hygiene.md](../shared/10-memory-hygiene.md) — this page says *when it starts mattering*, never *how often* |
| Which flows push, and when | [07-the-flows.md](../shared/07-the-flows.md), [08-ticket-pipeline.md](../shared/08-ticket-pipeline.md). The hook says what is *possible*. A flow says what it *does*. **And since [the push answer above](#and-when-the-answer-is-yes-the-agent-pushes), no flow declines a push the hook would permit.** A flow may still stop short of the *merge*, which is a different verb. |

Everything on this page is on disk:
[`repo-allowlist.sample`](../../templates/hooks/repo-allowlist.sample),
[`block-secret-staging.sh`](../../templates/hooks/block-secret-staging.sh), the two-way
sort in [`block-infra-staging.sh`](../../templates/hooks/block-infra-staging.sh), and the
`.gitignore` exceptions that make the sort mean anything.

---

## Why this doc exists

The stage docs tell you what the bootstrap writes and what the seam checks. Neither
answers the question you are holding the first time a hook blocks something you actually
meant:

- **Three guardrails hold and one is replaced, and it is not the split you would guess.**
  The one that goes is §6, the one that sounds most like real-infrastructure caution.
- **The rule of thumb was two rules the whole time**, and solo deletes exactly one of them.
  Everything else on this page is that sentence applied four times.
- **The path list was the bug, not the paths.** Provenance expressed as location works
  until your own flow starts producing files at those locations. Then it fails in
  *both* directions on the same hook.
- **Loosening a guardrail can create the need for a new one.** Push was doing a second job
  nobody had written down.
- **Cost and review are not guardrails**, and the honest thing is to say so rather than
  ship a rule with no teeth.

Read this before your first bootstrap, alongside
[04-the-bootstrap.md](04-the-bootstrap.md). That stage asks you the two allowlist
questions, and it is where the first commit happens.

---
> **Last verified against:** Claude Code `2.1.226` — August 2026
