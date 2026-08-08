# 06 — Choosing the stack

Choosing the stack is **not a stage**. It is the last two tickets on the map — **the tail**
— resolved inside [charting](03-charting.md), after every product decision is closed.

[`03-charting.md`](03-charting.md#the-tail) owns **placement and ordering**: why the tail
goes last, why that is a rule you follow rather than blocker wiring you maintain, and the
one documented escape. This doc owns **method** — how one candidate stack gets proposed and
killed, and what the tail's first ticket actually decides.

It is **one session**. If it is turning into three weekends, you are comparing, and
*propose-and-kill* below is the section you want.

---

## The bar is read-level, not write-level

*"Do you know this stack?"* was written for a world where you type the code. Claude types
the code, so the question needs restating.

Three parties need to know the stack, and they are not the same party:

| Who | Needs to | What that actually requires |
|---|---|---|
| **Claude** | write it well | popularity — it writes mainstream stacks well and obscure ones worse |
| **Serena** | index it | a mature language server ([04-serena.md](../shared/04-serena.md)) — *if* Serena applies here at all |
| **You** | **catch it being wrong** | the ambiguous one, below |

Only the third was ever ambiguous. There are two candidate bars:

| Bar | Means | Verdict |
|---|---|---|
| **Write-level** | You could have built it yourself. | Too strict. Rules out most stacks for most people, and makes this path unusable for the case it exists to serve. |
| **Read-level** | You can read a diff and tell it is wrong. Read a stack trace. Notice when Claude is confidently talking nonsense. | **This is the bar.** |

**Read-level, because on a solo project there is no second reviewer.** If you cannot judge
the output, nobody does — and the playbook already names this exact failure, in
[12-when-not-to-use.md](../shared/12-when-not-to-use.md#unfamiliar-codebase):

> *"You can't tell whether a good plan is actually good, or just well-written."*

That line was written about the pipeline. It is the stack-choice bar restated.

Read-level is reachable in a weekend and **improves while the project runs**. Write-level
is neither.

---

## Mainstream-first

Read-level widens the candidate set well past *"stacks I know"*, so it needs a tiebreaker.

> **Pick the most boring stack that does the job. If you already read one of the boring
> options, that is your answer — stop.**

Two of the three parties above care only about popularity. Only you care about
familiarity, and your bar is one you can reach. Popularity wins the majority. Where an
already-read stack *is* mainstream, all three agree and the session is over in minutes,
which is the outcome to hope for.

**The conflict case is a niche stack you read fluently.** Mainstream still wins: Claude and
Serena both degrade there, and you can reach read-level on the boring option — the one
thing that *is* recoverable in a weekend.

---

## The session is propose-and-kill, never comparison

This is what makes it a session rather than a hobby.

| | Exit condition |
|---|---|
| **Comparison** | None. There is always one more framework. **Running the comparison is the three weekends.** |
| **Propose-and-kill** | Natural. Name one candidate, try to kill it, stop the moment one survives. |

This is deliberately the **same shape as the kill gate** one stage earlier: you do not
compare your idea against other ideas, you try to kill the one you have. See
[02-the-kill-gate.md](02-the-kill-gate.md).

### The three kill checks

| # | Check | Kills when |
|---|---|---|
| 1 | **Does a product decision rule it out?** | Something already closed on the map demands offline, or realtime, or that it runs on a phone — and this stack cannot. |
| 2 | **Does Serena matter here, and if so is there a mature language server?** | Conditional. See the next section. |
| 3 | **Can you read it, or reach read-level quickly?** | Not *could you have written it*. Not *have you used it*. |

Survive all three and that is the stack. Fail one and you name the next candidate — you do
not open a spreadsheet.

```
   THE TAIL, ticket 1 — nothing else on the map is open
           │
           ▼
   re-read the closed gists ──► the constraints earlier decisions
           │                    already placed on the stack
           ▼
   name ONE candidate ◄──────────────────────┐
     the most boring thing that does the job │
           │                                 │
           ▼                                 │
   1. product decision rules it out? ─ YES ─►│
           │ no                              │
           ▼                                 │  name the
   2. Serena matters here?                   │  next one
        no ──► check passes, verdict NO      │
        yes ─► mature LSP? ── no ────────────┤
           │ yes                             │
           ▼                                 │
   3. can you reach read-level? ─── no ─────►┘
           │ yes
           ▼
   IT SURVIVED — stop. That is the stack.
           │
           ▼
   decide: the layer chain · whether a green test command gates at all
           │
           ▼
   ticket 2 (the make) — write the checks stage 3 will run
```

---

## Serena is a conditional check, not a universal requirement

**This is the one part of the method that contradicts something the playbook used to say
flatly.**

Serena's value scales with **symbol density**. An application has functions calling
functions, and Serena earns [pillar one](../shared/04-serena.md). A shell-and-YAML
project — a home server, an Ansible tree, a scripts repo — has no symbol graph to walk.
Making a weak language server a universal kill would kill good projects for a bad reason.

> **The test: will you ever need to ask *"who calls this?"***

| Answer | What check 2 does | What the seam does |
|---|---|---|
| **Yes** | A weak or missing language server is a **real kill**. | [Seam check 4](01-the-solo-path.md#the-seam--where-the-solo-path-stops) expects a real index. |
| **No** | Check 2 passes. Serena is optional on this project. | Seam check 4 reads the verdict and passes. `CLAUDE.md` says why. |

**Record the verdict either way.** It is not a private conclusion — it goes into the repo's
`CLAUDE.md` at [bootstrap step 3](04-the-bootstrap.md#the-eight-steps),
and the seam looks it up rather than deciding it. A verdict of *no* is a **pass**, not a
gap.

**This bites inside the current scope, not at its edge.** Bash and Ansible projects are
code, they are in scope today, and they are symbol-poor. This is the third situation the
playbook now has words for: day-one empty (correct), unfamiliar-and-sparse (stop), and
**symbol-poor by nature** (correct, permanently) — see
[12-when-not-to-use.md](../shared/12-when-not-to-use.md#unfamiliar-codebase).

---

## What the session already knows

Earlier product decisions constrain the stack quietly. *Should this work offline?* was
answered weeks ago by a ticket that never mentioned a language. Two ways to get that to the
tail:

| | Why not / why |
|---|---|
| **Push forward** — every ticket records any stack constraint it creates | **No.** It fails *silently*: a ticket forgets and nothing tells you. It also needs somewhere to accumulate, and the obvious place is the map's Notes — which has no optimistic concurrency, so appends lose writes. |
| **Re-read at the tail** — the tail reads the closed decisions and extracts the constraints itself | **Yes.** Re-reading closed decisions means reading **one-line gists**, not reopening tickets. The map's decision list is built for exactly this. |

**The tail's placement is what makes re-reading complete.** It runs last, with nothing else
open, so the list it reads is the whole list. A tail that ran early would read a partial one
and not know it.

> **An honest cost, recorded.** Gists drift long in practice — this playbook's own map has
> paragraphs where it should have one-liners. Re-reading is cheaper than reopening tickets,
> but it is not free, and it scales with the length of the map. That is a gist-discipline
> problem, not a reason to add a second place to store constraints.

---

## What ticket 1 decides — and what it writes

**Three decisions, no files.**

| | Decides | Writes |
|---|---|---|
| **Ticket 1** *(decision)* | the **stack name**; the **layer chain**; whether a green test command **gates at all** | nothing |
| **Ticket 2** *(make)* | nothing | the build command, the run command, the test command **and what green means on an empty stub**, and the Serena symbol check if the verdict calls for one |

That split is what [decide-or-make](03-charting.md#decide-or-make--never-both) demands: one
ticket produces an answer, the next produces a file.

**Whether tests gate is a *stack* question, not a taste one.** Run the test command against
an empty project and stacks disagree about what happens:

| Stack | Empty project | Meaning |
|---|---|---|
| Go | `go test ./...` exits **0** | Cleanly green. A test gate works from day zero. |
| Python | `pytest` exits **5** | *No tests collected* — neither a pass nor a failure. Gating on it means gating on a number you have to special-case. |

Same question, different answer, caused purely by the stack. So ticket 1 answers it, and
ticket 2 writes down whatever ticket 1 decided.

### The layer chain is named here too

Ticket 1 names the layer chain alongside the stack. Not the bootstrap — even though the
bootstrap is where the chain first becomes *visible*, as folders at step 2 and agent files
at step 5.

| Why not stage 3 | |
|---|---|
| **A checklist is the wrong place for an architecture decision** | You are executing, not deliberating, and a real decision dropped into a checklist gets rubber-stamped. |
| **Stage 3 *consumes* the chain** | It generates the layer specialists from it. Deciding it there means deciding and building from it in the same breath, with nothing in between to catch a bad answer. |

**The obvious objection is fair:** you are naming layers for an application that has no
folders and no code. That is the same ignorance the stack itself is chosen under, one
paragraph earlier, and it has the same answer — [one backwards
step](03-charting.md#one-backwards-step). A folder is cheap to move. See
[06-claude-md-layers.md](../shared/06-claude-md-layers.md) for what a chain is.

---

## Ticket 2 writes checks it cannot run

Only two seam checks are stack-specific — build/run and Serena. The other six do not vary
by stack, so ticket 2's output is short.

**Ticket 2 runs during charting, when the repo is still empty.** So it cannot execute its
own checks. It writes them; [stage 3](04-the-bootstrap.md) runs them. Some of them will
fail on first contact, and that is expected rather than embarrassing — they were written
blind.

That splits Serena verification cleanly across the seam:

| Who | Verifies | How |
|---|---|---|
| **Ticket 1** | that a mature language server **exists** for this stack | by **reading** |
| **Stage 3** | that it **actually indexes this repo** | by **running** — scaffold the stub, run a symbol search, see real results |

**Reading verifies claims; running verifies code.** If stage 3 runs the check and the index
comes back sparse *on a real stub*, that is not a step to retry — it is
[the backwards step](03-charting.md#one-backwards-step). The stack cannot be read the way
the project assumed. No new machinery is needed for that; it was already written down.

---

## The stack ticket writes no files

Seam check 1 says *the stack is named and written down* without saying where. The answer
uses only homes that already exist — no ADR, no new artifact.

**Three moments, not three homes:**

| When | Where the stack lives |
|---|---|
| **Charting** | in the ticket's resolution comment, gisted on the map — exactly like every other decision |
| **The bootstrap** | copied into the repo's `CLAUDE.md`, and into memory two (*the stack and the layer chain, and why*) |
| **The seam** | check 1 is true **because both of those exist** |

So the choosing→generating handover needs nothing new. Generation
([11-adapting-to-your-stack.md](../shared/11-adapting-to-your-stack.md)) reads **`CLAUDE.md`
and nothing else** — not memory two, and never the map, which by then may be closed while
`CLAUDE.md` is in the repo permanently. Memory two is not an input at all; it holds the
*why* for a session months later that needs to know what was ruled out. The seam is the
interface; generation starts on the far side of it and does not look back.

---

## Why this doc exists

[`03-charting.md`](03-charting.md#the-tail) tells you *when* the stack gets chosen and why
it waits. [`01-the-solo-path.md`](01-the-solo-path.md) tells you what has to be true
afterwards. Neither answers the question you are actually holding when you sit down to do
it:

- **The bar moved and nobody said so.** Claude types the code, so *could you have written
  this* is the wrong test and *can you tell when it is wrong* is the right one — and the
  second is reachable in a weekend.
- **Boring is the correct answer**, and it is correct for a reason that has nothing to do
  with taste: two of the three parties that need to know the stack care only about
  popularity.
- **Comparison is the trap.** It has no exit condition, and running it costs more than
  picking wrong would have.
- **Serena is a question here, not a requirement**, and the answer gets recorded rather
  than assumed.
- **The layer chain is decided here too**, which is not where a reader expects to find it.

Read this when the frontier is empty and the tail is all that is left. Read
[04-the-bootstrap.md](04-the-bootstrap.md) next — it is what consumes everything decided
here.

---
> **Last verified against:** Claude Code `2.1.226` — August 2026
