---
name: adapt-to-stack
description: >-
  Generate one layer specialist agent and one engineering-standards skill per layer of a
  repo's chain, read out of that repo's own CLAUDE.md — creating what is missing, never
  overwriting what exists, and ending in one report. Use when a repo's CLAUDE.md declares a
  layer chain and the specialists do not exist yet, when the chain gains a layer, or the
  user says "adapt to my stack" / "generate the layer specialists". NOT for writing
  CLAUDE.md itself, and NOT for editing a generated file that already exists.
---

# Adapt to stack — one specialist per layer, generated from one file

A repo declares its layer chain once, in its own `CLAUDE.md`. This turns that declaration
into the agent files and skill files the pipeline dispatches to.

> **This is not a stage. It is one step**, and it runs again — unchanged — every time the
> chain gains a layer. The first run happens on a repo that has just been scaffolded; the
> second may be months later.

**Choose nothing.** Every fact you write into a generated file is already written down one
file away. If you find yourself deciding what a layer is, where it lives, what it builds
with, or which model it should run on, you are reading the wrong file — **stop and say so.**

## The one input

**Read the repo's `CLAUDE.md`. That is the only input.** No arguments, no prompts, nothing
asked of the human. A prompt would state the stack a second time, and two copies can
disagree.

| You need | Section of `CLAUDE.md` |
|---|---|
| The layers, in order, and where each one lives | the chain section |
| Each layer's build / test commands | *build / test / run* |
| Each layer's upstream and downstream contract | the chain **order** — the neighbours either side |
| A model per layer, **if one is stated** | the chain section's optional model lines |

### Which `CLAUDE.md`

**The one in the repo you are standing in, and never the workspace file.** Run inside a
repo, you generate that repo's layers from that repo's own file. `repo.CLAUDE.md` ships two
chain shapes and the repo kept one:

| Shape | What the chain section says | What you generate |
|---|---|---|
| **A** — this repo is the whole chain | every layer, in order, plus where each lives | one specialist and one standards skill **per layer** |
| **B** — this repo is one layer among sibling repos | this repo's one layer, and the contract either side | **one** specialist and **one** standards skill |

### If the input is missing or unfilled, stop

Three ways it fails, and all three end the same way:

| | |
|---|---|
| No `CLAUDE.md` | **Stop.** |
| No chain section, or no build/test commands | **Stop.** |
| The chain section still carries `<PLACEHOLDER>` brackets, or **both** shapes A and B | **Stop.** It was copied, not filled in. |

Say which of the three it is, name the sections you need, and point at
`templates/claude-md/repo.CLAUDE.md`.

> **Do not write that file.** It is this step's input, and a flow that generates its own
> input generates from itself. Do not offer to draft it, and do not fill a gap by asking —
> a missing chain means someone has not yet decided what the layers are, and that is a
> decision, not a blank.

## The five steps

| # | Step |
|---|---|
| 1 | Read the chain out of the repo's `CLAUDE.md` |
| 2 | Generate one **layer specialist** per layer, into `.claude/agents/` |
| 3 | Generate one **standards skill** per layer, into `.claude/skills/` |
| 4 | Confirm what you wrote is visible to git |
| 5 | Report, and stop |

Everything lands **inside the repo**. That is deliberate: a specialist file is *facts about
this codebase*, and the files are committed.

### 1 — Read the chain

List the layers in order. For each one you now hold: its name, its paths, its build and
test commands, its neighbours either side, and its model **only if `CLAUDE.md` states one**.

Then list what is already on disk under `.claude/agents/` and `.claude/skills/`. That list
decides every *created* vs *skipped* in the report, and it is read **before** you write
anything.

### 2 — One layer specialist per layer

From `templates/agents/layer-specialist.md`, one file per layer, into the repo's
`.claude/agents/`, named `<layer>-specialist.md`.

| Fill in | From |
|---|---|
| `name`, and the **`You are the <LAYER NAME> specialist`** line | the layer's name |
| the **repo(s)/paths it owns** | where the chain says that layer lives |
| the **build / test commands** in its verify block | *build / test / run* |
| the **contract** it reads and the one it writes | the layers either side of it in the chain |
| the **engineering-standards skill it loads** | the skill step 3 generates for this layer, by name |
| `model` | see below |

**The template's description opens with a line about where the file comes from and how many
of it there are. Replace it with the layer this file is for.** That opener is provenance,
addressed to whoever is holding the template — and a description is what the harness reads
to decide whether to route work here, so on a generated file it is the one sentence that
must say *which layer*.

#### The model field

| `CLAUDE.md` | What you write |
|---|---|
| States a model for that layer | that id, in `model:` |
| States none, or leaves `<model-id>` unfilled | **omit the field entirely** |

An unfilled `<model-id>` counts as **absent**, never as a model called `<model-id>`.

When you omit it, write the comment in its place, in the frontmatter — a `#` line, so it
reaches a human reading the file and never the agent's prompt:

```yaml
# model: omitted on purpose — this specialist inherits the session's model. Set one per
# layer in CLAUDE.md's chain section once you know which layer is mechanical and which is
# design-heavy. That is a tuning act, not a day-one decision.
```

The standards skills get no such line: they carry no model of their own, because they are
loaded by the specialist and run on whatever it is running on.

### 3 — One standards skill per layer

From `templates/skills/engineering-standards/SKILL.md`, one directory per layer, into the
repo's `.claude/skills/`.

> **Name the directory `<layer>-standards`, not `engineering-standards`.** The directory
> name is what gets typed and what makes the skill distinct — three layers copied into one
> directory name is three skills answering to the same one. Fill the `<layer>` and
> `<language>` placeholders in the body to match.

**Check that name is not already taken in `~/.claude/skills/`.** A personal skill and a
project skill with the same name do not both survive, and **personal wins** — the opposite
of the way project agents resolve, where the definition closest to the working directory
wins. So a personal `backend-standards` left over from another project silently shadows the
one you just generated, in this repo and every other. If the name is taken, **stop and say
so** rather than picking a different one: the specialist names this skill, and a name chosen
to dodge a collision is a name nobody can predict.

**Replace the template's provenance opener with the layer and language**, for the same
reason as step 2.

**You can fill in the layer and the language and no more, and that is the expected
output.** The rules themselves are the human's to write as they learn what this codebase
gets wrong. Generate the file anyway — the specialist in step 2 names it, and the
alternative is pointing an agent at a file that does not exist. Every one of these lands in
the report as **still a scaffold**, on day one and honestly.

### 4 — Confirm what you wrote is visible to git

Ask git whether the two directories you just wrote to are ignored:

```
git check-ignore -v .claude/agents .claude/skills
```

A blanket `.claude/` ignore line hides them. If it does, add the two exceptions beside the
existing line — `!.claude/agents/` and `!.claude/skills/` — and change nothing else.

These files are meant to be committed, and an ignored file produces **no error at all** —
which is why you ask git rather than assume.

### 5 — Report, and stop

One report. Every file you generated **and** every file you left alone.

```markdown
## Adapt-to-stack report — <repo>

Chain: **schema** ──► **api** ──► **web** (3 layers, shape A)

| File | Layer | Did | Found |
|---|---|---|---|
| `.claude/agents/schema-specialist.md` | schema | **created** | — |
| `.claude/skills/schema-standards/SKILL.md` | schema | **created** | **still a scaffold** — 7 `<…>` brackets |
| `.claude/agents/api-specialist.md` | api | **skipped** | — |
| `.claude/skills/api-standards/SKILL.md` | api | **skipped** | — |
| `.claude/agents/web-specialist.md` | web | **skipped** | **disagrees with `CLAUDE.md`** — names `src/ui`; the chain says `src/web` |
| `.claude/skills/web-standards/SKILL.md` | web | **skipped** | **still a scaffold** — 12 `<…>` brackets |

`.gitignore`: `.claude/` ignored, with `!.claude/agents/` and `!.claude/skills/` — added this run.

**`.claude/agents/` and `.claude/skills/` did not exist before this run. Restart the
session before anything dispatches to these files.**
```

**Say the restart line whenever you created either directory, and only then.** A running
session watches the directories that existed when it started; one you have just created is
not among them. The files are on disk and every check that reads the disk passes — what
does not work is the *dispatch*, in this session, which is the one failure a report whose
every row says **created** would otherwise hide.

**The four rows sit on two axes.** *Created* and *skipped* are what **you did** and are
exclusive; *disagrees* and *still a scaffold* are what **you found** and are orthogonal to
both. A standards skill generated one minute ago is *created* **and** *still a scaffold*,
every time.

| Row | What it means |
|---|---|
| **created** | generated this run |
| **skipped** | already existed, untouched |
| **disagrees with `CLAUDE.md`** | the file names a path, command or layer the chain no longer says |
| **still a scaffold** | the file still carries the template's `<PLACEHOLDER>` angle brackets |

**"Still a scaffold" costs no state.** No timestamps, no ledger, no marker file — you detect
it by reading the file for angle brackets. The convention that makes a template fillable is
what makes un-filled-ness visible.

**Every row carries evidence** — the bracket count, the path that disagrees, the layer it
belongs to. A row with nothing beside it is an opinion.

> **Then classify nothing and stop.** Do not rank the findings, do not offer to reconcile a
> disagreement, and do not fill in a scaffold you have just reported. A *disagrees* row is
> either a file that drifted or a chain that moved, and which one it is only the human
> knows.

## Never overwrite

**Create what is missing. Leave everything that exists exactly as it is.** A re-run after a
layer is added generates one specialist and one standards skill and touches nothing else.
Change the test command in `CLAUDE.md` and nothing changes automatically — it lands in the
report as *disagrees*, and there it stops.

Diff-and-patch is not an option, and neither is regenerating over the top: once real rules
are written by hand there is no reliable boundary between the template's lines and someone's
own, so a patcher that guesses wrong **destroys hand-written standards silently**.

## Two things generated, three refused

| Not generated | Why |
|---|---|
| `CLAUDE.md` | It is this step's **input**. |
| Serena setup | Owned by the scaffolding step that has the project's Serena verdict. Two steps owning one act is one too many. |
| `commit-conventions` | **Not per-stack.** One `<scope>` placeholder and a main-branch name, identical whatever the language is — a setup-time copy. Generating it per repo makes N copies of one workspace-wide convention. |

If something else looks like it ought to be generated here, that is a decision and it is
not yours. Say so and stop.

## Where you stop

Five stops, and none of them is a failure of the step:

| You stop when | And you say |
|---|---|
| `CLAUDE.md` is missing, short a section, or unfilled | which of the three, which sections you need, and where the template is |
| A standards skill's name is taken in `~/.claude/skills/` | which name, and that the personal one would shadow the generated one everywhere |
| The report is done | nothing more — no ranking, no reconciliation, no filling in |
| A generated file would land outside the repo | what you were about to write, and where |
| Something genuinely needs deciding | what it is, and that it is a decision rather than a step |

## Stop condition

**The step is done when the report exists.** Not when every row says *created*, and not
when the scaffolds are filled in — a report of six *skipped* rows is a complete, correct
run on a repo that was already adapted.
