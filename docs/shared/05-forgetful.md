# 05 — Forgetful: a memory that survives (pillar two)

**What it is:** a self-hosted, persistent semantic memory. It stores conclusions as
linked **memories** and retrieves them by *meaning*, not keyword. Knowledge persists
across sessions, machines, and weeks.

Forgetful is open-source, ships a PostgreSQL + pgvector backend, speaks HTTP, and can
embed locally. So memory content never has to leave the host, which matters in a
regulated or privacy-sensitive environment.

> Any semantic-memory MCP with create/query/link works here. This playbook uses Forgetful
> as the reference implementation. The *pattern* is what matters.

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
- **Tags by functionality**, not by ticket id. You'll search by topic/symbol/component
  later, never by ticket number. (Put the ticket id in the body if you want provenance.)
- **Links** between related memories, so one query returns the whole chain (root cause →
  fix → blast radius → test recipe).
- A **confidence** and a **validated** marker where relevant (e.g. a test recipe that's
  "provisional" until a real staging run flips it to "validated").

Your memory server has its own exact call shape and field limits. Capture those in a
`memory-schema` skill, so the agent uses the right shape and stops inventing fields.
See [`../../templates/skills/`](../../templates/skills/).

**If you run Forgetful, that skill is already written**:
[`../../templates/skills/memory-schema/forgetful.SKILL.md`](../../templates/skills/memory-schema/forgetful.SKILL.md)
ships filled in — the wrapper-trio call shape, the 2000-char `content` cap, the strict
`entity_type` / `project_type` enums, the asymmetric linking table, and the three tools
that look obvious and do not exist. `mv forgetful.SKILL.md SKILL.md` inside that folder
and delete the placeholder. Everything else in this playbook stays server-agnostic: it
loads `memory-schema` by name and never names Forgetful.

That file is worth having whether or not the shape ever surprises you. A memory write that
fails validation is cheap; one that *succeeds* with `project_ids: []`, or with the ticket
id as a tag, is not — it is invisible or unfindable months later, and nothing at write time
says so. Enums and caps are what the skill enforces; the tagging and scope rules are what
it is actually for.

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

Config snippet: [`../../templates/mcp/global.claude.json.snippet`](../../templates/mcp/global.claude.json.snippet)
— paste it as-is. What each entry means is in
[`../../templates/mcp/README.md`](../../templates/mcp/README.md).

---

## A note on sharing it across a team

See [02-team-adoption.md](../team/02-team-adoption.md) for the team-wide governance discussion.

Per-developer memory compounds for one person. The obvious next step is **one shared
memory** the whole team contributes to and queries. A bug root-caused once becomes
queryable by everyone, forever. That is feasible: Forgetful is built as a shared
knowledge base. But the real gate is **governance**, not throughput. A shared store needs
access gating, a strict **no-secrets / no-raw-PII** contribution policy, hosting on
approved infrastructure, and a data-protection review before launch. Start personal.
Graduate to shared once the policy is in place.
---
> **Last verified against:** Claude Code `2.1.226` — August 2026
