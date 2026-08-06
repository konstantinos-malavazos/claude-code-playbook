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
  **`engineering-standards` is the one template where this matters**: there is one per
  layer, so the *directory* is named `backend-standards` (or whatever) as well as the
  `<layer>` placeholder being filled — otherwise you have three skills all answering to
  `/engineering-standards`. `/adapt-to-stack` does that renaming when it generates them;
  the rule is here because it is what makes the output distinct, not because you type it.
- **A personal skill beats a project skill of the same name** — the opposite of what "more
  specific wins" would suggest, and the opposite of how project *agents* resolve, where the
  definition closest to the working directory wins. It bites the generated per-layer
  standards skills, which live in a repo's own `.claude/skills/`: one stray
  `backend-standards` in `~/.claude/skills/` shadows every repo's generated one, silently
  and everywhere. Keep layer names out of `~/.claude/skills/`.
- **A `.claude/` directory created mid-session is not watched.** Edits to skills that
  existed at startup are picked up live; a `.claude/skills/` or `.claude/agents/` folder
  that did not exist when the session began needs a restart before anything can load from
  it. This is exactly the state `/adapt-to-stack` leaves behind on its first run.
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
| `engineering-standards` | **one per layer, generated** — the review/coding standard for that language | ✓ | ✓ |
| `adapt-to-stack` | a repo whose `CLAUDE.md` names a layer chain — generates one specialist and one standards skill per layer into that repo's own `.claude/`, and never overwrites | ✓ | ✓ |
| `tdd` | test-first feature/bug work (red-green-refactor) | ✓ | ✓ |
| `diagnose` | hard bugs / performance regressions | ✓ | ✓ |
| `grilling` | stress-testing a plan; the deferred-decision gate | ✓ | ✓ |
| `memory-schema` | before any memory WRITE — enforces your memory server's call shape | ✓ | ✓ |
| `research` | a decision blocked on an **outside** fact — third-party docs, a vendor API, a spec | ✓ | ✓ |
| `prototype` | a design question nobody can settle on paper — throwaway code built to be reacted to and then deleted | ✓ | ✓ |
| `charting` | an effort too big for one session and too foggy to plan — maps it into tickets on the tracker | ✓ | ✓ |
| `pitch` | a raw idea with no repo — the one-hour kill gate that ends in build, kill or park | ✓ | |
| `bootstrap` | a decided-but-empty repo — scaffolds it and reports on the pipeline's preconditions. **Runs once per project** | ✓ | |
| `cut-backlog` | a closed map + a scaffolded repo — cuts them into an ordered backlog of work units, approved on a board before anything is created | ✓ | |

The **solo** / **team** columns say which entrance needs each template. `pitch`, `bootstrap`
and `cut-backlog` are the ones that claim a single column: they are stages of the solo
front-end, which the agile path does not have. Everything above them is shared by both.

**`charting` used to sit with them and no longer does.** It is stage 2 of the solo path
*and* the engine behind the massive-ticket flow, which runs it against a mature multi-repo
codebase — see [13-massive-tickets.md](../../docs/shared/13-massive-tickets.md). Same skill,
opposite situation. The solo front-end is four stages but only three solo-only skills.

`pitch` ships one agent alongside it — `pitch-judge`, in
[`templates/agents/`](../agents/README.md). The skill is not complete without it.

## On `disable-model-invocation` — three skills set it, and the rule says why

Four of these are **conversations** — `charting`, `pitch`, `grilling`, `diagnose` — and none
of them sets `disable-model-invocation: true`, so Claude may load any of them on its own.
That is left as-is on purpose: a conversation that starts a turn early costs you one
redirect.

The field earns its place on skills with **side effects or timing you own** — a deploy, a
commit, a send. **`bootstrap`, `cut-backlog` and `adapt-to-stack` are the three templates
here that meet that test, and all three set the field.** None is a conversation.
`bootstrap` scaffolds a repo, writes a `CLAUDE.md`, indexes a language server, generates
agent files and writes memory; `cut-backlog` files a dozen issues in a tracker other people
may be able to see; `adapt-to-stack` writes an agent file and a skill directory per layer
into a repo, and they are meant to be committed. A conversation firing a turn early costs a
redirect; those firing early cost a tree of files nobody asked for, or a backlog nobody
approved. Same rule, applied — not a new one.

The three share a shape worth naming: **each one's output is somebody else's input** — the
bootstrap's report is read at the seam, the backlog is read by `/start-ticket`, and the
generated specialists are what `/start-ticket` dispatches **to** — so an unasked-for run
does not merely waste a turn, it publishes something downstream may act on.

### The precondition the test does not state: nothing else dispatches to it

`prototype` writes files, so the side-effects test above would seem to put the field on it.
It does not get one, and the reason is mechanical rather than a judgement call. The field
does not merely stop autoloading — it blocks the Skill tool:

> The `user-invocable` field only controls menu visibility, not Skill tool access. Use
> `disable-model-invocation: true` to block programmatic invocation.
>
> **Hide individual skills** by adding `disable-model-invocation: true` to their frontmatter.
> This removes the skill from Claude's context entirely.
>
> — [Extend Claude with skills](https://code.claude.com/docs/en/skills)

**A skill body that says *run `/other-skill`* is a programmatic invocation.** `charting`'s
ticket-types table names `/prototype` as what backs a `prototype` ticket, so setting the
field there would turn that row into a dead pointer — the skill would be unreachable from
the only thing that dispatches to it.

So the side-effects test has a precondition it never stated: **nothing else dispatches to
it.** The three above pass because a human types all three and nothing calls them —
*except* that `/bootstrap` step 5 says **Run `/adapt-to-stack`**, and `/adapt-to-stack` sets
the field. One of those two is wrong; which one changes is
[#49](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/49), not this
README's call.

`pitch` is the closest remaining call, since it dispatches subagents and spends real time.
Watch it; if it ever fires unasked, that is the signal to set the field rather than reword
the description.
