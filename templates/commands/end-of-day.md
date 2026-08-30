---
description: Daily memory nomination — harvest the day's durable conclusions, dedupe, approve each individually.
---

Harvest today's durable knowledge into memory. Do it deliberately, with a high bar.

## Sequence
1. **Scan** today's session transcripts for durable conclusions:
   - root causes,
   - negative / staging findings ("X doesn't work because Y; here's what we ruled out"),
   - cross-repo blast-radius facts,
   - reusable recipes,
   - settled decisions.
2. **Filter out** anything that's NOT durable knowledge:
   - in-flight ticket state (handoff files already covered that),
   - anything already in code, git history, or a CLAUDE.md,
   - facts that only matter to today's conversation.
3. **Dedupe** each candidate against existing memory (query first).
4. **Draft** the survivors to `<workspace>/.claude/memory-review/<date>.md`.
5. **Present one at a time** for explicit approval. Write to memory **only** on per-item
   approval, using the `memory-schema` skill (tag by functionality, never by ticket id).

## The bar
0–5 candidates on a normal day. **Zero is a correct outcome.** If everything gets
nominated, the memory becomes a junk drawer and retrieval quality collapses. When in
doubt, leave it out.

## Then say what they do now

End with the `next-steps` block: the memory ids written, and the draft file's path for
anything still un-approved; the candidates still waiting on a per-item yes, because none of
them lands without one; no next command — the day is done; and nothing to commit, since
memory is not a repo artifact. **On zero candidates say exactly that.** Zero is a correct
outcome, and an ending that simply stops reads like the scan failed.
