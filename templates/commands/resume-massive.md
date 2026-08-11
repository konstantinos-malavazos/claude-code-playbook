---
description: Walk a chart - pick the next takeable ticket, claim it, dispatch it by type, then do the bookkeeping: gist, close, regenerate the decision list, graduate the fog. Owns the three endings - done, stalled, abandoned. On done it runs the closing review sequence and banks the map's memories. One ticket per session, research excepted.
argument-hint: <TICKET-ID> — optional; omit to pick up the only map in flight
disable-model-invocation: true
---

# Resume Massive — $ARGUMENTS

Walk the map in the chart folder, one ticket, then stop.

**Load the `charting` skill and read your tracker adapter first.** Charting owns the method,
the adapter owns what each verb means on disk. This file is the workspace binding, plus the
bookkeeping, which is yours alone.

Three hard rules, nothing overrides them:

- **Zero tracker writes.** The development ticket the effort hangs off is read-only. The
  session ends with text for the user to paste. **Map writes are yours and nobody else's.**
  Creating, claiming, commenting on and closing *this chart's* tickets is most of step 5, and
  no command you dispatch does any of it. The two words are not interchangeable. Where the
  adapter puts the chart on a shared tracker, a map write is still seen by everyone.
- **One ticket per session** — `research` is the only exception, because it runs in a
  background context and does not spend this one.
- **Never modify `/start-ticket`, `/resume-ticket`, `/fix-ticket`, `/test-ticket`** or any
  agent they use.

## 1. Find the map

- `$ARGUMENTS` given → that chart folder. Missing → say so and stop. `/start-massive` charts
  one.
- Not given → list the charts, **skipping every map whose `map.md` opens with
  `State: closed`**. Exactly one left → take it. Several → **ask which**, showing each with
  its destination and its open count. None left → say every map is closed and stop.

A closed map's folder stays on disk as the record. A map with no `State:` line at all is open.
The stamp is written once, at close.

## 2. Load it low-res

`map.md` — Destination, Notes, Decisions so far, Not yet specified, Out of scope. Nothing
else: the frontier in step 3 is computed live, from disk, every session.

Do **not** read every ticket body. That is what the map exists to spare you.

## 3. Choose, then claim

The user named a ticket → take that one. Otherwise take the first on **the frontier**: open,
unclaimed, and every blocker `resolved` **on disk**. Read each blocker's file. A `Blocked by:`
line still says blocked long after the blocker closed.

**Frontier empty → go to step 7.** Something is ending. Work out which thing.

Claim it: set `Claim:` to your name and the date, save, then **read it back**. A claim that
silently failed to write looks exactly like one that worked.

Already claimed with an older date? The claim is advisory, not a lock. Say who holds it and
when, and let the user decide to take it over.

**A claim naming anyone but this session is a handoff, not a stale claim. Never take it
over.** It says a person or a background agent is holding the ticket. Say who, and how long
it has sat.

## 4. Dispatch by type

| `Type:` | What happens |
|---|---|
| `make:<layer>` | `/build-chart-ticket <KEY>#<NN>`. It guards, implements with the one specialist the label names, and hands back a draft resolution comment. It does not close. You do |
| `grilling` | **you** run it, here, with the `grilling` skill. The human decides. An agent that answers its own grilling question has broken the ticket, not finished it |
| `research` | one background agent, with the `research` skill's discipline in its prompt. Findings to the chart's `research/` folder. **Claim it to the agent as you dispatch**, then carry on while it runs |
| `task` | the human does it — an account, an access grant, a file moved. Done inside this session? Record what they report and what it now unblocks. **Still outstanding when the session ends? Claim it to them** and comment what was asked and when |

**Claiming a handed-off ticket is not bookkeeping politeness. It is what lets the map
finish.** An unclaimed handoff is open with no `Blocked by:` edge, so it never leaves the
frontier, so step 7 never runs.

If `/build-chart-ticket` came back with a **decision report** instead of a resolution
comment, it hit a real decision and stopped. It wrote nothing. Filing it is yours:

1. Create a `grilling` ticket on the map with its question, at the next free number.
2. Add that number to the make ticket's `Blocked by:`.
3. Post the progress comment, and **leave the claim on**.
4. **End the session.** Do not close anything, and do not start the grilling ticket — that is
   next session's one ticket.

**Every write in that list is a map write, which is why it sits here and not there.** A
command dispatched mid-session cannot be trusted with the map: it does not know whether the
run was asked for.

## 5. Record it — this is the part only you do

1. **Post the resolution comment.** Leading gist on line one. The rest may run as long as it
   needs. For a make, `/build-chart-ticket` drafted it. For a grilling, write what was decided
   **and why**. The why is what the next session cannot reconstruct.
2. **Close** the ticket, and clear the claim.
3. **Regenerate `Decisions so far`.** Ask for *the whole graph*, take every **closed**
   ticket's first line, in number order, and rewrite the section whole. Never append.
   **Re-read `map.md` immediately before editing it**, never from the copy you loaded at
   session start.
4. **A ticket closed as out of scope is not a decision.** It gets its line under *Out of
   scope* and stays out of *Decisions so far*, which records the route actually walked.

## 6. Update the edges

Resolving a ticket clears fog ahead of it:

- **Graduate** whatever is now sharp enough to state precisely into new tickets, and
  **delete the graduated patch from `Not yet specified`**, so it lives in one place.
- **Rule out** anything the decision put past the destination: close it, one line under *Out
  of scope*.
- **Delete or rewrite** tickets the decision invalidated, per the adapter's `delete` verb.
  The number is burned, never reused.
- **A repo whose first make ticket only just graduated has no commit message in Notes.** Ask
  the user for one now, in your `commit-conventions` format.

## 7. Which ending are you in

Frontier empty. Three possibilities, and they look identical until you check whether anything
is still open.

**Stalled — frontier empty, tickets still open.** Every one of them is waiting on somebody
outside this session. **This is not done, and never report it as finished.** Name each
waiting ticket, and who owns the thing it waits on. **That owner is the ticket's `Claim:`**,
which is why step 4 writes one. Offer to open **one** `grilling` ticket — *proceed without X,
or wait?* — because answering that refills the frontier.

**A handoff claim that has gone stale is the trigger for that grilling ticket.** Access asked
for three weeks ago and still not granted is not a map waiting patiently; it is a map that
needs the question put to the human.

**Leave a stalled map unstamped and pickable.** The day somebody clears the blocker, it has
to be resumable.

**Abandoned — the destination turned out not to be worth reaching.** Only the human calls
this. It is a finished map and the cheapest outcome there is. Stamp it closed the way step 8.7
describes, with `abandoned` and the reason, and skip the rest of the closing sequence — there
is nothing to review.

**Done — frontier empty and nothing open.** Go to step 8.

## 8. The closing sequence

In this order. Do not skip step 2 because step 1 came back clean.

1. **One `@release-reviewer` per repo the map touched, release mode, in parallel, fresh
   contexts.** Its file describes release mode over a tag-to-tag delta. **Say explicitly in
   the prompt that the range is `origin/<main>..<branch>`**, a branch and not a tag, and give
   it the output path `reviews/<repo>-release.md`.

2. **`@map-reviewer`**, once, after all of them finish. It judges the Destination and the
   ticket's acceptance criteria and writes `reviews/map-review.md`.

3. **Every finding becomes a new ticket.** You create them, with the type `@map-reviewer`
   proposed. The frontier refills and **the map does not close.** That is charting's fog rule,
   not a special case.

4. **One re-sweep of `@map-reviewer`, and only one.** If it still finds something, **stop and
   escalate to the human.** A third round means the map is wrong, not the code.

5. **Bank the memories.** Aim for one. When one cannot hold the effort, write a **hub** plus
   **one per repo**, and cross-link them. Never one per ticket. Tag by functionality and
   lifecycle. **The ticket id goes in the title, the content or the keywords, never in a
   tag.**

6. **Hand `@map-reviewer`'s unproven criteria to `/test-ticket`.** Anything artifact-shaped —
   a field order, a timezone bucketing — was never provable by reading code, and the map must
   not claim it was.

7. **Stamp the map closed.** Write `State: closed` as the first line of `map.md`, with the
   date and the ending:

   ```markdown
   State: closed — done, <date>. Memories: <hub id>, <per-repo ids>.
   ```

   Do this last, and only here. Without it the folder is indistinguishable from a live map,
   and the next `/resume-massive` with no argument picks it up and tries to walk it.

   **Only `done` and `abandoned` get this stamp. A stalled map never does** — it is waiting on
   somebody, and the day their blocker clears it has to be pickable again.

## 9. Hand back

Every session ends with text the user pastes into the tracker themselves:

```
<what this session resolved — the gist, one line>
Takeable next: <ticket number and name>
Waiting on: <ticket — the thing, and who owns it>
Progress: <n> of <m> resolved.
```

Say the next command is `/resume-massive <KEY>`, and stop.

## When the session ends mid-ticket

**Post a progress comment on the ticket, and keep the claim.** The chart is the only durable
surface left, and keeping the claim is safe precisely because it was never a lock.

## Git, whenever you touch it

- Push the branch where the allowlist permits; never merge, and never push the trunk.
- Never commit AI-infra files.
