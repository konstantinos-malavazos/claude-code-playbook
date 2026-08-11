# 08 — I'm feeling lucky (charting while you sleep)

Every other doc on this path assumes you are sitting there. This one is for when you are
not.

**I'm feeling lucky is a mode, not a fifth stage and not a third entrance.** Same four
stages, same [seam](01-the-solo-path.md#the-seam--where-the-solo-path-stops), same docs. It
drives **[stage 2 — charting](03-charting.md)** and nothing else. It changes exactly two
things: **who drives the loop**, and **who answers a `grilling` ticket**.

| | Ordinary charting | Feeling lucky |
|---|---|---|
| Who drives | you, one ticket per sitting | a loop, one ticket per iteration |
| Who answers a `grilling` | you | two agents, on the record |
| What ends it | you stop typing | a halt condition fires, or the map does |

---

## What it is actually doing, plainly

A stage 2 map is **mostly decisions**: *"charting produces decisions by default"*
([03-charting.md](03-charting.md)). The only make the path guarantees is the very last
ticket on it. So this mode is not clearing a mechanical backlog while you sleep. There is no
mechanical backlog here yet, because the repo is a stub.

**It is answering your open design questions from the record, overnight, and telling you
every one it had to guess at.**

That is a bigger thing to hand over than it sounds. The whole design below exists to make
it survivable. Every answer carries a **basis**. Every guess lands in one file you read in
the morning. And the decisions expensive enough to matter stop the walk instead.

---

## Three hard requirements

### 1. The tracker must not be a shared place

**Any adapter works.** [Every verb works on every
adapter](../../templates/trackers/README.md), and there is nothing about a hosted tracker a
loop cannot drive. GitHub claims and closes perfectly well.

What the mode refuses is a **shared** one. Both adapter files open by asking exactly this:
*"Is this a shared place?"* ([github.md](../../templates/trackers/github.md),
[local-markdown.md](../../templates/trackers/local-markdown.md)). The answer is written
into the adapter itself. If the answer is yes, the walk stops before iteration one.

This is [guardrail 2](07-guardrails-when-solo.md) applying unchanged: *ask before writing
where others can see it*. That doc keeps it as-restated rather than relaxing it. A night of
unattended comments and closes is the largest single batch of tracker writes this playbook
can produce. It is also the one nobody read first.

**The audience clause is the half that survives here.** The reversibility clause is not
doing the work: closing a ticket is trivially reversible, and being seen is not.

### 2. The frontier must be asked, never read off a summary

This is a **hard rule about how the walk computes the frontier**, and on one adapter it
changes which call you make.

> **Blocking is a question, not an edge.** The verb is *"can I start this right now?"*, and
> the adapter goes and checks ([`trackers/README.md`](../../templates/trackers/README.md)).
> A stored `Blocked by:` line is a claim about the past. **So is a cached count.**

[local-markdown](../../templates/trackers/local-markdown.md) and
[Jira](../../templates/trackers/jira.md) already comply by construction: one reads each
blocker's file for `resolved`, the other reads each blocker's real `statusCategory`. Both ask.

**GitHub's stated frontier query does not**, and it is the one place this bites:

> The frontier call filters on `issue_dependencies_summary.blocked_by`, a derived count.
> That count **lags a close**. Verified: closing a blocker and immediately reading the
> blocked ticket returned `blocked_by: 1`, while GraphQL `blockedBy` showed every blocker
> already closed. *"The same instant, two endpoints, two answers."* It settled about thirty
> seconds later, with no intervening write. The trap's own words are that **"the frontier
> query silently hides a ticket that just became takeable"**
> ([github.md](../../templates/trackers/github.md)).
>
> With you driving, that is a shrug: you re-read and carry on. **In a loop it corrupts the
> one thing the loop runs on.** Iteration *n* closes a blocker. Iteration *n+1* computes the
> frontier seconds later, and the newly takeable ticket is invisible. If it was the last one,
> the walk reads *frontier empty*, decides the map is finished, and stops for the night on a
> map with work left in it.

**The fix is in the same file and costs nothing.** *"The summary is eventually consistent;
the graph is not."* The [whole-graph call](../../templates/trackers/github.md) returns
`blockedBy` as a real connection: one GraphQL request, verified at 1.3 s on a 35-child map.
It was correct at the same instant the count was wrong. **On GitHub the walk computes its
frontier from that call, never from the REST summary.**

The adapter note prescribes *"re-read before believing a count you did not expect"*. That
instruction has a reader in it. Unattended there is nobody to be surprised, so the rule has
to move from the reader into the query.

### 3. The map must already have decided something

Both commands refuse on a map with **fewer than three closed tickets**.

`grounded` means *the record settles this*. An empty record settles nothing, so every early
answer would be `guessed` or `yours`. The mode would halt on iteration one. Worse, under
`--very`, it would decide your entire product from nothing. Three closed tickets is not a
magic number. It is the smallest record that can ground anything at all.

**Chart the first few decisions yourself.** That is the part where you find out what you
actually think. It is also the part the steward is worst at.

---

## Why nothing else on this path is lucky

The other three stages each have a reason they want you, and none of them is squeamishness.

| Stage | Why it is not lucky |
|---|---|
| 1 — the kill gate | It is **one sitting**, and it already runs agents. There is no loop to drive. An unattended gate also hands itself the *build* verdict, which is the one verdict nobody should mark their own homework on. |
| 3 — the bootstrap | Already unattended after its first step, by design ([04-the-bootstrap.md](04-the-bootstrap.md)). Nothing left to automate. |
| 4 — cutting | Its exit condition is literally *"and **you approved them**"* ([01-the-solo-path.md](01-the-solo-path.md)). A mode that approves the backlog for you has deleted the stage, not automated it. |

Charting is the only one that is **a loop over many sessions**, which is the only shape a
driver can drive. The other three run once each.

> **The massive-ticket flow is a different path and this mode does not touch it.**
> `/start-massive`, `/resume-massive` and `/build-chart-ticket` walk a map over a codebase
> that already exists, from a ticket somebody handed you. They are
> [team-only](../team/03-massive-tickets.md), so a solo install does not carry them at all.
> That makes this rule easier to keep, but not redundant. Nothing here drives them, and
> nothing here should be read as permission to answer a `grilling` on that flow.
>
> **Nor on your own map, once the repo is no longer greenfield.** This mode is scoped to
> **stage 2**, not to solo. Charting a codebase you already shipped is a case you keep
> ([03-charting.md](03-charting.md)), but you walk that map yourself.

---

## The two commands

```
/feeling-lucky <effort-slug>          walks the map. Stops when it has to guess at
                                      something it cannot take back, or at something
                                      that is yours to say.

/feeling-very-lucky <effort-slug>     walks the map. Stops only when the map stops, the
                                      map turns out to be broken, or the budget runs out.
                                      Every guess is logged either way.
```

Both take `--max <n>` for the iteration cap. **Neither is derived from the other.** This
doc owns the method, and each command states its own halt table in full.

---

## The loop

Each iteration is **one ticket in a fresh context**, and that is not an optimisation. *One
ticket per session* exists because a ticket is **sized** to a fresh context
([03-charting.md](03-charting.md)). Ten tickets in one long session means the tenth runs
on the remains of the first. A loop that reuses its context has not automated the flow. It
has broken the rule the flow was built on.

Per iteration, which is [the ordinary stage 2 session](03-charting.md#what-a-session-feels-like)
with one substitution:

1. **Open the map low-res** — Destination, Notes, Decisions so far. Not every ticket body.
2. **Recompute the frontier from disk** — open, unclaimed, every blocker `resolved` **in its
   own file**. Never carry it between iterations.
3. **Take the first takeable ticket. Claim it, then read the claim back.**
4. **Resolve it** — [by type](#dispatch).
5. **Post the resolution comment, gist first, and close it.** The gist matters more here than
   anywhere: `Decisions so far` is regenerated from those first lines, and nobody watched
   this happen.
6. **Graduate the fog** — ticket whatever the answer just made visible, and delete the
   graduated patch from *Not yet specified*. This is [the step that feels like
   nothing](03-charting.md#fog-of-war) and is the stage working.
7. **Log the iteration, bump the counters, test the halt table.**

### Dispatch

| `Type:` | Ordinary charting | Feeling lucky |
|---|---|---|
| `grilling` | you decide | [two agents, on the record](#the-two-agent-grilling) |
| `research` | a background subagent | **unchanged** — it already ran unattended ([02-the-kill-gate.md](02-the-kill-gate.md)) |
| `task` | you do it | **claimed to you and left.** It does not halt. Claiming is what takes it off the frontier, so the walk continues past it |
| `prototype` | you react to something rough | **halts.** Reacting *is* the ticket, and there is nobody to react |
| `make:<layer>` | rare here — no chain is declared yet | **halts.** [Stage 2 has no layer chain and no specialists](../../templates/skills/charting/SKILL.md). `/adapt-to-stack` runs a stage later, so there is nothing to dispatch to |

### The tail always stops the walk

Charting ends with **the tail**: *name the stack*, then *write the bootstrap checks*, and
neither is takeable while any other ticket is open ([01-the-solo-path.md](01-the-solo-path.md)).

**`/feeling-lucky` halts the moment the tail is all that is left.** Naming the stack is the
single most expensive decision on this path. Every later ticket, the whole bootstrap, the
layer chain and all eight seam checks are downstream of it. Undoing it is not a ticket, it is
starting again. The [reversibility test](#the-reversibility-test) would catch it anyway. This
rule is here so it does not depend on the steward classifying it correctly.

`/feeling-very-lucky` will take the tail. **That is a machine picking your stack overnight.**
It is the sharpest example of what that setting is for, and what it costs.

---

## The two-agent grilling

This is the part that is genuinely new, and the part with a real failure mode. Charting says
a `grilling` is *"a judgement only the human can make"*
([charting/SKILL.md](../../templates/skills/charting/SKILL.md)). This mode does not
pretend otherwise. It makes the judgement **attributable** instead of silent.

Two roles, two contexts, never the same agent:

| Role | Who | Sees | May |
|---|---|---|---|
| **The interrogator** | the iteration's own session, running the `grilling` skill | everything — the map, the code, Serena, memory | ask, push, refuse a vague answer |
| **The steward** | [`@decision-steward`](../../templates/agents/decision-steward.md), a subagent | **only a prepared evidence pack** | answer, and label the basis |

**The interrogator tries the code first.** The `grilling` skill's opening rule is never to
ask what Serena or memory can settle. Anything the code answers is not a decision. It is a
lookup, and it never reaches the steward.

### The evidence pack

The steward gets a pack, not a transcript, and not the repo: the map's **Destination**,
**Decisions so far**, **Not yet specified**, **Out of scope** and **Notes**; the ticket's
**Question** and **Comments**; and whatever memories exist.

Restricting it is the whole mechanism. Give the steward the run of the repo and `grounded`
becomes trivial to manufacture, because it will always find *some* line to point at. The same
reasoning gives [`@pitch-judge`](../../templates/agents/pitch-judge.md) one tool that fetches
nothing, and one turn: the case file arrives in the prompt, and there is nothing to fetch.

### Every answer carries a basis

| Basis | Means | Must include |
|---|---|---|
| `grounded` | the pack **settles** this | the citation, quoted — which decision, which Notes line, which memory |
| `guessed` | the pack does not settle it, and it is a question of **fact** | what **would** settle it |
| `yours` | the pack does not settle it, and it is a matter of **taste** | why it reads as taste rather than fact |

`yours` is not a softer `guessed`. It is the steward saying *this one is not mine to know* —
what the product is called, its tone, which of two acceptable shapes you prefer. Cheap to
reverse, and still yours. Without this row, a mode that halts only on irreversibility would
happily name your product overnight.

**A `grounded` answer whose citation does not resolve is a `guessed` answer.** The
interrogator checks it against the file. An invented citation is the exact failure this
structure exists to catch.

---

## What stops the walk

| | `/feeling-lucky` | `/feeling-very-lucky` |
|---|---|---|
| `grounded` answer | continue | continue |
| `guessed`, cheap to reverse | log, continue | log, continue |
| `guessed`, hard to reverse | **halt** | log, continue |
| `yours` | **halt** | log, continue |
| only the tail is left | **halt** | continue — it picks your stack |
| **three `guessed` or `yours` in a row** | **halt** | **halt** |
| iteration cap reached | **halt** | **halt** |
| frontier empty — cleared, stalled, or looks abandoned | **halt** | **halt** |
| a `prototype`, or a `make` with no chain | **halt** | **halt** |
| a ticket appears claimed to someone else | **halt** | **halt** |

Everything is logged under both. The difference is only ever whether the walk *continues*
after logging.

### The reversibility test

This is not a list of forbidden things, because [the path list was the bug, not the
paths](07-guardrails-when-solo.md). One question:

> **Would undoing this be one more ticket, or a re-chart?**

*One more ticket* — a default, a name inside a module, a shape that can change later. *A
re-chart* — the destination moves, ticket numbers burn, decisions downstream were already
taken on top of it. If undoing it means reopening the map, `/feeling-lucky` stops there.

This is the surviving half of the two-clause rule in
[07-guardrails-when-solo.md](07-guardrails-when-solo.md). **The audience clause is
already spent.** [Requirement 1](#1-the-tracker-must-not-be-a-shared-place) refused a
shared tracker before iteration one, and [the push rule](#the-walk-pushes-to-main) only
applies to a private stub nobody else has. You pay that clause once, up front and
mechanically. Reversibility is then the only clause left to test per decision, exactly as
that doc predicted.

### The breaker fires in both, and that is the point

Three `guessed` or `yours` answers in a row is not three hard questions. It means **the map
was charted in more fog than anyone realised.**

`/feeling-very-lucky` promises not to stop for a decision. It does not promise to keep
running on a broken map. Without this row you wake to nine open questions and nine spent
sessions. Every one of them looks like progress in a log, because **a loop cannot tell
working from failing productively.** Nine new tickets read exactly like nine resolved ones
until you check which.

### The iteration cap is the cost habit finally getting teeth

[07-guardrails-when-solo.md](07-guardrails-when-solo.md) rules cost out as a guardrail,
for a reason that is correct: *"a hook cannot see token spend."*

**But a loop can count its own iterations.** The cap and the breaker are the first
mechanical limit on spend anywhere in this playbook, and they are only possible because
there is now something that counts. This mode also creates the need, because it removes the
human who was absorbing the spend by feeling it.

---

## The walk pushes to main

**An iteration that changed the repo commits and pushes when it closes the ticket.** No
branch, no PR, no waiting, because [stalling a loop to ask for a push is the one thing a
loop cannot do](07-guardrails-when-solo.md).

### What is actually being pushed

Almost always: **ticket files.** Stage 2 produces decisions, not code
([03-charting.md](03-charting.md)). On
[local-markdown](../../templates/trackers/local-markdown.md) those decisions *are* files in
`tickets/`, committed. So the night's output is the map, the closed tickets and their
resolution comments: a **record**, in markdown.

The one make this stage guarantees is the tail's bootstrap checks, and `/feeling-lucky`
halts before the tail. On a hosted-tracker map there is usually nothing to commit at all.

> **This is the argument for pushing, not a caveat.** The thing most worth getting off the
> machine overnight is the decision record. It is also the thing a crashed laptop otherwise
> loses entirely, because nobody was awake to notice.

### Why `main`, when guardrail 1 says push is where reversible becomes irreversible

That rule protects **a trunk other things depend on**. At stage 2 there is no such trunk:
the repo is a private stub the kill gate created, with no deployment, no consumers, no CI
and no other contributors. Its `main` is *the only branch of a repo nobody else has*. A
branch-and-PR dance here is ceremony against an audience of one, who is asleep.

**The reasoning expires when the repo gains a consumer**, which is also roughly when
charting ends. Nothing here licenses pushing to `main` on a repo that has one.

### Two prerequisites, both mechanical

| | Why |
|---|---|
| the repo is **allowlisted for push** ([`repo-allowlist`](../../templates/hooks/repo-allowlist.sample)) | not listed means no, and that is what keeps a live project two folders over out of this |
| [`block-secret-staging.sh`](../../templates/hooks/block-secret-staging.sh) is **installed** | this hook exists *because* push was loosened — see below |

**The second one is not optional here, and this mode is the sharpest reason to have that hook.**
[07-guardrails-when-solo.md](07-guardrails-when-solo.md) records the hole loosening push
opens: *"the agent writes `.env` with a live key, commits, pushes. The repo is private, so it
feels fine. Six months later you make it public to show someone, and the key is in the
history."* That scenario assumed a human who merely did not read the diff. **Here there is no
human and no diff was rendered.** The hook is the only reader left.

### Never rewrite what was pushed

Amend-as-you-go is how the rest of the playbook commits, and it stops at the push. Once a
commit is on the remote the walk **appends**. It never amends, rebases or force-pushes. A
force-push is the one git operation that can destroy a record you cannot re-derive, and
[the hooks block it outright](../../templates/hooks/block-dangerous-git.sh). That block
stays on, for this mode as for every other.

---

## The ledger

Charting normally leaves its record in two places: the tickets, and you. Unattended, the
second one is missing. Forty iterations of *what happened and why* then have nowhere to go.

So the walk writes to **`.claude/lucky/`**, local, whatever the tracker is:

| File | Holds | Read it |
|---|---|---|
| `ledger.md` | one line per iteration — ticket, type, outcome, basis | to see what happened |
| `guesses.md` | every `guessed` and `yours` answer, its question, and what would settle it | **first, in the morning** |
| `summary.md` | the halt reason and the counts | to know where you are |

**Never on the tracker, and never beside the tickets.** A ticket is a project record. It
passes §5's provenance test, *would a fresh clone need this file?*
([local-markdown.md](../../templates/trackers/local-markdown.md)). A log of what an agent
did overnight fails that test outright. It is AI infra, it lives under `.claude/`, and the
hooks already keep that out of a commit.

**The decisions themselves are not in here.** Those go where they always go: the resolution
comment on the ticket, and `Decisions so far`. The ledger holds what the tracker has no field
for: which answers were guessed, and on what basis.

> ### This is not a violation of *re-derive, never store*
>
> [That rule](01-the-solo-path.md#re-derive-never-store) bans **a fact about the repo written
> down beside the repo** — a stage marker, a progress file — because the repo can disagree
> with it and nothing would notice.
>
> The ledger is not a fact about the repo. It is **a record of what happened while nobody was
> watching**, and it is derivable from nothing, because the sessions are gone. Delete
> `ledger.md` and the information is not recomputed, it is lost. That is the opposite of the
> test a progress file fails.

---

## Why this does not contradict *HITL never resolves without the human*

It is stated most flatly at
[charting/SKILL.md](../../templates/skills/charting/SKILL.md): *an agent that answers its
own grilling question has broken the ticket, not finished it.* Read cold beside this doc,
that is a contradiction. On this repo a contradiction is a defect, because an agent loads
both files at once and has no tiebreak.

It is not one, and the reason has the same shape as the finding in
[07-guardrails-when-solo.md](07-guardrails-when-solo.md). **That rule was two clauses the
whole time.**

| Clause | What it tests | Feeling lucky |
|---|---|---|
| **Ownership** | Is this decision mine to make? | **Satisfied by the path, not by this mode.** Solo, you own the product, the repo and the tracker. There is no absent stakeholder whose call is being taken. |
| **Silence** | If an agent decides, does anything record that it decided, and on what? | **This is the clause the rule was really protecting**, and the one this mode has to earn. The basis label and `guesses.md` are how it earns it. |

**The team path fails the ownership clause, and no mechanism rescues it.** A steward reading
a pack cannot stand in for a product owner who is simply not in the room. That is the premise
[07-guardrails-when-solo.md](07-guardrails-when-solo.md) opens with. It is why this mode is
solo-only, and why no new guardrail was needed to keep it off the team path. The hook layer
says what is *possible*. A flow says what it *does*
([07-guardrails-when-solo.md](07-guardrails-when-solo.md)). This mode simply does not
exist over there.

So the shared rule holds **by its reason**, and the places that state it now say *silently*,
which is what they always meant.

---

## What you are trading away

Worth stating plainly, because a mode named *I'm feeling lucky* should not also be sold as
free.

- **Decisions you would have made differently.** Every `guessed` answer is one. They are all
  in `guesses.md`, and reversing one is a ticket. But you pay for the ticket.
- **The thinking you do while grilling.** Half the value of a grilling round is that *you*
  find out what you actually think while defending it. The steward does not hand that back,
  and on a stage 2 map — which is almost entirely decisions — that is most of the stage.
- **Under `/feeling-very-lucky`, coherence.** A wrong `guessed` answer in iteration 3 is
  load-bearing by iteration 12. `/feeling-lucky` stops at the ones expensive enough to
  matter. `--very` does not, and that is the setting's nature.

**Use `/feeling-lucky` for the long middle of a map**, once the shape is settled and what is
left is filling it in. Use `/feeling-very-lucky` when you have decided the map is cheap
enough to be wrong about — a weekend idea you would rather see built badly tonight than
correctly next month. That is a real reason. It is just not the usual one.

---

## What this doc does not own

| Owned elsewhere | Where |
|---|---|
| How a map is charted, what a type means, the fog rule | [`charting/SKILL.md`](../../templates/skills/charting/SKILL.md) and [03-charting.md](03-charting.md) |
| What each verb means on your tracker, and what a claim is | [`trackers/README.md`](../../templates/trackers/README.md) and your installed adapter |
| The steward's own rules | [`decision-steward.md`](../../templates/agents/decision-steward.md) |
| Which guardrails hold solo, and why reversibility is the surviving clause | [07-guardrails-when-solo.md](07-guardrails-when-solo.md) |
| The `*-massive` commands over a codebase that already exists | [../team/03-massive-tickets.md](../team/03-massive-tickets.md) — **a different path, team-only, which this mode does not drive** |
| Charting a codebase *you* already shipped | [03-charting.md](03-charting.md) — still yours, still `/charting`, but walked by hand: this mode is scoped to stage 2 |

---

## Why this doc exists

- The playbook had a **topology** axis and no **cadence** axis. Every flow said what runs and
  in what order. Nothing said *how often, and driven by whom*.
- **A loop adds no failure modes. It removes the human who was absorbing the ones already
  there.** Before looping any flow, go and find every place it quietly relied on somebody
  noticing. Here that was [the eventually-consistent
  frontier](../../templates/trackers/github.md): a known bug whose written fix is *"re-read
  before believing a count you did not expect"*. That is an instruction with a reader in it.
  A human shrugs and re-reads. A loop calls it an ending and goes to bed.
- **The obvious design of two-agent grilling is the broken one.** Two agents agreeing is not
  a second opinion. It is the same opinion twice, in a format that looks like deliberation.
  The basis label is the only part doing work.
- **Reversibility keeps turning out to be the invariant.** It survived the guardrail
  re-derivation, and it is what separates the two settings here. Turning up twice, derived
  independently, is the evidence it is the real one.

---
> **Last verified against:** Claude Code `2.1.226` — August 2026
