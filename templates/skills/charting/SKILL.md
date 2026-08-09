---
name: charting
description: >-
  Chart an effort that is too big for one session and whose route is not yet visible —
  turn the fog into a map of tickets on the issue tracker, then resolve them one per
  session until nothing is left to decide. Use when the goal is clear but the way to it is
  not, when work will span many sessions, or when the user says "chart this" / "map this
  out" / "I don't know where to start". NOT for work you can already plan in one pass.
---

# Charting — find the way, don't charge at the destination

An idea arrives too big for one session and wrapped in fog: you can see the
**destination**, but not the route. Charting is the work of finding that route. It writes
the route down as a **map** on the issue tracker and then walks it, one ticket per
session, until nothing is left to decide.

> Prior art: the `wayfinder` skill. This is a re-derivation, not a copy — it swaps native
> tracker edges for adapter verbs, the claim-as-lock for an advisory claim, and the
> hand-appended decision list for a generated one.

**The stage is charting. The artifact is the map. They never share a name.**

## The destination is an input

Charting does not know what you are building. **Whoever invokes it supplies the
destination**, every time — a spec to hand off, a decision to lock before planning
starts, a change made in place. The map is domain-agnostic; it charts a docs effort as
readily as a migration.

If no destination was supplied, that is the first thing to settle, and it is settled with
the human before a single ticket exists. The destination fixes the scope, so everything
downstream depends on it.

## Decide or make — one or the other, never both

> Every ticket is a **decision** or a **make**. A decision ticket writes no files. A make
> ticket decides nothing new — if it finds a real decision, it **stops and opens one**.

They fail differently, which is why they cannot share a ticket. A decision ends when the
human and the agent agree, and nobody can predict when that is. A make ends when the file
is on disk, and you can see it coming. Put both in one ticket and the unpredictable half
eats the context the predictable half needed.

A decision ticket normally spawns its make ticket on close. That is the system working,
not a ticket that ran long.

**Charting charts; it does not execute.** Whether a map is mostly decisions or mostly
makes depends on how much fog it started in. A map drawn from a written spec is mostly
makes. A map drawn from a vague idea is mostly decisions. The rule that does not vary:
the pull to go and do the work *while inside a decision ticket* means you have reached the
edge of the map, so open a make ticket and hand off.

## Talk to the tracker in verbs, never in commands

Charting never names a tracker and never writes a raw CLI call. It states an intent in the
contract's vocabulary, and the one installed adapter doc at `~/.claude/tracker.md`
answers it. One tracker in context, never four.

| | Verbs |
|---|---|
| **Small** | create · read · list · comment · close · reopen · edit body · link child to parent · label · claim · mark blocked · *is this blocked?* · retitle · delete a ticket |
| **Composed** | *the frontier* — the open, unblocked, unclaimed children of a map<br>*the whole graph* — every child with its state, claim, blockers, body and comments |

**`read` includes the ticket's comments.** On a closed ticket the body is the *question* and
the answer is in the resolution comment — so a read that returns the body alone hands you
the one half you already had. Ask for a read; the adapter makes however many calls that
takes.

**Blocking is a question, not an edge.** Ask *"can I start this ticket right now?"* and let
the adapter go and check. A `Blocked by:` line is a claim about the past — it still says
*blocked* after the blocker resolves. Demanding the edge accepts a rotten answer;
demanding the answer forces a check.

**Identity is the id; the title is decoration.** Retitling is normal while mapping and must
never break a link — which is why `retitle` is a verb and not something you improvise. On an
adapter whose links carry the title rather than the id, retitling breaks them, and the
adapter is the thing that has to say so.

**`delete a ticket` is a verb because trackers disagree about it.** On some it removes the
ticket; on others there is no delete at all and the nearest thing is a close. Ask for the
verb and let the adapter reconcile it. Never reuse a deleted ticket's number.

**`claim` names whoever holds the ticket now — not only this session.** A ticket handed to a
person outside the session, or to a background agent, is claimed *to them*. That is what
keeps it off the frontier while it is in someone else's hands; see *Stop condition* for what
goes wrong when it stays unclaimed.

## The map

One issue labelled `<LABEL-PREFIX>:map`. Its tickets are its child issues. The map is an
**index, not a store** — a decision lives in exactly one place, its own ticket, and the map
only gists it and links.

```markdown
## Destination

<what reaching the end of this map looks like. One or two lines; every session
orients to it before choosing a ticket.>

## Notes

<domain; skills every session should consult; standing preferences for this effort>

## Decisions so far

<!-- GENERATED — rebuilt from the closed children. Never hand-append. -->

- [<closed ticket title>](link) — <its resolution comment's leading gist>

## Not yet specified

<!-- in-scope fog you cannot ticket yet; graduates as the frontier advances -->

## Out of scope

<!-- work ruled beyond the destination; closed, never graduates -->
```

Open tickets are **not** listed. They are open child issues, found by asking for the
frontier.

### Two sections are authored, one is generated

| Section | Treatment |
|---|---|
| Destination | authored once |
| Notes | authored once |
| **Decisions so far** | **generated — rebuilt from the closed children, never hand-appended** |
| Not yet specified / Out of scope | authored, edited constantly, derived from nothing |

Regeneration is the rule because no tracker has optimistic concurrency on a body edit:
two sessions appending an hour apart silently lose one of the writes. Rebuilding from the
closed children turns that data loss into a shrug.

**Rebuild it by asking for *the whole graph*, not by reading twenty tickets one at a time.**
That is the verb's reason for existing: every closed child's leading gist, in whatever the
cheapest number of calls is on the tracker you happen to be on.

**The authored sections get a rule instead of a lock:** *re-read the map body immediately
before editing it — never edit from the copy you loaded at session start.* Nothing
stronger is available; no shipped tracker can honour a lock.

### The picture

**Only if the page template is installed at `~/.claude/dependency-graph.html`.** Ask for the
whole graph, fill that page's data slot, write the result to `.claude/dependency-graph.html`
in the repo being worked on, ensure `.claude/` is in that repo's `.gitignore` **with
`!.claude/agents/` and `!.claude/skills/` beside it**, and open it — one command, and never
on ticket-close. The page's own header comment carries the schema and the two rules that
fail silently. It is for the human, not for you: a tracker that cannot draw its own
dependencies leaves *what is takeable now* as a question answered by hand.

**One repo is the default, not the only case.** An effort with no single owning repo has no
`.gitignore` to edit and nowhere obvious to write — so where the adapter says the map lives,
the picture lives beside it, and the two gitignore rules do not apply. That is the only
override; absent it, use the paths above.

**If the template is not installed, say so once — then ask for *the whole graph* and print
the same facts as text**: the destination in one line, the frontier by number and name, what
is blocked and on what, and the closed count. Nothing else depends on the picture, and no
tracker owes you a substitute for it — the fallback is this paragraph, not an artifact.
Print it; never write it to a file, which would be a second store going stale from the
moment it lands.

## The leading-gist rule

> **Every resolution comment opens with a one-line gist.** The rest may run as long as it
> needs to.

This is **contract, not style** — the single line the rest of the map rests on. Without it,
"rebuild from the closed children" means re-reading twenty long comments and
re-summarising each: expensive *and* non-deterministic, a different answer every run. With
it, rebuilding is a mechanical concatenation of twenty first lines — free, and identical
every time.

The gist must be recoverable **from the ticket**, not only from the map.

## Refer to everything by name

Maps and tickets are issues, so each has a title. In everything the human reads — your
narration, the map's decision list — use that title. A wall of `#42, #43, #44` is
illegible; names read at a glance.

**The link target is the id; the link text is the title.** That is how a stable id and a
human-readable name coexist, and it is why retitling never breaks anything.

## Tickets

A child issue of the map, sized to one agent session:

```markdown
## Question

<the decision or investigation this ticket resolves>
```

The answer is **not** in the body — it is posted as a resolution comment on close. Assets
made along the way are linked, never pasted in.

Each ticket carries one `<LABEL-PREFIX>:<type>` label. **A type is a session shape**, and
for the `make:*` types it is also the dispatch:

| Type | Who drives | Backed by | Use when |
|---|---|---|---|
| `research` | agent alone (AFK) | `/research` | the fact lives outside this workspace — vendor docs, a spec, an RFC |
| `grilling` | human in the loop | `/grilling` | the default for a decision. A judgement only the human can make — see the exception below, which is solo-only and does not change what the type *means* |
| `prototype` | human in the loop | `/prototype` | "how should it look / behave" — make something cheap and rough to react to |
| `task` | either | needs none, by design | manual work blocking a decision: an account to open, access to provision, data to move |
| `make:<layer>` | agent | `@<layer>-specialist` | a piece of the destination, built in one layer of your implementation chain |

**`make:<layer>` is one row, not a list, and you do not enumerate it here.** The layers are
whatever your repo's `CLAUDE.md` declares as its implementation chain — the same source
`/adapt-to-stack` generates the specialists from. A chain of `schema → service → consumer`
gives you `make:schema`, `make:service`, `make:consumer`, dispatching to
`@schema-specialist` and its siblings. Adding a layer to the chain adds a ticket type for
free; nothing here needs editing.

**No declared chain means no `make:<layer>`, and that row is simply off the table.** A map
charted before its repo is scaffolded has no `CLAUDE.md` to read a chain from and no
specialists to dispatch to — `/adapt-to-stack` has not run yet. Do not invent layer names
to fill the gap. A make ticket on such a map carries no layer, dispatches to nobody, and
should be rare enough to be worth a sentence in the map's Notes explaining why it is there.

**The `make:<layer>` label IS the dispatch.** There is no separate track-allocation step and
no planner deciding who implements it — the label already said. Cross-layer ordering is
expressed as blocking edges between tickets, never as a hardcoded chain: on a given map the
chain order often is not the order the tickets have to run in.

**HITL types never resolve without the human.** An agent that answers its own grilling
questions has broken the ticket, not finished it — and the break is not that an agent
*answered*. It is that a decision got made with **nobody owning it and nothing recording on
what basis**. Both halves have to be false before this rule stops applying, and on this
skill they never are: charting is shared by both entrances, and on one of them the owner is
not in the room.

> **One driver is excepted** — [I'm feeling
> lucky](../../../docs/solo/08-feeling-lucky.md), and only while it is driving. That doc owns
> the exception and states what buys it. If it is not driving, this rule is flat.

`task` and the makes both *do* rather than decide, and they are not the same thing. A make
delivers a piece of the destination. A `task` delivers something outside the codebase — an
account, an access grant, a file moved — whose only purpose is to unblock a decision.

### One name per thing

Write a name down when it is **contested, or when a newcomer would read it wrong**. Two
words for one thing costs a mapping to explain in every later session — and a word read the
wrong way costs more, because nobody notices. *Seam* is the case that sets the trigger:
nobody argued about it, and everywhere else it means a place you inject a test double.

A settled name then lives in **two homes, in sequence**:

| When | Home | Written by |
|---|---|---|
| Charting | the map's **Notes** | the session that settles it, **inline** |
| Once the repo has a `CLAUDE.md` | the repo's **`CLAUDE.md`** | greenfield, the bootstrap step that writes that file; on an existing repo the file is already there, so the copy is part of closing the map |

**Write inline, prune at the tail.** Only the session that settled a name knows why *that*
word won, and a resolution comment often never says. So it goes into Notes while the session
still holds it, and the last pass before the hand-off is **subtractive only** — delete the
names that died, never invent one. A folder renamed three tickets later is what that pass
exists to catch: copy without pruning and every future session reads a path that is gone.

**No number.** A name earns its line only if it stops a wrong turn, which is the ruler
`CLAUDE.md` is already priced by.

**Never memory.** `CLAUDE.md` is loaded and memory is searched — and you cannot search for a
name you do not know you have the wrong way round.

**One collision is already live in your own session.** Step 2 runs
[`grilling`](../grilling/SKILL.md), whose *askable now* is questions in a conversation, while
the **frontier** here is tickets on a map with no open blockers. Both are loaded at once, so
say which you mean.

## Fog of war

The map is *deliberately* incomplete. Do not chart what you cannot yet see.

**The test is whether you can state the question precisely now — not whether you can
answer it now.**

- **Ticket it** when the question is already sharp, even if it is blocked and you cannot
  act on it yet.
- **Leave it in Not yet specified** when you cannot yet phrase it that sharply. Do not
  pre-slice fog into ticket-sized pieces; one patch may graduate into several tickets, or
  none.

Resolving a ticket clears the fog ahead of it. Graduate whatever is now specifiable into
fresh tickets, and **delete each graduated patch from Not yet specified** so it lives in
exactly one place.

## Out of scope

Fog only ever gathers *toward* the destination. Work beyond the destination is not fog —
it is out of scope, and it gets its own section. Scope, not sharpness, lands it there.

Out-of-scope work never graduates. It returns only if the destination is redrawn, and then
as a fresh effort, not a resumption.

When a ticket that already exists turns out to sit past the destination, **close it** — a
closed ticket is unambiguously off the frontier — and leave one line under **Out of scope**
with the gist, the reason, and a link. It stays *out* of Decisions so far, which records
the route actually walked. A scope boundary is not a step on it.

## Reading code — Serena, and the greenfield exception

Read code through Serena, never with whole-file reads or a grep sweep.

**And if nothing is indexed yet, say so and stop looking. Never fall back to globbing the
tree.** Charting is general, so it meets both worlds: on a day-one repo an empty index is
**correct**, not broken, and an agent that concludes Serena is down will burn a third of
its context proving it. On an existing codebase a sparse index is a real finding — report
it and stop. Either way the answer is stop, but say which situation you are in.

## The two modes

```
   CHART ONCE                      THEN, ONE TICKET PER SESSION
   ──────────                      ────────────────────────────
   destination                     load the map (low-res)
        │                                │
   grill breadth-first             claim a frontier ticket ── read it back
        │                                │
   create the map                   resolve it ─── decide ──► no files
        │                                │      └── make ────► the file lands
   create tickets ─► wire blockers       │
        │            (second pass)  gist + close + regenerate the map
   fire research subagents               │
        │                          graduate the fog ──► new tickets
       STOP                              │
                                    ◄────┘  until the frontier is empty
                                         │
                                    map closes ──► bank the conclusion
```

### Chart the map

1. **Name the destination** with the human. It fixes the scope, so it is settled first.
2. **Grill breadth-first** — fan out across the whole space rather than deep on one
   thread, surfacing the open decisions and the first steps takeable now. **If no fog
   surfaces**, the way is already clear and the effort fits one session: say so and stop.
   You do not need a map.
3. **Create the map** — Destination and Notes filled in, Decisions so far empty, the fog
   sketched into Not yet specified.
4. **Create the tickets you can specify now**, then wire the blocking edges in a **second
   pass** — issues need ids before they can reference each other.
5. **Fire the research subagents** for every `research` ticket, in parallel — but **name
   the list and get the human's nod first**, since each one spends a background context.
   Claim each to the agent as you dispatch it.
6. **Stop.** Charting hand-resolves nothing. Sizing the map is one session's work.

### Work through the map

1. **Load the map** — the low-resolution view, not every ticket body.
2. **Choose the ticket.** If the user named one, take it. Otherwise take the first ticket
   on the frontier. **Claim it before any work**, then **read the claim back** — a claim
   that silently failed looks identical to one that worked.
3. **Resolve it.** Zoom as needed: **read** a related or closed ticket on demand — body
   *and* comments, because on a closed one the decision is in the comment; invoke the
   skills the Notes name.
4. **Record it** — post the resolution comment (leading gist first), close the ticket,
   regenerate Decisions so far.
5. **Update the map's edges** — graduate newly-specifiable fog into tickets, rule anything
   past the destination out of scope, and delete or rewrite tickets the decision
   invalidated.
6. **If the ticket ends the session in someone else's hands, claim it to them** — the
   person who owes the access grant, the agent still researching. Comment what was asked
   and when. This is not politeness; see below.

**A handed-off ticket that stays unclaimed makes the map unfinishable.** A `task` waiting on
a person is open, unclaimed, and has no blocking edge — so it sits on the frontier and every
later session picks it up and asks for the same thing again. The frontier never empties, so
the *stalled* ending below can never be reached and the map can neither stall nor close.
Claiming it to its holder takes it off the frontier, which is the only way the frontier
empties. The same applies to a `research` ticket left unclaimed: the next session sees it
takeable and fires a second agent at a question already being answered.

**One ticket per session — research is the only exception**, because research runs AFK in
subagent contexts and does not spend the session's own.

Expect other sessions to be editing the tracker concurrently. The claim is **advisory, a
note to others, not a lock** — no tracker can give you one. A stale claim is a nuisance
cleared by hand, not a jam.

## When a session ends mid-ticket

**Post a progress comment, and keep the claim.**

Charting is the only thing that knows the session is ending, and handoff files
auto-delete — the tracker is the only durable surface left. Keeping the claim is safe
precisely because the claim was never a lock.

## When the map closes — one memory per map, not one per ticket

**The unit of work is the whole map, not the ticket.** When the map closes, write the
distilled conclusion of the effort.

Aim for **one** memory. Split only when one cannot hold it: memories have a size limit, and
a map spanning several repos has a different conclusion for each. Then write a **hub**
memory carrying the effort's conclusion plus **one per repo**, and cross-link them.

**Never one per ticket.** A per-ticket memory is a second copy of something the tracker
already holds, free to drift from the first — and twenty of them arrive downstream as
noise. The tickets are the record; the memory is the conclusion.

## Stop condition

Three ways a map can stop. Work out which one you are in before you say anything.

**Done.** The frontier is empty *and* no tickets are open — every question resolved,
ticketed, or ruled out of scope, and nothing left to decide before someone goes and does
the thing.

**Stalled.** The frontier is empty but tickets are still open, because every one of them is
blocked on something outside this session. This is **not** done. Name each blocked ticket
and who owns the thing it waits on — that owner is the ticket's claim, which is why you
wrote one. Never report a stalled map as finished, and never stamp it closed: the day the
blocker clears it has to be pickable again.

A stalled map has one move that refills the frontier: open a single `grilling` ticket asking
*proceed without X, or wait?* A handoff claim that has gone stale is the signal to do it.

**Abandoned.** The destination turned out not to be worth reaching. This is a finished map,
and the cheapest possible outcome — the one charting exists to make affordable.
