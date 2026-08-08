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
  The analyzer can read the tracker but not touch code; the planner can design but can't write
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

- **Hooks hard-block** dangerous git (`reset --hard`, `--no-verify`, force pushes,
  branch deletes) at the tool layer — the *harness* runs them, not the model. Plain
  `push` is on the list too, but conditionally; see the last bullet.
- **Ask before writing anywhere other people can see it.** The test is the *audience*, not
  the tool: tracker comments, transitions and field edits need explicit human approval when
  they land somewhere others read — enforced by a read-only veto at the MCP layer, not just
  a policy line. On a private solo repo nobody is watching, so write freely; on a **public**
  one they are, so ask. Each tracker adapter declares which it is
  ([`templates/trackers/README.md`](templates/trackers/README.md)).
- **AI-infra files are sorted, not blanket-blocked.** The test is *provenance*, not path:
  **if you cloned this repo fresh on a new laptop, would you need this file?** The repo's
  own `CLAUDE.md` and the generated layer specialists pass it and are committed; memory
  state, handoffs, the code index and generated views fail it and never are. A rule that
  names locations instead of origins breaks the moment one of your own flows starts
  producing files at those locations — which is exactly what happened.
- **Push is a per-repo answer, and the default is no.** The human owns the irreversible
  outward-facing steps (push, open the MR/PR, merge) unless that repo is explicitly listed
  in `~/.claude/repo-allowlist`, keyed by remote URL. The hooks are wired globally — one
  install, every repo — so an allowlist is the only thing that lets a weekend project
  loosen without loosening the live project two folders over. `git add -A` stays blocked
  everywhere regardless.

The rule of thumb: *if it's hard to reverse or leaves your machine, a human confirms it.*

**That is two tests, not one** — *reversibility* and *audience* — and working alone deletes
exactly one of them. Owning the project makes nothing easier to undo, so the reversibility
half is untouched; the audience half was doing all its work because the driver did not own
the repo. Every solo verdict falls out of that one sentence, worked through in
[docs/solo/07-guardrails-when-solo.md](docs/solo/07-guardrails-when-solo.md).

> **These are defaults with a reason, not laws.** They were written out of a workflow where
> the driver does **not** own the code or the projects, which is why they are so cautious.
> Every rule above is protecting something specific — usually *"someone else owns this"* or
> *"other people are watching"*. On a project you own outright, ask what the rule was
> protecting and re-derive the right answer, rather than either obeying it blindly or
> deleting it. Note that "nobody is watching" stops being true the moment a repo is public.

---

## 6. Read-first, staging-only for anything live

Any interaction with real infrastructure is **read-first**. Where the flow must write
(e.g. produce a test event), it does so **on staging only**; production is forbidden by
default and every other write-class action needs explicit approval. Investigations prove
root cause from returned data — they never patch blindly.

> **This is the one section that does not survive solo work, and it is replaced rather than
> relaxed.** A weekend project has no staging tier, so the environment axis has nothing to
> point at — while a live payment API and your only copy of real data are still there. The
> replacement asks the rule of thumb directly: *can I undo it, and does it touch anyone but
> me?* See
> [docs/solo/07-guardrails-when-solo.md](docs/solo/07-guardrails-when-solo.md).

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

"Is this getting more efficient?" should be answerable with a number rather than a
feeling — but the units are yours, and the measuring is optional. Pick what would
change what you *do*; a metric nobody acts on is overhead. A team costs each run
against story points, where the scarce resource is budget and no single person can
see the whole picture. Working alone both of those change, and so do the numbers.
The memory is the one case with the same answer either way: a periodic golden-query
eval, because a memory that is never retrieved fails silently, and no amount of
attention catches a thing that did not happen.

The two instances: [docs/team/01-metrics.md](docs/team/01-metrics.md) (the ledger, story
points, cost per ticket) and
[docs/solo/07-guardrails-when-solo.md](docs/solo/07-guardrails-when-solo.md) (two numbers,
counted by hand). Neither is the rule; the paragraph above is.

---

## The mindset in one sentence

> Give the agent **eyes** and a **memory**, wrap the work in **scoped flows** with
> **file handoffs** and **hook guardrails**, keep **durable knowledge separate from
> in-flight noise**, and **measure** whether it's compounding.
---

> **When this mindset doesn't apply** — see [docs/shared/12-when-not-to-use.md](docs/shared/12-when-not-to-use.md) for the boundaries of this pattern.
---
> **Last verified against:** Claude Code `2.1.226` — August 2026
