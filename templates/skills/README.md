# Skill templates

Copy a skill's folder into `~/.claude/skills/` and fill in the `<PLACEHOLDERS>`.

## Anatomy of a skill

A skill is a directory containing `SKILL.md`:

```markdown
---
name: my-skill
description: >-
  WHAT it is + WHEN to use it. The harness matches this against the current intent to
  auto-load the skill, so be explicit about trigger conditions and phrases.
---

<the recipe: the steps / rules / templates the model should follow when this loads.>
```

- **Auto-loaded** skills fire on intent (e.g. "commit" → `commit-conventions`).
- **User-invoked** skills run when you type `/skill-name`.
- Keep the front `description` tight and trigger-focused; put the detail in the body.
- Skills can bundle extra files (templates, checklists) the body points to —
  progressive disclosure keeps the base cost low.

## The set

| Skill | Loads on / used for | solo | team |
|---|---|---|---|
| `commit-conventions` | about to commit / branch naming / MR-PR template | ✓ | ✓ |
| `engineering-standards` | **copy per layer** — the review/coding standard for that language | ✓ | ✓ |
| `tdd` | test-first feature/bug work (red-green-refactor) | ✓ | ✓ |
| `diagnose` | hard bugs / performance regressions | ✓ | ✓ |
| `grilling` | stress-testing a plan; the deferred-decision gate | ✓ | ✓ |
| `memory-schema` | before any memory WRITE — enforces your memory server's call shape | ✓ | ✓ |
| `research` | a decision blocked on an **outside** fact — third-party docs, a vendor API, a spec | ✓ | ✓ |

The **solo** / **team** columns say which entrance needs each template. Everything here is
shared today; the columns exist so path-specific templates can declare themselves as they
arrive.
