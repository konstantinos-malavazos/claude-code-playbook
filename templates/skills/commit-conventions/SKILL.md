---
name: commit-conventions
description: >-
  Canonical commit / branch convention for this workspace. Type/scope/ticket-id format,
  allowed values, the MR/PR description template, and the one-commit-per-branch rule.
  Auto-loads when about to commit, when naming a branch, or when finishing a logical
  change on a feature branch. Triggers on "commit", "commit message", "branch name",
  "MR/PR description".
---

# Commit & branch conventions

## Branch
```
<TICKET-ID>_<short-kebab-description>
```

## Commit
```
<type>(<scope>): <imperative summary> [<TICKET-ID>]
```
- `<type>` ∈ `feat` | `fix` | `chore`. Anything else → ASK.
- `<scope>` = <YOUR SCOPE RULE — e.g. the component/module/service touched>.
- `[<TICKET-ID>]` always at the end, in square brackets, matching the branch ticket id.

## One commit per branch per repo (amend-as-you-go)
Every feature branch lands as **exactly one commit per repo**.
```
existing=$(git rev-list --count origin/<main-branch>..HEAD)
if [ "$existing" -eq 0 ]; then
    git add <explicit-paths> && git commit -m "<message>"
else
    git add <explicit-paths> && git commit --amend --no-edit
fi
```
- Review-fix loops also amend — no follow-up "address review" commits.
- The reviewer asserts `git rev-list --count origin/<main>..HEAD` returns `1`.
- Never silently rewrite the message; if you disagree mid-flight → STOP and surface it.

## Never commit AI-infra files
`.claude/`, MCP-state dirs, memory files. Use explicit paths in `git add` — never
`git add -A`/`.`.

**Three exceptions, decided by whether a fresh clone would need the file:**
`.claude/agents/**` and `.claude/skills/**` are generated from this repo's `CLAUDE.md` and
are product files; and the repo's own `CLAUDE.md` is committable where
`~/.claude/repo-allowlist` says so. Everything else under `.claude/` regenerates or belongs
to your machine.

## MR/PR description template
```
## What
<one-paragraph summary of the change>

## Why
<the ticket goal / problem>

## How
<key decisions; anything a reviewer should look at first>

## Testing
<what you ran; what a reviewer should run>

## Blast radius
<downstream consumers / contracts touched, or "none">

Ref: <TICKET-ID>
```
> Keep replies/descriptions terse. <Add any house style rule here, e.g. dash usage.>
