---
name: adapt-to-stack
description: >-
  Generate one layer specialist agent, its slice-mode variant, and one engineering-standards
  skill per layer of a repo's chain, read out of that repo's own CLAUDE.md — creating what is
  missing, never overwriting what exists, and ending in one report. Use when a repo's
  CLAUDE.md declares a layer chain and the specialists do not exist yet, when the chain
  gains a layer, or the user says "adapt to my stack" / "generate the layer
  specialists". NOT for writing CLAUDE.md itself, and NOT for editing a generated file
  that already exists.
---

# Adapt to stack — one specialist per layer, generated from one file

A repo declares its layer chain once, in its own `CLAUDE.md`. This turns that declaration
into the agent files and skill files the pipeline dispatches to.

> **This is not a stage. It is one step**, and it runs again — unchanged — every time the
> chain gains a layer. The first run happens on a repo that has just been scaffolded. The
> second may be months later.

**Choose nothing.** Every fact you write into a generated file is already written down one
file away. If you find yourself deciding what a layer is, where it lives, what it builds
with, or which model it should run on, you are reading the wrong file. **Stop and say so.**

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
| **A** — this repo is the whole chain | every layer, in order, plus where each lives | one specialist, one slice variant and one standards skill **per layer** |
| **B** — this repo is one layer among sibling repos | this repo's one layer, and the contract either side | **one** specialist, **one** slice variant and **one** standards skill |

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
> input generates from itself. Do not offer to draft it, and do not fill a gap by asking.
> A missing chain means someone has not yet decided what the layers are, and that is a
> decision, not a blank.

## The six steps

| # | Step |
|---|---|
| 1 | Read the chain out of the repo's `CLAUDE.md` |
| 2 | Generate one **layer specialist** per layer, into `.claude/agents/` |
| 3 | Generate one **slice variant** of that specialist per layer, into `.claude/agents/` |
| 4 | Generate one **standards skill** per layer, into `.claude/skills/` |
| 5 | Confirm what you wrote is visible to git |
| 6 | Report, and stop |

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
| the **engineering-standards skill it loads** | the skill step 4 generates for this layer, by name |
| every `<…>` placeholder on the **`tools:`** line — today that is `<memory-read-tools>` | see *The tool placeholders* below |
| `model` | see below |

**The template's description opens with a line about where the file comes from and how many
of it there are. Replace it with the layer this file is for.** That opener is provenance,
addressed to whoever is holding the template. And a description is what the harness reads
to decide whether to route work here, so on a generated file it is the one sentence that
must say *which layer*.

#### The tool placeholders

The template's `tools:` line carries `<memory-read-tools>`. **Fill it. Never delete it, and
never leave the brackets in.** This field fails in the one way nothing reports: an
unresolvable name in a `tools:` list is stripped at launch with no error, so the specialist
runs, says nothing is wrong, and does its optional memory step by skipping it.

| Where you get the value | |
|---|---|
| `~/.claude/.playbook-install.json` → `config.placeholders.values["<memory-read-tools>"]` | the answers the installer already recorded. **Read them back rather than asking the same question twice.** |
| That file does not exist (a hand-install) | **Stop and ask the user** for their memory server's read-tool names — `/mcp` in Claude Code lists them. Then write **the specialist**. |

**Read that file; never create it.** It is the installer's own record of a machine, and this
step is scoped to one repo. On a hand-install there is nothing to read and nothing to write:
you ask, and the answer goes into the specialist alone.

Asking is the fallback, not a default value. The playbook does name Forgetful, and the
installer pre-fills its wrapper trio — but a reader running something else gets the wrong
three names from a hardcoded answer and no error to tell them so. **Never write the file
with a bracket still on the `tools:` line**: that is the failure this row exists to prevent,
and it is silent.

Derive the set rather than trusting this paragraph, and scope the question to the `tools:`
line: if the template you are holding carries a placeholder on **`tools:`** that neither
this subsection nor step 2's fill table tells you what to write, that is a gap in this
skill. **Stop and say so.** `<layer>` is not one of those — the table's first row fills it,
and `name:` is where it lives.

#### The model field

| `CLAUDE.md` | What you write |
|---|---|
| States a model for that layer | that id, in `model:` — **and delete the template's whole `# model:` comment block**, every `#` line of it, because it explains an omission this file no longer has |
| States none, or leaves `<model-id>` unfilled | **omit the field entirely**, and leave the `#` comment exactly as it is |

An unfilled `<model-id>` counts as **absent**, never as a model called `<model-id>`.

The two branches are exclusive and the comment belongs to only one of them. A pinned
specialist that keeps the comment ships a file which states a model on one line and explains
why it states none over the next several — permanently, because this flow never overwrites.
The comment is not documentation of the field; it is documentation of the *omission*.

**It is a block, not a line** — seven `#` lines on the base template, four on the slice
variant, and it runs to the last one before `---` or before `# effort:`. Delete all of them
or none. A partial delete is the worst outcome available: it strips the `# model:` marker
and leaves the rest as orphaned `#` prose, which no longer reads as being about anything —
and the *stale model comment* check in step 6 keys on that marker, so it cannot see the
residue it would otherwise catch. The `# effort:` comment on the slice variant is a
different field and stays either way.

When you omit it, the template already carries the `#` comment that belongs in its place —
a `#` line, so it reaches a human reading the file and never the agent's prompt. **Leave
that comment exactly as it is, and do not write one of your own.** Step 3 says the same
thing about the slice variant, and taking the text from the template in both places is what
keeps a specialist and its slice variant from ever disagreeing about this field.

What the comment says, so you can recognise the right one: **the omission is what makes the
specialist weight-eligible** — with no pin, the dispatching flow sets the tier for each run,
cheap for a light dispatch and strong for a heavy one — and a stated model is a **floor**
under that layer, which a weight can raise above but never drop below. Pinning one is not a
half-finished decision someone left for you to complete.

> **Read the sense, not the string.** The current template *names* the session-inheritance
> reading in order to deny it — its comment says the omission does **NOT** mean the
> specialist inherits the session's model. That is the healthy text. It is stale only if the
> comment **asserts** inheritance — offers it as what the omission means, with nothing
> denying it. Both current templates deny it, in different words: the base says it does NOT
> mean that, and the slice variant says the flow sets the tier per run *rather than* letting
> it inherit. Neither is stale. Halting on a denial is a false stop, on a downstream repo's
> setup, so read the sentence rather than matching the phrase. If the comment really does
> assert inheritance, **stop and say so** rather than copying it forward — that is the
> behaviour the flows now set a tier precisely to avoid.

The standards skills get no such line: they carry no model of their own, because they are
loaded by the specialist and run on whatever it is running on.

### 3 — One slice variant per layer

From `templates/agents/slice-layer-specialist.md`, one file per layer, into the repo's
`.claude/agents/`, named `slice-<layer>-specialist.md`. It is the decompose-path variant of
the specialist step 2 just wrote for the same layer.

| Fill in | From |
|---|---|
| `name` — `slice-<layer>-specialist` — and every `<layer>` in the description and the body | the layer's name |
| the **base agent file it Reads first** | the file step 2 wrote for this layer, `.claude/agents/<layer>-specialist.md` |
| the **next layer's slice variant** it hands on to | the layer after this one in the chain |
| every `<…>` placeholder on the **`tools:`** line — today that is `<memory-read-tools>` | the same rule as step 2, and the same value: this variant carries the same `tools:` line as its base |
| `model` | the same rule as step 2, on the same layer |

**There is almost nothing to fill in, and that is the point.** This file is an override
shell: it Reads its base specialist and inherits everything it does not override. Anything
you copy across from the base is a second copy, and it drifts the first time the base is
edited. If you find yourself restating a rule, you are writing the wrong file.

**Drop the template's provenance paragraph** — the one that says this file is generated
once per layer. It is addressed to whoever is holding the template, and a generated file is
past that. Step 2 replaces its base's opener for the same reason.

**`model` follows step 2 exactly**: the id if `CLAUDE.md` states one for this layer — with
the `# model:` comment deleted, because it explains an omission the file no longer has — and
the field omitted with that comment left intact if it does not. Same layer, same
declaration, same answer, so a specialist and its slice variant never disagree. The
`# effort:` comment below it is not part of this and stays either way. **`effort` you never
write.**
The chain declares none, and how hard a layer has to think is a fact about the chain rather
than about slice mode. Leave the template's `#` comment as it is.

**Generate it for every layer, every run.** Do not ask, and do not look for a flag. Whether
a ticket decomposes is decided per ticket by the planner, months later, and the fork lives
inside `/start-ticket` — so at generation time nobody knows. Making it conditional would
need a new declaration line in `CLAUDE.md`, and this flow chooses nothing. The cost of
generating it anyway is one file per layer on disk that nothing loads unless a slice
dispatch names it. And because the flow never overwrites, a re-run on a repo generated
before this step existed adds the missing slice variants and touches nothing else. That
re-run is how a reader upgrades.

### 4 — One standards skill per layer

From `templates/skills/engineering-standards/SKILL.md`, one directory per layer, into the
repo's `.claude/skills/`.

> **Name the directory `<layer>-standards`, not `engineering-standards`.** The directory
> name is what gets typed and what makes the skill distinct. Three layers copied into one
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
gets wrong. Generate the file anyway. The specialist in step 2 names it, and the
alternative is pointing an agent at a file that does not exist. Every one of these lands in
the report as **still a scaffold**, on day one and honestly.

### 5 — Confirm what you wrote is visible to git

Ask git whether the two directories you just wrote to are ignored:

```
git check-ignore -v .claude/agents .claude/skills
```

A blanket `.claude/` ignore line hides them. If it does, add the two exceptions beside the
existing line — `!.claude/agents/` and `!.claude/skills/` — and change nothing else.

These files are meant to be committed, and an ignored file produces **no error at all**.
That is why you ask git rather than assume.

### 6 — Report, and stop

One report. Every file you generated **and** every file you left alone.

```markdown
## Adapt-to-stack report — <repo>

Chain: **schema** ──► **api** ──► **web** (3 layers, shape A)

| File | Layer | Did | Found |
|---|---|---|---|
| `.claude/agents/schema-specialist.md` | schema | **created** | — |
| `.claude/agents/slice-schema-specialist.md` | schema | **created** | — |
| `.claude/skills/schema-standards/SKILL.md` | schema | **created** | **still a scaffold** — 7 `<…>` brackets |
| `.claude/agents/api-specialist.md` | api | **skipped** | **stale model comment** — its `# model:` line says the omission means it inherits the session's model |
| `.claude/agents/slice-api-specialist.md` | api | **created** | — |
| `.claude/skills/api-standards/SKILL.md` | api | **skipped** | — |
| `.claude/agents/web-specialist.md` | web | **skipped** | **disagrees with `CLAUDE.md`** — names `src/ui`; the chain says `src/web` · **still a scaffold** — 1 `<…>` bracket, on `tools:` |
| `.claude/agents/slice-web-specialist.md` | web | **skipped** | — |
| `.claude/skills/web-standards/SKILL.md` | web | **skipped** | **still a scaffold** — 12 `<…>` brackets |

`.gitignore`: `.claude/` ignored, with `!.claude/agents/` and `!.claude/skills/` — added this run.

**`.claude/agents/` and `.claude/skills/` did not exist before this run. Restart the
session before anything dispatches to these files.**
```

**Say the restart line whenever you created either directory, and only then.** A running
session watches the directories that existed when it started; one you have just created is
not among them. The files are on disk and every check that reads the disk passes. What
does not work is the *dispatch*, in this session, which is the one failure a report whose
every row says **created** would otherwise hide.

**The values sit on two axes.** *Created* and *skipped* are what **you did** and are
exclusive; *disagrees*, *still a scaffold* and *stale model comment* are what **you found**,
are orthogonal to both, and can appear together on one row. A standards skill generated one
minute ago is *created* **and** *still a scaffold*, every time.

| Row | What it means |
|---|---|
| **created** | generated this run |
| **skipped** | already existed, untouched |
| **disagrees with `CLAUDE.md`** | the file names a path, command or layer the chain no longer says |
| **still a scaffold** | the file still carries the template's `<PLACEHOLDER>` angle brackets |
| **stale model comment** | the file's `# model:` comment **asserts** that the omission means the specialist inherits the session's model |

**"Still a scaffold" costs no state.** No timestamps, no ledger, no marker file. You detect
it by reading the file for angle brackets. The convention that makes a template fillable is
what makes un-filled-ness detectable.

**Run that bracket check on the generated agents too, not only on the standards skills.**
On a skill a leftover bracket is expected and honest — the rules are the human's to write.
On an agent it is a defect, and the worst-behaved of the three: a bracket left on `tools:`
is stripped at launch in silence, and the agent runs looking correct without the tools its
own body calls mandatory. So an agent row with an unfilled `tools:` placeholder carries
**still a scaffold** with the bracket count and the field it sits on, and never a bare
**created**. A row that says only *created* is a claim that the file is finished.

**`stale model comment` is scoped to what you did not write.** A file you generated this
run took its comment from the current template, so the value can only land on a **skipped**
row — a specialist generated by an older copy of this skill, in a repo that has been adapted
before. Behaviour there is already correct: the tier is set by the dispatching flow, which
is installed globally, so the file is wrong about itself and about nothing else. Reporting
it is the whole remedy. **Do not edit the file** — *never overwrite* covers this exactly as
it covers a *disagrees* row.

Detect it the way the step-2 stop-rule says: the phrase alone is not the finding. The
current template names session inheritance in order to **deny** it, so a line carrying the
phrase *and* a negation is healthy. Only an assertion is stale.

**Every row carries evidence** — the bracket count, the path that disagrees, the layer it
belongs to. A row with nothing beside it is an opinion.

> **Then classify nothing and stop.** Do not rank the findings, do not offer to reconcile a
> disagreement, and do not fill in a scaffold you have just reported. A *disagrees* row is
> either a file that drifted or a chain that moved, and which one it is only the human
> knows.

## Never overwrite

**Create what is missing. Leave everything that exists exactly as it is.** A re-run after a
layer is added generates that layer's three files and touches nothing else.
Change the test command in `CLAUDE.md` and nothing changes automatically. It lands in the
report as *disagrees*, and there it stops.

Diff-and-patch is not an option, and neither is regenerating over the top: once real rules
are written by hand there is no reliable boundary between the template's lines and someone's
own, so a patcher that guesses wrong **destroys hand-written standards silently**.

## Three things generated, three refused

| Not generated | Why |
|---|---|
| `CLAUDE.md` | It is this step's **input**. |
| Serena setup | Owned by the scaffolding step that has the project's Serena verdict. Two steps owning one act is one too many. |
| `commit-conventions` | **Not per-stack.** One `<scope>` placeholder and a main-branch name, identical whatever the language is — a setup-time copy. Generating it per repo makes N copies of one workspace-wide convention. |

**A fourth is not yours to add.** If something else looks like it ought to be generated
here, that is a decision and it is not yours. Say so and stop. The slice variant sat in the
refused column until the repo owner decided otherwise and wrote the decision into this
file. That is the bar, and it is met before a run, never during one.

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
when the scaffolds are filled in. A report of nine *skipped* rows is a complete, correct
run on a repo that was already adapted.

**Then the `next-steps` block.** Where the restart line fired it **is** the next step and it
goes first: nothing can dispatch to these files until the session restarts. The block carries
the rest — every generated file by path, that this step commits nothing and staging them is
the user's, and which flow resumes: the one that dispatched this, or `/bootstrap` when it ran
as step 5.
