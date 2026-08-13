---
description: >-
  Read a repo and write it into memory as tagged memories, in batches. Auto-detects the path:
  no project for this repo means bootstrap (draft and prove a tag vocabulary, then encode); an
  existing project means delta (diff from the watermark commit, then encode what changed).
  Pass `all` to run every encoded repo and print one cross-repo table.
argument-hint: "[repo-name | all]"
disable-model-invocation: true
---

# Encode codebase — `$ARGUMENTS`

Read a repo. Write it into memory. Serena finds the code by symbol. The work runs in batches,
and a **fresh agent handles each batch**, so a long run never fills one context.

Two commands, two jobs, no overlap:

- **this one** — put knowledge in. Recon, vocabulary, inventory, batch loop, audit.
- [`/garden-memory`](garden-memory.md) — keep what is already in there healthy. Duplicates,
  obsoletes, retags, the retrieval eval.

`memory-schema` carries the call shape and the caps. Load it before any write.

## What this needs declared before it can run

This command takes **no stack facts from its own body**. It reads them from the
`## Memory encoding` section of the repo's `CLAUDE.md`
([template](../claude-md/repo.CLAUDE.md)). Absent, or any line still bracketed → **STOP** and
name the exact line. Never guess one. The same split the layer chain and the testing seams
already use: the command holds the method, one declaration holds the nouns.

The declaration answers five things: which languages your Serena install indexes (the flow
works on those and says so and stops otherwise), where the authoritative vocabulary lives,
what a tier tag means in this repo, whether there is an **optional extra tag axis**, and the
work-list inclusion rule.

## Paths on disk

```
<workspace>/.claude/encode-runs/<repo>/          run state
<workspace>/.claude/encode-vocab/<repo>.json     vocabulary cache — a BUILD ARTIFACT
<workspace>/.claude/memory-eval/golden-queries.yaml   the golden set — human-owned
```

**Run state never goes in `handoffs/`.** That directory is wiped at session end, and this flow
spans sessions by design — the watermark is what lets a later session pick the work up.

## Always show the path

**Whenever you name an artifact that is ready to look at, give its full path in the same
breath.** Every time, not just the first. The user reads these to check your work, and a bare
"the vocabulary" makes them hunt for something you already know the location of.

**The approval gates are the strict case.** At steps 5 and 9 the user is asked to approve or
promote something. There the path is not a courtesy — it is what makes the approval real. A
gate that names an artifact without its path is a defective gate.

---

## Step 0 — resolve the argument

- **`all`** → run steps 1–9 for each encoded repo in turn, then step 10.
- **A repo name** → steps 1–9 for that repo.
- **Empty** → list the repos that have a memory project, list the ones that do not, and ask.

In `all` mode, sync each repo first: fetch, checkout its main branch (read the name from that
repo's `CLAUDE.md`, never assume), pull `--rebase`. A dirty tree → **STOP and ask**, never
auto-stash. A rebase conflict → **STOP and surface**, never resolve silently.

## Step 1 — detect the path

List the memory server's projects.

- **No project for this repo → Path A (bootstrap).** Nothing to inherit.
- **A project exists → Path B (delta).** Its memories are input, not truth.

Report the path, the project id, and the memory count.

## Step 2 — regenerate the vocabulary cache

**Unconditionally, every run.** Not "if changed".

Read the authoritative vocabulary and write the cache from it.

- The cache version differs from the authoritative one, or the cache is missing → **the
  authoritative copy wins. Overwrite. No prompt, no merge.**
- The cache looks hand-edited → **discard the edit** and put one line in the report: *"local
  tag cache was edited, discarded, version N applied."*

Nothing writes the cache except this command, and nothing else reads the authoritative copy.
That is what keeps two copies from ever drifting. A scheme that asks a human to keep two copies
in step is a scheme that discovers they diverged months later.

No vocabulary yet → it does not exist, and step 3 must produce it. **A repo with memories and
no written vocabulary is a normal Path B starting state**, so it runs the full prologue below,
gate included.

## Step 3 — recon

Dispatch **`@encode-recon`** for the repo. It is read-only on memory, and it produces, in
`<workspace>/.claude/encode-runs/<repo>/`: `recon.md`, `vocab-proposed.json`, `worklist.json`,
`inventory.md`, `rename-map.json` (Path B only) and `dry-run.md`.

Read `recon.md`. **Do not read the memories it read.**

## Step 4 — the proving gate

The vocabulary does not lock until both hold:

1. **The 10-unit dry run passes** (`dry-run.md`, no writes). Every unit fully taggable. No tag
   on over 80% of units. No tag on fewer than 2 units.
2. **5 golden questions exist for the repo**, written by recon from the code — never from a
   memory, which would only prove memory agrees with itself.

A fail goes back to `@encode-recon` to revise. **Two fails in a row is a conversation, not a
third try** — at that point the repo's shape is the likelier problem than the draft.

## Step 5 — user approval gate

Show the user, compactly. **Every bullet naming a file gives its full path.** They cannot
approve what they cannot open.

- the detected path, A or B, and the memory count on B
- the proposed axes, one line of justification each → `…/encode-runs/<repo>/vocab-proposed.json`
- the mandatory skeleton, which is **not negotiable**: the repo tag and one tier tag, plus the
  declared optional axis if the repo declares one
- the work-list size after ranking and cut → `…/encode-runs/<repo>/worklist.json`
- tier-1 candidate patterns, stated as an incomplete list, because it always is
- Path B: the tag histogram, the drift, the ledger holes, the duplicates →
  `…/encode-runs/<repo>/rename-map.json` and `…/encode-runs/<repo>/inventory.md`
- the proving-gate result → `…/encode-runs/<repo>/dry-run.md`
- the 5 golden questions → `…/encode-runs/<repo>/candidate-questions.yaml`, and the file they
  would land in, `<workspace>/.claude/memory-eval/golden-queries.yaml`

Ask for four separate approvals. **Never bundle them.**

1. **The vocabulary** → on approval, write it to its authoritative home at version 1, then
   regenerate the cache from it (step 2 again).
2. **The work-list inclusion rule** → stored with the vocabulary, so next month reproduces the
   same list instead of a differently-drawn one.
3. **The rename map** (Path B, if any) → approval means it is **handed to `/garden-memory`**,
   which already does exactly this job. **This command never applies it, and new encoding never
   waits for it.**
4. **The golden questions** → approved ones are appended to the golden set by the user's
   decision, with no agent marker, because these are theirs.

Then report **both** locations of the vocabulary — the authoritative one and the regenerated
cache. Two copies exist by design, so name both or the user checks the wrong one.

## Step 6 — Path A only: create three things

1. **The project**, named for the repo, with a one-line description.
2. **One foundation record** — what the repo is, its layers, its mechanisms.
3. **The watermark memory** — tagged as the watermark plus the repo tag, holding the current
   `git rev-parse HEAD`. This is the bookmark the next run reads.

**Do not create entities.** Link to the ones that exist. The repo is already the project.

## Step 7 — discover the work

**Path A** → the work is the whole ranked work-list.

**Path B** → read the SHA from the watermark memory, then
`git -C <repo> diff <watermark-sha>..HEAD --name-status`. Git reports renames itself as `R`, so
moved files come free — never match filenames by hand to guess at a rename.

Map the diff onto the work-list:

- **new file** matching the inclusion rule → encode
- **changed file** with a memory → update that memory
- **renamed file** → update the memory's source-file list, not a new memory
- **deleted file** with a memory → mark obsolete with a reason, **never delete**
- **new file** outside the inclusion rule → skip, and count the skips

Then reconcile against `inventory.md`. **Any disagreement between the memories and the disk is
a finding to report, not a silent fix.**

## Step 8 — the loop

Repeat until the work-list is done or the cap is hit:

1. Dispatch a **fresh `@encoder`** with the repo and the current `position`. **A new instance
   every batch.** Never reuse one.
2. Batch size: **8 symbol-level units, or 3 architecture-level units.**
3. The encoder gates every write on the approved vocabulary. **No pass, no write.**
4. Then dispatch a **fresh `@encode-rechecker`** over that batch's memory ids — a new instance
   every batch, same as the encoder. It is read-only, it fixes nothing, and it writes
   `lint-recheck-batch<N>.md` into the run folder.

   It exists because **the encoder's own report is a claim, including its self-assessments.**
   Point it at the batch's ids and the run folder — do not re-brief it on the rules, which are
   in its own charter where they survive the session.

   **Never let the re-checker apply what it finds.** A correction goes to
   **`@encode-corrector`**, and only after the user approves it. **Brief it on the finding, not
   on the rules.** An auditor that repairs its own findings destroys the evidence that the
   audit worked, and a correction agent that trusts its brief will eventually "fix" something
   that was right.

   `@encode-corrector` also owns **every memory write in this flow that is not batch
   encoding** — amending the vocabulary and regenerating the cache. That is not a convenience.
   `@encode-recon` and `@encode-rechecker` are chartered read-only and hold no write tool, and
   `@encoder` is a batch worker driven by a work-list and a cursor. Without the corrector those
   writes fall to a general-purpose agent holding every tool, limited only by whatever the
   orchestrator remembers to type that day.
5. Read the batch report. Keep **one line** in context: batch number, units done, anomalies.
   **Never read a memory body. Not once.** That is what stops this command from filling up.
6. **Stop and ask on an anomaly:** a tag outside the vocabulary; two or more memories on one
   file; a source file that is missing with no git rename; more than 3 low-confidence units in
   a batch; a whole new subsystem in the diff.
7. **"Continue" is required from the user for the first two batches.** That is where a bad
   vocabulary shows itself, while it is still cheap to fix.
8. **Cap: 30 units per session.** Then stop, even with work left.

## Step 9 — close the session

1. **Write the watermark** — `git rev-parse HEAD` — **only if the batch that just ran was
   clean, and clean means both**: the encoder finished without a stop-worthy anomaly, **and**
   `@encode-rechecker` returned a pass on it. An encoder-clean batch with no re-check is **not
   clean, it is unverified**, and the watermark stays put. A session that stopped on an anomaly
   leaves the old SHA too, so the next run redoes that ground rather than skipping it.
2. Show the candidate golden questions and name the file they would be promoted into. The user
   promotes them **one at a time**. Agent questions prove retrieval works; the user's own
   questions prove you encoded the right things. **They are not interchangeable, so never merge
   the two kinds silently.**
3. Report. Every line carries a full path or an id, so the report is a set of things the user
   can open rather than a set of claims:

```
# Encode — <repo> — <date>

Path        : A or B
Units done  : <n> of <total>   (cap 30)
Created     : <n> memories (ids)   Updated: <n>   Obsoleted: <n>
Skipped     : <n> files outside the inclusion rule
Anomalies   : none | <what stopped it>
Watermark   : <sha> | unchanged, session ended on an anomaly
Vocabulary  : <authoritative id or path> v<n>  +  <workspace>/.claude/encode-vocab/<repo>.json
Run state   : <workspace>/.claude/encode-runs/<repo>/
Golden set  : <workspace>/.claude/memory-eval/golden-queries.yaml  (<n> promoted)
Handed to /garden-memory : <n> rename-map entries | none
Left to do  : <n> units. Run again to continue.
```

## Step 10 — cross-repo report (`all` mode only)

One table: repo, path, units done, units left, anomalies, watermark moved yes or no. Then one
authorization question for anything deferred.

---

## Hard rules

- **No approved vocabulary, no writes.** Ever.
- **Never name a ready artifact without its full path or id.** Every time it comes up.
- **The vocabulary gates every write.**
- **Never delete a memory.** Mark it obsolete, with a reason and a superseded-by pointer.
- **One owner project per memory** — the repo where the behaviour starts. Then link outward.
  Multiple owners sound tidy until two delta runs fight over the same memory.
- **The source-file list is mandatory on every symbol-level memory.** It is the reverse index
  the inventory is rebuilt from.
- **Never create an entity.** Link to the ones that exist.
- **The inventory is derived, never authored.** Rebuild it every run.
- **The vocabulary cache is a build artifact.** The authoritative copy always wins.
- **This command never applies the rename map.** `/garden-memory` does.
- **Never write run state to `handoffs/`.** The session-end hook wipes it.
- **Never dispatch a general-purpose agent for a memory write.** Batch encoding is `@encoder`;
  every other write is `@encode-corrector`. The four specialist agents carry their limits in
  their charters, where they outlive the session that dispatched them.
- **Never commit, never push.**
