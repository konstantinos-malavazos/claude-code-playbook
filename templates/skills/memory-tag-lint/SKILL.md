---
name: memory-tag-lint
description: >-
  The write gate for /encode-codebase — the seven assertions every candidate memory must pass
  before it is written, and the positive control that proves the gate is wired up. Auto-loads
  before encoding a unit, before re-checking an encoded batch, and when running the proving
  gate on a draft vocabulary. Load it whenever a tag is about to be written or judged.
---

# Memory tag lint (the write gate)

**This file is the single definition of the gate.** Three agents apply it and they must apply
it identically: `@encoder` enforces it before every write, `@encode-rechecker` re-runs it as a
positive-controlled audit, and `@encode-recon` checks its 10 dry-run samples the same way. If
one of those files and this skill disagree, **this skill wins** — say so and stop, rather than
enforcing two gates.

That rule exists because of a real failure. A vocabulary cache key was renamed, the
drifted-tag assertion silently dereferenced a key that no longer existed, and the check never
fired again — for 29 tags across two vocabulary versions. Nothing errored. The gate reported
clean the whole time. **A schema that no single file owns is a schema that drifts, and this
one failed open.**

## Check against the cache, never against memory of it

Every assertion is evaluated against the regenerated vocabulary cache at
`<workspace>/.claude/encode-vocab/<repo>.json`, read at the time of the check. Never against
what the vocabulary said earlier in the session, and never against a vocabulary you remember
approving. The cache is a build artifact regenerated every run, and it is the only copy the
gate reads.

**A hand-edited cache is reported, not repaired.** Use it as it stands and put one line in the
report. Repairing it locally hides a drift between the cache and its authoritative source.

## The seven assertions

All seven pass → write. Any fail → fix the candidate, or stop. **Never write past a fail.**

| # | Assertion | Fails as |
|---|---|---|
| 1 | Every tag sits on an axis the vocabulary **declares** | ERROR |
| 2 | The mandatory skeleton is complete: the repo tag **and** exactly one tier tag | ERROR |
| 3 | No tag is a known drifted form of a canonical tag (check the rename map) | ERROR |
| 4 | The tag count is within the vocabulary's cap | ERROR |
| 5 | The required body sections for this tier are present and non-empty | ERROR |
| 6 | The source-file list is non-empty and **case-exact** against `git ls-tree` | ERROR |
| 7 | Exactly one owner project | ERROR |

**Assertion 1 is an ERROR, not a warning.** A tag on an undeclared axis is how a vocabulary
quietly grows a sixth axis nobody approved, and every future query then has to know about it.

**Assertion 6 is case-exact on purpose.** A path that differs only in case resolves on a
case-insensitive filesystem and fails on the build server, and the memory that names it is the
reverse index the whole inventory is rebuilt from.

**The optional axis is optional.** If the vocabulary declares no extra axis, a tag from one is
an assertion-1 violation — not a bonus. If it does declare one, the axis is mandatory only on
units that axis actually distinguishes, never on a shared-contract unit.

## Prove the gate fires — once per batch

Feed the gate **one known-bad tag** per batch and confirm it rejects. This is not ceremony:

**A gate nobody has seen reject anything is indistinguishable from a gate that is not wired
up.** Both report clean. The renamed-key failure above ran green for two vocabulary versions
precisely because nothing ever tested the negative case.

Record the control's result next to the batch's result. A control that fails to reject is a
BLOCKER on the batch, whatever the batch itself reported.

## If you have a validator script

Run it and require **exit 0** in addition to the assertions above — never instead of them. A
script is additive here.

**Check the keys the script dereferences against the cache it reads**, and fix the cache rather
than renaming a template key. Renaming a key the validator reads is exactly how the gate above
failed open.

---

**On loops over a list.** Where this gate is implemented as a loop over patterns or assertions,
every entry needs its own test case. A loop is only as tested as its least-tested entry, and
the untested one is free to fail open — see the same lesson in
[`../../README.md`](../../templates/README.md).
