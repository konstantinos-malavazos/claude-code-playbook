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

**Every field is optional; only `description` is recommended.** The harness supports more
than the two above:

| Field | What it does |
|---|---|
| `name` | **Display name only. Defaults to the directory name** — see below |
| `description` | What it does + when to use it. Truncated at 1,536 chars in the listing |
| `when_to_use` | Extra trigger phrases, appended to `description` and sharing that cap |
| `argument-hint` | Autocomplete hint, e.g. `[ticket-id]` |
| `arguments` | Named positional args for `$name` substitution |
| `disable-model-invocation` | `true` = only you can invoke it. **This is what makes a skill user-invoked** |
| `user-invocable` | `false` hides it from the `/` menu. Does *not* block the Skill tool |
| `allowed-tools` | Pre-approved for the invoking turn only — not a restriction |
| `disallowed-tools` | Removed from the pool while active |
| `model` / `effort` | Override for the turn the skill is active |
| `context: fork` + `agent` + `background` | Run the skill in its own subagent |
| `hooks` | Hooks scoped to this skill's lifecycle |
| `paths` | Globs limiting when the skill auto-loads |
| `shell` | `bash` (default) or `powershell` for inline `` !`cmd` `` blocks |

- **The directory name is what you type**, not the `name` field. `name` only changes the
  label in listings — so a skill in `foo/` is always `/foo`, however the frontmatter reads.
  **`engineering-standards` is the one template where this matters**: it is copied per
  layer, so rename the *directory* to `backend-standards` (or whatever) as well as filling
  the `<layer>` placeholder, or you will have three skills all answering to
  `/engineering-standards`.
- **Auto-loaded** skills fire on intent (e.g. "commit" → `commit-conventions`). This is the
  default: any skill without `disable-model-invocation: true` can be loaded by Claude.
- **User-invoked** skills run when you type `/skill-name`. **A description that says "use
  when the user says…" does not make a skill user-invoked** — it is a hint, not a
  constraint. Set `disable-model-invocation: true` if it must never fire on its own.
  Nothing in this set does yet; that is a deliberate default, not an oversight — see below.
- Keep the front `description` tight and trigger-focused; put the detail in the body.
- Skills can bundle extra files (templates, checklists) the body points to —
  progressive disclosure keeps the base cost low.
- **Live reload**: editing a `SKILL.md` takes effect in the current session. Agents do
  **not** work this way — see the agents README.

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
| `charting` | an effort too big for one session and too foggy to plan — maps it into decision tickets on the tracker | ✓ | |
| `pitch` | a raw idea with no repo — the one-hour kill gate that ends in build, kill or park | ✓ | |
| `bootstrap` | a decided-but-empty repo — scaffolds it and reports on the pipeline's preconditions. **Runs once per project** | ✓ | |

The **solo** / **team** columns say which entrance needs each template. `charting` was the
first to claim a single column, and `pitch` and `bootstrap` followed: all three are stages
of the solo front-end, which the agile path does not have. Everything above them is shared
by both.

`pitch` ships one agent alongside it — `pitch-judge`, in
[`templates/agents/`](../agents/README.md). The skill is not complete without it.

## On `disable-model-invocation` — one skill sets it, and the rule says why

Four of these read as user-invoked — `charting`, `pitch`, `grilling`, `diagnose` — and none
of them sets `disable-model-invocation: true`, so Claude may load any of them on its own.
That is left as-is on purpose: all four are **conversations**, and a conversation that
starts a turn early costs you one redirect.

The field earns its place on skills with **side effects or timing you own** — a deploy, a
commit, a send. **`bootstrap` is the first template here that meets that test, and it sets
the field.** It is not a conversation: it scaffolds a repo, writes a `CLAUDE.md`, indexes a
language server, generates agent files and writes memory. A conversation firing a turn early
costs a redirect; that firing early costs a tree of files nobody asked for. Same rule,
applied — not a new one.

`pitch` is the closest remaining call, since it dispatches subagents and spends real time.
Watch it; if it ever fires unasked, that is the signal to set the field rather than reword
the description.
