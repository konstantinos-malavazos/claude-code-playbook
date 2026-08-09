---
description: Walk a stage 2 charting map unattended, stopping only when the map stops, the map turns out to be broken, or the budget runs out. Answers grillings from the record and takes the tail - it will name your stack. Every guess is logged. Solo path only, and never on a shared tracker. For a map you have decided is cheap enough to be wrong about.
argument-hint: <effort-slug> [--max <n>] — which map to walk; --max caps iterations (default 12)
disable-model-invocation: true
---

# Feeling Very Lucky — $ARGUMENTS

Walk the map until it ends. Do not stop for a decision.

**Read [`docs/solo/08-feeling-lucky.md`](../../docs/solo/08-feeling-lucky.md) first — it owns
the method for both settings.** Then the `charting` skill and your tracker adapter.

**The walk itself is identical to [`/feeling-lucky`](feeling-lucky.md).** Run its steps 0–4
and 6 exactly as written — the guards, the counters, the loop, the dispatch table, the
two-agent grilling, the handoff. This file replaces **one** thing: the halt table, stated in
full below rather than as a diff. Its three hard rules are unchanged, including **never touch
the massive-ticket flow**.

## Read this before you type it

`/feeling-lucky` stops at the decisions that are expensive to get wrong. This one does not.
On a stage 2 map — which is [almost entirely
decisions](../../docs/solo/08-feeling-lucky.md) — that means an agent may settle what the
product is, what it is called, and **what it is built on**, from a record you have not
finished writing.

**It will take the tail.** *Name the stack* is downstream of nothing and upstream of
everything: the bootstrap, the layer chain, every one of the eight seam checks. Undoing it is
not a ticket, it is starting again.

**It will then stop immediately, and that is correct.** The tail's second ticket — *write the
bootstrap checks* — is [the one make the solo path
guarantees](../../docs/solo/03-charting.md), and stage 2 has no declared chain to dispatch
it to. So the realistic end of a `--very` run is: your stack was chosen for you, and the very
next ticket handed the map back. Read `guesses.md` before you touch anything downstream of
that choice.

That is a real thing to want — a weekend idea you would rather see built badly tonight than
correctly next month. It is just not the usual thing to want, and the command will not
pretend otherwise in the morning.

## Halt

Test after every iteration. First match wins.

| Condition | Halt? | Reason to log |
|---|---|---|
| basis `grounded` | no | — |
| basis `guessed`, reversibility `ONE MORE TICKET` | **no** — log and continue | — |
| basis `guessed`, reversibility `A RE-CHART` | **no** — log and continue | — |
| basis `yours` | **no** — log and continue | — |
| only the tail is takeable | **no** — take it | — |
| `consecutive_soft >= 3` | **halt** | `fog` |
| `iterations >= max` | **halt** | `cap` |
| frontier empty | **halt** | `ending` |
| a `prototype` ticket | **halt** | `prototype` |
| a `make:<layer>` ticket | **halt** | `no-chain` |
| a ticket appeared claimed to another person | **halt** | `handoff` |

**Every guess is still logged in full** — basis, citation-or-gap, reversibility, and what
would settle it. This setting changes whether the walk *continues* after logging. It never
changes what gets written down. A walk that stopped recording would not be lucky, it would be
unaccountable.

**`prototype` still halts, and there is no flag for it.** A grilling can be answered from the
record, because a record is the kind of thing a decision can be grounded in. *Reacting* is
not — the reaction **is** the ticket.

**The breaker and the cap fire here too, deliberately.** This command promises not to stop
for a decision. It does **not** promise to keep running on a map that is broken or a budget
that is spent. Three soft answers in a row means the map was charted in more fog than anyone
realised — past that point you wake to nine open questions and nine spent sessions, every one
of which reads like progress in a log. **A loop cannot tell working from failing
productively.** That is why the one thing it may never do is run forever.

## The handoff

`/feeling-lucky`'s step 6, with the ordering rule enforced harder: **lead with what cannot be
undone.**

```
Walked <n> of <max>. Halted: <reason>.

⚠ Decided for you, and hard to reverse: <n>
   <each one: the question, the answer taken, and what already depends on it>
   <if the tail was taken, it goes first: the stack, and why it picked that>

Yours, decided anyway: <n>
   <each one, one line>

Guessed, cheap to reverse: <n> — see .claude/lucky/guesses.md
Resolved: <ticket numbers and gists>
Waiting on: <ticket — the thing, and who owns it>
Progress: <n> of <m> resolved.
```

That first block holds the decisions the owner would have been asked about, taken without
them, on something a ticket cannot undo. Burying them under a count of closed tickets is the
one formatting choice here that could actually cost a map.

## Never

`/feeling-lucky`'s prohibitions all hold here unchanged. One of them changes weight:

- **Never skip the citation check on a `grounded` answer.** Nothing downstream halts, so this
  check is the only thing standing between this command and a night of confident invention.
