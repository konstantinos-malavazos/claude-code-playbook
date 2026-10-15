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

Memory is only valuable if it's **signal-dense**. The rule: **write what the next reader
will read, and nothing else.** So:

- **In-flight ticket state** → filesystem handoff files: scratch space that stays until you
  delete it, never a durable store. That includes the open questions a grilling round
  defers: they go in `open-questions.md` in the ticket's handoff folder, where
  `/resume-ticket` reads them. **No in-flight state goes to memory** — memory gets only the
  approval writes and the end-of-session writeback types.
- **Durable conclusions** → written only when the unit of work is done, and only what
  reading the code would not tell you. A ticket lands as separate, linked memories:
  - up to five `gotcha` memories, one per trap, non-obvious why, negative result,
    cross-repo contract or per-config divergence found in the code the ticket visited
    (importance 8, `source_files` = that file, owned by its repo). Zero is normal;
  - then one `feature` memory for what shipped (importance 6, `source_files` = the diff,
    one owner project), linked to each gotcha.

### Which flows write memory

| Flow | When | What it writes |
|---|---|---|
| `/start-ticket` | on APPROVE, at Land | up to five `gotcha` memories, then one `feature` memory linked to each |
| charting | when the map closes | one `ruling` memory per map (plus one per repo when it will not fit) |
| bootstrap | step 7 | memory two, a `ruling`: why this stack, why this chain, what was ruled out |
| `/test-ticket` | after the run | the `recipe` memory, banked or confirmed |
| `/end-of-day` | on per-item approval | the day's durable conclusions |
| session-end writeback | end of a session | one `gotcha`, `ruling`, `investigation` or `contract` memory — never flow state |

A changed fact gets a new memory, and the old one is marked obsolete with `superseded_by`.
A small correction is an update instead.

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

**Every memory has exactly one type**, carried as one tag. The type sets its importance
(±1) and whether `source_files`, the repo-relative files it is about, is required. The
seven are a default; edit them in the `memory-lint` skill's `vocab.json`.

| Type | Holds | Importance | `source_files` |
|---|---|---|---|
| `ruling` | a settled decision and its why | 9 | optional |
| `contract` | what one side promises another, across repos | 8 | required (both sides) |
| `gotcha` | a trap reading the code will not show | 8 | required |
| `architecture` | how a part fits and why | 8 | required |
| `investigation` | a negative result, what was ruled out | 7 | optional |
| `recipe` | reusable steps, such as a test's produce recipe | 7 | required |
| `feature` | what a finished ticket shipped | 6 | required |

**Anti-rot rules.** Serena reads structure live; memory keeps only what reading the code
would not tell you. Memory rots in predictable ways, so these stay out:

- **Line references** (`file.ext:123`, `line 123`, `L123`) — rejected. Name the symbol.
- **Branch state** ("branch X is current", "X is merged") — rejected.
- **Flow-state words** (`RESUME`, "in progress", "watermark") — rejected. In-flight state
  belongs in handoff files.
- **Hard counts** ("5 flags") — warned. The code changes and the count does not.
- **Tags that drift** — at least one repo/project tag, at most ten, lowercase. A renamed
  tag is rejected with its replacement named, a retired tag is rejected, and a tag shaped
  like a ticket id is rejected.

**Enforcement.** The `memory-lint` skill checks every create against these rules, and an
update on the fields it supplies. Its hook runs before the memory server's write tool and
blocks a write that fails; if the lint cannot run, the write is blocked too.
`/garden-memory` re-runs the lint over stored memories to catch vocabulary drift.

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

- **First action when starting work on a ticket, a component, or an investigation** —
  query memory for prior context before touching code.
- **The gatherer** does the heavy sweep in a throwaway context and distils it into the
  handoff brief.
- **On APPROVE**, the ticket's handoff text is harvested into up to five `gotcha`
  memories and one linked `feature` memory; the handoffs stay on disk as scratch space
  until you delete them.
- **`/end-of-day`** harvests any other durable conclusions from the day.
- **`/garden-memory`** periodically writes a read-only staleness report and changes a
  memory only on a per-row approval.

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
