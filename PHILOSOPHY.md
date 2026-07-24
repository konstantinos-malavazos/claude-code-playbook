# The mindset

This is the *why* behind every template in this repo. If you internalize this page,
you can rebuild the rest yourself.

---

## 1. Give the agent capabilities before you give it tasks

An LLM coding agent has two structural handicaps. Fix the handicaps first; the
productivity follows.

- **It's file-blind.** To find one method it reads whole files — burning tokens and
  filling its context with noise — and it *guesses* symbol names. → Give it **eyes**: a
  semantic code-navigation server (Serena) that returns a symbol with its exact
  `file:line`, not the file.
- **It's amnesiac.** The moment the session ends, everything it learned is gone. Every
  investigation restarts from zero. → Give it **memory**: a persistent semantic store
  (Forgetful) where a conclusion reached once is retrievable forever.

Everything else — agents, skills, commands, hooks — is orchestration built *on top of*
those two capabilities.

---

## 2. Structure beats one big chat

One giant conversation doing analysis + design + coding + review blows its own context,
mixes concerns, and has no guardrails. Instead:

- **Scoped specialist agents.** Each agent does *one* job with *only* the tools it needs.
  The analyzer can read Jira but not touch code; the planner can design but can't write
  files; reviewers can read code but can't edit it. Scope = cheap + safe.
- **Retrieval is offloaded.** A throwaway "gatherer" context does the token-heavy memory
  and code sweep, then hands the *distilled brief* to the planner. The expensive context
  is discarded; the planner stays lean.
- **Handoffs are files, not chat.** Agents pass state through handoff files on disk that
  **auto-delete at session end**. In-flight noise never reaches long-term memory.

---

## 3. Two kinds of memory, deliberately separated

The single most important design decision:

| Kind | Mechanism | Lifetime | Example |
|---|---|---|---|
| **Ephemeral pipeline state** | filesystem handoff files (`…/handoffs/<TICKET>/`) | auto-deleted at `SessionEnd` | "Backend added field `X`; the client must map it to `Y`." |
| **Durable knowledge** | a persistent memory store (Forgetful) | permanent, cross-session | "Root cause: the fee is sourced from the wrong upstream event." |

In-flight chatter would **pollute** the semantic memory if written to it, so it goes to
disk and evaporates. Only the distilled, durable conclusion is consolidated into **one**
memory when the ticket is done. This keeps memory retrieval signal-dense.

---

## 4. The compounding loop

The pillars aren't additive — they multiply:

```
   remember  ──►  locate  ──►  edit  ──►  remember
   (Forgetful:    (Serena:      (surgical  (Forgetful:
    what & why)    where)        change)    new conclusion)
        ▲                                        │
        └──────── next ticket starts here ───────┘
                  (from the answer, not zero)
```

A bug root-caused once is queryable forever. A test recipe derived once is reused
forever. The value shows up on ticket *N+1*, not ticket 1 — which is exactly why it's
worth the up-front setup.

---

## 5. Guardrails enforced by the harness, not by trust

Don't rely on the model "remembering" not to do dangerous things. Make them impossible:

- **Hooks hard-block** dangerous git (`push`, `reset --hard`, `--no-verify`, force,
  branch deletes) at the tool layer — the *harness* runs them, not the model.
- **The ticket tracker is read-only by default.** Never write to Jira (comments,
  transitions, field edits) without explicit human approval — enforced by a
  read-only veto at the MCP layer, not just a policy line.
- **AI-infra files are never committed** to product repos (`.claude/`, `CLAUDE.md`,
  MCP state).
- **You push; the agent doesn't.** The human owns the irreversible outward-facing steps
  (push, open the MR/PR, merge).

The rule of thumb: *if it's hard to reverse or leaves your machine, a human confirms it.*

---

## 6. Read-first, staging-only for anything live

Any interaction with real infrastructure is **read-first**. Where the flow must write
(e.g. produce a test event), it does so **on staging only**; production is forbidden by
default and every other write-class action needs explicit approval. Investigations prove
root cause from returned data — they never patch blindly.

---

## 7. Coding behaviour (adopted defaults)

Four principles that keep the agent's output senior-grade
(after Andrej Karpathy's coding principles):

1. **Think before coding.** State assumptions; if multiple interpretations exist,
   surface them — don't silently pick. If a simpler approach exists, say so.
2. **Simplicity first.** Minimum code that solves the problem. No speculative
   abstractions, no unrequested flexibility, no error handling for impossible cases.
3. **Surgical changes.** Touch only what the task requires. Don't "improve" adjacent
   code or reformat. Match existing style. Every changed line traces to the request.
4. **Goal-driven execution.** Define success criteria, loop until verified. "Fix the
   bug" becomes "write a failing test that reproduces it, then make it pass."

---

## 8. Measure it

Every pipeline run is costed (tokens per story point, cache-reuse) so "is this getting
more efficient?" is a number, not a feeling. Token counts are durable — they survive
model-price changes. The memory gets the same treatment: a periodic golden-query eval
scores whether the canonical questions still retrieve the right answers.

---

## The mindset in one sentence

> Give the agent **eyes** and a **memory**, wrap the work in **scoped flows** with
> **file handoffs** and **hook guardrails**, keep **durable knowledge separate from
> in-flight noise**, and **measure** whether it's compounding.
-e 
---

> **When this mindset doesn't apply** — see [docs/13-when-not-to-use.md](docs/13-when-not-to-use.md) for the boundaries of this pattern.
-e 
---
> **Last verified against:** Claude Code `2.1.219` — July 2026
