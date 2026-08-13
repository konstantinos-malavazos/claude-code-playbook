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

**Every field is optional. Only `description` is recommended.** The harness supports more
than the two above:

| Field | What it does |
|---|---|
| `name` | **Display name only. Defaults to the directory name** — see below |
| `description` | What it does + when to use it. Truncated at 1,536 chars in the listing |
| `when_to_use` | Extra trigger phrases, appended to `description` and sharing that cap |
| `argument-hint` | Autocomplete hint, e.g. `[ticket-id]` |
| `arguments` | Named positional args for `$name` substitution |
| `disable-model-invocation` | `true` = only you can invoke it. **This is what makes a skill user-invoked.** It also blocks the Skill tool, so **no other skill can dispatch to it** |
| `user-invocable` | `false` hides it from the `/` menu. Does *not* block the Skill tool |
| `allowed-tools` | Pre-approved for the invoking turn only — not a restriction |
| `disallowed-tools` | Removed from the pool while active |
| `model` / `effort` | Override for the turn the skill is active |
| `context: fork` + `agent` + `background` | Run the skill in its own subagent |
| `hooks` | Hooks scoped to this skill's lifecycle |
| `paths` | Globs limiting when the skill auto-loads |
| `shell` | `bash` (default) or `powershell` for inline `` !`cmd` `` blocks |

- **The directory name is what you type**, not the `name` field. `name` only changes the
  label in listings, so a skill in `foo/` is always `/foo`, however the frontmatter reads.
  **`engineering-standards` is the one template where this matters.** There is one skill
  per layer, so the *directory* must be named `backend-standards` (or whatever) as well as
  the `<layer>` placeholder being filled. Otherwise you have three skills all answering to
  `/engineering-standards`. `/adapt-to-stack` does that renaming when it generates them.
  The rule is here because it is what makes the output distinct, not because you type it.
- **So an unfilled `name:` placeholder is harmless in a skill, and fatal in an agent.**
  Three installed copies of `engineering-standards` all carrying the shipped
  `name: <layer>-engineering-standards` each loaded correctly under their own directory
  name. The field was simply ignored. An agent has no directory to fall back on: it
  registers under the literal placeholder and then refuses to be dispatched by it. Same
  text, opposite consequence —
  [`../agents/README.md`](../agents/README.md#an-unfilled-placeholder-is-not-an-error).
  Fill it anyway: a listing entry reading `<layer>-engineering-standards` tells you
  nothing about which layer you are looking at.
- **A personal skill beats a project skill of the same name.** That is the opposite of what
  "more specific wins" would suggest, and the opposite of how project *agents* resolve,
  where the definition closest to the working directory wins. It bites the generated per-layer
  standards skills, which live in a repo's own `.claude/skills/`: one stray
  `backend-standards` in `~/.claude/skills/` shadows every repo's generated one, silently
  and everywhere. Keep layer names out of `~/.claude/skills/`.
- **A `.claude/` directory created mid-session is not watched.** Edits to skills that
  existed at startup are picked up live. A `.claude/skills/` or `.claude/agents/` folder
  that did not exist when the session began needs a restart before anything can load from
  it. This is exactly the state `/adapt-to-stack` leaves behind on its first run.
- **A description that says "use when the user says…" does not make a skill user-invoked.**
  It is a hint, not a constraint. Only `disable-model-invocation: true` stops a skill
  firing on intent. The section below decides which ones get it.
- Keep the front `description` tight and trigger-focused. Put the detail in the body.
- Skills can bundle extra files (templates, checklists) the body points to.
  Progressive disclosure keeps the base cost low.

## The set

| Skill | Loads on / used for | solo | team |
|---|---|---|---|
| `commit-conventions` | about to commit / branch naming / MR-PR template | ✓ | ✓ |
| `engineering-standards` | **one per layer, generated** — the review/coding standard for that language | ✓ | ✓ |
| `adapt-to-stack` | a repo whose `CLAUDE.md` names a layer chain — generates one specialist and one standards skill per layer into that repo's own `.claude/`, and never overwrites | ✓ | ✓ |
| `tdd` | test-first feature/bug work (red-green-refactor) | ✓ | ✓ |
| `diagnose` | hard bugs / performance regressions | ✓ | ✓ |
| `grilling` | stress-testing a plan; the deferred-decision gate | ✓ | ✓ |
| `wait-what` | **you type it** — the last message did not land, so it gets re-pitched simply | ✓ | ✓ |
| `handoff` | **you type it** — compact this session into one file a fresh session resumes from | ✓ | ✓ |
| `memory-schema` | before any memory WRITE — enforces your memory server's call shape | ✓ | ✓ |
| `memory-tag-lint` | the `/encode-codebase` write gate — seven assertions, applied identically by three agents | ✓ | ✓ |
| `research` | a decision blocked on an **outside** fact — third-party docs, a vendor API, a spec | ✓ | ✓ |
| `to-questionnaire` | **you type it** — a decision blocked on a fact another **person** holds; writes the document you send them | ✓ | ✓ |
| `wizard` | manual work only a human can do — writes a bash script that walks them through it stage by stage. **Ships `template.sh`; copy both or neither** | ✓ | ✓ |
| `prototype` | a design question nobody can settle on paper — throwaway code built to be reacted to and then deleted | ✓ | ✓ |
| `charting` | an effort too big for one session and too foggy to plan — maps it into tickets on the tracker | ✓ | ✓ |
| `pitch` | a raw idea with no repo — the one-hour kill gate that ends in build, kill or park | ✓ | |
| `bootstrap` | a decided-but-empty repo — scaffolds it and reports on the pipeline's preconditions. **Runs once per project** | ✓ | |
| `cut-backlog` | a closed map + a scaffolded repo — cuts them into an ordered backlog of work units, approved on a board before anything is created | ✓ | |

The **solo** / **team** columns say which entrance needs each template. `pitch`, `bootstrap`
and `cut-backlog` are the ones that claim a single column: they are stages of the solo
front-end, which the agile path does not have. Everything above them is shared by both.

**`charting`'s `✓ ✓` is load-bearing, not leftover.** It is stage 2 of the solo path *and*
the engine behind the massive-ticket flow ([03-massive-tickets.md](../../docs/team/03-massive-tickets.md)).
The three `*-massive` commands went team-only, charting an existing codebase did not. Solo,
you point `/charting` at your own repo and hand each make to `/start-ticket`. Delete this
skill from a solo install and you take stage 2 with it.

`pitch` ships one agent alongside it — `pitch-judge`, in
[`templates/agents/`](../agents/README.md). The skill is not complete without it.

## On `disable-model-invocation`

`bootstrap`, `cut-backlog`, `to-questionnaire`, `wait-what` and `handoff` set it. Two tests
decide it, and a veto overrides both.

**Test 1 — [`PHILOSOPHY.md`](../../PHILOSOPHY.md) §5:** *if it's hard to reverse **or**
leaves your machine, a human confirms it.* `bootstrap` writes memory and ends in a commit.
`cut-backlog` files a dozen issues where other people may see them. `adapt-to-stack` gets no
field because it never overwrites. The worst an unasked run does is add files you delete.

**Test 2 — the run is not the model's to start.** `wait-what` is *you* saying the last
message did not land. `to-questionnaire` needs a recipient only you know exists. `handoff` is
you deciding this session ends here, which is a fact about your day and not about the work.
None of the three is a run the model can decide to begin, so the field makes them typed-only
rather than confirmation gates.

Conversation skills — `charting`, `pitch`, `grilling`, `diagnose` — deliberately leave it
unset. A conversation that starts a turn early costs you one redirect.

**The veto: a skill something else dispatches to cannot carry the field**, whatever the tests
return. The field blocks the Skill tool. So the dispatch fails, the flow stops mid-run, and
it asks you to type the thing. `prototype` writes files and still gets no field, because
`charting`'s ticket-types table names `/prototype` as what backs a `prototype` ticket.
`bootstrap` step 5's *Run `/adapt-to-stack`* is why `adapt-to-stack` has none either.

**When the veto and a test conflict, test the test first.** A skill that must be dispatched to
and looks too dangerous to dispatch is usually holding a side effect that belongs to its
caller. Move the side effect and the conflict goes with it.
