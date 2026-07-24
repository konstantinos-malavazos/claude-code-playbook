# 05 — Forgetful: a memory that survives (pillar two)

**What it is:** a self-hosted, persistent semantic memory. Conclusions are stored as
linked **memories** and retrieved by *meaning*, not keyword. Knowledge persists across
sessions, machines, and weeks.

Forgetful is open-source, ships a PostgreSQL + pgvector backend, speaks HTTP, and can
embed locally — so memory content never has to leave the host, which matters in a
regulated or privacy-sensitive environment.

> Any semantic-memory MCP with create/query/link works here. This playbook uses Forgetful
> as the reference implementation; the *pattern* is what matters.

---

## Why it matters

| | Re-investigate from scratch | One memory query |
|---|---|---|
| Cost | hours–days, repeated staging runs, tens of thousands of tokens | one call, seconds, a few thousand tokens |
| Quality | risk of missing the subtle bit → wrong conclusion again | the full conclusion chain, with provenance and links |

The killer case is the **negative result**. "We tried X; it doesn't work on staging for
reason Y; here's what we ruled out" is expensive to rediscover and easy to forget.
Banking it once saves the next person (or the next-you) from paying for it again.

---

## The two-memory rule (the reason it stays useful)

Memory is only valuable if it's **signal-dense**. So:

- **In-flight ticket state** → filesystem handoff files, auto-deleted at session end.
  Never written to Forgetful.
- **Durable conclusions** → one consolidated memory per ticket, written only when the
  ticket is done (root cause, fix shape, blast radius, reusable recipes, settled
  decisions).

If you write chatter to memory, retrieval degrades and the whole pillar rots. Guard the
gate: nothing enters memory un-reviewed. See [10-memory-hygiene.md](10-memory-hygiene.md).

---

## How memories are shaped

Keep memories **atomic and tagged**:

- **One fact/conclusion per memory**, with a short title and a body that states *what*
  and *why*.
- **Tags by functionality**, not by ticket id — you'll search by topic/symbol/component
  later, never by ticket number. (Put the ticket id in the body if you want provenance.)
- **Links** between related memories, so one query returns the whole chain (root cause →
  fix → blast radius → test recipe).
- A **confidence** and a **validated** marker where relevant (e.g. a test recipe that's
  "provisional" until a real staging run flips it to "validated").

Your memory server will have its own exact call shape and field limits — capture those
in a `memory-schema` skill so the agent uses the right shape and stops inventing fields.
See [`../templates/skills/`](../templates/skills/).

---

## How it plugs into the flow

- **First action of any non-trivial session** — query memory for prior context on the
  topic/component/ticket before touching code.
- **The gatherer** does the heavy sweep in a throwaway context and distils it into the
  handoff brief.
- **On APPROVE**, the ticket's handoff files are consolidated into one durable memory;
  the handoffs then evaporate.
- **`/end-of-day`** harvests any other durable conclusions from the day.
- **`/garden-memory`** periodically evaluates retrieval quality and prunes cruft.

Config snippet: [`../templates/mcp/global.claude.json.snippet`](../templates/mcp/global.claude.json.snippet).

---

## A note on sharing it across a team

See [14-team-adoption.md](14-team-adoption.md) for the team-wide governance discussion.

Per-developer memory compounds for one person. The obvious next step is **one shared
memory** the whole team contributes to and queries — a bug root-caused once becomes
queryable by everyone, forever. That's feasible (Forgetful is built as a shared
knowledge base) but the real gate is **governance**, not throughput: a shared store needs
access gating, a strict **no-secrets / no-raw-PII** contribution policy, hosting on
approved infrastructure, and a data-protection review before launch. Start personal;
graduate to shared once the policy is in place.
-e 
---
> **Last verified against:** Claude Code `[run \`claude --version\` and insert here]` — July 2026
