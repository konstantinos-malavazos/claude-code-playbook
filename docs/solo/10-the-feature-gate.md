# 10 — The feature gate

The feature gate is how a product **past the seam** takes on one more feature. The
[solo path](01-the-solo-path.md) ends at
[the seam](01-the-solo-path.md#the-seam--where-the-solo-path-stops). Past it, the agile
path assumes **somebody hands you a ticket**. Working alone, nobody does. You have an idea
for one more thing, and nothing between that idea and the pipeline asks whether it belongs.

The stage answers **does this feature belong in this product, and how does it enter?** It
ends in a verdict: **build**, **kill**, or **rerouted**. On *build* it also gives a route:
onto the open map, into one work ticket, or into a small map.

The stage is **the feature gate**. The skill is **`/add-feature`**. The output is a
**verdict** plus a **route**. Three names, kept distinct.

You run it with **`/add-feature`**, from
[`templates/skills/add-feature/SKILL.md`](../../templates/skills/add-feature/SKILL.md).
That template owns the mechanics: the questions in full, the briefs, the tables, the
ticket shape. This doc does not repeat them. It explains why the gate is built the way it
is.

> **The burden of proof is on the feature.** The product does not owe it a place. That is
> the same stance as [the kill gate](02-the-kill-gate.md), pointed at a smaller thing: one
> feature on a product that exists, not a whole idea with no repo.

**Worked example, used throughout:** a game prototype that passes the seam. You want a
**daily challenge**, one generated level a day, the same for everybody.

---

## Where it sits

```
   SOLO PATH                          │  PAST THE SEAM
                                      │
   /pitch ─► /charting ─► bootstrap   │
          ─► cutting ─────────────────┼──► /start-ticket ──► the pipeline
                                      │          ▲
              /adopt ─────────────────┤          │ no open decisions:
          (setup has one home)        │          │ one work ticket
                                      │          │
                                      │   /add-feature ── "one more feature?"
                                      │          │
                                      │          │ open decisions, or an open map:
                                      │          ▼
                         /charting ◄──┼──── onto that map, or a small map
                                      │
                                    SEAM
                         (eight checks, read-only here)
```

The gate stands on the far side of the seam and looks back across it once, without
touching it. A build leaves through one of two doors. Work with nothing left to decide
goes forward to [`/start-ticket`](../shared/08-ticket-pipeline.md). Work with real fog
goes back to [charting](03-charting.md), the one place on the path that burns fog off.

---

## The seam check is read-only

The gate starts by running the eight seam checks, and it **changes nothing**. A failing
check is never fixed here: not a missing memory, not a missing specialist, not one line of
`CLAUDE.md`.

**Setup has one home, and it is [`/adopt`](09-adoption.md).** Adoption is the stage that
decides where an existing project enters the path and puts it there. If the feature gate
patched its own precondition, there would be two places that set a project up. They would
drift, and neither would be the whole story. A gate that repairs what it checks has also
stopped being a gate. It passes everything, because it fixed whatever failed.

So a failing seam gives one of two stops, and which one depends on whether a map is open.

| Seam | Open map | The stop | Why |
|---|---|---|---|
| any check fails | **none** | *Not at the seam — run `/adopt`.* | Nothing on the path claims this project yet. Adoption decides where it enters. |
| any check fails | **yes** | *Finish charting first — map #N is still open.* | The project **is** on the solo path, just not at the seam yet. It already has a stage, and that stage is not this one. |

Both stops name each failing check by number. You learn exactly what is missing, and the
gate still fixes none of it.

---

## Question zero checks the recorded destination

The questions follow the kill gate's rhythm: one at a time, six of them, question zero
first. Question zero is different here, and the difference is the point.

**`/pitch`'s question zero is untouched.** It is asked **once**, at a project's birth, and
what it settles is written down: the memory *what this project is and who it is for*, and
the map's Notes. The feature gate does not ask that question again. It asks **does this
feature move the product toward the destination it already recorded?** It quotes that
destination in the question.

> ❓ **Q0** — **Does a daily challenge move the game toward "a puzzle game people come back
> to every day, on the Play Store"?**

Reading the destination from the record is what keeps the question honest. Ask "where is
this product going?" fresh, with a feature in your head, and you will describe a
destination the feature fits. The record was written before the feature existed, so it
cannot have been bent to fit it.

**It is asked before any lookup is dispatched**, for the same reason as on `/pitch`. You
commit before you know what the code says. Answer afterwards, and a lookup that finds the
feature half-built makes "yes, obviously" far too easy.

---

## The lookups go inward and outward

Question 2 asks *does it already exist?*, and on a product that exists it has two
meanings, so it gets two cold agents.

| Direction | Agent | Answers |
|---|---|---|
| **Inward** | `@serena-lookup` | Does the product already do this, or half of it? |
| **Outward** | a `/research` subagent | Is there a library or a known pattern for this? |

**Inward is the new direction.** `/pitch` has no code to read, so its search only goes
outward. Here the most likely place to find the feature is the product itself. Serena reads
by symbol, so the answer comes back as `file:line` sites, not a guess from filenames.
Question 4, *what is the hard part, in this code?*, sends a second inward lookup for what
depends on the feature's landing site.

**Outward still matters.** A feature that already exists as a well-kept library is a
dependency, not a build.

**They run cold for the reason the kill gate's searches do.** A fresh agent never heard
how much you want the daily challenge, so it cannot mirror that back. The interview
carries on while they run.

In the example, the inward lookup finds `LevelGen.seed()`: levels are already generated
from a seed. It finds **no scheduler**, because nothing in the game runs on a date. The
outward search finds nothing worth a dependency. The second inward lookup finds that the
save file has no notion of a day. The hard part is small.

---

## Two kills and one reroute

| Outcome | Fires when | Why |
|---|---|---|
| **Kill — no first version** | after real pushback on size, you still cannot name the smallest version | everything downstream assumes one exists |
| **Kill — the product already does it** | the inward lookup found it, **and it works** | point at the code; there is nothing to build |
| **Reroute — off-destination** | question zero answered *no* | not a "no"; a different decision |

The kills are mechanical, as on `/pitch`: never weighed, and never un-fired once they
fire.

**"Found something close" is not the second kill.** `LevelGen.seed()` is half the daily
challenge, not the daily challenge. It becomes a constraint on the build, never a reason to
stop.

**Off-destination is a reroute and not a kill, because a kill means "don't build this".**
A feature that pulls the product somewhere new has not been judged bad. It has raised a
bigger question, *should this product be going somewhere else?*, and that question is not
this gate's to answer in either direction. Calling it a kill would quietly answer it *no*.
Waving it through would quietly answer it *yes*. Choosing a destination is
[adoption's](09-adoption.md) job, so the gate stops without asking questions 1 to 5, records
**rerouted**, and points there.

There is **no park and no judge**. Park needs a trigger, and a feature on a live product
has a simpler honest answer: kill it now, and the record is there when it comes back. The
judge earns its keep when you and the agent disagree about a whole idea. One feature,
checked against a written destination and real code, leaves much less to disagree about.

---

## The verdict is a closed `:feature` issue

Every outcome writes one issue labelled `<LABEL-PREFIX>:feature` and **closes it at once**.
Build, kill, and reroute all do this. It holds the gate's answers, the lookup reports with
their sites, what was settled, what is still open, and the verdict. A kill also records which
rule killed it.

**It is a record, not a ticket.** Nothing is worked from it. The route's own tickets carry
the work, and closing it on creation keeps it out of every open-work query.

**It is not the ideas file.** That file holds **projects**, ideas with no repo yet. A feature
belongs to a product, so its verdict lives in that product's tracker, next to the code it
was judged against. That is also where the next run of this gate looks first. Pitch the
daily challenge again a year from now, and the gate finds the closed issue and quotes it
back to you before question zero. If it was killed, you get the reason, and the burden goes
up.

A kill is still **a recorded no, not a deletion**, as on [`/pitch`](02-the-kill-gate.md).

---

## Fog decides the route, never size

On *build*, one question chooses the route: **are there open decisions?**

The README states the rule: *the discriminator is fog, not size.* A large feature with
nothing left to decide is one work ticket. If it is too big for one sequential pass, that is
[the decompose path](../shared/09-decompose-path.md), which `/start-ticket` already takes. A
small feature with one real unknown still goes through charting, because the pipeline plans
work. It does not discover it.

**A decision you settle in the gate is settled.** *"Same level worldwide, or by local
date?"* You answer *"by local date"*, and it becomes a constraint with a trace back to the
`:feature` issue, not an open question. Only what you cannot settle stays open.

| | Daily challenge, as asked | Route |
|---|---|---|
| **Leaderboard cut from the first version** | nothing open | one work ticket, *Play today's daily challenge* → `/start-ticket` |
| **Leaderboard kept** | *"do we need a server for a leaderboard?"* is fog | a small map with that question as its first ticket → `/charting` |

Same feature, and about the same size either way. The fog alone moves it.

---

## An open map absorbs the feature

Before fog is weighed, one thing outranks it. **If the product already has an open map,
the feature goes onto that map**: its open decisions as child tickets, or one child ticket
for the feature itself if none are open.

**One product, one open frontier.** Two open maps on one product means two places that each
think they know what is still undecided, and they will disagree. Charting walks one map, one
ticket at a time. A second map would make you choose between them every session, and it
would hide how the new feature and the work in flight depend on each other. Folding the
feature into the open map keeps one list of what is unknown about this product.

---

## Why this doc exists

The [skill](../../templates/skills/add-feature/SKILL.md) tells you how the gate runs. The
[spine](01-the-solo-path.md) tells you where the solo path stops. Neither answers the
questions you have once you are past the seam with one more idea:

- **Past the seam, nobody hands you a ticket.** This gate is what you use instead.
- **The seam check only reads.** Setup has one home, [`/adopt`](09-adoption.md), and the two
  stop messages send you to the stage that owns your project.
- **Question zero checks against what was recorded.** It does not ask the destination again.
- **Off-destination is a reroute, not a kill.** It belongs to a different decision.
- **Fog routes the build, never size.** An open map absorbs it, because one product has one
  open frontier.

Read [02-the-kill-gate.md](02-the-kill-gate.md) for the gate this one is modelled on,
[03-charting.md](03-charting.md) for where a foggy feature goes, and
[08-ticket-pipeline.md](../shared/08-ticket-pipeline.md) for where a clear one goes.

---
> **Last verified against:** Claude Code `2.1.226` — August 2026
