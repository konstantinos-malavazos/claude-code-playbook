---
name: research
description: >-
  Investigate a question whose answer lives OUTSIDE this workspace — third-party docs,
  a vendor API, a spec, an RFC — and capture the findings as a cited Markdown file.
  Dispatch it to a background agent so the main session keeps working. Use when a
  decision is blocked on a fact nobody here knows yet.
---

# Research — answer it from the source that owns it

Research is the **outside-knowledge** flow. Its whole job is to turn "nobody here knows"
into a cited fact somebody can decide on.

> Prior art: Matt Pocock's `research` skill (MIT). This is a re-derivation that wires the
> flow into the playbook's memory, Serena and handoff conventions.

## Know which tool owns the question

Getting this wrong is the expensive mistake — it burns a background agent rediscovering
something you already own.

| The question is about | Use | Not |
|---|---|---|
| **our** code — a symbol, a caller, a signature | Serena (`find_symbol`, `find_referencing_symbols`) | research |
| something we already concluded once | **query memory first** | research |
| a third-party API, spec, RFC, vendor doc | **research** | guessing from training data |
| a ticket's own requirements | the tracker | research |

**Query memory before you dispatch.** The two-memory rule means a prior investigation —
especially a *negative* result — is already banked and one query away. Re-researching it
is the exact cost the memory pillar exists to avoid.

## Dispatch it to the background

Hand the question to a background agent and keep working. Research is read-heavy and
context-hungry; it belongs in a throwaway context, like the gatherer's sweep. Give the
agent the **question**, not a topic — "does provider X's webhook retry on a 500, and with
what backoff?" not "look into webhooks".

## What the agent does

1. **Go to the primary source** — official docs, the spec, the vendor's own API
   reference, the library's source. Not a blog post *about* the source. Follow every
   claim back to whoever owns it.
2. **Cite every claim** with a link, and where the source is versioned, the version it
   was read at. A fact with no citation is a guess wearing a suit.
3. **Write one Markdown file** and say where it went. Match whatever convention the repo
   already uses for notes; if there is none, put it next to the ticket's handoffs and
   name the path in the report.
4. **Report the negative result too.** "The docs do not say" and "X is not supported" are
   findings, and they are the ones most expensive to rediscover.

## Landing the result

- **In-flight** → the findings file sits with the ticket's handoffs and evaporates with
  them.
- **Durable** → a conclusion that will matter again (a rate limit, an auth quirk, a
  ruled-out approach) gets banked as a memory on APPROVE, tagged by
  topic/component — **never** by ticket id.

Findings are **inputs to a decision, not the decision**. Hand them back to whoever owns
the call; don't let the research agent quietly settle the design on the way past.

## Stop condition

Stop when the question is answered from a primary source with a citation, or when the
agent can state precisely *why* the source doesn't answer it — and what it would take to
find out (a spike, a support ticket, a paid tier). "I couldn't find anything" without
that second half is not a finished research task.
