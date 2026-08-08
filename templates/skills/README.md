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
| `disable-model-invocation` | `true` = only you can invoke it. **This is what makes a skill user-invoked** — and it blocks the Skill tool too, so **no other skill can dispatch to it** |
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
  **Two of these skills do** — `bootstrap` and `cut-backlog`; the rule that sorts them is
  below, and it is `PHILOSOPHY.md`'s, not a local invention.
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
codebase — see [03-massive-tickets.md](../../docs/team/03-massive-tickets.md). Same skill,
opposite situation. The solo front-end is four stages but only three solo-only skills.

**That flow is team-only and this skill is not** — the `✓ ✓` above is load-bearing, not
leftover. The three `*-massive` commands are what went team-only; charting a codebase that
already exists did not. Solo, you point `/charting` at your own repo and hand each make to
`/start-ticket`. Delete this skill from a solo install and you take stage 2 with it.

`pitch` ships one agent alongside it — `pitch-judge`, in
[`templates/agents/`](../agents/README.md). The skill is not complete without it.

## On `disable-model-invocation` — two skills set it, and the rule is `PHILOSOPHY.md`'s

Four of these are **conversations** — `charting`, `pitch`, `grilling`, `diagnose` — and none
of them sets `disable-model-invocation: true`, so Claude may load any of them on its own.
That is left as-is on purpose: a conversation that starts a turn early costs you one
redirect.

**The test is not local to this directory.** It is `PHILOSOPHY.md`'s rule of thumb, which is
already two tests and already sorts these skills correctly:

> *if it's hard to reverse **or** leaves your machine, a human confirms it.*
>
> — [`PHILOSOPHY.md`](../../PHILOSOPHY.md) §5

| Skill | Hard to reverse? | Leaves your machine? | Field |
|---|---|---|---|
| `bootstrap` | **yes** — writes memory, ends in a commit | no | **set** |
| `cut-backlog` | no | **yes** — files a dozen issues where other people may see them | **set** |
| `adapt-to-stack` | no — you `rm` the generated files | no | **not set** |

**`adapt-to-stack` used to set it, and the earlier version of this rule is why.** This
README once said the field earns its place on skills with *"side effects or timing you own"*
— and `adapt-to-stack` writes files, so that test returned **set it**. It was the wrong
question: writing a file is a side effect whatever else is true of it, so the test could
only ever answer yes. *Hard to reverse* asks the thing that decides, and it returns **no**
for a skill whose whole contract is that it never overwrites — the worst an unasked run does
is add files you delete. Settled in
[#49](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/49).

**Do not re-derive a rule the repo already states.** A local version drifts, and this one
drifted into a wrong answer before anybody noticed.

The shape all three share is **each one's output is somebody else's input** — the bootstrap's
report is read at the seam, the backlog by `/start-ticket`, and the generated specialists are
what `/start-ticket` dispatches **to**. Worth naming, and **not the test**: it is true of
`adapt-to-stack`, which gets no field.

### The mechanical veto: nothing else may dispatch to it

The test above is a judgement. This is not. The field does not merely stop autoloading — it
blocks the Skill tool:

> The `user-invocable` field only controls menu visibility, not Skill tool access. Use
> `disable-model-invocation: true` to block programmatic invocation.
>
> **Hide individual skills** by adding `disable-model-invocation: true` to their frontmatter.
> This removes the skill from Claude's context entirely.
>
> — [Extend Claude with skills](https://code.claude.com/docs/en/skills)

**A skill body that says *run `/other-skill`* is a programmatic invocation**, so a skill
something else dispatches to cannot carry the field, whatever the test above returns:

- **`prototype` writes files and still gets none.** `charting`'s ticket-types table names
  `/prototype` as what backs a `prototype` ticket; the field would make that row a dead
  pointer — unreachable from the only thing that dispatches to it.
- **`bootstrap` step 5 says *Run `/adapt-to-stack`***, which is the second reason the field
  came off it. Here the veto and the test agreed, so #49 never had to rank them.

**They do not always agree, and this repo ships the case where they do not.**
`/resume-massive:63` dispatches to `/build-chart-ticket`, which commits, amends, **pushes**
and writes to the tracker — so it fails *both* halves of the test and earns the field, and it
is dispatched to and so cannot have it. Filed as
[#53](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/53). **Do not
read the veto as *dispatch always wins*** — where they conflict, something about the shape of
the two skills has to change, not the frontmatter.

**The harness does not fail silently, which is why this hid through three tickets.** It
blocks the call and *"instructs it not to reproduce the deploy steps another way, so expect
Claude to suggest running `/deploy` yourself"* — so a broken dispatch surfaces as a flow
stopping mid-run and asking you to type the thing. Survivable, and therefore easy to walk
past.

`pitch` is the closest remaining call, since it dispatches subagents and spends real time.
Watch it; if it ever fires unasked, that is the signal to set the field rather than reword
the description.
