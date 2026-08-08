---
description: Walk a stage 2 charting map unattended - claim, resolve, close, graduate the fog, repeat. Grillings are answered by @decision-steward on the record, never silently. Stops at a guess it cannot take back, at anything that is the owner's to say, and always at the tail. Solo path only, and never on a shared tracker. Keeps its guess ledger under .claude/.
argument-hint: <effort-slug> [--max <n>] — which map to walk; --max caps iterations (default 12)
disable-model-invocation: true
---

# Feeling Lucky — $ARGUMENTS

Walk the map named by `$ARGUMENTS` until it ends or something stops you. Nobody is
watching.

**Read [`docs/solo/08-feeling-lucky.md`](../../docs/solo/08-feeling-lucky.md) first — it owns
the method.** Then the `charting` skill and your tracker adapter: charting owns how a ticket
is resolved, the adapter owns what each verb means on your tracker. This file is the
**driver** — the guards, the loop, the ledger and the halt table.

Three hard rules, nothing overrides them:

- **One ticket per iteration, one fresh context per iteration.** A ticket is *sized* to a
  fresh context. Never resolve two in one.
- **Never touch the massive-ticket flow.** `/start-massive`, `/resume-massive` and
  `/build-chart-ticket` are a different **path** — team-only, over a codebase somebody else's
  ticket described. This command does not drive them, is not driven by them, and grants
  nothing on that path. A solo install has none of the three, so on your machine this rule
  should have nothing to bite on; it stays because the rule is about ownership, not about
  which files you happened to copy.
- **Never modify `/start-ticket`, `/resume-ticket`, `/fix-ticket`, `/test-ticket`** or any
  agent they use.

## 0. Guards — once, before iteration 1

Stop with a plain sentence if any fails. Do **not** fix them on the way past.

| Check | Fail how |
|---|---|
| the adapter answers **no** to *"is this a shared place?"* | this tracker is shared. A night of unattended comments and closes is the largest batch of tracker writes this playbook produces, and guardrail 2 — *ask before writing where others can see it* — holds solo. Walk it by hand |
| **on GitHub:** you can make the whole-graph GraphQL call | the REST frontier filters on `issue_dependencies_summary.blocked_by`, which **lags a close** — see [step 2.2](#2-the-loop). Without the graph call this walk cannot compute a frontier it can trust |
| the map exists | no such map — `/charting` starts one |
| **at least 3 tickets are already closed** | this map has decided `<n>` things. `grounded` means *the record settles it*, and an empty record settles nothing — chart the first few yourself |
| **no ticket is claimed to a name other than yours** | `<NN>` is claimed to `<who>`. Somebody else is on this map, and this mode has no standing to answer their decisions |
| the frontier is not empty right now | nothing takeable — resolve the map by hand to find out which ending you are in |
| this repo is **allowlisted for push**, and `block-secret-staging.sh` is **installed** | this walk pushes to `main` unattended. Not listed means no. And the secret hook is the only thing that reads a diff tonight — without it, one `.env` written at 3am is in the history for good |
| `git config user.email` is the identity you meant for this repo | every commit tonight carries it, and you are not there to notice the wrong one |

**No argument is not a prompt to go looking.** Refuse and ask which map.

## 1. Set the counters

```
iterations       = 0
max              = --max if given, else 12
consecutive_soft = 0        # guessed or yours in a row — resets on any grounded answer
```

Create `.claude/lucky/` with `ledger.md`, `guesses.md` and `summary.md` if absent. **Append;
never rewrite.** A previous walk starts a new dated section — the record of what happened
unattended is the one thing here that cannot be recomputed.

**`.claude/lucky/`, never the tracker and never beside the tickets.** A ticket is a project
record; a log of what an agent did overnight is AI infra, and stays out of the commit.

## 2. The loop

Each iteration is a **fresh context**. Repeat until step 5 halts you.

1. **Open `map.md` low-res** — Destination, Notes, Decisions so far, Not yet specified, Out
   of scope. **Not** every ticket body; that is what the map exists to spare you.
2. **Recompute the frontier, by asking — never from a summary.** Open, unclaimed, and every
   blocker checked in **its own record**: a stored `Blocked by:` line is a claim about the
   past, and so is a cached count. Never carry the frontier between iterations.

   > **On GitHub this means the GraphQL whole-graph call, not the REST frontier query.**
   > `issue_dependencies_summary.blocked_by` lags a close by ~30 s — verified — so it
   > *"silently hides a ticket that just became takeable"*. One iteration closes a blocker;
   > the next reads the count, sees nothing takeable, and calls a live map finished. GraphQL
   > `blockedBy` was correct at the same instant the count was wrong. On local-markdown and
   > Jira the stated frontier already reads each blocker's real state — nothing to change.
3. **Frontier empty → halt**, reason `ending`. **Only the tail left → halt**, reason `tail`.
4. **Take the first takeable ticket. Claim it, then read the claim back.** A claim that
   silently failed to write looks exactly like one that worked — and here it costs the whole
   night, because the next iteration takes the same ticket.
5. **Resolve it** — [step 3](#3-dispatch).
6. **Post the resolution comment, gist first, then close and clear the claim.** Write what
   was decided **and why**, plus the basis. The *why* is what the next session cannot
   reconstruct, and nobody watched this one.
7. **Regenerate `Decisions so far` whole** — every closed ticket's first line, in number
   order. Never append. **Re-read `map.md` immediately before editing it**, never from the
   copy loaded at iteration start.
8. **Graduate the fog** — ticket what the answer just made visible, and **delete the
   graduated patch from *Not yet specified*** so it lives in one place. Anything the decision
   put past the destination gets closed with one line under *Out of scope*.
9. **Commit and push to `main`, if this iteration changed the repo.** Explicit paths in
   `git add` — never `-A`, never `.`, and never `.claude/`. One commit per iteration, in
   your `commit-conventions` format, naming the ticket. Then push.

   > **Append, never rewrite.** The rest of the playbook amends as it goes; that stops at
   > the push. Once a commit is on the remote this walk only adds to it — no amend, no
   > rebase, no force. Nothing else tonight is going to notice a history that got rewritten
   > underneath it.
   >
   > **Nothing to commit is the normal case on a hosted-tracker map** — the decisions live
   > on the tracker, not in the working tree. Skip the step and say so in the ledger.
10. **Append one line to `ledger.md`**, bump `iterations`, test [the halt table](#5-halt).

## 3. Dispatch

| `Type:` | What happens |
|---|---|
| `grilling` | [the two-agent conversation](#4-answering-a-grilling) |
| `research` | one background subagent with the `research` skill's discipline in its prompt, findings to `research/`. **Claim it to the agent as you dispatch**, then carry on — it runs in its own context and does not spend an iteration |
| `task` | **claim it to the owner**, comment what is being asked and when, move on. It does **not** halt — claiming is what takes it off the frontier so the walk continues past it |
| `prototype` | **halt**, reason `prototype`. Reacting to something rough *is* the ticket |
| `make:<layer>` | **halt**, reason `no-chain`. Stage 2 has no declared layer chain and no specialists — `/adapt-to-stack` runs a stage later, so there is nothing to dispatch to |

## 4. Answering a grilling

**You are the interrogator. `@decision-steward` is not you.**

1. **Try the code and memory first.** Settle what you can yourself with pinpoint symbol
   lookups. Record what they settle, with `file:line`. Anything answered this way is a
   lookup, not a decision, and never reaches the steward.
2. **Build the evidence pack** — the shape is in
   [`decision-steward.md`](../agents/decision-steward.md): the map's Destination, Decisions
   so far, Not yet specified, Out of scope and Notes; the ticket's Question and Comments; and
   whatever memories exist. **That pack is the whole of what it sees** — no repo, no
   transcript, no tools.
3. **Invoke `@decision-steward`**, once, with the pack.
4. **Check the citation resolves.** On a `grounded` answer, open the thing it cited and
   confirm it says what it was quoted as saying. **An invented or unquotable citation is a
   `guessed` answer** — downgrade it yourself and log that you did. Skipping this check makes
   `grounded` a label the steward awards itself, and the whole structure collapses to one
   agent guessing confidently.
5. **Push once if the answer is vague.** The `grilling` skill's rule — never accept an answer
   too vague to implement — still applies with a steward on the other side. One re-ask,
   naming what was missing. Vague again → treat it as `yours`.
6. **Append to `guesses.md`** for any `guessed` or `yours` answer: the question, the answer
   taken, the reversibility, and what would settle it.
7. Counters: `grounded` → `consecutive_soft = 0`. Otherwise → `+1`.

## 5. Halt

Test after every iteration. First match wins; there is no "carry on and see".

| Condition | Reason to log |
|---|---|
| basis `yours` | `yours` |
| basis `guessed` **and** reversibility is `A RE-CHART` | `irreversible-guess` |
| only the tail is takeable | `tail` |
| `consecutive_soft >= 3` | `fog` |
| `iterations >= max` | `cap` |
| frontier empty | `ending` |
| a `prototype` ticket | `prototype` |
| a `make:<layer>` ticket | `no-chain` |
| a ticket appeared claimed to another person | `handoff` |

**`tail` is the one that will fire most, and it is not a failure.** *Name the stack* is the
most expensive decision on this path — the bootstrap, the layer chain and all eight seam
checks hang off it, and undoing it is not a ticket, it is starting again.

**`fog` and `cap` are not failures either.** Three soft answers in a row means the map was
charted in more fog than anyone realised. The cap is the budget doing its job — [a hook
cannot see token spend, but a loop can count its own
iterations](../../docs/solo/08-feeling-lucky.md).

**Never call the map abandoned.** Only the owner can, and they are asleep.

## 6. The handoff

Write `.claude/lucky/summary.md`, and print it:

```
Walked <n> of <max>. Halted: <reason>.

Guessed: <n> — see .claude/lucky/guesses.md      ← read this first
Yours:   <n> — <the questions, one line each>

Resolved: <ticket numbers and gists, one line each>
Waiting on: <ticket — the thing, and who owns it>
Progress: <n> of <m> resolved.
Next: <the command, or the ticket that needs you>
```

**Lead with the halt reason and the guesses, never with the count of tickets closed.** Nine
tickets closed on three guesses is not a good night, and a summary ordered by volume hides
that.

## Never

- Never run on a shared tracker. The guard checks it once; do not re-interpret it later.
- Never let `@decision-steward` hold a tool, see the repo, or see this conversation.
- Never record an answer without its basis.
- Never close a ticket without its leading gist — `Decisions so far` is rebuilt from those
  first lines, and a blank one is a hole in a history nobody witnessed.
- Never hand-append to `Decisions so far`. Regenerate it.
- Never take the tail, and never continue past a `yours` — those are the two differences
  between this command and `/feeling-very-lucky`, and they are the owner's to choose by
  typing one or the other.
- Never stamp a map abandoned, and never report a stalled map as finished.
- Never force-push, amend a pushed commit, or rebase what is already on the remote. Once it
  is pushed, the walk appends.
- Never commit AI-infra files. Explicit paths in `git add`, never `-A`, never `.`.
