---
description: Chart a tracker effort too big for one session into a local map of small tickets, then STOP. Sweeps context once, grills breadth-first, writes the chart folder, authors one final commit message per repo, and asks before firing research agents. Does not implement and does not claim the first ticket.
argument-hint: <TICKET-ID>
disable-model-invocation: true
---

# Start Massive — $ARGUMENTS

Chart `$ARGUMENTS` into a map. **This session charts and stops.** It writes no product code,
creates no branch, and does not claim the first ticket.

**Load the `charting` skill and read your installed tracker adapter before anything else.**
Charting owns the method; the adapter owns what each verb means on disk. This file only binds
them to your workspace. Where they disagree with something below, they win — except on the
three hard rules, which nothing overrides:

- **Zero tracker writes.** The development ticket is read-only, always; the session ends with
  text for you to paste. Writing the chart is a **map write** and is not the same act.
- **Chart state lives where the adapter says**, never in the handoffs directory — that
  auto-deletes at session end and a map runs for weeks.
- **Never modify `/start-ticket`, `/resume-ticket`, `/fix-ticket`, `/test-ticket`** or any
  agent they use. This flow borrows those agents; it does not edit them.

## 0. Guard

If the chart folder for `$ARGUMENTS` already exists, **stop and say so** — this effort is
already charted, and `/resume-massive $ARGUMENTS` walks it. Never chart over an existing map.

## 1. Read the ticket, fresh

Fetch `$ARGUMENTS` from the tracker, read-only. It is normally the development ticket, and
then it is the only id in play: it names the chart folder, and every branch and commit on
this map carries it.

If you charted something else — an epic, say — ask which development ticket the commits carry
and record it in the map's Notes as `Development ticket: <id>`. Nothing else changes.

A ticket this size usually already holds a proto-map in its body. Say which section you are
reading as which part of the map, and let the user correct you:

| Ticket section | Becomes |
|---|---|
| Purpose / background | the **Destination**, once the user agrees to it |
| Open questions | candidate **decision tickets** |
| Out of scope | **Out of scope**, verbatim |
| Acceptance criteria | **not charted.** `@map-reviewer` re-fetches them at close — the map never caches them, and a ticket that quotes one has cached it |

## 2. Name the destination

Settle it with the user before a single ticket exists — it fixes the scope, so everything
downstream depends on it. One or two lines. Do not proceed on a destination you inferred and
the user has not confirmed.

## 3. Sweep the context once

Invoke `@context-gatherer` scoped to the **destination**, not to a ticket.

It writes to the handoffs directory, which is hardcoded in that agent and which you do not
edit. **Copy the brief into the chart folder as `context.md` in this same session**, before
session end clears the handoffs, and stamp the first line:

```markdown
> **Swept:** <date>, at chart time, scoped to the destination.
> Older than your memory-refresh cadence? Refresh the destination layer before trusting it.
```

Every later session reads this file instead of re-sweeping. That is the point of it, and it
is the step most easily skipped without anything appearing to break.

## 4. Grill breadth-first

Load the `grilling` skill. Fan out across the whole space rather than deep on one thread:
what has to be decided, what could be started today, what nobody knows yet.

Charting's no-fog exit applies, and on this path the fallback is named: `/start-ticket`.

## 5. Write the map

`map.md`, in the charting skill's shape. Two things this binding adds to **Notes**:

- **One final commit message per repo the map will touch**, in your `commit-conventions`
  format. These are authored **now**, at chart time, because one branch per repo carries one
  commit, and a child's planner runs days before its siblings exist — it cannot describe
  their work. A repo whose first make ticket only graduates out of the fog later has no
  message here; the walker asks for one when that happens.
- **`Development ticket: <id>`** — only when the map's own key is not that ticket. Omit it
  otherwise; the folder name already is the id.
- **Any term the grilling found contested — or that a newcomer would read wrong**, settled,
  one line each. Notes is the *first* home, not the last: charting's *One name per thing*
  graduates what survives the tail prune into the repo's `CLAUDE.md`. On this path that file
  already exists, so the copy happens as the map closes, into the repo the name is about.

The commit messages do **not** create branches. The first make ticket for a repo creates it.

## 6. Write the tickets, then wire the edges

One file per question, per charting's fog-or-ticket test. Type comes from its table — and for
the makes the label **is** the dispatch: `make:<layer>` → `@<layer>-specialist`, where the
layers are the implementation chain in the repo's `CLAUDE.md`. Nobody decides afterwards.

Wire `Blocked by:` in the second pass. Cross-layer ordering is expressed here as blocking
edges — never as a hardcoded chain, because on a given map it often is not one.

## 7. Ask before firing research agents

**List the research tickets and get an explicit yes.** Each one spends a background context.

On a yes, dispatch one background agent per ticket with the `research` skill's discipline in
its prompt: primary sources, cite every claim, findings to the chart's `research/` folder, a
negative result is a result, and the ticket gets the one-line gist plus the path — never the
findings pasted in.

**Claim each ticket to the agent as you dispatch it.** Left unclaimed it stays on the
frontier and the next session fires a second agent at the same question.

## 8. Stop, and hand back

Print, for the user to paste into the tracker themselves:

```
Charted as <n> tickets under <destination, one line>.
Takeable now: <the frontier, by number and name>.
Blocked on someone else: <ticket — who owns the blocker>.
Not yet specified: <one line each>.
```

Then say the next command is `/resume-massive $ARGUMENTS`, and **stop**.
