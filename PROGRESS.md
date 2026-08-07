# Progress — the solo builder's path

Local tracking file for the wayfinder effort on
[#1 MAP: the solo builder's path](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/1).
**Committed and pushed**, so the effort can be resumed from any machine. The tracker is
still the source of truth; this is a reading convenience that goes stale between sessions.

> **THIS FILE IS RETIRED — [#51](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/51) deletes it.**
> [#8](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/8) dropped the
> progress file entirely. #8 is a decision ticket and writes no files, so the deletion is
> #51's; until that make lands this is still the live record, and a hole in it would be
> worse than one more entry. **Do not start a new one.**
>
> **Snapshot taken:** 7 August 2026, after resolving
> [#8 Resuming an effort that spans dozens of sessions](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/8)
> — **nothing is stored: every resume question on this path is answered by re-deriving from
> the repo, the tracker or the map.** `PROGRESS.md` is dropped, no solo walker command is
> added, backlog status is ruled **out of scope**, and nothing in-flight ever reaches memory.
> Decided only; spawned **#51** (retire the file, 7 files) and
> **[#52](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/52)**
> (write down the resume rules, 5 files).
>
> **Two premises had expired, and checking them first is what shrank the ticket from three
> holes to one rule.** #8's body says a mid-ticket death leaves *"nothing recording how far
> it got"* — [#5](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/5)
> settled that and it has been on disk since (`charting/SKILL.md:348`,
> `03-charting.md:96`), so hole 1 was only ever **stages 3 and 4**, which nobody owned. And
> the body asks whether the command *"duplicates `/resume-ticket` or extends it"* knowing of
> only those two — **`/resume-massive` did not exist when the ticket was written**, and
> `03-charting.md:98-100` already points solo readers at it. The map's own *premise you
> obeyed* rule, applied to the ticket's own body for the third time (#42, #15, now this).
>
> **The one rule underneath all seven answers: re-derive, never store.** Every artifact
> considered would have been a second copy of something the repo or the tracker already
> holds — which is [#18](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/18)'s
> *no ledger, anywhere* arriving from the status side rather than the measuring side.
>
> **The bootstrap and the cut both store nothing.** Seven of stage 3's eight steps leave a
> footprint you can look at, and **step 6 is the only one that writes nothing** — a
> verification, free to redo — so a session that dies at step 5 is resumed by typing
> `/bootstrap` again, with step 5 already idempotent from
> [#15](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/15). The
> cutting board lives only in the conversation (`cut-backlog/SKILL.md:160`, `:175`), but
> everything it is built from is permanent, so a dead session costs **the human's editing on
> three-to-ten units** and nothing else. **A cut that cannot fit one sitting is #12's trace
> check saying the smallest version grew** — a finding, not a resume problem.
>
> **`PROGRESS.md` dies on its own stated reason, and that is the finding worth carrying.**
> `local-markdown.md:161` says it exists because *"every hosted tracker gives you an
> at-a-glance view for free; local markdown gives you a directory listing."* So it patches a
> hole **one adapter** has — while `charting/SKILL.md:160` tells every caller to fall back on
> *"the adapter's generated progress view"* and `views/README.md:104` heads a section *"It
> does not replace `PROGRESS.md`"*. **`templates/trackers/github.md` defines no progress view
> at all.** Two files assuming universally what one adapter defines, and the map has been on
> a hosted tracker for four months without anyone noticing the fallback was empty. Fixed by
> removing the artifact rather than adding it to five adapters.
>
> **Three more grounds, all checked rather than asserted.** [#39](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/39)'s
> *whole graph* killed the cheap-read argument — one GraphQL call returns every ticket, body
> and comment, so reading the tracker is also one call. **This file is the evidence against
> itself**: 2,755 lines, and its entry for #50 and the map's gist for #50 say the same things
> in the same order at the same length. And it **contradicts its own spec** —
> `local-markdown.md:169` says *generate it; never hand-maintain it*, and this one is
> hand-written narrative.
>
> **The one thing it alone held has two homes that already exist.** The cross-ticket lessons
> — *fifth arrival of the premise rule*, *a rule you have written is not a rule you have
> applied* — go to the **map's Notes** while the map is live (one is already there, from #36)
> and to the **one memory written when the map closes**, which is what `charting/SKILL.md:356`
> says that memory is for. **Stated rather than papered over:** a local-markdown user with no
> HTML template installed is left with a directory listing, and `charting/SKILL.md:160`'s
> fallback needs a new second half — ask for the whole graph and print it. A sentence, not an
> artifact.
>
> **The hole in hole 3 was in the doc that creates it.** `01-the-solo-path.md:119` closes
> with *"read the stage you are actually standing in"*, and nothing on the page says how to
> find out which that is. Five tells answer it, every one a thing you go and look at: no repo
> · issue #1 open · issue #1 closed with no `CLAUDE.md` · `CLAUDE.md` and specialists on disk
> with no work tickets · work tickets carrying `From map #1`. **Rejected: a marker file or a
> `CLAUDE.md` line** — a fact about the repo written down beside the repo can be wrong and
> nothing would catch it.
>
> **Hole 2 was ruled out of scope, not answered — and the body's reason for it is false.**
> *"At work, Jira gives you a board; solo, nothing does."* A solo builder is on a tracker, and
> the tracker does not get worse because you are alone; this map is the evidence.
> `05-cutting.md:285` had already drawn the line — *"The solo path stops here. Everything
> after this is the shared pipeline."* **It sharpens
> [#41](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/41)**, which had
> written the same doubt into its own body: the label-per-backlog option existed only to
> regenerate the picture six weeks into implementation, and that need is now out of scope.
> Commented there; **not resolved** — #8 is one input to #41, not a verdict on it.
>
> **The interesting tension dissolved rather than resolving.** The body called
> memory-vs-tracker *"the interesting part of this ticket"*. Once nothing is stored, the only
> in-flight state that survives a session is the charting progress comment, which #5 already
> put on the tracker — so `PHILOSOPHY.md` §3 needs no exception at all. **And #18's nudge is
> paid, in the negative**: it asked whether hole 1 would hand the pipeline the same comment
> shape, making *sessions per unit = progress comments + 1* free. It does not — hole 1 turned
> out to be stages 3 and 4, and neither is a ticket. #18's *count it by hand* stands as
> written, exactly as its own comment allowed for.
>
> **The command question was reopened mid-session by the driver and closed on numbers.** The
> challenge was that a thin command would avoid loading both charting modes. It would not:
> `charting/SKILL.md` is **388 lines** and `### Chart the map` is **15** of them, the other
> ~341 being shared by both modes — and `resume-massive.md:11` shows a thin command **loads**
> the skill rather than replacing it, so it costs context and cannot save it. Held open to
> the last question anyway, because the honest case for a command was never mode-loading but
> whether solo has **bookkeeping of its own**. Dropping the progress file deleted the only
> candidate. **A challenge answered with a line count rather than an argument, and it changed
> nothing — which is why it was worth measuring.**
>
> **Deliberately left: nothing is written.** A grilling cannot also be a make (#5), so all
> twelve files went to #51 and #52 whole. **Not verified: that `/bootstrap` is re-runnable** —
> nothing was run, and *safe to re-run* rests on reading the eight steps and on #15's
> decision. #29 still owns proving the templates run. **Also not done: `Decisions so far` was
> not fully regenerated** — the new entry was inserted after a fresh re-read of the body, in
> the file's existing resolution order. A true regeneration from 40 resolution comments would
> have truncated gists that have been edited since they were first written.
>
> **The frontier is now four:** [#24](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/24),
> #41, [#46](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/46),
> [#49](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/49) — plus #51
> and #52 unclaimed. **#47 is still down to #49 alone.**
>
> The session before it resolved
> [#50 Land the two-layer `CLAUDE.md` reframe for the solo path](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/50)
> — **landed across 17 files: the tree now says what
> [#48](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/48) decided.**
> A make that decided nothing; every claim traces to #48. `06-claude-md-layers.md` opens on
> **how many repos do you work across at once** and draws **two pictures** — the two-layer
> one-repo shape and the three-layer sibling shape. Layer 2 opens with *skip this entirely if
> you have one repo*. Rule 2 makes *"this repo ships from `develop`"* **per-repo in both
> shapes**, with the workspace table named an **index** rather than the worked example simply
> flipped. `global.CLAUDE.md` gained the command block and all three stop rules;
> `repo.CLAUDE.md` gained a **Main branch (prod target)** section; `workspace.CLAUDE.md`
> thinned to a pointer, **kept** its table, and lost the false claim at `:6`.
> **#47 is down to #49 alone**, and the frontier is back to five.
>
> **The layer numbers now name the files, not a count**, stated at `06:50`. Layer 2 comes and
> goes; 1 and 3 are always there. The alternative was renumbering the two-layer shape to
> *1 and 2*, which would have cascaded into every template header (`repo.CLAUDE.md` says
> *"This is LAYER 3"*), every doc cross-reference, and every closed ticket that has ever said
> *layer 3* — including #48's own resolution comment. **A number that has been used as a name
> for months has stopped being a count**, and renaming it costs more than the ambiguity it
> removes.
>
> **The re-grep found three more sites, and one of them was on the ticket's own
> expected-correct list.** `11-adapting-to-your-stack.md:195-196` claimed shape B's workspace
> file carries *"the cross-repo order **and the new-branch workflow**"*. The first half is
> right and always was; the second was **falsified by this ticket's own layer-1 move** — and
> it sits thirty lines below `:82-83`, which the ticket checked, found correct, and passed.
> So **checking a file is not checking a claim**: #48 read the passage that mattered to *it*,
> wrote the file down as verified, and the sentence that its own decision would break was in
> the same file all along. This is the sharpest form yet of the *premise you obeyed* rule in
> the map's Notes — the list of what to leave alone is itself a premise, and this session
> nearly obeyed it.
>
> **`templates/commands/start-ticket.md:25` was hidden behind a fence.** It said *dispatch the
> layer specialists in chain order (per the **workspace** CLAUDE.md)*, and the ticket's own
> *do not reopen where the layer chain lives — settled by #10, routed by #44* reads like an
> instruction to skip it. It is not: this is not reopening #10, it is a **site still
> contradicting #10's settled answer**. #44 fixed the docs; this command file kept pointing
> the old way and no grep of `06` reaches it. **A fence around a decision is not a fence
> around the sites that disagree with it** — and the fence is what makes them hard to see,
> because the reflex it trains is *don't look there*.
>
> **`docs/team/02-team-adoption.md:24` had two errors in one line, sixty lines above two
> sites the ticket checked and passed.** *"Workspace CLAUDE.md is the source of truth …
> the implementation chain, the branch workflow, which repos exist."* The workflow is global
> now, and **a one-repo team has no workspace file at all**. #48 noted that `06` lives in
> `docs/shared/` precisely because the team path has this fork too — and then nobody told the
> team doc. **A decision scoped to one path still lands in every doc that path shares.**
>
> **The count grew four → five in all three places** (`04-the-bootstrap.md:48`, `:282`,
> `bootstrap/SKILL.md:113-120`), recomputed against the tree rather than transcribed — and
> the repo's *other* fours were left alone: `07-guardrails-when-solo.md:21` (*all four
> verdicts*) and `templates/views/README.md:127` (*all four states*). That is #35's trap
> stated as a procedure: **grep the number, then check each hit is the number you are
> changing.**
>
> **Deliberately left, and it is a scope call rather than a decision.** `README.md:123` and
> `templates/README.md:9` still read *global · workspace · per-repo CLAUDE.md skeletons*.
> They inventory a **directory**, and all three skeletons do ship; only `README.md:103`, which
> described *the doc*, had to move, because the doc no longer teaches three fixed layers.
> **A line can name three files without asserting you need three.** One line each if a later
> reader disagrees.
>
> Footers stay `2.1.219` (no doc gained a harness claim, so #17 keeps the audit and its stray
> `-e ` count is still **13**); no `docs/solo/08`; no ninth seam check; `03-setup.md` steps 6
> and 8 untouched. **Not verified: that a two-layer install behaves** — nothing was
> bootstrapped and no `CLAUDE.md` was written from these templates.
> [#29](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/29) still owns
> proving they run.
>
> **Previous snapshot** was after resolving
> [#48 Does the solo path have a workspace `CLAUDE.md` layer at all?](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/48)
> — **the solo path has two `CLAUDE.md` layers, not three.** Layer 2 is absent on a one-repo
> project; its two surviving facts split by kind — **the new-branch workflow up to layer 1,
> the main branch down to layer 3** — and `06-claude-md-layers.md` is **reframed around how
> many repos you have** rather than around three fixed layers. **Shape B keeps all three,
> unchanged.** Decided only; spawned
> [#50](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/50), which
> **takes #48's place blocking #47**.
>
> **The answer was written inside the doc that got it wrong.** `06`'s own rule 2 uses this
> exact pair as its worked example — *"We rebase, never merge" is global. "This repo ships
> from `develop`" is workspace* — and `01-architecture.md:75` states the general form,
> *behaviour is global, facts about this codebase are project-scoped*. Read *workspace* as
> *the file that owns codebase facts* and the split falls out; on one repo that file is the
> repo's own. **Nor is the fork itself new:** `02-prerequisites.md:59` already routes the
> layer chain by *"the repo's for one repo, the workspace's for sibling repos"* and
> `repo.CLAUDE.md:42-53` already ships both shapes. **A ticket that looks like it needs a
> new rule is often a ticket that needs an existing rule applied one place further.**
>
> **Half of it had already moved and nobody had noticed.** `global.CLAUDE.md:81-82` states
> the workflow today and defers only the branch *name*, so `workspace.CLAUDE.md:37-51` was
> already a fuller second copy — a mild rule-1 (*one fact, one layer*) violation predating
> this ticket. Landing the detail in layer 1 **fixes an existing overlap** rather than
> creating a new asymmetry, which is the difference between this and a widening.
>
> **Shape B keeps its main-branch table, and that is not a contradiction of the split.**
> Layer 3 owns the fact; the workspace table is a cross-repo **index** of facts each repo
> also states, earning its place on a need one repo does not have — in `recipes-api/` you
> may need what `recipes-web/` ships from, and that repo's `CLAUDE.md` is not loaded. **The
> same fact can need an index without the index owning it**, which is also why `06` rule 5
> (*canonical mappings live once*) comes out satisfied rather than broken.
>
> **`06` is reframed rather than annotated, and the reason generalises.** Deleting the false
> sentence at `:77-78` is the smallest fix and is not enough: the picture at `:16-26` draws
> three boxes as *the* structure and rule 2 at `:109-110` names the middle box as the
> branch's home, both independently of that sentence. #31 already found that two files
> disagreeing read to an agent as a contradiction with an arbitrary winner. **One file that
> disagrees with itself is worse, because nothing marks which half is current.**
>
> **The re-grep found three sites the body did not name, and a fourth inside a template.**
> `planner.md:47`, `08-ticket-pipeline.md:52` and `global.CLAUDE.md:82` all point an agent at
> *the workspace `CLAUDE.md`* — a file the solo path never writes — and `01-architecture.md:71`
> defines project scope in workspace-shaped words. The fourth is the sharp one:
> **`templates/claude-md/workspace.CLAUDE.md:6` restates `06:77`'s false claim inside the
> template the doc links to.** No grep of `06` reaches it; the concept does. Fifth arrival of
> *grep the concept, not the wording*, in its sharpest form yet — **the doc and the artifact
> it hands the reader carried the same false sentence, so fixing the doc alone would leave
> the reader's own copy asserting it.**
>
> **`commit-conventions` looked like a competing home and is a consumer.** Its
> `origin/<main-branch>` (`SKILL.md:29`, `:37`, and `layer-specialist.md:74`) sits **inside a
> shell snippet** — a runtime slot the agent fills when it runs the command, not a stated
> fact — so a skill #15 made a workspace-wide setup-time copy does **not** hold the main
> branch at global scope. #23's three-kinds-of-brackets rule arriving from the other
> direction: #23 used it to decide **what a placeholder may hold**, this uses it to decide
> **whether a placeholder is evidence of ownership at all.** Neither file says where to read
> the value from; #50 adds one clause to each.
>
> **Adds no seam check and no bootstrap step — checked, not assumed.** `workspace.CLAUDE.md:34`
> already prescribes `git symbolic-ref refs/remotes/origin/HEAD`, and stage 3 runs inside a
> repo stage 1 created, so the bootstrap detects the branch; an unknown one degrades to
> detect-and-ask and is therefore not a precondition. The seam stays **eight**. **But the
> bootstrap's own count grows from four to five** — `04-the-bootstrap.md:48` and `:282`, and
> `templates/skills/bootstrap/SKILL.md:119-120` — which is #35's trap exactly, so #50 carries
> *recompute against the tree* rather than the new number.
>
> **Deliberately left: nothing is written.** A grilling cannot also be a make (#5), so all
> sixteen-odd edits went to #50 whole rather than the easy half landing here. **Not verified:
> that a two-layer install behaves** — no repo was bootstrapped and no `CLAUDE.md` written;
> the claim that a solo builder loses nothing rests on reading the five items. #29 still owns
> proving the templates run. **Last snapshot's "No makes are left" is now false** — #50 is
> one, and #47 was already one.
>
> **The snapshot before that** was after resolving
> [#23 Write the prototype skill template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/23)
> — **written: `templates/skills/prototype/SKILL.md` — single file, zero placeholders — plus
> the flow catalogue row and four files the ticket did not name. [#11](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/11)'s
> last open placeholder is closed, and the one ticket type charting names with an empty shelf
> no longer has one.** A make that decided nothing; every rule traces to #5. **It spawned the
> map's first new ticket in two sessions:
> [#49](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/49), which
> blocks #47.**
>
> **Single file, because the upstream's reason for splitting does not survive the port.** Its
> two branch files are long only where they are stack-specific, and stack-specific is exactly
> what cannot be written here. And **picking the branch is the skill's first act**, so
> progressive disclosure would defer a file that loads on every run anyway — half a page
> saved, one hop and the repo's one-file convention spent.
>
> **It ships zero `<PLACEHOLDER>`s, against the ticket's own third bullet** — and checking
> that premise against the tree first, as the Notes require, turned up something better than
> a count. **The repo uses angle brackets for three different things**: a *reader
> placeholder* filled once at copy time (3 of 12 — `<LABEL-PREFIX>`, `<IDEAS-FILE-PATH>`,
> memory-schema's), a *generator slot* `/adapt-to-stack` fills per layer (`<layer>`,
> `<LANGUAGE>`), and a *runtime slot* the agent fills every run (`<N> of 7 pass`,
> `<TICKET-ID>`). A naive grep hits **7 of 12** and looks like a refutation; it is not. The
> rule that follows: **a placeholder holds what is constant for the reader**, and a run
> command is constant for the **repo** — so it is read off `CLAUDE.md` rather than
> transcribed. #44's *transcription drifts*, one level down.
>
> **Deciding whether `/prototype` sets `disable-model-invocation` found a live bug on
> `master`.** The docs say the field *"blocks programmatic invocation"* and *"removes the
> skill from Claude's context entirely"* — so `/prototype` **cannot** set it, because
> `/charting` dispatches to it and the row would become a dead pointer. Generalising *why*
> exposed the precondition the README never stated — **nothing else dispatches to it** — and
> `/bootstrap` step 5 breaks it by telling the agent to **Run `/adapt-to-stack`**, which sets
> the field. Opened as **#49** rather than fixed here: neither file is wrong on its own terms
> and the two repairs are not equivalent. Second instance of *a convention written for typed
> output contradicted by a decision about dispatched output* — #44 found the first, in
> `templates/agents/README.md`.
>
> **The spike sites are the ones worth carrying.** `12-when-not-to-use.md` has answered
> *"use an ad-hoc investigation agent"* for spike work since before this map and was
> **complete when written**. It stopped being complete the moment a skill existed for the
> half of spike work that is *building something to look at* — and it names the gap in its
> own words, so **no grep for `prototype` reaches it**. Generalised: **shipping a capability
> silently falsifies every doc that answered "there is nothing for that yet."** Spike work now
> splits **reading → investigation agent** / **building something to look at → `/prototype`**
> in three places, plus both copies of the kill gate's *spike clash* argument.
> **Then my own table falsified the paragraph beneath it** — #16's rule again, and this time
> the inconsistency was *created by the fix* and sat two paragraphs from it, in a file I had
> already finished editing.
>
> **Deliberately left:** no footer bumped — the two harness quotes went into
> `templates/skills/README.md`, which has none, and **no *doc* gained a harness claim**, so
> #17 keeps that audit and its stray-`-e ` count is still **13**, re-counted. And the flow
> catalogue's opening definition now has a **fifth** row it does not fit; still #17's.
> 0 dead links, 0 bad anchors across seven files. **Not verified: that the skill loads or
> dispatches** — nothing was run, and the dispatch claim rests on primary-source docs rather
> than an observation. #29 still owns proving the templates actually run.
>
> The session before it resolved
> [#45 Write the `/adapt-to-stack` skill template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/45)
> — **written: `templates/skills/adapt-to-stack/SKILL.md`, plus the flow catalogue row and
> both README entries — the six sites #44 handed over are landed, its marker is deleted, and
> both claims [#15](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/15)
> left unverified now have primary-source answers.** A make that decided nothing.
> **`disable-model-invocation: true` is the third application**, and the skills README now
> names what all three share rather than what two did.
>
> **Omitting `model:` inherits — confirmed, and #27's lesson does not generalise from
> `tools:` to it.** The subagent reference says it twice: *"Defaults to `inherit`"*, and
> *"Omitted: defaults to `inherit`."* An empty `tools` list refuses to launch **because a
> subagent needs at least one tool** — a floor `model` does not have. So the two fields fail
> in opposite directions and #15 decision 3 is safe.
> **A project-scoped `.claude/skills/` is loaded — and a personal skill of the same name
> beats it.** The opposite of *more specific wins*, and the opposite of how project *agents*
> resolve, where the definition closest to the working directory wins. So **one stray
> `backend-standards` in `~/.claude/skills/` shadows every repo's generated one**, silently
> and everywhere. The flow checks the name and **stops** rather than picking another: a name
> chosen to dodge a collision is a name the specialist cannot predict.
> **The live probe failed, and the reason it failed is the finding.** A throwaway skill
> written into this repo's `.claude/skills/` was not invokable in the session that wrote it —
> *"if you create a top-level skills directory that didn't exist when the session started,
> restart Claude Code."* The agents reference says the same of `.claude/agents/`. **The first
> run of `/adapt-to-stack` creates both directories**, so its own output cannot be dispatched
> to until a restart, while every disk-reading check passes. Hence the report carries the
> restart line whenever it created either directory. **This does not contradict item 4 of the
> session order** — that probe copied a file into a `~/.claude/agents/` that already existed,
> and an existing directory *is* watched. The unit that needs the restart is the **directory**,
> not the file.
>
> **Two mechanical points #15 implied and nobody had stated.** The four report rows are **two
> axes**: *created*/*skipped* is what you did, *disagrees*/*still a scaffold* is what you
> found, and a standards skill generated one minute ago is *created* **and** *still a
> scaffold* — every time, by decision 4 — so a single-verdict report would have to hide the
> one thing the fourth row exists to show. And **step 4 confirms what was written is visible
> to git**: #42's already-decided rule applied at the flow that *creates* those directories,
> since a blanket `.claude/` ignore line hides its output with no error. Fourth site of *two
> mechanisms, one directory*.
> **The re-grep found two sites the list did not have, and my own output was the third.**
> `03-setup.md:105` and `04-the-bootstrap.md:111`/`:115` all said *the stack-adaptation
> flow* — correct when written, because #34's *never let an artifact guess* forbids naming a
> flow that does not exist, and now the only places a reader meets a flow they cannot type.
> Then `templates/agents/README.md:31`'s `model` row said *✓ all*, **falsified four minutes
> earlier by my own edit** removing the field from `layer-specialist.md`; and the draft told
> the flow to delete a `COPY THIS…` opener from a template whose opener it had itself
> rewritten. So #16's *re-grep your own output* has a sharper form: **a site can be falsified
> by the fix rather than by the landing**, which no list written before the session could
> contain. Both rewritten to describe what the line **is** rather than what it **says**.
> **Deliberately left:** no footer bumped — the two new harness facts went into
> `templates/skills/README.md`, which has none, and **no *doc* gained a harness claim**, so
> #17 keeps that audit; and the flow catalogue's opening definition is now too narrow for a
> **fourth** row, already true of `/bootstrap` and `/cut-backlog`, and #17's to fix.
> 0 dead links, 0 bad anchors. **Not verified: that a generated specialist launches** — no
> subagent was spawned. **Unblocks nothing on its own** — #47 is down to #48 alone.
>
> And before that, the session resolved
> [#44 Rework `11-adapting-to-your-stack.md` as the explainer](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/44)
> — **written: `11` is the explainer behind `/adapt-to-stack` — you name the chain, the flow
> generates the rest — and the last dead forward link on the solo docs is closed.** A make
> that decided nothing. **Unblocks
> [#45](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/45).**
> **The ticket's file list was short by four, and the sharpest was in setup:**
> `03-setup.md:133` told you to copy *"your layer specialists"* into `~/.claude/` beside
> `ticket-analyzer` and `planner` — the exact opposite of #15's project-scoped decision, and
> nothing in the ticket pointed there. Found by grepping the **concept** (*per-layer
> copying*), not a filename.
> **`06-choosing-the-stack.md:256` is the one worth carrying.** It said generation reads
> `CLAUDE.md` *and memory two* — true when #21 wrote it, falsified by #15 decision 2 making
> `CLAUDE.md` the only input, and **not on #15's own list**. So: *the doc most likely to be
> falsified by a decision is the one written by the ticket that handed the decision over.*
> **A contradiction the ticket could not have named, because it lives in a template
> README.** `templates/agents/README.md:69` says pipeline agents *pin exact model ids,
> deliberately*; the layer specialist is a pipeline agent; #15 decision 3 omits the field on
> the generated ones. Neither file is wrong on its own terms — **a decision about
> *generated* output can contradict a convention written for *hand-written* output.**
> Pinning is advice to a human who knows the agent, and a generator knows only a layer's
> name. It now carries the exception, because **the file an agent loads while writing an
> agent file is that README.**
> **The ticket's line number was stale** — `04-the-bootstrap.md:94` for a marker sitting at
> `:115`, moved by #42 and #43. *A handoff's line number decays faster than anything else in
> it.*
> **Graduated the last of the *Single-vs-multi-repo* fog:**
> [#48 Does the solo path have a workspace `CLAUDE.md` layer at all?](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/48),
> which **blocks #47**. The word `workspace` appears **nowhere** in `docs/solo/` — the
> bootstrap writes exactly one `CLAUDE.md`, the repo's — while `06-claude-md-layers.md:77`
> still tells a single-repo reader that layer 2 is useful and puts the new-branch workflow
> and the main-branch table there. The patch is now empty and removed from the map.
>
> **[#16](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/16) closed
> in the session before this one and never got a snapshot here** — that session updated no
> part of this file. Its findings are in its resolution comment, and the map's
> Decisions-so-far carries its gist; nothing below has been back-filled for it, so treat any
> #16-shaped gap in this file as missing rather than decided.
>
> The session before it resolved
> [#18 How is progress measured on the solo path?](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/18)
> — **measuring is optional and its units are the reader's to pick; the unit is one shipped
> work unit, the two numbers worth keeping cost nothing to collect, nothing automates any of
> it, and it lands as a section under *habits* rather than a doc of its own.**
> **[#16](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/16) is now
> takeable — the capstone has no open blockers left.**
> **The ticket cited a source that said the opposite of what it claimed.** Its load-bearing
> fact was that `/goal` is *"a native, durable, zero-effort measurement surface"*; #6's own
> durability column says the condition survives a resume but **turn count, timer and token
> baseline reset**, so `/goal` measures one *session*, never one unit. Fifth arrival of the
> premise rule and a sharper one — #36's came from the Notes, #15's from another open
> ticket's body, #42's and #38's from their own, and **all four were true when written**.
> This one was false on the day it was typed, in the sentence it was summarising. Hence
> **re-read the source, not the ticket's summary of it**: a gist is a compression, and
> compression is where the qualifier goes missing.
> **`blocked_by` lied for about thirty seconds.** Closing #18 and immediately reading #16
> returned `blocked_by: 1` while GraphQL showed every blocker already closed — same instant,
> two endpoints, two answers, settling to `0` with no intervening write. **The summary is
> eventually consistent; the graph is not**, so the frontier query can silently hide a
> ticket that just became takeable. Added to `templates/trackers/github.md`'s traps table.
>
> The session before it resolved
> [#43 Rewire the guardrails for solo](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/43)
> — **the allowlist, the two-way `.claude/` sort, `block-secret-staging.sh` and the
> bootstrap's eighth step are on disk, and `test-hooks.sh` is 66 green cases across three
> blocking hooks.** A make that decided nothing about the guardrails.
> **`jq` is missing on this machine, so all four hooks currently fail open.** Verified
> outside the suite: `command -v jq` returns nothing and the hook exits **127**, which the
> hooks README's own box calls a *non-blocking* error — the tool call proceeds and the
> guardrail is not there. `jq` appeared **nowhere** in `docs/`, `README.md` or
> `PHILOSOPHY.md`. The halves needing no decision landed (`02-prerequisites.md` gains it as
> required; the README names the consequence); the decision is
> [#46](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/46), because
> fail-closed blocks the very `git` commands needed to fix it. **Third guardrail here that
> reported success while guarding nothing**, after `exit 1` and the multi-line flatten —
> and all three were found by **running** it. *These scripts cannot be verified by reading
> them* was already known; what was not is that **the suite is not the same as the
> machine.**
> **Then the repo did it to itself in the same commit.** `.gitignore`'s `*secret*` made
> `block-secret-staging.sh` invisible to `git add` from the moment it was written — no
> error, absent from `git status`, and it would have been missing from the commit. The
> identical two-mechanisms-one-directory failure the ticket exists to fix, one directory
> over: **a pattern that matches on the name cannot tell a secret from a file about
> secrets.** The previous session had already written the abstract rule into
> `07-guardrails-when-solo.md` and this one still walked into it — **a rule you have
> written is not a rule you have applied.**
> **The allowlist lookup is duplicated verbatim in both hooks on purpose:** a shared helper
> you can forget to copy turns a guardrail into one that silently stops guarding.
> **The new bootstrap step goes first and is the only one not placed by a dependency** — an
> inserted step that needs nothing falsifies *the order is forced* wherever it goes, so `04`
> now says forced *for seven of the eight*.
> **The suite caught a false positive no reading would have:** `.env.example`, the one file
> in that family that is supposed to be committed, was blocked by the `.env` pattern.
> **#14's sorting rule held exactly and still missed a thirteenth site** —
> `02-prerequisites.md:34`, where the conclusion (read scope) is right and the reason
> (*"you push manually anyway"*) is dead. **A claim can survive while the reason under it
> dies.**
>
> The session before it resolved
> [#42 Write the solo guardrails doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/42)
> — **written: `docs/solo/07-guardrails-when-solo.md`**, the reader-facing *why* behind #14,
> and `docs/solo/` is seven files. A make that decided nothing.
> **The ticket's own body carried an expired premise.** It instructs *"exactly one file
> flips"* and *"is `.claude/` part of the product? — **no**"*; #15 amended both a session
> later. The doc therefore states **three path classes flip** (`CLAUDE.md` conditional on
> the allowlist, `.claude/agents/**` and `.claude/skills/**` unconditionally) and that the
> product question has **no per-directory answer** — it is per *file*, and the fresh-clone
> test is what answers it. #36 survives on *the viewer* not being product rather than
> *`.claude/`* not being. **Second consecutive ticket to find its instructions expired
> inside an open ticket's body**, where no grep of `master` reaches: #15 found it in #43's
> body, this one in its own.
> **The finding: flipping the hook does not make the file committable.** Two independent
> mechanisms keep a file out of git and #14 moved only one — the hook blocks the *command*,
> `.gitignore` makes the file invisible to it — and **three files** instruct a **blanket**
> `.claude/` ignore line: `templates/views/README.md:78`,
> `templates/skills/charting/SKILL.md:134`, `templates/skills/cut-backlog/SKILL.md:252`.
> Deletion is wrong (#36 needs that line), so the fix is **exceptions written with the
> line**, sorting the way the hook now sorts. **Two guardrails on one directory, living in
> different files** — the ticket that changed one had no reason to grep for the other.
> **Two unowned falsified claims fixed in `04-the-bootstrap.md`.** The crosses-the-line
> table lost a row and *three things cross* is recomputed to **two** (#15 lands the
> specialists in-repo, so step 4's output crosses nothing); and the *"whether stage 3 ends
> with a commit is not settled here"* paragraph — which carried **both** #43's *never
> committed* claim **and** an open question #14 had closed — was rewritten whole rather
> than split across two tickets. #43 has a comment saying so.
> **Handed to #43, four sites its sweep does not have:** `global.CLAUDE.md:82` (four lines
> below the `:76` it already owns, failing #14's sorting rule the same way),
> `commit-conventions/SKILL.md:40`, the `.gitignore` trio, and the `/test-ticket` §6
> knock-on (`test-ticket.md:23`/`:33`, `07-the-flows.md:87`).
> Verified: every relative link and `#anchor` in both files resolves — **0 dead, 0 bad**.
> Ships one *still being written* marker for #43 to delete.
>
> The session before it resolved
> [#15 Turn a chosen tech stack into working agents and skills](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/15)
> — **the flow is `/adapt-to-stack`: it reads the repo's `CLAUDE.md` and nothing else,
> generates one layer specialist and one standards skill per layer into the repo's
> `.claude/agents/` and `.claude/skills/` where they are **committed**, never overwrites on
> a re-run, and mentions neither path.**
> **The two-entry-point split this ticket was written to design does not exist.** The body
> called it *a genuine test of the context-window-first rule* and expected a shared skill
> plus a thin entry point per path; #10's comment sharpened it to *the chain is read on
> solo and proposed on agile*. Narrowing the input to one file dissolved it — the
> difference stopped being a branch in the generation and became **whether the input file
> exists yet**. A skill that names no path loads no other path's context, so the rule is
> passed by being **path-agnostic rather than split** — #5's move on charting, arriving
> from the other direction. **A ticket predicting two variants should re-check the
> prediction after its input is settled.**
> **The conflict with #43 is a new kind, and no grep of `master` reaches it.** #43's body
> instructs that *only `CLAUDE.md` flips* out of `block-infra-staging.sh`. That is **not a
> false premise** — #14 reached a correct conclusion without knowing what #15 would decide,
> and #43 wrote it down as an instruction to a future session. It was true when written and
> **expired mid-effort**, sitting in an **open ticket's body**. #43 keeps the script (it
> already runs `test-hooks.sh`, the only way these can be verified) and is amended:
> `.claude/agents/**` and `.claude/skills/**` flip, the rest of `.claude/` stays blocked.
> The check that would have caught it: **when a ticket decides where generated files land,
> re-read the open tickets that own the guardrails on that path.**
> **Four prose sites #43's own sweep missed**, because *"AI-infra files are never
> committed"* is a different sentence from *never push*, so #14's sorting rule does not
> cover it: `07-the-flows.md:26`, `04-the-bootstrap.md:150`, `03-setup.md:104`,
> `templates/commands/start-ticket.md:39`.
> **The driver's catch exposed an under-specified decision.** Where the *agents* land was
> argued and settled; the per-layer *standards skills* are also generated and where **they**
> land was never asked. Same argument, same answer — but the gap was invisible until
> someone read the flip back as a list of directories.
> **"Still a scaffold" costs no state.** A file at its default still carries the template's
> `<PLACEHOLDER>` brackets — **the convention that makes a template fillable is what makes
> un-filled-ness detectable**, a job nothing in `templates/` had been asked to do before.
> **Model ids rot**, which is what kills a fixed default: a written-in id is N files to
> update the day it changes, inheriting is zero.
> **#36 survives with its reason narrowed** — the viewer is still refused by the hook, but
> *"`.claude/` is not part of the product"* must become *the viewer* is not. Recorded on the
> closed ticket, the one place no grep of the working tree reaches.
> Spawned [#44](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/44)
> (the doc) blocking [#45](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/45)
> (the template). **Nothing verified live.**
>
> **This file was two sessions behind, not one** — #14's session closed without writing to
> it, so the frontier and blocked tables below listed #14 as takeable and knew nothing of
> #42/#43. Both sessions are folded in here.
> The session before it resolved
> [#14 Which guardrails hold when you are solo](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/14)
> — **working solo deletes the *audience* half of `PHILOSOPHY.md` §5 and leaves the
> *reversibility* half standing, which produces all four verdicts with no special-casing.**
> §5 has always read *hard to reverse **or** leaves your machine* — two clauses nobody had
> noticed were two — so **reversibility was the real invariant all along**. Push holds with
> its reason rewritten (a private repo is not a private disk). §6 does not apply and is
> **replaced rather than modified**: a weekend project has no staging tier. AI-infra holds
> with **exactly one file flipping** — the path list becomes **would a fresh clone need this
> file?** — and the mechanism is **one allowlist in `~/.claude/`, keyed by remote**, both
> answers defaulting to no. **One guardrail was added because this ticket created the need
> for it**: the push block was quietly doing secret-leak protection. **Stage 3 commits,
> green-only.** Spawned #42 and #43, both blocking #16.
> The session before it resolved
> [#38 Write the `/cut-backlog` skill template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/38)
> — **`templates/skills/cut-backlog/SKILL.md` is written, the skills README carries its
> entry, and the marker `05-cutting.md` shipped is deleted — so all four solo stages now
> ship a doc *and* a template.** A make that decided nothing; every rule traces to #12,
> plus #40's step-7 block posted verbatim.
> **The ticket's own step 7 contradicted the ticket's own bullet.** It asked for *"native
> blocked-by edges where the tracker has them, the HTML viewer where it does not"* — a
> branch on tracker capability — sitting four bullets above *"the tracker is never named;
> abstract verbs only."* #4 forbids exactly that: where a tracker lacks a verb the adapter
> fakes it and the calling skill is **never told**. So step 7 is written unconditional —
> *mark blocked* once per body line **and** generate the picture, both, always — which is
> the shape `charting/SKILL.md`'s picture section already had. Not a new decision, the
> standing contract applied. **This map's premise rule arriving from a new direction: the
> false premise was inside the ticket, not the Notes.**
> **One mechanical point #12 implied and nobody had stated: create in dependency order.**
> The board shows **positions**, ids do not exist until step 6, and the body's
> `needs #6 first` line is the truth. Those three cannot all hold in one pass unless
> blockers are created before the things they block — the alternative is filing a dozen
> issues and then **editing a dozen bodies** to fill in ids that only just came into being.
> Step 3's ordering is **load-bearing, not cosmetic**, and the board says its numbers are
> positions rather than ids because a human editing it will otherwise name a number that
> does not survive.
> **The re-grep found one site, and it was in the paired stage doc.** `05-cutting.md:8`
> said approval *"is the eighth item"*, while three other lines of the same file and `01`'s
> seam table all say **item 6**. That is the third instance of the seam's 7 → 8 growth
> outliving its ordinals (#35 correcting #34, #37 correcting `04:252`, now this) — and the
> sharp part is not the repeat: **#37 fixed that exact phrase in `04` and wrote it fresh in
> `05` in the same session.** A session correcting an error in one file reproduced it in the
> file it was writing — the one place no grep of `master` reaches, and the one copy nobody
> re-reads. See the gotcha.
> **Second template to set `disable-model-invocation: true`**, and the skills README now
> names what the two have in common: **each one's output is somebody else's input** — the
> bootstrap's report is read at the seam, the backlog by `/start-ticket` — so an
> unasked-for run **publishes** something downstream may act on rather than costing one
> redirect. That is why these two and not the four conversations.
> **No flow catalogue row was owed** — #37 landed it a session early, and it was checked
> against the finished template rather than assumed. **Unblocks nothing**: #38 was on no
> other ticket's blocker list, and #16 still waits on #14, #15 and #18.
> **One thing it could not decide, and did not — spawned as
> [#41](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/41).** #39
> predicted it in writing: ***the whole graph* is defined over the children of a parent**,
> and #12 made work units **standalone on purpose**, so the one artifact the picture exists
> to draw on the backlog side is the one the fetching verb cannot name. #39's verb, #12's
> standalone units and #36's one-page-for-both are each right and jointly incomplete. Step 7
> ships the instruction that is **true under every available answer** — ask for the graph
> over **the ids in hand**, which the skill holds because it created them one step earlier —
> and states the constraint rather than papering over it. The question that separates the
> alternatives is **what regenerates the picture six weeks later**, when nobody holds the
> ids.
> The session before it resolved
> [#40 Write the dependency viewer template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/40)
> — **`templates/views/dependency-graph.html` and its README are written, generated once
> against this map and opened in a browser — and *the whole graph* on GitHub is now one
> GraphQL call, because REST cannot draw an arrow.** A make; every design decision traces
> to #36.
> **The finding: `issue_dependencies_summary` is four integers.** It answers *is this
> blocked?* and cannot answer *blocked by what?*, so the two-REST-call whole graph #39
> landed the day before returns every box on the picture and **not one edge**. The REST way
> to the edges is a request per blocked child — 16 of them on this map. GraphQL's
> `blockedBy` is a real connection, so **one call returns children, state, claims, labels,
> bodies, all 48 comments and all 16 edges**: 1.3 s, ~520 KB, verified twice. And `gh api`
> takes `--jq`, so the same call reshapes into the page's data slot — the generator is
> literally one command.
> **A cost check is not a completeness check.** #36's *two requests against the naive
> sixty-six* was arithmetically right and never asked whether the cheap answer contained the
> thing the picture is made of. The contract now carries the rule in general form: **an
> adapter answers *by what?*, never just *how many?***
> **The directory is `views/`.** Every other subdirectory here is named for what the harness
> turns the file into; nothing turns this into anything, so it is named for what it is to
> the reader. Not `skills/` — a 545-line artifact a skill copies without reading does not
> belong in a loading path. That forced one edit the file list did not imply:
> `templates/README.md`'s *every file here is a claim about the harness* now carries an
> exemption, because a directory quietly contradicting the README's first section is the
> *docs are model input* failure this map keeps re-learning.
> **Verified live, because #36 said nothing was:** 480 KB page, no console errors, all four
> states legible at 35 boxes — told apart by **outline rather than colour** (thick solid /
> dotted / dashed / thin-and-small), which survives greyscale and colourblindness where four
> hues would not. **Two markdown bugs only real ticket text could find**: `**bold with an
> *italic* inside**` did not render, and every gist on this map is that shape; and the
> code-span placeholder was a bare `" N "` that any body containing a number would corrupt.
> **Prose written by this effort is the only test data that would have caught either.**
> **Deliberately not done: no flow catalogue row and no new skill.** A flow is a slash
> command orchestrating agents; the picture is neither, and asserting one would be *never
> let an artifact guess* with a `/` in front of it. Both flow rows mention the picture and a
> paragraph says why it has no row.
> Not verified: light theme, the `.gitignore` step (no repo was bootstrapped this session),
> and anything past 35 boxes — the GraphQL `first:` arguments are **caps, not pagination**.
> **#38 is unblocked**, with the five-line block posted on it verbatim.
> The session before it resolved
> [#39 The tracker contract: read must include comments, and a whole-graph verb](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/39)
> — **both changes are landed in all five tracker files: `read` is *defined* to include the
> ticket's comments, and *the whole graph* is the contract's second composed verb.** A make
> that decided nothing; both changes were argued and handed over by #36. **Eight files
> edited, not the five the ticket listed**: `templates/skills/charting/SKILL.md` restates the
> vocabulary table and had to gain both, this file's own ten-line contract summary asserted
> *"exactly one composed verb"*, and `05-cutting.md` used the phrase *the whole graph* in
> plain English before it was a verb.
> **`read` is a definition, not a thirteenth verb.** Still twelve small verbs, now two
> composed. Where a tracker needs two calls the adapter makes both and the caller never
> finds out — the faking-it rule the contract already had. **The local adapter is why nobody
> caught it**: question and comments live in one file there, so the one adapter that
> satisfies the fix for free is also the one that hid the defect for four months.
> **The whole graph earns its place on the frontier's own test**, and the GitHub numbers are
> what make it concrete: `…/issues/<map>/sub_issues --paginate` returns every child with its
> body, and `…/issues/comments --paginate` returns **every comment in the repo** in one
> paginated call — join on `issue_url`. Two requests against the naive sixty-six.
> **Corrected by #40 the next day: those two requests return no blockers**, only counts, so
> the GitHub whole graph is a single GraphQL call. The verb and its earning test stand; only
> the commands were wrong.
> **One number was deliberately not written down.** #36's note here says *"all 52 comments"*;
> it is 54 today and will be 55 after this ticket closes. A count that changes every time
> anyone comments is not a fact an adapter can carry, so `github.md` states the shape — a
> fixed handful of requests rather than one per ticket — and quotes no total.
> **New verified trap:** `gh api …/issues/<n>` carries a `comments` field that is a **count**
> and a `comments_url` that is a **link**. Nothing about a one-call read looks wrong; it just
> returns the question.
> The session before it resolved
> [#36 The dependency viewer: one HTML picture for the map and the backlog](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/36)
> — **the viewer is a shipped HTML page with a data slot, generated on demand into
> `.claude/`, serving the map and the backlog both.** The adapter fetches, the page draws.
> Decided only; spawned **#39 the contract fixes** and **#40 the viewer template**, with #40
> taking #36's place as the real blocker on **#38**.
> **This file is now load-bearing, and #36 is why.** It decided `PROGRESS.md` and the viewer
> both stay, split by **who reads them** — this file is prose for the next session and is
> committed; the viewer is a picture for you and is never committed. That is also the answer
> to *where does the generated file go*: `.claude/`, where `block-infra-staging.sh` refusing
> to stage it is the **enforcement, not the obstacle** — the same hook #34 found *wrong* for
> the bootstrap, because the real difference is **provenance**, which is exactly what #34
> said the hook expresses badly by talking about paths.
> **The ticket's own premise was false and cost it the right answer for a whole session.**
> The map's Notes said *"nothing here ships code"*; `templates/hooks/` has held **seven
> working bash scripts** since long before this map opened, so "we cannot ship a generator"
> was never a real constraint. The Notes are corrected. **A constraint nobody checks is
> indistinguishable from a real one** — and this one was read out of a Note rather than out
> of the tree.
> **Two pre-existing defects in the tracker contract surfaced, neither invented by the
> viewer** (both are #39's): **`read` never included comments**, so on GitHub *"read ticket
> #12"* hands back **2,224 chars of question and 0 of answer** while the resolution comment
> holds **14,193** — and charting's own *zoom a closed ticket* instruction has rested on that
> since #5 made the resolution comment the most load-bearing line in the contract. And the
> contract needs **a second composed verb, *the whole graph***, which breaks its own boast of
> *"twelve small verbs and exactly one composed verb"* and should, because it earns its place
> on the **identical test the frontier already passed**: the cheapest answer differs per
> tracker and every caller wants the same thing.
> Verified live, so do not re-derive: `…/issues/1/sub_issues --paginate` returns all 33
> children **with bodies**, and `…/issues/comments --paginate` returns all 52 comments
> **repo-wide in one paginated call** — so a self-contained page costs **two** requests, not
> 66. Nothing else here is verified: the open risk is whether a ~420 KB page with 33 boxes
> still reads clearly, which is #40's to check.
> **Both halves of that were settled by #40, one of them against.** The page reads clearly
> at 35 boxes. But those two requests carry **no dependency edges** — `sub_issues` reports
> blocker *counts* — so the picture they pay for has no arrows, and GitHub's whole graph is
> **one GraphQL call**, not two REST ones.
> The session before it resolved
> [#37 Write the cutting stage doc and rename the stage](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/37)
> — **`docs/solo/05-cutting.md` is written, the stage rename is landed, and `docs/solo/` is
> six of six.** All four stage docs now exist, end to end, which is what the capstone #16 was
> waiting to be able to describe. A make that decided nothing; every claim traces to #12.
> **The rename was ten sites, not the four the ticket listed** — #12's own grep found the
> four that say *"the backlog"* where they mean the stage, and missed six more that name it
> **in passing, in a list of the other three stages**: `01:61` and `03:186` (*"the bootstrap
> or the backlog"*), `02:92` (*"charting has nothing to chart, the bootstrap nothing to
> scaffold…"*), `03:39`, and `04`'s closing ASCII and section heading. **A rename grep finds
> the sentences about the thing and misses the sentences that merely walk past it.** Also
> retired: `01`'s *"the four stage docs are still being written"* note, false the moment this
> file landed, and `04:252`'s *"stage 4 makes the eighth"* — the remaining seam item is
> number **6**, not 8. Ships **one dead link** to `templates/skills/cut-backlog/SKILL.md`
> with a *still being written* marker for **#38** to delete.
> The capstone [#16](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/16)
> still has **three** open edges — #37 was never one of them — and **#38 is down to one**.
> The session before it resolved
> [#12 Cleared map to backlog of work units](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/12)
> — **stage 4 is *cutting*, the command is `/cut-backlog`, and the units are cut from the
> *smallest version* rather than from the decisions.** The ticket's own opening premise turned
> out to be wrong: decisions do not convert into work, and **the scope was named a full stage
> earlier** — the kill gate's Q3 writes the smallest version into the map's Notes, so the
> sentence says *what* and the map says *how and what not to do*. **One ticket = one thing the
> app can now do, all the way through**; plumbing-only tickets are forbidden. **The
> `12-when-not-to-use.md` size bar is deliberately not reused** — on a day-one repo it cannot
> return *no*. **Dependencies are real** (the driver rejected the recommended flat list and was
> right), with the **ticket body as the single truth** and native links plus a generated HTML
> view as pictures of it. The scope check is a **trace, not a count**, after the count was
> recommended and then withdrawn mid-session — see the gotchas. Decided only; spawned
> **#36 the dependency viewer**, **#37 the stage doc** and **#38 the skill template**, with
> #36 *and* #37 wired as real blockers on #38.
> The session before that resolved
> [#30 Write the stack-choice doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/30)
> — **`docs/solo/06-choosing-the-stack.md`, and all three link fixes it owed.** A make that
> decided nothing. It took **`06`**, leaving `05` reserved for the last stage doc. **One stale
> count was corrected on the way through, and where it was hiding is the finding:** #21 §7's
> *the other **five** seam checks do not vary by stack* was true when written and wrong once
> #10 grew the seam to eight — and it sat **inside a closed ticket's resolution comment**, the
> one place no grep of the working tree reaches and the one place this map treats as the
> durable record. **When a ticket retires a number, the closed comments that quoted it are not
> retired with it.**
> And before that,
> [#35 Write the /bootstrap skill template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/35)
> — **`templates/skills/bootstrap/SKILL.md`, wiring the bootstrap pair**, the first template
> to set `disable-model-invocation: true`, and it **corrected #34: the exit report is seven
> checks, not eight**. Before it,
> [#34 Write the bootstrap stage doc and retire the count seven](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/34)
> — **`docs/solo/04-the-bootstrap.md`, the seam's eighth check, and the count *seven* gone
> from every file that stated it** — and
> [#10 The bootstrap](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/10),
> which designed stage 3, grew the seam to eight, and spawned both. Before those,
> [#33 Retire the flat Serena gate from every file that states it](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/33)
> and
> [#31 Serena is conditional: what happens to seam item 4?](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/31),
> which is what made #10 takeable.
> **#10 found this file to be the fifth site of the phrase #33 retired** (the Destination
> section, *"a scaffolded, Serena-indexed repo"*) — #33's grep covered `docs/`, `templates/`,
> `README.md` and `PHILOSOPHY.md` and skipped the tracking file.
> Off-map, a live probe of `pitch-judge` failed and opened
> [#32 pitch-judge cannot launch](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/32);
> [#29 install and run every template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/29)
> is still open and deliberately parked.
> Regenerate rather than trust — the one-call frontier query is:
> ```
> gh api repos/konstantinos-malavazos/claude-code-playbook/issues/1/sub_issues --paginate \
>   --jq '.[] | select(.state=="open") | select(.assignees|length==0)
>             | select(.issue_dependencies_summary.blocked_by==0) | "#\(.number)\t\(.title)"'
> ```
>
> **Tickets carry both number and name throughout.** The number is what you type at
> `/wayfinder`; the name is what makes it legible six weeks later. Never one without the other.

---

## Destination

A **second entrance** to this repo: a documented path taking a solo builder from a raw idea
to *a backlog of work units on a scaffolded repo that passes the seam*, where it hands off to
the existing implementation pipeline. Delivered as docs + templates in the house style.

> **Corrected 4 August 2026 by #10.** This line said *"a scaffolded, Serena-indexed repo"*
> until today — the exact phrase #33 retired from four files last session, surviving in a
> **fifth**, because #33's grep ran over `docs/`, `templates/`, `README.md` and
> `PHILOSOPHY.md` and never looked at the tracking file. **The file that records the lesson
> is not exempt from it.**

Done when a reader with an idea and no repo can follow the path end to end.

---

## Status at a glance

| | Count |
|---|---|
| Tickets closed | **39 of 45** |
| Tickets open | **6** — one closed (#50) and **none arrived**. The first genuine fall in three sessions: the two before it were flat by cancellation, and this one is flat-free because a make that decides nothing has nothing to spawn |
| On the frontier (takeable now) | **5** — #8, #24, #41, #46, #49 |
| Blocked | **1** — #47, now on **#49 alone** |
| Repo files changed since the effort began | **65** distinct files — map tickets and #28's off-map audit together, `PROGRESS.md` excluded, this session's working tree included. *Recomputed from `git log 04cf1a6~1..HEAD` plus `git diff --name-only` plus untracked.* **+1, and the single new file is worth naming:** `templates/agents/planner.md`. Sixteen repo files were edited this session and **fifteen had already been touched** by an earlier ticket — which is what a landing ticket looks like once a map is this far in. The count measures *reach*, not effort, and a 16-file session moving it by one is the clearest demonstration of that this effort has produced. |
| Branches | none — findings live in ticket comments, not in the repo |
| Working tree | committed and pushed at the end of this session — **asked for, not assumed**, per #14's per-repo push answer defaulting to no. **17 files changed**: the sixteen #50 landed, plus this one |

*Ticket counts recomputed this session from the map's children, not carried — one GraphQL
call now returns the states, the claims and the blocking edges together, so the frontier
and the blocked list below are counted rather than reasoned about.*

**The carried count reproduced this session, and that is the first time.** *38 of 45*
carried, **39 of 45** recomputed — one closure, no new child, so only the numerator moved.
It is worth saying out loud that it matched, because the last four entries here all record a
mismatch and the habit that produces is *assume it is wrong*. **A rule that only ever fires
on failure gets read as a prediction**; the rule is *recompute*, not *expect a discrepancy*.
The denominator held at 45 for the first time in three sessions, and the reason is
structural rather than lucky: **a make that decides nothing cannot spawn a ticket**, so the
one session shape that leaves the denominator alone is exactly the shape #50 had. Seventh
session running the counts off one call. Recomputed, not
reconciled: #17, #28, #29 and #32 are **not** children of the map and never enter this count.
Same discipline as the file count on the row above, and as #30 and #39 — **recompute any
number you are about to write down.**

**And this paragraph was itself a full session stale.** It read *"32 of 41 carried, 33 of 41
recomputed"* while the table three lines above said **35 of 43** — #44's session recomputed
the table and left the prose beside it untouched. A number in a table looks like data and
gets recomputed; **the same number in a sentence looks like narration and gets skipped**,
which is how a file whose standing rule is *recompute, do not transcribe* ended up carrying
a stale count in the paragraph that states the rule. Sixth arrival of *the file that records
the lesson is not exempt from it*.

**Recorded because it will bite again: `blocked_by` is eventually consistent.** Reading #16
seconds after closing #18 returned `blocked_by: 1` while GraphQL's `blockedBy` showed all 19
blockers already `CLOSED` — the same instant, two endpoints, two answers. It settled to `0`
about thirty seconds later with no intervening write. **The frontier query is built on that
count**, so for a short window after any close it can silently omit a ticket that just became
takeable. Now a row in `templates/trackers/github.md`'s traps table.

**The seam is eight checks now, and the eighth was a hole the size of the whole implement
step.** `08-ticket-pipeline.md:18` dispatches to layer specialists, and **no seam check said
those agent files exist** — all seven could hold and `/start-ticket` would have nothing to
dispatch to. #10 put generation into stage 3 and the check onto the seam, and #34 landed it
on the seam table. **The seam had been read many times by many tickets and nobody looked at
what was on the far side of it.**

**#34 is the first re-grep ticket in five that found nothing extra.** The body listed four
sites for the count *seven*; a wider grep on `seven|six|eight|seam|all must hold|items 1`
across `docs/`, `templates/`, `README.md`, `PHILOSOPHY.md`, `examples/` **and this file**
returned exactly those four. That is not the pattern breaking — it is the first body that
had already been widened once, by #10, before it was written. **The fix for a narrow list is
to widen it in the body, not to re-derive it in the session.**

**#33's claim was false, and this file was the counterexample.** It said *no file on master
states a flat Serena gate*. `PROGRESS.md:38` — the Destination section of this very file —
still said *"a scaffolded, Serena-indexed repo"*, because #33 grepped `docs/`, `templates/`,
`README.md` and `PHILOSOPHY.md`. **The tracking file is tracked**, it is on master, and it is
model input like everything else here. Fixed by #10.

**That is now four tickets in a row where a wider re-grep found the site that mattered.**
#31 found the `/pitch` template; #33 found the tail's ticket-2 row; #10 found its own exit
condition at `01-the-solo-path.md:24` after listing three sites, and then found this file.
**The pattern a ticket body hands you is narrower than the claim it is chasing** — and the
*directory list* you grep is narrower still. Grep the repo, not the docs.

**Still knowingly wrong on disk, and ticketed:** `pitch-judge.md`'s `tools: TodoWrite`
(#32). That is the only one left.

**The map grew, then closed the hole it grew for.** #25 and #26 both wrote their files and
decided nothing — but verifying one of #26's claims turned up a real problem, so it spun
#27, which is now resolved. That is the decide-or-make rule working in the direction it is
usually quiet about: a make found a decision and stopped instead of quietly deciding it.

**#28 found four silent failures, and two were guardrails that were not guarding.**
`repo-reviewer` promised to dispatch `@release-reviewer` and had no `Agent` tool, so the
pipeline's cross-repo review could never run. The git hooks matched only `Bash`, so
**`PowerShell` walked straight past them** — on Windows, which is where this repo is
driven. Both are fixed. See the gotchas below; both generalise well beyond this repo.

**Then the hooks were actually run, and a fifth failure appeared that reading could not
have found.** Both git guardrails ignored `git push` on any line but the first, because
they flattened newlines to spaces and their patterns anchor on a separator. `cd /tmp &&
git push` was caught; the ordinary multi-line form was not. **The audit's method was the
limit, not its diligence** — every documentation claim it checked was correct. The repo now
has its first executable test, `templates/hooks/test-hooks.sh`, and a standing rule: **where
a claim can be executed, execute it.**

**Both stage pairs are now fully wired.** Charting — #11 the skill, #22 the doc, #13 the
path they pointed at. The kill gate — #25 the doc, #26 the skill and the judge. The two
pairs were built in **opposite orders**, and it made a visible difference: charting's
template landed first, so its doc never shipped a dead link, while `02-the-kill-gate.md`
carried a *still being written* marker for one commit. #26 deleted it.

**No makes are left again — and this is the second time that sentence has been true, which
is exactly why it is not worth trusting.** #23 closed and it was true; #48 spawned #50 and
it was false one session later; #50 has now landed and it is true again. The frontier is
#8, #24, #41, #46 and #49, all grillings, plus the blocked #47, which is itself a make.
**A "none left" claim about a queue that any ticket can add to expires the next time one
closes** — and having now expired and reappeared, it is a **state**, not a milestone. Read
it as *nothing is queued to be written today*, never as *the writing is done*.

**The exit report is seven checks, not eight — #35 caught #34's error a session later.**
Seam item 6 is *the backlog exists*, which is stage 4's, so stage 3 cannot speak to it. The
seam went from seven to eight **inside #34**, so every *seven* in its body read as a stale
count to be updated; one of them was counting a different set. **When a ticket retires a
number, not every instance of that number is the number being retired.** No grep of `master`
could have caught it — it was inside the doc being written.

**`docs/solo/` is 6 of 6 — the four stage docs exist end to end.** `01` the spine, `02` the
kill gate, `03` charting, `04` the bootstrap, `05` cutting, `06` choosing the stack. #37
closed the last gap. **`06` is the first non-stage solo doc**, and it took its number at
write time rather than claiming one in advance, which is what let `05` stay reserved for a
doc nobody had written yet. `07+` is now open for **#42 (#14’s doc) and #18** in write order. **#15 took no number** — it decided there is no new doc, because the stack-adaptation flow is step 4 *inside* stage 3, not a stage, so it reworks `docs/shared/11` in place.

**Stage 4 broke #5's naming rule in the spine that states it, and nobody had noticed.**
`01-the-solo-path.md:27` says *"the stage is charting; the artifact it produces is the map.
They never share a name — otherwise you can never say which one you mean."* Three rows above,
stage 4 was called **the backlog** and produced **the backlog**. It is now **cutting**, and
the artifact keeps its name — and the spine now states the rule for both rows.

**The rename was ten sites, not the four #12 estimated — and the six it missed are all the
same shape.** #12's grep was right that nearly every *"backlog"* in `docs/` names the
**artifact** and stays, **seam item 6 included**; it found every sentence that is *about*
the stage. What it missed were the sentences that **walk past** the stage on the way
somewhere else — *"the bootstrap or the backlog"* (twice), *"charting has nothing to chart,
the bootstrap nothing to scaffold, the backlog nothing to cut up"*, a table cell in `03`, and
`04`'s closing ASCII and section heading. **A rename grep finds the sentences about the
thing and misses the sentences that merely list it beside its siblings** — so grep the
stage's *siblings*, not just its own name.

**A recommendation was withdrawn mid-grilling and the replacement is better, which is the
second time the driver's pushback changed an answer this month.** #12 recommended a ticket
**count** as the scope brake — over ~10, go back. The driver asked why the count would vary
at all, and it does not: the count *is* the number of things the app can do, pinned by the
smallest-version sentence. Twenty tickets means **the sentence grew during charting**, which
has one cause and one fix. So the brake became a **trace** — every ticket points at the phrase
it came from, and anything pointing at nothing is flagged. **When a number varies for exactly
one reason, check the reason directly.**

**All three stage pairs are now fully wired.** Charting — #11 the skill, #22 the doc. The
kill gate — #25 the doc, #26 the skill and the judge. The bootstrap — #34 the doc, #35 the
skill. Two of the three were doc-first and both shipped a *still being written* marker for
exactly one commit, deleted by the template ticket. **Charting remains the only pair built
template-first, and the only one that never shipped a dead link** — three pairs in, the
evidence for template-first is now three for three.

**Two tickets running, two grillings the driver redirected — and both redirects were
right.** #21's was the bigger one: pushing back on Serena as a universal requirement
changed the answer and spun #31. #31's came on the last question, where the recommendation
was *leave the destination phrase alone, the seam three screens down carries the nuance* —
and the answer was **check again**. Checking found the `/pitch` template. **The questions a
ticket body lists are not the only ones on the table, and a recommendation is not a
finding.**

**The reason all four copies of the phrase move together is now a standing rule — and #33
made it eight copies.** Leaving the human-facing headline and fixing only the ones an agent
touches was the tempting call. It is wrong because **every doc here is model input**: two
files that disagree do not read as headline-then-nuance to an agent loading both, they read
as a contradiction whose winner is arbitrary. In a repo whose entire output is context, an
unresolved contradiction between two files is a **defect, not a matter of style**. The
corollary #33 added: **half-landing a fix of this shape leaves master worse than before**,
which is why it was one ticket and one commit.

**The off-map pull produced its best result yet on the way in.** A two-minute probe of
`pitch-judge` — the thing #29 was parked holding — **failed**, which is #32. The map is the
destination, *and* ten minutes of running something is worth more than a session of reading
it. Do the probe, then take the map ticket.

**Templates now carry four solo-only entries** — the `charting`, `pitch` and `bootstrap`
skills, and the `pitch-judge` agent. The solo/team columns #2 added are doing real work
rather than sitting all-✓. **`bootstrap` is also the first template to set
`disable-model-invocation: true`**, which is the skills README's stated rule finally meeting
a skill with side effects rather than a conversation.

---

## The path #3 settled

```
   THE KILL GATE  ──►  CHARTING  ──►  THE BOOTSTRAP  ──►  CUTTING  ──►  /start-ticket
   is this worth      what are we      make the repo      cut it into    (the existing
   building?          building, and    real               pipeline-      pipeline takes
        │             on what?              ▲             sized tickets      over here)
        │                  │                │                  │
   verdict:          ends CLEARED      scaffolds,         ordered +          ▲
   build/kill/park   or ABANDONED      never creates      you approve        │
        │                  │                                                │
   on "build" the     the TAIL, last:                                   THE SEAM
   agent creates a    1. name the stack + the LAYER CHAIN            (8 checks below)
   PRIVATE repo,      2. write the bootstrap checks
   map = issue #1     not takeable while anything else is open

            ◄──── one backwards step allowed ────
```

**Stage 4 is *cutting* since #12** — the stage renamed, the artifact still called *the
backlog*, the command `/cut-backlog`. The four stage names and the four checks below are
unchanged otherwise; **seam item 6 still reads *the backlog exists***, because it names the
artifact.

**The seam — all eight must hold:**

1. The stack is named and written down.
2. The stub builds and runs. *(A green test command is optional — the stack ticket decides.)*
3. The layer chain is declared in `CLAUDE.md`. *(#10 — **stage 2 picks it**, with the stack;
   stage 3 only writes it down.)*
4. Serena matches the verdict recorded at the tail. *(#31 — **yes**: a symbol search
   returns real results; **no**: Serena is not required here and `CLAUDE.md` says why.
   **On master since #33**, which also renamed the check to "Serena matches the verdict".)*
5. The tracker adapter is installed.
6. The backlog exists, ordered, and you approved it.
7. Two memories exist: what the project is and why; **why** the stack and layer chain — not
   the facts themselves, which live in `CLAUDE.md` and are never copied (#10).
8. **The layer specialists exist.** *(#10 — new. `/start-ticket` step 4 dispatches to them,
   and nothing on the seam said the agent files were on disk.)*

**All eight are on master** — [#34](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/34)
added row 8 and retired the count *seven* from all four sites, so
[`docs/solo/01-the-solo-path.md`](docs/solo/01-the-solo-path.md) and
[`docs/solo/03-charting.md`](docs/solo/03-charting.md) are safe to quote as current.

Written down in full in
[`docs/solo/01-the-solo-path.md`](docs/solo/01-the-solo-path.md) — the only place both
entrances are visible at once.

---

## Decisions locked

| Ticket | Decision |
|---|---|
| [#6 What Claude Code already does natively](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/6) | Lean on the harness for `/init`, plan mode, the task list, background sessions, worktrees, `/goal`. The playbook must supply its own durable map artifact, its own backlog, and every judgement stage of the front-end. `/effort ultracode` is the *worst* default for a solo builder. |
| [#2 Where the solo path lives](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/2) | `docs/` splits three ways (below). Templates stay flat with a path column in their READMEs. Moved docs keep their `2.1.219` footer. |
| [#19 Reorg docs into shared/ team/ solo/](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/19) | **Done — the layout below now exists.** 14 docs moved as git renames, 54 relative links resolve and 0 dead. |
| [#7 Tracker primitives](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/7) | **The floor is narrower than charting assumed.** Native blocking is not universal; the claim **cannot be a mutex**; nothing has optimistic concurrency, so the map body should be regenerable. Handed four judgement calls to #4. |
| [#3 The stages and the seam](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/3) | **Four stages: kill gate → charting → bootstrap → backlog.** The repo is the gate's output, so bootstrap *scaffolds* and never *creates*. Bootstrap runs **before** the backlog. Stack choice is a **ticket on the map**, in a two-ticket tail not takeable while anything else is open. Charting can end in **abandon**. One backwards step allowed. Seam = the checks above — **seven as #3 wrote it, eight since #10.** |
| [#4 The tracker-adapter contract](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/4) | **A skill never names a tracker.** Ten decisions — see the table below. |
| [#20 Write the solo path overview doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/20) | **Done — `docs/solo/01-the-solo-path.md` is on master.** An index, not a summary. **Sets the `docs/solo/` numbering** (below). |
| [#5 The charting skill's contract](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/5) | **The skill is `charting`, and it is general.** Eight decisions — see the section below. |
| [#11 Write the charting skill template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/11) | **Done — `templates/skills/charting/SKILL.md` is written.** All eight of #5's decisions carried; nothing reopened. Three `<PLACEHOLDER>`s, two of which are waiting on other tickets. |
| [#22 Write the charting stage doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/22) | **Done — `docs/solo/03-charting.md` is written.** States the solo destination and the trap beside it (that is where the *path* ends, not where *charting* ends). Authored two things nothing had settled: the **cleared-vs-abandoned test**, and that **charting cannot reopen the kill gate**. Found a wrinkle in #3's tail — see below. |
| [#13 Tracker adapter templates + the Jira retrofit](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/13) | **Done — `templates/trackers/` exists and the playbook no longer assumes Atlassian.** The fixed path is **`~/.claude/tracker.md`**. The MCP key becomes **`tracker`, not `jira`** — a breaking change for an existing install. §5 becomes the audience rule. Setup gained **step 5**. README deliberately excluded — see below. |
| [#9 The kill gate](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/9) | **The gate is `/pitch` — a skill plus a doc.** Six questions, ~1 hour, three hard kills whose teeth depend on a **question zero** that classifies what the idea's value rests on. Sycophancy beaten structurally, not by instructing harshness. A fourth agent, **`pitch-judge`**, reads an **anonymised case file** and can fire a hard kill but never un-fire one. See the section below. |
| [#25 Write the kill gate stage doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/25) | **Done — `docs/solo/02-the-kill-gate.md` is written.** A make that decided nothing; every claim traces to #9. The `12-when-not-to-use.md` cross-reference is **live in both directions**, and the **spike clash is named as a hole and then closed** rather than left to be found. |
| [#26 Write the `/pitch` skill + `pitch-judge` agent](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/26) | **Done — `templates/skills/pitch/SKILL.md` and `templates/agents/pitch-judge.md` are written**, with the flow catalogue entry and both README rows. A make that decided nothing. Made explicit three mechanics #9 only implied: the **case file rides in the dispatch prompt** (no tools means no `Read`), the hard kills need an **arming table transposed by class**, and verdict resolution needs an **explicit precedence order**. |
| [#27 `pitch-judge` cannot have zero tools](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/27) | **`tools: TodoWrite` plus `maxTurns: 1`.** Zero tools is impossible **by design** — the harness refuses to spawn an agent that would hold none — so `tools: []` never launches. Two guarantees on different axes: the allowlist means it holds nothing that finds, the single turn means it cannot act on a result. The agents README gains a **least privilege has a floor** convention and a **complete sixteen-field anatomy block**. **"No tools" is retired as vocabulary** in favour of **"gathers no evidence"**. Decided only; **#28 applied it**. **Its mechanism has since been proven wrong by running it — see [#32](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/32).** |
| [#21 How the tech stack actually gets chosen](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/21) | **Propose-and-kill against a mainstream default, judged at read-level.** Claude writes the code, so the human's bar is *can you tell when it is wrong*, not *could you have written it*. Default: **the most boring stack that does the job** — an already-read boring option ends the session. **Never compare**; name one candidate and try to kill it on three checks. Constraints reach the tail by **re-reading the closed gists**, not push-forward. **Serena becomes a conditional kill check** on *"will you ever need to ask who calls this?"* — which spun #31 and blocked #10. #3's tail ambiguity settled on the first reading: **ticket 1 decides the stack and whether tests gate; ticket 2 writes the commands.** The stack ticket **writes no files**, and **#15 needs no new artifact**. *Corrected by #15: it reads `CLAUDE.md` and **nothing else** — not memory two, which #10 had already stripped down to the *why*. A second input is a second place the stack is stated.* |
| [#31 Serena is conditional: what happens to seam item 4?](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/31) | **Item 4 becomes two branches — decided at the tail, recorded in the repo's `CLAUDE.md`, looked up at the seam.** A conditional *check* is weak; a conditional *answer* is not. **Seam item 2 already worked this way**, so the seam was never seven flat checks. `CLAUDE.md` over memory two because **only `CLAUDE.md` can contradict `CLAUDE.md`** — that is where the *Serena is MANDATORY* block lives. **The destination string drops the word *Serena* in all four places**, because the kill gate writes it a full stage before the stack exists. `12-when-not-to-use.md:68` is **correct in its own context** and gains one clause for the third case nobody had written down: **symbol-poor by nature**. Spawned #33. |
| [#33 Retire the flat Serena gate from every file that states it](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/33) | **Done — no file on master states a flat Serena gate.** A make that decided nothing. The destination string is **"a backlog of work units on a scaffolded repo that passes the seam"**, identical in all four places; seam item 4 is renamed **Serena matches the verdict** and reads as two branches looked up in `CLAUDE.md`; `12-when-not-to-use.md` gained one clause for **symbol-poor by nature**. **Eight edits, not six** — a re-grep on the word *Serena* found two more sites in `03-charting.md`. One asymmetry is deliberate: `pitch/SKILL.md` names the seam without linking to it, because an installed skill has no `docs/` beside it. **Unblocks #16** by one edge. |
| [#10 The bootstrap](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/10) | **Stage 3 is a seven-step checklist Claude runs alone inside the repo folder, ending in one pass/fail report — and it generates the layer specialists, which makes the seam eight checks.** #15 owns *how* the specialists are written, stage 3 owns *when*, the seam owns *whether*. **The layer chain is named in stage 2**, settling what #21 refused. The stub is **generator output plus one empty folder per layer**. **The repo folder is the line** — inside it Claude works alone, outside it you see first — stated as **blast radius, not audience**. **Memory two holds only the *why***, never the facts. The exit test **runs every check, reports once, stops, and classifies nothing**. Spawned #34 and #35. |
| [#12 Cleared map to backlog of work units](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/12) | **Stage 4 is *cutting*, the command is `/cut-backlog`, and units are cut from the *smallest version* — not from the decisions.** Decisions are **constraints on every unit, not units**; the gate's Q3 named the scope a full stage earlier, which makes its first hard kill a **precondition three stages downstream**. **One ticket = one thing the app can now do, all the way through**; plumbing rides inside the first unit that needs it. **`12-when-not-to-use.md`'s bar is not reused** — on a day-one repo it cannot return *no*. **Dependencies are real, and the ticket body is the single truth**; native links and an HTML view are generated from it. **A board on screen, nothing created until you approve.** Scope is checked by a **trace to the smallest-version phrase, not a count**. Constraints are **copied into each ticket** (the analyzer reads nothing else) with a bottom **`Where this came from`** section that makes the copy falsifiable. Work tickets are **standalone, not children of the map**. Spawned #36, #37, #38. |
| [#37 Write the cutting stage doc and rename the stage](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/37) | **Done — `docs/solo/05-cutting.md` is written and the stage rename is landed.** A make that decided nothing; every claim traces to #12. **`docs/solo/` is 6 of 6 and all four stage docs exist end to end.** The rename was **ten sites, not four** — the six #12 missed all name the stage **in passing, in a list of its siblings**, which a grep for the stage's own name never reaches. Also retired `01`'s *"the four stage docs are still being written"* note and corrected `04:252`'s *"the eighth"* to **item 6**. Ships one dead link to `templates/skills/cut-backlog/SKILL.md` with a marker for **#38** to delete, and adds the `/cut-backlog` flow catalogue row. **Unblocks #38 by one edge.** |
| [#36 The dependency viewer](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/36) | **A shipped HTML page with a data slot, generated on demand into `.claude/`, serving the map and the backlog both.** The adapter fetches, the page draws. Four box states with **frontier** the one it exists to surface; **closed tickets stay** or the arrows explain nothing. **A click opens the body plus every comment**, because on a closed ticket the answer is in a comment. **One command regenerates and opens**, never on ticket-close. `PROGRESS.md` stays alongside it, split by **who reads it**. Its own premise — *nothing here ships code* — was **false**, and the map's Notes are corrected. Spawned #39 and #40. |
| [#39 The tracker contract: read must include comments, and a whole-graph verb](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/39) | **Done — both changes landed in all five tracker files.** `read` is **defined** to include the ticket's comments (a definition, not a thirteenth verb); *the whole graph* is the second composed verb, earning it on the frontier's own test. **Twelve small verbs and two composed.** Eight files, not five. **Its GitHub commands were corrected the next day by #40** — see that row. |
| [#40 Write the dependency viewer template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/40) | **Done — `templates/views/dependency-graph.html` and its README are written, generated against this map and opened in a browser.** A make; every design decision traces to #36. The directory is **`views/`** — named for what it is to the reader, because the harness turns it into nothing — and `templates/README.md` gains an **exemption** from *every file here is a claim about the harness*. **`issue_dependencies_summary` is four integers**, so #39's two-call whole graph draws **no arrows**; GitHub's is now **one GraphQL call** returning children, states, claims, bodies, comments and edges, reshaped by `--jq` into the data slot in the same call. The contract gains **an adapter answers *by what?*, never just *how many?*** Verified live: 480 KB, 35 boxes, four states told apart by **outline rather than colour**. **No flow catalogue row and no new skill** — the picture has no command; two flows generate it. **Unblocks #38.** |
| [#38 Write the `/cut-backlog` skill template](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/38) | **Done — `templates/skills/cut-backlog/SKILL.md` is written, the skills README carries its entry, and the marker in `05-cutting.md` is deleted. All four solo stages now ship a doc *and* a template.** A make that decided nothing; every rule traces to #12 plus #40's step-7 block. **The ticket's own step 7 contradicted its own bullet** — *"native edges where the tracker has them, the viewer where it does not"* is a branch on tracker capability, which #4 forbids — so step 7 is unconditional: *mark blocked* per body line **and** generate the picture, always. **One mechanical point nobody had stated: create in dependency order**, because the board shows positions, ids do not exist until step 6, and the body line is the truth — so step 3's ordering is load-bearing. Second template to set `disable-model-invocation: true`. **The re-grep found one site, in the paired stage doc**: `05-cutting.md:8`'s *"the eighth item"*, where the rest of the file says **item 6** — see the gotcha. No flow catalogue row was owed; unblocks nothing. **Spawned [#41](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/41)** — *the whole graph* is parent-scoped and #12 made work units standalone, which #39 predicted in writing; step 7 asks over **the ids in hand**, true under every answer, and the contract question goes to #41. |
| [#30 Write the stack-choice doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/30) | **Done — `docs/solo/06-choosing-the-stack.md` is written.** A make that decided nothing; every claim traces to #21 plus #10's layer-chain settlement. Took **`06`** at write time, so `05` stayed reserved — #12 has since named it `05-cutting.md` and handed it to #37. Carries read-level over write-level, mainstream-first, propose-and-kill as a table on *exit condition*, the three kill checks as an ASCII loop, Serena's *who calls this?* test with **verdict-*no* stated as a pass rather than a gap**, re-read-at-the-tail with its cost recorded, and the `go test ./...` exits 0 / `pytest` exits 5 table. **All three link fixes landed** — `03-charting.md`'s tail section plus the two `04-the-bootstrap.md` sites #34 left as *being written*. **Corrected a stale count inside #21's own resolution comment** (five stack-independent seam checks → six, since #10 grew the seam) — see below. |
| [#42 Write the solo guardrails doc](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/42) | **Done — `docs/solo/07-guardrails-when-solo.md` is written.** A make that decided nothing; every claim traces to #14. §5's rule of thumb is **two tests** and solo deletes exactly one; three guardrails hold with the reason rewritten, **§6 is replaced not modified**, and the AI-infra path list becomes the **fresh-clone test**. The allowlist sits **outside every repo** so the agent cannot write it. Cost and review are **habits, explicitly labelled**. **The ticket's own body had expired** — #15 amended *"exactly one file flips"* and the *`.claude/` is not product* answer, so the doc states **three path classes flip** and that the question is **per file, not per directory**. **Found: the hook flip alone does not make a file committable** — three files still write a **blanket** `.claude/` `.gitignore` line, and the fix is exceptions, not deletion. Fixed two unowned falsified claims in `04-the-bootstrap.md` and handed **four extra sites** to #43. |
| [#43 Rewire the guardrails for solo](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/43) | **Done — the allowlist, the two-way `.claude/` sort, `block-secret-staging.sh` and the bootstrap's eighth step are on disk; `test-hooks.sh` is 66 green cases.** A make that decided nothing. The allowlist lookup is **duplicated verbatim in both hooks** because a shared helper you can forget to copy turns a guardrail into one that silently stops guarding. The new step goes **first** and is the only one in the stage not placed by a dependency. **`jq` is missing on this machine, so all four hooks currently fail open** — documented here, decided in [#46](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/46). **`.gitignore`'s `*secret*` hid the new hook from `git add`** in this very commit — the same failure, one directory over. |

### The layout #2 decided — now live

```
docs/
├── shared/          ← the trunk BOTH entrances converge on   (01–12)
├── team/            ← the agile front-end                    (01 metrics, 02 adoption)
└── solo/            ← the solo front-end (01–06 written; 07+ free)
```

Numbering restarts at `01` per directory.

### The `docs/solo/` numbering #20 set

| Number | Doc | Owner |
|---|---|---|
| `01-the-solo-path.md` | the overview — **written** | #20 |
| `02-the-kill-gate.md` | the kill gate — **written** | #25 |
| `03-charting.md` | charting — **written** | #22 |
| `04-the-bootstrap.md` | the bootstrap — **written** (designed by #10) | #34 |
| `05-cutting.md` | cutting — **written**. Renamed from `05-the-backlog.md` by #12, which found the stage and its artifact sharing a name (designed by #12) | #37 |
| `06-choosing-the-stack.md` | the stack-choice method — **written**, the first non-stage solo doc | #30 |
| `07-guardrails-when-solo.md` | which guardrails hold when you are solo — **written** (designed by #14) | #42 |
| `08+` | everything else solo — progress, resuming | in the order they are written |

The stage block is reserved in **stage order**, so a stage doc never collides with a
non-stage one.

### The tracker contract, in ten lines

| | Decided |
|---|---|
| Adapters shipping | Jira, GitHub, local markdown. **GitLab is a *shape*, not an adapter.** |
| The floor | **Every verb works on every adapter.** Where a tracker lacks it natively, the adapter fakes it and the skill is never told. |
| Vocabulary | **Twelve small verbs and two composed** — the frontier, and *the whole graph* (#39, on the frontier's own earning test). **`read` is defined to include the ticket's comments**, not made a thirteenth verb. |
| Blocking | The predicate *"can I start this right now?"* — **not** a native edge. |
| Claim | **Advisory, not a mutex.** Local declares itself single-session. |
| Map body | **A generated view, not a store.** Rebuild from the closed children. |
| Local ticket files | **Committed** — and the folder is renamed away from `.scratch/`. |
| Read-only rule | Restated as **"ask before writing anywhere other people can see it"** — audience, not tracker. |
| Adapter location | `templates/trackers/`, flat. **Exactly one installed at a fixed path** — #13 set it to **`~/.claude/tracker.md`**. |
| Identity | **A stable id; titles are decoration.** Retitling must never break a link. |

---

## The charting contract #5 settled

The skill is called **`charting`** — `/charting`, a sibling of `/grilling`. Not `wayfinder`
(collides with the driver's global skill). It matches the word already on master in
`01-the-solo-path.md`, and preserves the rule that **the stage is charting, the artifact is
the map, and they never share a name.**

| # | Decision | The reason that settled it |
|---|---|---|
| 1 | **General, not solo-specific.** The destination is an **input**. | This map is a *docs* effort. A skill with `backlog + scaffolded + indexed` baked in could not have run the playbook's own map. The solo path supplies the destination from outside, in `03-charting.md`. |
| 2 | **Named `charting`.** | Matches master; rhymes with `/grilling`; keeps stage and artifact distinct. |
| 3 | **Decide-or-make — one or the other, never both.** | This map's own escape valve fired twice (#3→#20, #20→#22). Deciding ends when humans agree; making ends when the file lands. Mixed, the unpredictable half eats the context. |
| 4 | **Points at skills, never absorbs them.** No `/domain-modeling` reference. | Context-window-first. And `CONTEXT.md`/ADR storage would be a **third** home for durable knowledge alongside memory and the layer chain. A two-line vocabulary rule covers charting instead. |
| 5 | **Memory: one per map, not one per ticket.** | `PHILOSOPHY.md` §3 is right about the shape, wrong about the unit. In charting the unit of work is the *whole map*. This makes seam item 7's *exactly two* arithmetic work with no special-casing. |
| 6 | **Serena, with the greenfield exception adjacent.** | An empty index on a day-one repo is **correct**, not broken. Without the exception, an agent burns a third of its context globbing an empty tree to prove Serena is down. |
| 7 | **Only Decisions-so-far is generated.** | The map's four sections behave differently; only one is derivable. Authored sections are protected by *re-read immediately before writing*, not by a lock no tracker can honour. |
| 8 | **Mid-ticket death: post a progress comment, keep the claim.** | Charting is the only thing that knows the session is ending, and handoff files auto-delete. Everything after the map closes belongs to #8. |

**The most load-bearing line in the whole contract:**

> **Every resolution comment opens with a one-line gist.**

Without it, #4's *"rebuild Decisions-so-far from the closed children"* means re-reading twenty
long comments and re-summarising each — expensive *and* non-deterministic. With it,
regeneration is a concatenation of first lines: free, and identical every run.

**Four ticket types, three of which name a skill.** A type is a *session shape*, not a pointer
to a skill: `research` → `/research`, `grilling` → `/grilling`, `prototype` → `/prototype`
(**shipped by #23**; the reframe was what let four types survive when only two had templates,
and now three do), `task` → needs none by design.

---

## The frontier — takeable right now

Five tickets, recomputed from the graph this session. **Six → five, and it fell for the
first time in three sessions.** The two before it held flat by cancellation — a closure and
an arrival in the same session, twice — and this one did not, because a make that decides
nothing has nothing to spawn. **The number finally moved for the reason it appears to have
moved**, which is worth noting only because twice running it had not.

**Five grillings and no makes**, the shape last session broke and this one restored. **Two
tickets are still about the playbook's own machinery being wrong** rather than about what to
write — #46 and #49 — and they are half the frontier.

| Ticket | Type | Note |
|---|---|---|
| [#49 `/bootstrap` cannot invoke `/adapt-to-stack`](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/49) | grilling | **New this session, and it blocks #47.** `disable-model-invocation: true` does not merely stop autoloading — the docs say it *"blocks programmatic invocation"* and *"removes the skill from Claude's context entirely"*. `/bootstrap` step 5 tells the **agent** to run `/adapt-to-stack`, which sets the field. **Neither file is wrong on its own terms**, which is why it is a decision: drop the field and lose the guard on a skill that writes agent files into a repo, or break the one unattended flow with a manual step. A third shape may exist. |
| [#46 The blocking hooks fail open when jq is missing](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/46) | grilling | **Verified live: all four hooks are off on this machine.** No `jq` on `PATH` → the script dies at the parse and exits **127**, which is a *non-blocking* error, so the tool call proceeds. Documentation landed with #43; the decision left is whether **not running** is an acceptable state for a guardrail — fail-closed blocks the `git` commands you need to fix it, and dropping `jq` means hand-rolling a JSON parse in a security-relevant script. |
| [#41 The whole graph has no parent to scope by on the backlog side](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/41) | grilling | **#39 predicted this one in writing and #38 hit it.** *The whole graph* is defined over the **children of a parent**; #12 made work units **standalone on purpose**; #36 said one page serves the map and the backlog both. Three right decisions, jointly incomplete. `/cut-backlog` ships the instruction that survives every answer — ask over **the ids in hand** — so nothing is blocked, but the contract does not say it. **The question that separates the alternatives is what regenerates the picture six weeks later**, when nobody holds the ids. |
| [#8 Resuming an effort across dozens of sessions](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/8) | grilling | **must check #5's §8 boundary first.** **#18 handed it the progress file** — #13's comment had given *what goes in it* to #18, but #8's own body and the map's fog both claim it, and #18 stood down. It also inherits one requirement: if mid-session death in the *implementation* pipeline posts a progress comment the way #5 made charting do, then **sessions per work unit = progress comments + 1**, and #18's headline metric collects itself. |
| [#24 The playbook's own domain-modeling skill](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/24) | grilling | side quest, blocks nothing. **The last of the two tickets #5 spun out as side quests** — #23 was the other, and it closed this session |

## Blocked

| Ticket | Waiting on |
|---|---|
| [#47 A worked walkthrough of the solo path, end to end](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/47) | **#49 alone.** #50 came off this session and **nothing replaced it** — the tree now says two layers, so the walkthrough can show which `CLAUDE.md` files exist at each stage. **#49** because the walkthrough narrates `/bootstrap` calling `/adapt-to-stack`, and that call cannot execute as written. |

**#50 is closed and #47 finally moved.** The #48 → #50 handoff is what this looks like
completed: a grilling that blocks something hands its edge to its own make, the make lands,
and **only then** does the count fall. Two sessions of an identical blocked table were the
decide-or-make rule being honest, not a stall — and the third session is the payoff. **#47 is
now one ticket from takeable**, and #49 is on the frontier right now.

**#45 is closed** — the row it used to occupy on the frontier is gone, and what it handed
forward is below.

**#23 is closed too**, and it left this table heavier rather than lighter. **A make is
supposed to unblock things and this one blocked one** — which is the decide-or-make rule
working, not failing: it found a real decision and stopped rather than settling it in passing.

**#16 is off this table too, and it has landed.** It waited on 19 tickets over the life of
the map; #18 was the last. What it *inherited* is kept below rather than lost with the row —
**it is now a record of what was handed over, not of what is outstanding**, and #16's own
resolution comment is the authority on which of these it acted on and how:

| Handed to #16 by | What it must carry |
|---|---|
| **#18** | `PHILOSOPHY.md:129–134` — §8 rewritten, replacement text written out in a comment, because §8 mandates measurement (*"**every** pipeline run is costed"*) while `docs/team/01-metrics.md:7` calls it optional. Plus a **recommendation to leave** `:142`, and `README.md:81`'s stale `11-metrics.md` path. |
| **#43** | Four sites with exact text: `PHILOSOPHY.md:88` and `:90`, `README.md:134`, and one nobody had listed — `templates/trackers/local-markdown.md:28`, which **quotes** §5's path list, so it is right today and wrong the moment §5 is edited. |
| **#33** | The phrase the front door must use: *a backlog of work units on a scaffolded repo that passes the seam*, not *"Serena-indexed repo"*. |
| **#13** | The README is the last file in the repo still claiming Jira is assumed. |
| **#26** | **Four** templates claim the solo column only (`charting`, `pitch`, `bootstrap`, `cut-backlog` — one per stage), and **two** set `disable-model-invocation`. **Recount before writing.** |
| **#12 / #38** | Stage 4 is **cutting**, not *the backlog* — and every solo stage now has both a doc and a template for the front door to point at. |

**Two retired claims, kept as a warning about this section.** A previous snapshot said the
capstone's remaining edges were *all conversations* and that *every make on this map is now
landed*. Both were true when written and both expired within two sessions. **A sentence
asserting that a set is complete is a sentence with a short shelf life on a map that spawns
tickets** — the same shape #37 found in `01`'s *"the four stage docs are still being
written"*. The row above says *the whole list* and inherits exactly that risk: it is true at
this snapshot and false the moment any open ticket spawns anything.

**And it fired.** #23 was a make — the category least expected to spawn — and it opened #49
and wired it onto #47. **The sentence naming which tickets could invalidate it was itself the
stale part**: it said *"the moment #44 or #16 spawns anything"*, and both had been closed for
sessions by the time the risk actually landed from a third direction. So the warning is
sharper without the names: **any open ticket can do it, and the make you were not watching is
as likely as the grilling you were.**

```
   DONE ── #3 stages+seam · #4 tracker contract · #5 charting contract
        ── #6 native capabilities · #7 tracker primitives
        ── #19 the reorg · #20 the solo path overview
        ── #11 the charting skill template  ┐ the charting pair —
        ── #22 the charting stage doc       ┘ skill FIRST, then the doc
        ── #13 the tracker adapters + retrofit  ── wires the pair to a real path
        ── #9  the kill gate design    ──► spun #25 (doc) + #26 (skill + judge)
        ── #25 the kill gate stage doc  ┐ the kill gate pair —
        ── #26 the /pitch skill + judge ┘ doc FIRST this time, template second
                    │
                    └──► spun #27 — the judge's `tools: []` is not a thing
                         the harness supports. A make catching itself.
        ── #27 tools: TodoWrite + maxTurns: 1 ──► applied by #28 (off-map), closed
                    │
                    └──► RUNNING IT proved the mechanism wrong ──► #32
                         TodoWrite is not a tool any more
        ── #21 the stack choice ──► spun #30 (the doc) + #31 (Serena is conditional)
                    │
                    └──► the non-code fork ruled OUT OF SCOPE — a fresh effort
        ── #31 seam item 4 is TWO BRANCHES, verdict recorded in CLAUDE.md
                    │      the gate that blocked #10 is open — #10 is takeable
                    │
                    └──► re-grep found 5 flat statements, not 2 ──► #33
                         the fifth was templates/skills/pitch/SKILL.md:273 —
                         an AGENT writing "Serena-indexed" into a reader's map
                              │
                              └──► BLOCKED #16 — now resolved
        ── #33 the flat gate is GONE from master — 8 edits, ONE commit
                    │      a 2nd re-grep found 2 more in 03-charting.md:
                    │      "the Serena index check", written unconditionally
                    │      by the very ticket that records the verdict
                    │
                    └──► #16 down to 5 edges, and it has its phrase now
                         ...but it MISSED THIS FILE. PROGRESS.md:38 kept
                         "Serena-indexed" for a whole session. Grepped
                         docs/ templates/ README PHILOSOPHY — not the repo.
        ── #10 the bootstrap ──► spun #34 (doc + seam check 8) + #35 (skill)
                    │
                    ├──► THE SEAM IS 8, NOT 7. /start-ticket dispatches to
                    │    layer specialists and nothing said they exist.
                    │    Seven checks green, pipeline with nothing to run.
                    │
                    └──► #16 UP to 6 edges — first increase of the effort
        ── #34 docs/solo/04 + seam row 8   ┐ the bootstrap pair —
        ── #35 templates/skills/bootstrap/ ┘ doc FIRST, template second
                    │      the count SEVEN is gone from all four sites;
                    │      a wider re-grep found no fifth — the first time
                    │      in five tickets. #10 had already widened the list.
                    │
                    ├──► #35 CORRECTED #34: the exit report is SEVEN checks.
                    │    Item 6 is the backlog — stage 4's, not stage 3's.
                    │    The seam went 7 → 8 inside #34, so every "seven"
                    │    read as stale. One was counting a different set.
                    │
                    ├──► first template to set disable-model-invocation,
                    │    applying the skills README's own rule
                    │
                    └──► #16 DOWN to 4 edges. All three stage pairs wired.
        ── #30 docs/solo/06 the stack-choice method — #21's make, landed
                    │      took 06 AT WRITE TIME, so 05 stays reserved for
                    │      a doc nobody has written. All 3 link fixes done.
                    │
                    └──► corrected a STALE COUNT INSIDE #21's OWN comment:
                         "the other five seam checks" — true at 7, wrong at 8.
                         No grep of master reaches a closed ticket comment,
                         and that is where this map keeps its decisions.
                         Second clean re-grep of master in three tickets.
        ── #12 STAGE 4 IS "CUTTING" — /cut-backlog. Units come from the
                    │      SMALLEST VERSION (named at the gate, stage 1),
                    │      not from the decisions. Decisions are CONSTRAINTS.
                    │      ──► spun #36 (viewer) + #37 (doc) + #38 (template)
                    │          #36 AND #37 both block #38
                    │
                    ├──► the stage and its artifact SHARED A NAME, breaking
                    │    #5's rule inside 01-the-solo-path.md:27, which is
                    │    where the rule is stated. Three rows apart.
                    │
                    ├──► the count brake was RECOMMENDED, then WITHDRAWN.
                    │    The driver asked why the count would vary; it does
                    │    not. Replaced by a TRACE to the smallest-version
                    │    phrase. Second driver redirect that changed an answer.
                    │
                    └──► #16 STILL 3 edges — now #43, #42, #18
        ── #37 docs/solo/05 CUTTING — #12's make, landed. The four stage
                    │      docs now exist END TO END. docs/solo/ is 6 of 6.
                    │
                    ├──► the rename was TEN sites, not the four #12 listed.
                    │    The six it missed all NAME THE STAGE IN PASSING,
                    │    in a list of its siblings — "the bootstrap or the
                    │    backlog". A rename grep finds the sentences ABOUT
                    │    the thing and misses the ones that WALK PAST it.
                    │
                    ├──► also retired: 01's "the four stage docs are still
                    │    being written", false the moment 05 landed; and
                    │    04:252's "stage 4 makes the EIGHTH" — it is item 6.
                    │
                    └──► #38 DOWN to 1 edge — #36 the viewer is all that is left
        ── #40 templates/views/ THE DEPENDENCY PICTURE — #36's make, landed.
                    │      Shipped page + data slot. Verified in a browser:
                    │      480 KB, 35 boxes, four states legible.
                    │
                    ├──► REST CANNOT DRAW THE GRAPH. sub_issues reports
                    │    blocker COUNTS, never ids — so #39's two-call whole
                    │    graph returns every box and NOT ONE ARROW. One
                    │    GraphQL call returns the lot. A cost check is not
                    │    a completeness check.
                    │
                    └──► #38 UNBLOCKED — the last stage pair is one session out
        ── #38 templates/skills/cut-backlog/ — #12's make, landed.
                    │      ALL FOUR STAGES NOW SHIP A DOC *AND* A TEMPLATE.
                    │      Every make on this map is done; what is left
                    │      is conversations.
                    │
                    ├──► STEP 7 OF THE TICKET CONTRADICTED THE TICKET.
                    │    "native edges where the tracker has them" is a
                    │    branch on tracker capability, four bullets above
                    │    "the tracker is never named". #4 forbids it.
                    │    Written unconditional. The false premise was
                    │    inside the TICKET this time, not the Notes.
                    │
                    ├──► create in DEPENDENCY ORDER — the board shows
                    │    positions, ids arrive at step 6, and the body
                    │    line is the truth. Any other order means filing
                    │    a dozen issues then editing a dozen bodies.
                    │
                    ├──► the re-grep found ONE site, in the doc #37 wrote:
                    │    05-cutting.md:8 "the eighth item" — it is item 6.
                    │    #37 FIXED THAT PHRASE IN 04 AND WROTE IT FRESH
                    │    IN 05 IN THE SAME SESSION.
                    │
                    └──► spun #41 — THE WHOLE GRAPH HAS NO PARENT on the
                         backlog side. #39 predicted it in writing. The
                         verb is child-of-a-parent, #12 made work units
                         standalone, #36 said one page serves both.
                         Step 7 asks over THE IDS IN HAND, which is true
                         under every answer. The contract still is not.

   #11 left three placeholders. NONE IS OPEN:
        <TRACKER-ADAPTER-PATH>       ──► RESOLVED by #13 = ~/.claude/tracker.md
        <PROTOTYPE-SKILL-OR-NONE>    ──► RESOLVED by #23 = /prototype
        <LABEL-PREFIX>               ──► never, reader's own convention

   #26 added one that is meant to stay open:
        <IDEAS-FILE-PATH>            ──► never, reader picks. Private + backed up.

   docs/solo/  01 ✓ spine   02 ✓ kill gate   03 ✓ charting   04 ✓ bootstrap
               05 ✓ cutting — renamed from "the backlog" by #12.
                  ALL FOUR STAGE DOCS NOW EXIST, END TO END.
               06 ✓ choosing the stack — first non-stage solo doc
               07 ✓ guardrails when solo — #42 (#14's doc)
               08+ NOBODY. #15 took no number (it reworks shared/11) and
                   #18 took no number ON PURPOSE — measuring is optional,
                   and an 08 devoted to it would say the opposite.
                   SIZE IS A CLAIM ABOUT IMPORTANCE.

        ── #18 HOW PROGRESS IS MEASURED — no doc, no make, no spawn.
                    │  Optional, units are the reader's. Unit = one SHIPPED
                    │  WORK UNIT. Two numbers, both free: sessions/unit and
                    │  the kill-gate ratio. NOTHING automates it.
                    │
                    ├──► the ticket CITED THE SOURCE THAT REFUTED IT.
                    │    /goal was called "durable, zero-effort"; #6's own
                    │    row says turn count and token baseline RESET on
                    │    resume. The four premise bugs before it had all
                    │    EXPIRED. This one was never true.
                    │    RE-READ THE SOURCE, NOT THE TICKET'S SUMMARY.
                    │
                    ├──► a session cannot be a denominator: it runs until
                    │    the context fills, so it costs the same every
                    │    time and CANNOT SHOW AN IMPROVEMENT. Inverts to
                    │    SESSIONS PER UNIT. A stage cannot either — it
                    │    runs once, and you can only measure what repeats.
                    │
                    ├──► §8 MANDATES and 01-metrics.md EXCUSES. A rule and
                    │    its own implementation, contradicting, both on
                    │    master the whole effort. §8 handed to #16.
                    │
                    └──► blocked_by LAGGED THE CLOSE by ~30s while GraphQL
                         showed every blocker shut. The frontier query is
                         built on that count. Now a trap-table row.

   6 open tickets ── 1 wired ────►  #47 waits on #49 ALONE. The list finally
                                    SHRANK — one blocked ticket, one edge,
                                    after two sessions frozen at two.
                  ── #50 LANDED AND NOTHING TOOK ITS EDGE. The #48 → #50
                     handoff completing: the grilling handed its edge to its
                     own make, the make wrote the tree, and only THEN did
                     the count fall. A make that decides nothing cannot
                     spawn, which is the one session shape that shrinks
                     both halves of the graph at once.
```

---

## Suggested session order

Wayfinder resolves **one ticket per session**, and tickets are sized to a fresh context window.

1. ~~#19 reorg · #7 tracker primitives · #3 stages and seam · #4 tracker contract ·
   #20 overview doc · #5 charting contract · #11 the charting template ·
   #22 the charting stage doc · #13 the adapters and the retrofit ·
   #9 the kill gate design · #25 the kill gate stage doc ·
   #26 the /pitch skill and the judge · #27 the judge's zero-tools defect~~ **Done.**
2. ~~#28, the template audit.~~ **Done, off-map.**
3. ~~#21, stack choice.~~ **Done.** Spun #30, #31 and an out-of-scope entry.
4. ~~Probe `pitch-judge`.~~ **Done, and it failed** — `TodoWrite` is not a tool any more, so
   the agent refuses to launch. Now [#32](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/32).
   **The restart caveat was wrong**: the agent registered the moment the file was copied, no
   restart needed. Two minutes of running beat three sessions of reading.
   **Narrowed by #45, and the two findings do not conflict.** That probe copied a file into a
   `~/.claude/agents/` that already existed, and an existing directory *is* watched — live,
   within seconds. What is **not** watched is a `.claude/agents/` or `.claude/skills/`
   **created during the session**, which needs a restart. So the unit the caveat applies to is
   the **directory, not the file** — and `/adapt-to-stack`'s first run creates both.
5. ~~#31, Serena is conditional.~~ **Done.** Spun #33, and **unblocked #10**.
6. ~~#33, retire the flat Serena gate.~~ **Done.** Eight edits in one commit, `2fa7e27`.
   Spawned nothing.
7. ~~#10, the bootstrap.~~ **Done.** Seven decisions, spun #34 and #35, and the seam grew
   its eighth check. Also caught this file stating the destination phrase #33 retired.
8. ~~#34, the bootstrap stage doc.~~ **Done.** `docs/solo/04` written, seam row 8 added, the
   count *seven* retired from all four sites, two slots added to `repo.CLAUDE.md`. The wider
   re-grep found **no fifth site** — the first time in five tickets, because #10 had already
   widened the list before writing the body.
9. ~~#35, the `/bootstrap` skill template.~~ **Done.** The bootstrap pair is wired, the
   marker is deleted, and it is the first template to set `disable-model-invocation: true`.
   It also **corrected #34**: the exit report is seven checks, not eight.
10. ~~#30, the stack-choice doc.~~ **Done.** `docs/solo/06-choosing-the-stack.md` written at
    the next free number, all three link fixes landed, and a stale count corrected inside
    #21's own resolution comment. Spawned nothing.
11. ~~#12, cleared map to backlog.~~ **Done.** Stage 4 is **cutting**; units come from the
    smallest version, not the decisions. Spawned #36, #37 and #38. **It went doc-first, not
    template-first as recommended here** — the template is blocked by the viewer, and the
    decisions live in the doc, so the bootstrap's order was the only one available.
12. ~~#37, the cutting stage doc.~~ **Done.** `docs/solo/05-cutting.md` written, the stage
    rename landed, the flow catalogue row added. **The four stage docs now exist end to end
    and `docs/solo/` is 6 of 6.** Carrying #12's ten decisions inline worked again — nothing
    was re-litigated — but **the re-grep still found six sites the ticket's list missed**,
    breaking the two-clean-re-greps run. See the gotcha: they all name the stage *in passing*.
13. ~~#36, the dependency viewer.~~ **Done.** A shipped HTML page with a data slot,
    generated on demand into `.claude/`, serving the map and the backlog both. Decided only.
    Spawned #39 and #40, and **#40 took its place as the blocker on #38**.
14. ~~#39, the tracker contract fixes.~~ **Done.** `read` now means the ticket *and* its
    comments, and *the whole graph* is the second composed verb — landed in all five tracker
    files plus the charting template and this file. A make that decided nothing. **Eight
    files, not the five the ticket listed**; the extras are the two places that restate the
    vocabulary and one that used the new verb's name as plain English.
15. ~~#40, the viewer template.~~ **Done.** `templates/views/` exists, the page was generated
    against this map and opened in a browser, and the `.gitignore` line rides with the
    generate step. It **corrected #39 the day after it landed**: `sub_issues` reports blocker
    counts, so the two-call whole graph draws no arrows and GitHub's is one GraphQL call.
    Spawned nothing.
16. ~~#38, the `/cut-backlog` template.~~ **Done.** The last stage pair is wired, the marker
    is deleted, and it is the second template to set `disable-model-invocation: true`.
    **It corrected its own ticket**: step 7 asked for a branch on tracker capability, which
    #4 forbids, so the picture is generated unconditionally. **Spawned #41**, the
    whole-graph scoping gap #39 predicted. **The banked-decision makes are now exhausted** —
    from here every ticket on this map is a conversation, so plan for sessions that end when
    you and the agent agree rather than when a file lands.
17. ~~#14, the solo guardrails.~~ **Done.** Reversibility was the real invariant and audience
    was the context-dependent half; §6 replaced rather than modified; one allowlist in
    `~/.claude/` keyed by remote; a secrets hook added because loosening push removed the
    protection it was quietly providing. **Stage 3 commits, green-only.** Spawned #42 and #43.
18. ~~#15, stack → agents and skills.~~ **Done.** `/adapt-to-stack`, one path-agnostic skill,
    `CLAUDE.md` as its only input, generating into the repo's `.claude/agents/` and
    `.claude/skills/` where they are committed, never overwriting. **The two-entry-point
    split it was written to design did not survive its own second decision.** Spawned #44
    blocking #45, and **amended #43's hook instruction** — see the gotcha.
19. **Next, and the order now matters more than it did.** #42 first: it is the only ticket
    blocking two others (#43 and #16). Then #44, which unblocks #45 and closes the last dead
    forward link on the solo docs. **#18 is the last conversation gating the capstone** — and
    the previous snapshot's advice to *plan for sessions that end when you and the agent
    agree* is now half wrong: three of the seven frontier tickets are makes that end when a
    file lands.
20. #8 resume whenever you like, but **read #5's §8 first** — the boundary is already fixed
    and #8 must respect it. `03-charting.md` closes with a deliberate hook for its doc.
21. ~~#23 and~~ #24 are side quests. They block nothing and are on nobody's critical path.
    **Half wrong, and #23 is why.** It blocked nothing on the way in and **opened a ticket
    that blocks #47** on the way out. A side quest is a claim about what a ticket *depends*
    on; it says nothing about what the ticket will *find*.
22. **#32 is small and off-map.** Pick an inert tool that still exists, then **spawn the
    agent and watch it return a verdict** before closing. Correct-by-reading is what got us
    here. Latent — nothing is installed, so no running gate is skipping its judge today.
23. **#29 still waits, but its argument is now weaker.** It remains the biggest thing on the
    board and Phase 0 alone is a full sitting. But the claim that its payoff is *latent* just
    took a hit: ten minutes of running one template found a defect that two documentation
    audits missed. **The cheap half of #29 — copy a template in and spawn it — is worth
    stealing at the top of any session.** The expensive half can keep waiting.

24. ~~#18, how progress is measured.~~ **Done.** Measuring is optional and its units are the
    reader's; the unit is one shipped work unit; two numbers, both free to collect; nothing
    automates any of it. **Spawned nothing** and wrote no new doc — it landed as a section
    under *habits* in `07-guardrails-when-solo.md`, because **size is a claim about
    importance** and an eighth `docs/solo/` file would have contradicted the decision it was
    recording. **Unblocked #16.**

25. ~~#45, the `/adapt-to-stack` skill template.~~ **Done.** The template, the catalogue row
    and both README entries; #44's six sites landed and its marker deleted. **Spawned
    nothing.** Both of #15's live probes finally answered: omitting `model:` inherits, and a
    project-scoped `.claude/skills/` is loaded **but loses to a personal skill of the same
    name**. **#16 and #44 have no entries in this list** — neither session added one, and
    they are not being back-filled here; their findings are in their resolution comments and
    in the snapshot chain at the top of this file.

26. ~~#23, the prototype skill template.~~ **Done.** Single file, zero placeholders, plus the
    catalogue row, both README entries and four files the ticket did not name. **#11's last
    placeholder is closed** and the four ticket types now stand three-to-one rather than
    two-to-two. **Spawned #49 and wired it onto #47** — the first blocker this map has gained
    from a make. Its transferable finding is not about prototypes at all:
    **`disable-model-invocation` blocks the Skill tool**, so a skill anything else dispatches
    to cannot carry it.

27. ~~#48, does the solo path have a workspace `CLAUDE.md` layer at all.~~ **Done.** **Two
    layers, not three** — the workflow moves up to layer 1, the main branch down to layer 3,
    and `06` is reframed around repo count. Decided only; **spawned #50 and handed it the
    #47 edge**, so nothing was unblocked. Its transferable finding is not about `CLAUDE.md`:
    **a template can restate the false sentence of the doc that links to it**
    (`workspace.CLAUDE.md:6` and `06:77`), so fixing the doc alone leaves the reader's own
    copy asserting it.

28. ~~#50, land the two-layer `CLAUDE.md` reframe.~~ **Done.** Seventeen files; the tree now
    says two layers on one repo, three on siblings, and the layer *numbers* were kept as
    names rather than renumbered. **Unblocked #47's second edge** — the first fall in the
    blocked table in three sessions. Its transferable finding is not about `CLAUDE.md`:
    **checking a file is not checking a claim.** #48 read `11-adapting-to-your-stack.md`,
    found the passage it cared about correct, and wrote the file down as verified — while
    thirty lines below sat a sentence its own decision would falsify. An expected-correct
    list is a premise like any other.

Plain `/wayfinder 1` takes the first frontier ticket in map order — still
#8 *Resuming an effort that spans dozens of sessions*, which is **not** what I would take.
Name the ticket. **Take #49** — it is the only ticket on the frontier that unblocks anything,
it is the last edge on #47, and it is a defect on `master` today: `/bootstrap` step 5 tells
the agent to run a skill that `disable-model-invocation` makes unreachable. Neither file is
wrong alone, so it is a genuine decision and not a sweep.

**Then #47**, the worked walkthrough, which becomes takeable the moment #49 closes and is
the closest thing left to a capstone now that every stage ships both a doc and a template.
Then **#46**, the other live defect — the hooks are off on this machine today — and **#8**,
which owns this file and inherits a requirement from #18 that makes *sessions per work unit*
collect itself if hole 1 lands on progress comments. **#24 is the last side quest**; #23 was
the other.

**Rewritten this session, and the two rewrites before it are why it keeps needing saying.**
Two sessions ago this block was two sessions stale — it advised #16 and then #44, both long
closed. **Advice ages faster than facts**, and it sits below every table a session actually
recomputes, so nothing forces a reader past it. If you resolve a ticket, rewrite this block
even when nothing else about it changed.

---

## Gotchas found so far

- **Checking a file is not checking a claim, and an expected-correct list is a premise like any other.** #48 listed `docs/shared/11-adapting-to-your-stack.md` under *check before writing, expected correct*, having read `:82-83` and found it right — which it was, and always had been. Thirty lines below, `:195-196` said shape B's workspace file carries *"the cross-repo order **and the new-branch workflow"***, and the second half was **falsified by #48's own decision**. So the file was half-verified by a ticket that named it once, and the half that broke was the half the ticket had no reason to look at. **The failure mode is specific to landing tickets**: a decision ticket reads a file to answer *does this contradict me today?*, then writes it down as verified, and the make inherits that verdict as a fence. The map's Notes already carry *check a stated constraint against the tree before you let it rule anything out* — this is its other face. **A list of what to leave alone is a claim about the tree, made by someone who was reading it for a different reason.**
- **A fence around a decision is not a fence around the sites that disagree with it.** #50's body said *do not reopen where the layer chain lives — settled by #10, routed by #44*, which is correct and which nearly hid `templates/commands/start-ticket.md:25`: *dispatch the layer specialists in chain order (per the **workspace** CLAUDE.md)*. That is not reopening #10; it is a site still contradicting #10's settled answer, three tickets after the routing ticket fixed the docs. **The fence is what makes them hard to see**, because the reflex it trains is *don't look there* — and the sites that contradict a settled decision are, by definition, in the territory the fence encloses. **Read every hit inside a fenced area; skip only the ones that agree.**
- **A decision scoped to one path still lands in every doc that path shares.** #48 noted that `06-claude-md-layers.md` lives in `docs/shared/` precisely because a **one-repo team** has the workspace-layer question too — and then nothing told `docs/team/02-team-adoption.md:24`, which asserted the workspace file owns *the implementation chain, the branch workflow, which repos exist*. Two errors in one line, sixty lines above the two sites in the same file the ticket did check and pass. **The `shared/` directory is not a hint about who reads the decision, it is a statement about it**; a decision landing in a shared doc has to be chased into both entrances, and the team half is the one nobody is thinking about while writing the solo path.
- **A number used as a name for months has stopped being a count, and renaming it costs more than the ambiguity.** Once layer 2 became conditional, *layer 3* named a thing that could be second. Renumbering was the honest-looking fix and would have cascaded into every template header (`repo.CLAUDE.md` literally says *"This is LAYER 3"*), every doc cross-reference, and every closed ticket that ever said *layer 3* — including the resolution comment of the ticket that made it conditional. `06:50` now says the numbers **name the files, not a count**. **A stable identifier that has leaked into a durable record is no longer free to change**, whatever it originally described.
- **A template can carry the false sentence of the doc that links to it — so fixing the doc leaves the reader's own copy asserting it.** `06-claude-md-layers.md:77` told a single-repo reader the workspace layer *"is still useful"*; `templates/claude-md/workspace.CLAUDE.md:6` says *"If you have a single repo today, keep this file anyway with a one-row repo map."* Same claim, one file over, in the artifact the doc hands you — and **the reader ends up holding the copy, not the doc.** No grep of `06` reaches it and no link-check catches it, because both files are internally consistent and the link between them resolves. **When a doc explains a template, they are one claim in two files**; retire a sentence in either and grep the other for the *idea*. Fifth arrival of *grep the concept, not the wording*, and the first where the second copy was downstream of the first by design.
- **A grilling that blocks something does not unblock it by closing — it hands the edge to its own make.** #48 blocked #47; closing #48 moved #47 from *#48 and #49* to *#49 and #50*, an identical count. This is decide-or-make working, not a stall: a walkthrough cannot narrate a decision, only a tree that has been edited. **The blocked table can come out identical for a completely different reason two sessions running**, which is the one way it goes quietly stale — so recompute the *edges*, never just the count.
- **`disable-model-invocation: true` blocks the Skill tool, not just autoloading — so a skill anything else dispatches to cannot carry it.** The docs are explicit: it *"blocks programmatic invocation"* and *"removes the skill from Claude's context entirely."* The field reads like *don't fire unasked*, and that reading is what put it on `/adapt-to-stack` while `/bootstrap` step 5 tells the agent to **run** it. **Nothing errors at authoring time and nothing errors at reading time** — the two files are each correct alone, and the failure only exists in the call between them. Now #49. The rule underneath: **a guard on invocation is a claim about every caller, and skill bodies are callers.**
- **The repo uses angle brackets for three different things, and only one is a placeholder.** A *reader placeholder* is filled once at copy time (`<LABEL-PREFIX>`, `<IDEAS-FILE-PATH>`); a *generator slot* is filled per layer by `/adapt-to-stack` (`<layer>`, `<LANGUAGE>`); a *runtime slot* is filled by the agent every run (`<N> of 7 pass`, `<TICKET-ID>`). Grep the brackets and 7 of 12 skill templates look parameterised; count the kinds and only **3** are. It matters because the kinds have different constraints: **a reader placeholder can only hold what is constant for the reader**, so a per-repo fact like a run command must be read off the repo, while a generator slot holds per-repo facts happily. Two templates were nearly given placeholders they could never have been filled in correctly.
- **A `.claude/` directory created mid-session is not watched; one that already existed is.** Editing a skill or agent file under a directory that existed at startup is picked up live, within seconds — which is what the `pitch-judge` probe found and recorded as *"the restart caveat was wrong."* Creating the directory itself is the case that still needs a restart, and it is exactly the case a generator hits: `/adapt-to-stack`'s first run brings `.claude/agents/` and `.claude/skills/` into existence, so its own output cannot be dispatched to in that session. **Every check that reads the disk passes**, which is why the report has to say it out loud. The two probes look contradictory and are not — **the unit is the directory, not the file.**
- **A personal skill beats a project skill of the same name.** The opposite of *more specific wins*, and the opposite of how project **agents** resolve, where the definition closest to the working directory wins. So the same flow, writing into `.claude/agents/` and `.claude/skills/` in one run, produces output whose collisions resolve in **opposite directions** — and one stray `backend-standards` in `~/.claude/skills/` silently shadows every repo's generated one. Nothing warns you.
- **`tools: []` and an absent `model:` fail in opposite directions.** #27 learned the hard way that an empty tools list refuses to launch, and the instinct afterwards is to distrust every omitted frontmatter field. It does not generalise: a subagent has a **floor of one tool** and no floor on model, so omitting `model` is documented to inherit. **The lesson from one field is not a lesson about frontmatter.**
- **A ticket can cite the source that refutes it.** #18's body called `/goal` *"a native, durable, zero-effort measurement surface"* and named #6 as the authority. #6's own durability column says the condition survives a resume but **turn count, timer and token baseline reset** — so `/goal` measures a *session*, not a unit, and the ticket's headline fact was false in the sentence it was summarising. **This is a different failure from the four premise bugs before it.** #36's premise came from the Notes, #15's from another open ticket's body, #42's and #38's from their own — **all four were true when written and expired**. This one was never true. **So *re-check the premise* is not enough: re-read the source, not the ticket's summary of it.** A gist is a compression, and compression is where the qualifier goes missing — which matters most on a map whose entire durable record is gists.
- **`blocked_by` is eventually consistent and the frontier query is built on it.** Closing #18 and immediately reading #16 returned `blocked_by: 1` while GraphQL's `blockedBy` showed all 19 blockers already `CLOSED` — same instant, two endpoints, two answers, settling to `0` roughly thirty seconds later with no intervening write. **For a short window after any close, the frontier can silently omit a ticket that just became takeable**, and there is no error to notice: a short list looks like a short list. **The summary is eventually consistent; the graph is not.** Now a row in `templates/trackers/github.md`'s traps table, which is the fourth entry there about a REST count that cannot be trusted for what it appears to say.
- **A principle file and the page implementing it can contradict each other, which is the pair least likely to be read apart.** `PHILOSOPHY.md:131` says *"**every** pipeline run is costed"*; `docs/team/01-metrics.md:7` says *"this is **optional**"*. Both have been on `master` the whole effort. Every earlier instance of *docs are model input* was two peer documents drifting; this one is a **rule and its own implementation**, where a reader who loads both cannot tell which is the exception. Found only because #18 went looking for whether *optional* was even available to it.
- **A guardrail's own dependency is a guardrail nobody guards.** Every blocking hook starts with `jq -r '.tool_input.command …'`. With no `jq` the script dies there and exits **127** — and the hooks README's own box says every non-2 exit is a *non-blocking* error, so the tool call proceeds. Verified live on 6 August 2026: `command -v jq` returns nothing on this machine, so **all four hooks are currently off**, and nothing anywhere said so — `jq` appeared in no doc, only as an aside inside `templates/hooks/README.md`. **The suite cannot catch it and does not claim to**: it shims the parse with python and prints a NOTE, because its job is the matching logic. **A green suite means the patterns are right, not that the hook runs on your machine.** Third instance in this directory of a guardrail reporting success while guarding nothing (after `exit 1`, after the multi-line flatten), and **all three were found by running it** — so *these scripts cannot be verified by reading them* needs a second half: **the suite is not the same thing as the machine.** Decision spun to [#46](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/46) rather than patched, because fail-closed blocks the very commands you need to fix it.
- **A pattern that matches on the name cannot tell a secret from a file about secrets.** `.gitignore` carries `*secret*`, so `templates/hooks/block-secret-staging.sh` was **invisible to `git add` from the moment it was written** — absent from `git status`, no error, and it would simply have been missing from the commit. This is #34's *a rule about provenance expressed as a rule about paths* in a new costume, and it happened **inside the ticket whose whole subject is that failure**. The sharpest part: the **previous session had already written the abstract rule into `07-guardrails-when-solo.md`** — *whatever writes that ignore line writes the exceptions with it* — and this session still walked into it. **A rule you have written is not a rule you have applied**, and the only thing that caught it was reading `git status` rather than trusting the edit.
- **A claim can survive while the reason under it dies.** #14 sorted twelve `never push` sites and its rule held exactly — only `global.CLAUDE.md:76` moved. It still missed a thirteenth: `02-prerequisites.md:34`, *"a git-host token (read scope; **you push manually anyway**)"*. Read scope is still right; the **because-clause** is dead, and the real reason is `block-mcp-writes.sh`. **A grep that sorts by conclusion never reads the justification**, so a loosened rule leaves correct sentences resting on retired ones.
- **When an inserted step has no dependency, the insertion point is a decision the doc has to admit to.** The bootstrap's allowlist step needs nothing before it, so it falsifies *the order is forced, each step needs the one before it* **wherever it goes** — position 2 was cheaper in edits and no more honest. Once the claim must be qualified anyway, place by the rule that does apply: it is the one crossing outside the repo folder, and everything after it runs unattended, so it goes first. `04` now says forced *for seven of the eight* and names the exception.
- **Two guardrails on one directory, living in different files, and moving one buys nothing.** #14 flipped `block-infra-staging.sh` so the repo's `CLAUDE.md` and (after #15)
  `.claude/agents/**` and `.claude/skills/**` can be committed. They still could not,
  because **three files instructed a flow to write a blanket `.claude/` line into the
  repo's `.gitignore`** —
  `templates/views/README.md:78`, `templates/skills/charting/SKILL.md:134`,
  `templates/skills/cut-backlog/SKILL.md:252` — all written by #36/#40 when nothing under
  `.claude/` was meant to survive. **The hook blocks the *command*; `.gitignore` makes the
  file invisible to it.** Two independent mechanisms, one directory, and every ticket that
  touched the subject reasoned about exactly one of them. Deletion is the wrong fix — #36
  genuinely needs the line — so the two have to sort the same way. **Landed by #43**: all
  three now write `!.claude/agents/` and `!.claude/skills/` beside it. **The check: when you
  loosen a guardrail, ask what *else* is enforcing the same outcome by a different
  mechanism.** Every re-grep lesson so far has been about **reach** (#33, #37) or **sorting**
  (#14); this one is about a **second enforcement point** that no wording of the first one
  would ever return.
- **A ticket's own body is a premise that can expire, and #42 found it in its own.** #42's
  body instructs *"exactly one file flips"* and *"is `.claude/` part of the product? — no"*.
  Both were correct when #14 wrote them and were amended by #15 the next session; #43 got the
  correction and #42 did not, because #15 was editing the ticket that owns the hook. **The
  make ticket read its instructions, and its instructions were a session stale.** Second
  consecutive ticket to hit this — see the entry below, which is the same failure seen from
  #15's side. The defence generalises one step: **a make should re-read the resolution
  comment of its parent decision, not only its own body**, because the parent is where a
  later correction gets posted.
- **An open ticket's body is a premise that can expire, and nothing on `master` will tell
  you.** #43's body instructs a future session that *only `CLAUDE.md` flips* out of
  `block-infra-staging.sh`. #14 reached that correctly, knowing nothing of what #15 would
  decide two sessions later — and #15 landed generated, **committed** files inside
  `.claude/`. **This is not the false-premise failure this map keeps finding** (#36 obeying
  a wrong Note, #38's step 7 contradicting its own bullet): the sentence was true when
  written and **expired mid-effort**. It is also unreachable by every defence built so far —
  a re-grep sweeps the working tree, and this lives in an issue body. **The defence is
  directional: when a ticket decides where generated files land, re-read the open tickets
  that own the guardrails on that path.** #43 was one hop away and named in #15's own second
  comment, which is the uncomfortable part — the link was already there and pointed the
  other way.
- **A ticket that predicts two variants should re-check the prediction once its input is
  settled.** #15 was written to design a shared skill plus one thin entry point per path,
  and #10's comment sharpened the split further. Then #15's own second decision narrowed the
  input to a single file, and the two variants collapsed into one path-agnostic skill.
  **Narrowing the input is the commonest way a predicted variant disappears** — and nobody
  goes back to check, because the prediction is in the body and the body is what you are
  working from.
- **A sentence asserting a set is complete has a short shelf life on a map that spawns
  tickets.** This file said *every make on this map is now landed* and that #16's remaining
  edges were *all conversations*. Two sessions later there were three new makes. Same shape
  #37 found in `01`'s *"the four stage docs are still being written"* — **a claim about a
  set belongs to whoever closes the set, and nobody is assigned that.**
- **The session that fixes an error is the session most likely to reproduce it.** #37
  corrected `04:252`'s *"stage 4 makes the eighth"* to **item 6** — and, in the same
  session, wrote *"which is the eighth item"* into `05-cutting.md`, the file it was
  creating. Three lines later in that same file it says **item 6** correctly, twice more.
  Nothing was careless: the fix and the recurrence were the same act of thinking about the
  same wrong ordinal, and the copy being written is the one copy nobody re-reads before the
  commit. **No grep of `master` reaches it** — #35 found the same thing a different way,
  inside the doc it was writing. So the third instance of the seam's 7 → 8 growth outliving
  its ordinals is also the clearest statement of the defence: **recompute any count or
  ordinal at the moment you write it, in the sentence you are writing right now** — not by
  re-grepping afterwards, which by construction cannot see the file you have not saved.
- **A ticket body is a premise, and this map's premise rule applies to it too.** #38's step
  7 asked for *"native blocked-by edges where the tracker has them, the HTML viewer where it
  does not"* — a branch on tracker capability — and four bullets later, in the same body,
  *"the tracker is never named; abstract verbs only."* Both were written by the session that
  designed the stage, and only one of them survives contact with #4, which says the adapter
  fakes what is missing and **the calling skill is never told**. #36 spent a whole ticket
  obeying a false premise in the map's **Notes**; this one was in the **instructions**, which
  a make ticket has every reason to treat as settled. **Check a stated constraint against the
  contract before you let it shape a file** — including, and especially, when the constraint
  is the task.
- **A cost check is not a completeness check.** #36 priced the whole graph on GitHub at *two
  requests against the naive sixty-six*, #39 landed those two calls verbatim, and both were
  right about the money. Neither asked whether the cheap answer **contained the thing the
  caller exists to draw**: `issue_dependencies_summary` is four integers, so the payload has
  every box and no edges. The verb was defined, verified live, exercised by two tickets, and
  still could not draw an arrow. **When you check what an answer costs, check separately
  what is in it** — and phrase the second check as the caller's question. *By what?* is a
  different question from *how many?*, and only one of them has a picture on the end of it.
- **The prose this effort writes is the only test data that finds its own rendering bugs.**
  #40's markdown pass rendered every hand-made sample correctly and broke twice on real
  ticket text: `**bold with an *italic* inside**`, which is the shape of every gist on this
  map, and a code-span placeholder that any body containing a bare number would corrupt.
  Neither is exotic; both are invisible until you point the thing at the corpus it exists to
  read. **Generate the real artifact before believing the sample one.**
- **The adapter that satisfies a contract clause for free is the one that hides the defect
  in it.** `read` never included comments. On local markdown the question and the comments
  are the same file, so `read` there was correct without anyone deciding it was — and the
  clause was never written down, because on the adapter the contract was drafted against
  there was nothing to write. On GitHub they are two endpoints and one of them was never
  called, which is how *"read ticket #12"* came to return **2,224 characters of question and
  0 of answer** while the resolution comment held **14,193**. **A verb that costs one adapter
  nothing is a verb whose definition nobody had to state** — check the cheap adapter last,
  or you will mistake its convenience for the contract.
- **Naming a verb can collide with prose that was correct until the moment you named it.**
  `05-cutting.md:133` said *"the whole graph is authored in one sitting"*, meaning the
  backlog's dependency graph — ordinary English, and unambiguous right up until #39 made
  *the whole graph* a contract verb. It sits three lines under a link to
  `templates/trackers/README.md`, so the one reader most likely to hit it is the one holding
  the contract in mind. Reworded to *the dependency graph*. **The grep to run when you coin a
  term is for the term you just coined, in the files that were written before it existed** —
  it finds sentences nobody broke, which is why nobody is looking for them.
- **A count of live things is not a fact you may write down.** #36 verified the repo-wide
  comments call and recorded *"all 52 comments"* in this file. It is **54** today, and it
  will be 55 once this ticket's own resolution comment posts — the number moved because
  *writing about it* moved it. The verified thing was the **shape** (one paginated call, not
  one per ticket); the total was incidental and decayed within the day. This is #30's
  recompute-don't-transcribe rule with a sharper edge on it: some numbers should not be
  transcribed *at all*, because there is no moment at which they are true for longer than it
  takes to write them.
- **A rename grep finds the sentences *about* the thing and misses the ones that walk past
  it.** #12 grepped before estimating — the right instinct, and it correctly separated the
  *artifact* uses of "backlog" (which stay, seam item 6 included) from the *stage* uses
  (which had to change). It found **four** and the real number was **ten**. Every one of the
  six it missed has the same shape: the stage is named **in a list of its siblings**, on the
  way to saying something else. *"If the bootstrap or the backlog breaks a decision…"*
  *"Charting has nothing to chart, the bootstrap nothing to scaffold, the backlog nothing to
  cut up."* A grep for the term under rename lands on the paragraphs that discuss it and
  skips the passing mentions, because a passing mention is **structurally unremarkable** —
  it is one item in a list. **The cheap fix: grep the siblings.** `the bootstrap`,
  `charting`, `the kill gate` — every hit is a place the fourth name is likely standing
  beside them. This is the fifth ticket in seven where a wider re-grep found the site that
  mattered, and the first where the *pattern* was right and the *reach* was short.
- **A "still being written" note is a claim with an expiry date, and nothing expires it.**
  `01-the-solo-path.md` carried *"the four stage docs are still being written"* from #20
  onward. Each of #25, #22, #34 and #37 made it one quarter less true and none of the first
  three touched it, because each was writing **its own** doc and the note is about **the
  set**. Retired by #37 as the last one in. **A note about a set of files belongs to whoever
  closes the set, and nobody is assigned that.**
- **A number that varies for exactly one reason is a proxy — check the reason instead.** #12
  recommended a ticket **count** as the brake on scope: over ~10 units, go back to the smallest
  version. It survived until the driver asked *why would the count vary?* — and it does not.
  Under the stage's own sizing rule the count **is** the number of things the app can do, which
  the smallest-version sentence pins. Twenty units does not mean the cut went wrong; it means
  **the sentence grew during charting**, which has one cause. The replacement measures the
  cause: every unit points at the phrase it came from, and anything pointing at nothing is
  flagged. The proxy was strictly worse — it could not name *which* unit was the problem, and
  it punished an honestly-large first version and a bloated one identically. **A threshold is
  usually a proxy for a question you could have asked directly.**
- **A rule can be broken inside the document that states it.** `01-the-solo-path.md:27` says
  *"the stage is charting; the artifact it produces is the map. They never share a name."*
  Three rows above, the stage-4 row called the stage **the backlog** and its output **the
  backlog**. The spine has been read by #22, #25, #26, #30, #31, #33, #34 and #35 and nobody
  saw it, because a rule is read as a claim about *other* content. **When a doc states a
  constraint, check the doc against it before checking anything else** — proximity is what
  makes the violation invisible, not obscurity.
- **A size bar calibrated on a mature codebase cannot return *no* on a day-one repo.**
  `12-when-not-to-use.md:20-24` gates the pipeline on *2+ files* or *a decision the codebase
  does not encode yet*. On a fresh stub the codebase encodes **nothing**, so the second clause
  is universally true, and the stub has one empty folder per layer, so the first clause is too.
  The bar was not wrong — it was **evaluated outside its domain**, where it degrades silently
  into a rubber stamp rather than failing. **Before reusing a heuristic in a new stage, find
  the input that makes it say no. If there isn't one, it is not a heuristic there.**
- **Duplication is dangerous when both copies can change — not because there are two.** #12
  copies charting's constraints into every work ticket rather than linking them, which looks
  like the exact failure #4 spent a session removing. It is not: the map is **closed and
  frozen** before the stage runs, so only one copy can still move. The forcing fact was the
  consumer — `@ticket-analyzer` reads nothing but the ticket, so a link is a door the first
  agent in the pipeline never opens. **State the anti-duplication rule with its condition
  attached**, or it gets applied where it costs correctness.
- **A ticket's framing is a claim from the past, not a given.** #12's body opened with *"what
  you hold is a set of resolved decisions — not work. Something has to convert them into
  units."* Nothing converts them, because they do not convert: the scope was named at the kill
  gate, a full stage earlier, and sits in the map's Notes the whole time. The premise had been
  written months before, when stages 1 and 2 did not exist yet. **Check a ticket's premise
  against what the map has learned since it was written** — a body ages exactly like the
  closed comment #30 found stale.
- **Grep before estimating the size of a rename.** The stage rename looked like a sweep across
  every doc mentioning *"backlog"*. It is **four sites**, because almost every occurrence names
  the **artifact**, which keeps its name — seam item 6 included. The cheap check ran before any
  promise was made about scope, which is the opposite order from the four tickets that were
  caught by a too-narrow grep. **The same command that stops you under-fixing stops you
  over-fixing.**
- **When a ticket retires a number, not every instance of that number is the number being
  retired.** #34 changed the seam from seven checks to eight and swept the count out of four
  files — correctly. Writing the same doc, it also turned *"one red among seven"* into
  *"among eight"*, because in a session whose whole job is replacing *seven* with *eight*,
  every *seven* looks stale. That one was counting a **different set**: the checks stage 3
  can actually make true, which is seven of the eight because item 6 is the backlog and
  belongs to stage 4. **No grep of `master` could have caught it** — the error was inside the
  new file, introduced by the same edit that was fixing the real instances. What catches it
  is asking *what is this number counting?* on every hit, which is slower than sweeping and
  is the price of a sweep that changes a number's meaning. Found by #35, one session later.
- **A guardrail that blocks a path can block a flow that *generates* files on that path.**
  `templates/hooks/block-infra-staging.sh` refuses to stage anything matching `CLAUDE.md` or
  `.claude/`, which is exactly right while those files are hand-written config the agent
  should not sneak into a product repo. The bootstrap **generates** a repo `CLAUDE.md` as
  step 2 and may generate `.claude/` agents at step 4 — so the stage cannot commit its own
  output. Nobody wrote a contradiction; a rule about *provenance* was expressed as a rule
  about *paths*, and then a new flow started producing those paths legitimately. **When a
  flow starts generating a file class some hook was written to keep out, re-read the hook's
  reason, not its pattern.** Found by #34, owned by #14. **Latent in this repo** — #34 staged
  `templates/claude-md/repo.CLAUDE.md` without being blocked, because the hooks here are
  templates and are not installed. It bites the first reader who follows setup step 7.
- **A doc that only a human reads is still model input, and a contradiction between two
  files has no tiebreak.** #31 nearly left `01-the-solo-path.md:8` stating a flat Serena
  gate on the grounds that the seam three screens below carries the nuance — which is how a
  *human* reads a document, top to bottom. An agent loads both files into one context and
  sees two claims that disagree; nothing in the context says which is the headline and which
  is the correction. **In a repo whose whole output is context, an unresolved contradiction
  between two files is a defect, not a matter of style.** Fix every copy, or the fix is not
  a fix.
- **Grep the repo, not the docs — the *directory list* is the narrower mistake.** #33 closed
  claiming *no file on master states a flat Serena gate*, and it was false: `PROGRESS.md:38`
  said *"a scaffolded, Serena-indexed repo"* for a whole session, because the grep ran over
  `docs/`, `templates/`, `README.md` and `PHILOSOPHY.md`. The pattern was right and the
  **search path** was wrong, which is the harder error to notice — a wide pattern over a
  narrow tree returns a confident empty result. **The tracking file is tracked**, and a file
  that records the lesson is not exempt from it. Four tickets in a row have now been caught
  by a too-narrow search; #31 and #33 got the pattern wrong, #10 got the path wrong twice.
  **#34 broke the streak, and not by grepping harder** — #10 had already widened the list
  inside the ticket body, so the session's own re-grep found nothing to add. The fix belongs
  in the ticket that hands the list over.
- **A checklist can be complete and still say nothing about what happens after it.** The
  seam had seven checks and had been read by #3, #20, #22, #31 and #33 without anyone
  noticing that `/start-ticket` step 4 **dispatches to layer specialists** and nothing on the
  seam said those agent files exist. All seven could pass and the pipeline would have nothing
  to run. **When a checklist exists to hand off, read the first thing on the far side and
  check every input it takes** — the gap is invisible from inside the list, because each
  individual check is correct.
- **For a solo builder, the right axis is blast radius, not audience.** #4 restated
  `PHILOSOPHY.md` §5 as *ask before writing anywhere other people can see*, which is right
  for a repo other people read — and returns *never ask* for every step of a solo bootstrap,
  because nobody else is watching. But the machine has **other projects on it**. #10's line
  is **the repo folder**: inside it everything is undoable with `git checkout .`, outside it
  nothing is. The two rules agree everywhere except the case the solo path is about.
- **A decision that says "record the verdict in `CLAUDE.md`" needs somewhere in the template
  to record it.** #31 and #33 settled that the Serena verdict lives in the repo's
  `CLAUDE.md`, and seam item 4 tells the reader to look it up there — but
  `templates/claude-md/repo.CLAUDE.md` has **no slot for it**, so the stage that fills the
  template in has nowhere to write the one thing the seam sends a reader to. **When a
  decision names a file as the home for a fact, open the template for that file in the same
  session.** #34 added the slot — a `## Serena` block with a verdict line and a one-line why.
- **Grep the concept, not the phrase — the pattern a ticket hands you is narrower than the
  claim it is chasing.** #33 listed five hits for `Serena-indexed|Serena is indexed` and
  landed eight edits, because grepping the bare word `Serena` found two more sites saying
  the same flat thing in different words. The sharp one was `03-charting.md:148`, the tail's
  second ticket writing *"the Serena index check"* with no condition — a flat gate **inside
  the very ticket that records the conditional verdict**, and invisible to the ticket's own
  done-when check. **Two tickets in a row now** (#31 found the `/pitch` template the same
  way). A `Done when` grep proves the listed sites are fixed; it does not prove the claim is
  gone. Run the narrow pattern to close the ticket and the wide one to trust the result.
- **A template is not documentation, and grepping prose misses it.** #31's body listed two
  places stating Serena flatly, both in `docs/`. The one that mattered was
  `templates/skills/pitch/SKILL.md:273` — **an instruction to an agent** to write
  *"a scaffolded, Serena-indexed repo"* into a reader's map as its Destination, which
  `03-charting.md:20` then says *fixes the scope*. Prose that is wrong misleads a reader;
  a template that is wrong **executes**. **When auditing a claim, grep `templates/` first
  and `docs/` second** — the blast radius is the other way round from the word count.
- **The kill gate writes the destination a full stage before the stack exists.** Stage 1
  seeds issue #1; the stack ticket is charting's tail in stage 2, explicitly not takeable
  while anything else is open. So anything the gate writes into Destination is written at
  the point of **maximum ignorance** — and Destination is the one field that fixes scope,
  so a guess there rules out the tail's honest answer before the tail is asked. **Check the
  stage ordering before letting any stage state a fact another stage decides.**
- **The seam was never seven flat checks, and nobody noticed.** #31 opened on the worry that
  a conditional item 4 is *"a judgement call wearing a checkbox"*. Item 2 has said *"a green
  test command is optional here; the tail's second ticket decides"* since #20 wrote it. The
  precedent was one row up the same table. **Read the artifact before arguing from the
  principle** — the shape you are about to invent may already be in use next door.
- **A conditional check is weak; a conditional answer is not.** The thing that degrades a
  gate is asking someone to exercise judgement at the moment they are trying to *verify*.
  Moving the judgement earlier — to a session with the information — and requiring it **in
  writing** keeps the gate a lookup. Generalises to any checklist that meets a case it
  cannot rule on uniformly.
- **Only `CLAUDE.md` can contradict `CLAUDE.md`.** The Serena verdict went there rather than
  into memory two, because `global.CLAUDE.md` carries the *Serena is MANDATORY* block and
  every code-touching agent carries a *Code access protocol (MANDATORY)* section. **A memory
  is searched; `CLAUDE.md` is loaded.** An override has to sit at the same altitude as the
  rule it overrides, or it is a fact nobody retrieves at the moment it applies.
- **#3's tail has an ambiguous sentence, and decide-or-make made it matter.** On whether a
  stack gates on a green test command, #3 says *"the test half is optional, and **the stack
  ticket** decides"* — then immediately *"which is what **the tail's second ticket** is
  for."* Those are two different tickets. Under #5's decide-or-make the second reading makes
  the tail's second ticket both a decision and a make, which is the exact collision the rule
  forbids. **#22 took the first reading** (ticket 1 decides the stack *and* the test gate;
  ticket 2 writes the commands down) and wrote `03-charting.md` to it without adjudicating
  in prose. ~~**#21 owns settling it.**~~ **Settled by #21 on the first reading**, and the
  deciding argument was decide-or-make rather than close reading: the second reading makes
  ticket 2 a decision *and* a make, which the rule forbids, so it was never available.
  **Assigning it to #21 was right** — a question two tickets each assume the other will
  answer is a question nobody answers. #10 now inherits an answer instead of an ambiguity.
- **A stage doc that lands before its template ships dead links, and it cost a marker.**
  The charting pair went template-first (#11 then #22), so `03-charting.md` never had the
  problem. The kill gate pair went the other way — #25 before #26 — so `02-the-kill-gate.md`
  shipped with two dead template links and a *still being written* blockquote, which #26
  then deleted. It worked, but it cost an extra edit and a commit that published a doc
  pointing at nothing. **Template-first is the better order** where a pair has a free
  choice. **#10 went doc-first anyway and knew it**: the decisions live in the doc and the
  template reads from it, so the reverse order would have had #35 inventing what #34 settles.
  **The rule is not free-choice-always** — where the pair is a design doc and its mechanics,
  the doc has to go first and you pay the dead link. ~~#12 still has the free choice.~~
  **#12 had no free choice after all** — its template ticket (#38) is blocked by the viewer
  (#36), so doc-first was the only order available. Four pairs in, **the free choice was
  available exactly once**, to charting. The rule is really *doc-first unless the mechanics
  are already settled elsewhere*, and they usually are not.
- **A subagent cannot have zero tools, and this is deliberate.** The errors page is
  explicit: *"Subagents require at least one tool to function, so Claude Code refuses to
  spawn an agent that would have no tools available."* So `tools: []` **refuses to launch** —
  that is the branch #26 could not determine. There is a version boundary: **before
  v2.1.208 the same YAML launched the agent toolless** and it "could return an empty or
  confusing result", so one file fails two different ways depending on the reader's install.
  ~~**`TodoWrite` is the inert floor**~~ — **wrong, and proven wrong by running it.**
  `TodoWrite` no longer exists; the task tools (`TaskCreate`, `TaskUpdate`, `TaskList`, …)
  replaced it. So `tools: TodoWrite` resolves to an empty list and hits the **same**
  refuse-to-launch branch as `tools: []`: *"would be spawned with zero tools — refusing. Its
  tools list resolved to nothing: unrecognized [TodoWrite]."* #27's diagnosis was right and
  its chosen floor rotted inside a week — which is #27's own lesson landing on #27. Now
  [#32](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/32).
  **A tool name in a `tools:` list is a claim with a shelf life.** It passes every reading
  check right up until the day the tool is renamed, and then it fails silently at spawn time.
- **Subagents run in the background by default, and that silently changes their tools.**
  Since v2.1.198 background is the default, and a background subagent keeps **every MCP
  tool** but only a fixed subset of built-ins: `Read`, `Grep`, `Glob`, `Bash`, `PowerShell`,
  `Edit`, `Write`, `NotebookEdit`, `WebFetch`, `WebSearch`, `TodoWrite`, `Skill`,
  `ToolSearch`, `EnterWorktree`, `ExitWorktree`, `Monitor`, `TaskStop`, `SendMessage`,
  `Artifact`. **Anything else in a `tools:` list is stripped with no error** — unless
  stripping empties the list, at which point the agent refuses to launch. So a template can
  name a tool that exists, is spelled correctly, and still is not there at runtime. Also
  worth knowing for the *inherit* case: an agent with `tools` omitted holds every MCP server
  you have configured, which is usually far more reach than the author pictured.
- **An agent that dispatches another agent needs `Agent` in its `tools` list, and nothing
  warns you.** `repo-reviewer` said *dispatch `@release-reviewer`* in its description and in
  its steps, and could not: nesting is on by default, but **an explicit allowlist still
  wins**. The first-level review would have finished and reported a verdict with the
  cross-repo half silently absent. **Check every agent whose body names another agent.**
- **Flattening input before matching erases the boundaries the pattern depends on.** Both
  git guardrails turned newlines into **spaces**, then matched `git push` anchored on
  start-of-string or `[;&|]`. So in an ordinary multi-line command every line after the
  first was invisible to them — `cd /tmp && git push` blocked, the three-line version did
  not. Newlines are now `;`. **Suspect this in any guardrail that normalises before it
  greps**: the normalisation looks like tidying and is load-bearing.
- **Auditing claims against documentation verifies the claims, not the code.** #28 checked
  every hook claim against the official docs and passed, because nothing in the docs was
  wrong — the playbook's own regex was. Configuration defects (a missing `Agent` tool, a
  matcher naming one shell) *do* fall out of reading. Behavioural ones do not.
  **`templates/hooks/test-hooks.sh` is the repo's first executable test** — 29 cases, and
  it was mutation-tested by reverting the fix and confirming it fails on exactly the four
  multi-line cases. A suite never seen to fail is not evidence.
- **A guardrail that stops guarding reports success — three instances now, one week.**
  #13's MCP key rename, #28's `Bash`-only matcher, and this. **Anything whose failure mode
  is silence needs a test, not a review.**
- **`PowerShell` is a separate tool from `Bash`, and a `"matcher": "Bash"` hook does not
  see it.** It is enabled automatically on Windows without Git Bash, rolling out
  progressively on Windows *with* Git Bash, and opt-in elsewhere. So the git guardrails were
  wide open on the platform this repo is actually driven from. Use `Bash|PowerShell`.
  **Second instance of the same failure shape #13 found** — a guardrail that stops matching
  keeps reporting success. Worth a standing suspicion: whenever a matcher names one way of
  doing a thing, ask what the other ways are.
- **Only `exit 2` blocks a hook. Every other non-zero code is non-blocking** — the
  transcript shows an error notice and the tool call proceeds anyway. The shipped scripts
  were right; the README taught *"non-zero (2)"*, which is the natural thing to get wrong,
  and `exit 1` in a guardrail guards nothing while looking like it does.
- **A skill's directory name is what you type; `name` is only a display label.** It defaults
  to the directory name and changing it does not change the command. Bites
  `engineering-standards`, which is copied per layer — rename the *directory*, not just the
  placeholder, or three skills answer to `/engineering-standards`.
- **Custom commands have been merged into skills**, and where they collide **the skill
  wins**. `templates/commands/` is still supported, not deprecated — but the whole skill
  frontmatter set works there too, and the skill shape is the one that grows.
- **No template carries a `Last verified against` footer, and that is now deliberate.** #28
  assumed the footers were over-claiming for templates; in fact templates never claimed
  anything. Adding one per file would have been worse — a template is copied and edited, so
  a stale footer is indistinguishable from the reader's own edits. **The check lives in
  `templates/README.md` instead**, as eight named checks against the doc pages that settle
  them. Checks 3, 4 and 6 are the ones that fail silently; three of #28's four findings came
  from them.
- **This playbook writes frontmatter the harness has to accept, and nobody was checking.**
  `tools: []` was written because it was the obvious YAML for "no tools". Every file in
  `templates/` is a **claim about what the harness will do**, and claims need verifying
  against the docs, not against what looks reasonable. The `2.1.220` footer implies exactly
  this checking has happened. **Check the field table in the subagent docs before inventing
  a frontmatter value**, especially for anything expressing an absence — absences are where
  "unset" and "empty" get conflated.
  **Now ticketed as [#28 Audit every template's frontmatter and harness claims against the
  official docs](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/28)**,
  standalone rather than a child of #1 — it covers all templates, most of them agile-path,
  so it sat outside this map's destination. Same shape as #17. **Both #27 and #28 are now
  closed.** #28 applied #27's edits and swept the rest: four silent failures found, both
  anatomy blocks widened to every documented field, and `templates/README.md` created to
  hold the re-verification check. **An incomplete anatomy block does not just omit options;
  it makes real solutions invisible** — `maxTurns` was not rejected by #26, it was never
  seen.
- ~~**You cannot dry-run a new agent in the session that wrote it.**~~ **No longer true, and
  it mattered.** Copying `pitch-judge.md` into `~/.claude/agents/` made it spawnable
  *immediately* — the harness announced the new agent type mid-session, no restart. The old
  rule had been quietly deferring every agent probe to "a fresh session", which is a
  session nobody ever spends. **Copy the file and spawn it in the same breath.** This is how
  #32 was found.
- **Decide-or-make is 15 for 15, and #27 was the first real pressure on it.** Every closed
  ticket so far is either a grilling/research that wrote no files or a `wayfinder:task` that
  wrote them — never both. #27 is the first decision whose entire output is a **two-line
  frontmatter edit**, which the rule's own justification does not cover: #5 justifies the
  split *only* by context budget (*"the unpredictable half eats the context the predictable
  half needed"*), and two lines cost no context. **The rule was kept anyway, with no size
  exception**, on the grounds that it has cost nothing so far, that *"small enough to just
  do"* is self-assessed at the start of a session — exactly when it is judged worst — and
  that #9 looked like one grilling and produced two makes. **#27 decides and #28 applies**,
  since #28 has those files open regardless. No exception, and no extra session either.
  Worth remembering the next time a decision has a trivial tail: look for a make already
  passing through the same files before carving an exception into the rule. **The rule paid
  for itself immediately**: #27 was supposed to be a two-line frontmatter change and it
  turned into a sixteen-field README rewrite, a retired vocabulary word, a correction on a
  closed ticket and two new gotchas. "Small enough to just do" would have been wrong.
- **A design ticket cannot settle mechanics it never has to execute.** #9 designed the gate
  completely and still left three things that only became questions when someone wrote the
  skill: the case file's *location* (no tools means no `Read`, so it must ride in the
  prompt), the hard-kill table's *direction* (the skill asks "given this class, which kills
  are live?", the reverse of how #9 listed them), and the *precedence* between rules that
  can fire at once. None was a new decision — each was forced. **#10 hit it in the other
  direction**: it was the design ticket, and #3's seam — a *finished* design it only had to
  consume — turned out to be missing a check, because #3 never had to stand on the far side
  of the seam and run `/start-ticket`. **A design ticket cannot settle mechanics it never has
  to execute, and it cannot see the gaps in a hand-off it never has to cross.** ~~#12 is the
  last one that will find this.~~ **#12 found it in a third direction**: not a missing
  mechanic and not a missing check, but a **naming rule broken in the document that states
  it** — stage 4 and its artifact both called *the backlog*, three rows from
  `01-the-solo-path.md:27` forbidding exactly that.
- **Four docs have H1 headings that no longer match their filenames.** `shared/11-adapting-to-your-stack.md`
  says `# 12`, `shared/12-when-not-to-use.md` says `# 13`, `team/01-metrics.md` says `# 11`,
  `team/02-team-adoption.md` says `# 14` — exactly the four #19 renumbered, since #19
  deliberately left prose alone. The other ten match. **Found by #9 and handed to #17**, whose
  list did not cover it. The check is comparing `head -1` to the filename across `docs/**`.
- **The guardrails fail *open* when `jq` is missing, and this machine has no `jq`.** Both
  blocking hooks parse with `jq` under `set -euo pipefail`, so a missing `jq` exits **127** —
  and only exit 2 blocks. Everything else is a *non-blocking* error, so the tool call
  proceeds and the sole signal is a hook-error notice that reads like noise. `git push
  --force` gets through. The hooks README does say *"`jq` is assumed"*, which makes this
  worse than undocumented: a documented dependency that silently disables the guard when
  absent. **Fifth instance of fails-open-silently.** Owned by
  [#29](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/29), and it is
  a real decision — failing closed blocks every matched call until `jq` is installed.
  **Latent, not live: nothing from `templates/` is installed on this machine.** No
  `~/.claude/hooks/`, no hook wiring in `settings.json`, no `~/.claude/tracker.md`; the only
  agents present are the driver's own. So this bites **on first install**, which is the
  argument for settling it inside #29 rather than hotfixing — and the argument for **not
  installing the hooks anywhere until it is settled.**
- **The playbook has never been installed, which is the fact behind every open verification
  ticket.** Worth stating plainly because it is easy to forget while editing `templates/`
  all day: this repo is a **blueprint**, and no part of it has ever been run as
  configuration. #29 exists to change that.
- **Two open housekeeping tickets outside this map, and they now split three ways.**
  **#17 owns prose-level rot in `docs/`.**
  [#28](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/28) owned
  machine-readable correctness in `templates/` **by reading**, and is closed.
  [#29](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/29) owns the
  same surface **by running** — install everything into a scratch environment and drive it.
  The split is the lesson #28 ended on: **reading verifies claims, running verifies code**,
  and #28 found five defects while still leaving every template unexecuted. The footer
  question that connected #17 and #28 is settled in #28's direction, so #17's remaining
  footer work is purely the stale `2.1.219` *values* in `docs/`. None was ever a child of #1.
  [#17 Docs housekeeping](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/17)
  is **not** a child of #1 — it is pre-existing rot in the agile path. It owns the stray
  `-e ` lines (14 left; #11's commit took the 15th), the stale `2.1.219` footers, and
  suspected factual drift in `07-the-flows.md`. **Check it before editing any shared doc**,
  or you will duplicate its work. Its own file list is pre-reorg and has been corrected in a
  comment. **Two shared docs have been edited around it since.** #25 added one paragraph to
  `12-when-not-to-use.md` (the reverse half of a required cross-reference) and #26 added one
  row to `07-the-flows.md`. Both deliberately left the strays, the mismatched H1s and the
  stale footers alone. All of those are still #17's.
- **The flow catalogue's own definition no longer matches its contents.**
  `docs/shared/07-the-flows.md` opens by defining a flow as *"a slash command that
  orchestrates a chain of scoped specialist agents."* `/charting` is a user-invoked skill,
  not an agent chain — and `ad-hoc: investigation` was already in the table without being a
  command at all. So the drift predates #11; #11 just made it visible. **Handed to #17**,
  which already owns that file. A one-line widening of the definition fixes it. **#26 added
  `/pitch` to the same table and left the definition alone** — `/pitch` genuinely does
  orchestrate three subagents, so it fits the narrow definition better than `/charting`
  does. Nothing worsened, nothing fixed.
- **The leading-gist rule is not retroactive.** #5 requires every resolution comment to open
  with a one-line gist so Decisions-so-far can be regenerated mechanically. The **seven
  comments closed before #5 have no gist**, so a full regeneration today still means
  re-reading and re-summarising those seven. Either accept the map's current
  Decisions-so-far as the canonical text for them, or retrofit gists as a chore. Not worth a
  ticket; worth knowing before someone tries to regenerate and finds it is not mechanical.
- **`gh api` sub-issue and dependency writes need `-F`, not `-f`.** `-f` sends the id as a
  string and the API rejects it with `is not of type integer`. Both take the issue's
  **database id** (`.id`), never its number.
- **`gh issue view <n>` prints nothing on this machine** — no error, no body, exit 0, from
  both Git Bash and PowerShell. **Read tickets with
  `gh api repos/<owner>/<repo>/issues/<n> --jq ...`** and do not waste a retry on `view`.
- **`issue_dependencies_summary.blocked_by` is open blockers only**; `total_blocked_by`
  includes closed ones and never decreases. **Use `blocked_by == 0`.**
- ~~**The GitHub adapter's frontier query does not work as written.**~~ **Fixed by #13** —
  `templates/trackers/github.md` now ships the working `gh api …/sub_issues` form, plus the
  other six traps, in a table. `gh issue list --json` still cannot see hierarchy at all
  (`parent` / `subIssues` error with `Unknown JSON field`); there is no flag that fixes it.
- **Renaming the tracker MCP key to `tracker` is a silent breaking change.** #13 moved the
  server key from `jira` to `tracker` and the hook matchers from `mcp__jira__.*` to
  `mcp__tracker__.*`. All four files moved together — but **anyone who already installed the
  old snippets must rename their own server key**, or the read-only veto stops matching and
  fails open with no error. A guardrail that silently stops guarding is the worst failure
  shape there is; it is worth checking `/mcp` after upgrading.
- **The local adapter's ticket folder is `tickets/`.** #4 said *rename it away from
  `.scratch/`* without naming the replacement; #13 chose `tickets/`, visible and committed,
  because the files are project records and a dot-prefixed name says throwaway.
- **`gh issue list --limit` defaults to 30.** Silent truncation. This map now has 22
  children.
- **`gh` will not auto-create labels.** Create before applying.
- **`gh api` breaks on Git Bash for Windows with a leading-slash path.** `/repos/…` gets
  rewritten to `C:/Program Files/Git/repos/…`. Always omit the leading slash.
- **Ticket bodies carry pre-reorg doc paths.** #12 and #15 still say
  `docs/07-the-flows.md`, `docs/13-when-not-to-use.md`, `docs/12-adapting-to-your-stack.md`.
  Post-#19 those are `docs/shared/07-the-flows.md`, `docs/shared/12-when-not-to-use.md` and
  `docs/shared/11-adapting-to-your-stack.md` — **two changed number as well as directory**.
  **#11 was fixed, and #9 hit this live** — its body said `docs/13-when-not-to-use.md`, which
  is now `docs/shared/12-…`; #25 and #26 carry corrected paths. **#10 was resolved with its
  stale paths still in the body** (`docs/12-adapting-to-your-stack.md`, `docs/13-…`) and it
  cost nothing, because the session re-resolved them on the way in — but **#34 and #35 carry
  corrected paths** so the next reader does not have to. **#12 was resolved with its stale
  paths still in the body** — the second time that cost nothing, because the session
  re-resolved them on the way in; #37 and #38 carry corrected paths. **#15 is the last one
  left unfixed.**
  Re-resolve every path in a ticket body before acting on it.
- **GitLab's API docs are wrong about blocking.** Blanket Free/Premium/Ultimate badge, but
  `blocks` links actually 403 on Free. This is why GitLab ships as a shape, not an adapter.
- ~~**The local adapter's `Status:` line is overloaded**~~ — **moot, and worth knowing why.**
  The overload was between `/triage`'s role strings and wayfinding's `claimed`/`resolved`,
  but **the playbook ships no `/triage`** — that command is prior art from the skill set
  this repo re-derives. #13's adapter has three clean fields instead: `Type:`, `State:`,
  `Claim:`. A defect inherited from prior art can vanish rather than need fixing.
- **The map's licensing premise was wrong.** `mattpocock/skills` *does* ship a LICENSE (MIT,
  © 2026 Matt Pocock). The decision to re-derive stands on the quality ground alone.
- **README's repo-layout block is stale, doubly so** — it lists `01`–`12`, omits `13`/`14`,
  and shows the old *flat* layout. #16 owns the rewrite.
- **The renumbering trap in #19.** Two classes did the damage: **numeric shorthand with no
  slug** (`docs/09`, `docs/11`), invisible to any filename search, where `docs/11` *silently
  changed meaning*; and **the depth change**, where every link pointing *out* of `docs/`
  needed `../../` — 19 links across 6 files. The check that caught both: resolve every
  `[text](target)` against the filesystem.

---

## What #50 handed forward

- **To [#47](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/47), which it unblocked:** the walkthrough can now show a solo builder holding **two** `CLAUDE.md` files, and `06-claude-md-layers.md` is the doc that carries the fork. **The bootstrap writes five things into the repo's `CLAUDE.md`, not four** — the branch it ships from is the new one, and it is **detected** (`git symbolic-ref refs/remotes/origin/HEAD`), never asked for, so the walkthrough narrates no extra question. #47 now waits on #49 alone.
- **To [#29](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/29), unchanged and now more load-bearing:** **nothing here was verified by running it.** No repo was bootstrapped, no `CLAUDE.md` was written from these templates, and the claim that a solo builder loses nothing by dropping the middle file still rests on reading the five items rather than on a session run without it. #50 moved that claim from a doc into the reader's own artifacts, which raises the cost of it being wrong without testing it at all.
- **To [#17](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/17):** stray `-e ` lines re-counted and **still 13** — unchanged by seventeen edited files, because none of them touched a footer region. No footer was bumped and **no doc gained a harness claim**, so the audit stays whole.
- **To whoever disagrees with the scope call:** `README.md:123` and `templates/README.md:9` still read *global · workspace · per-repo CLAUDE.md skeletons*, deliberately. They inventory a directory whose three skeletons all ship, and `README.md:103` — which described the *doc* — was the one that had to move. **A line can name three files without asserting you need three.** One line each if a later reader reads it the other way; it is a scope call, not a decision, and reopening it needs no ticket.
- **To whoever lands the next decision:** **re-read the sites the deciding ticket marked *expected correct*, and read the whole file rather than the passage it cited.** That list is the cheapest thing in a ticket body to trust and it was wrong once out of four here — `11-adapting-to-your-stack.md` was verified at `:82-83` and broken at `:195-196`. The general form is in the gotchas above.
- **To the *Which knowledge gets extracted into shared skills* fog patch:** nothing. #50 wrote no skill and split no path; it edited two existing skill templates by one clause each. Recorded as *not a data point* rather than left to look like one, the same way #23 was.

---

## What #23 handed forward

- **To [#49](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/49), which it opened:** the two doc quotes, the exact two sites (`templates/skills/bootstrap/SKILL.md:140-146` and `templates/skills/adapt-to-stack/SKILL.md:9`), the third site that describes the call in prose (`docs/shared/07-the-flows.md`'s catalogue row), and both candidate repairs with what each costs. **Whichever way it goes, `templates/skills/README.md` already carries the precondition** — *nothing else dispatches to it* — so the fix is to the two files, not to the rule.
- **To [#47](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/47), which it blocked:** the walkthrough must narrate `/bootstrap` reaching step 5, and today that step cannot execute. **The blocker was added by a make and is easy to undo** if the driver would rather the walkthrough carry a caveat than wait.
- **To [#17](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/17):** the flow catalogue's opening definition is now wrong for a **fifth** row — `/prototype` orchestrates no agents at all, which is the weakest fit yet after `/bootstrap`, `/cut-backlog` and `/adapt-to-stack`. Also re-counted the stray `-e ` lines: still **13**, unchanged by this session.
- **To whoever ships the next capability:** **shipping it silently falsifies every doc that answered "there is nothing for that yet."** `12-when-not-to-use.md` had told readers to reach for an ad-hoc investigation agent for spike work since before this map, and it was complete when written. Those docs describe the gap **in their own words**, so no grep for the new thing's name will find them — grep the *job* instead (*spike*, *throwaway*, *react to*), which is how both spike sites and `03-charting.md:77` turned up.
- **To whoever writes the next template:** **check which kind of angle bracket you need before adding one.** A reader placeholder can only hold what is constant for the reader; a run command or a route convention is constant for the repo and belongs in that repo's `CLAUDE.md`, where `/adapt-to-stack` already reads from. The ticket asked for placeholders and the tree said otherwise.
- **To the *Which knowledge gets extracted into shared skills* fog patch:** nothing. `/prototype` is used by both paths and needed no branch, but its input is a design question rather than a file, so it is not the two-genuinely-different-inputs case the patch is waiting for. Recorded as *not a data point* rather than left to look like one.

---

## What #45 handed forward

- **To [#47](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/47), which it unblocked:** every flow the walkthrough must narrate now has a template on disk, so it can show a reader real commands rather than describing an intention. It also inherits **the restart line**: a walkthrough that runs the bootstrap end to end will hit the moment `.claude/agents/` and `.claude/skills/` come into existence, and a narration that omits the restart describes a session in which `/start-ticket` cannot dispatch. #47 still waits on #48 alone.
- **To [#17](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/17):** the flow catalogue's opening definition — *"a slash command that orchestrates a chain of scoped specialist agents"* — is now too narrow for a **fourth** row. `/bootstrap` runs alone, `/cut-backlog` files tickets, and `/adapt-to-stack` orchestrates nothing whatever. Three rows in the table it heads are not the thing it defines. Left untouched here, as #26 also left it.
- **To whoever generates files into a repo next:** **two directories the same flow writes to can resolve name collisions in opposite directions.** A personal skill beats a project skill; a project agent closest to the working directory beats one further up. Neither is wrong and nothing warns you, so a generated `<layer>-standards` can be shadowed everywhere by one stray personal skill while the generated `<layer>-specialist` beside it behaves exactly as expected. Now a convention in `templates/skills/README.md`.
- **To whoever writes the next make:** **a site can be falsified by your fix rather than by your landing.** `templates/agents/README.md:31` said the `model` field was used by *all* the agent templates; that became false four minutes after this session removed the field from `layer-specialist.md`, and no list written before the session could have contained it. #16's *re-grep your own output* covered the buffer you are writing; this is the file you edited two edits ago. **Re-grep after each structural edit, not only at the end.**
- **To anyone quoting a template's text in an instruction:** this session's own draft told the flow to delete a `COPY THIS FILE ONCE PER LAYER` opener from a template whose opener it had already rewritten. The fix generalises: **describe what a line *is* — provenance, routing, a rule — not what it *says*.** The agents README already carries this for frontmatter (*a capability description survives a harness change, a mechanism description rots into a lie*); it applies just as well to prose an instruction points at.
- **To the *Which knowledge gets extracted into shared skills* fog patch:** the path-agnostic collapse #15 found in design **survived contact with the mechanics** — writing the skill needed no branch anywhere either. That is one more data point and not the answer: a flow whose entire input is one file is still the easiest possible case.

---

## What #44 handed forward

- **To [#45](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/45), which it unblocked:** the marker to delete (the blockquote closing `11`'s *It never overwrites* section), and **six template sites that say *copy once per layer*** — `templates/skills/bootstrap/SKILL.md:140-141`, `templates/agents/layer-specialist.md:4` and `:10`, `templates/skills/engineering-standards/SKILL.md:4`, `templates/agents/README.md:129`, `templates/skills/README.md:42-45` and `:63`. All are **true today** because no flow ships, and all become false the moment #45 lands. The `bootstrap/SKILL.md` one is the odd one: its own *call the generation flow; do not reimplement it* rule sits four lines below the sentence that names the templates. Plus `repo.CLAUDE.md`'s new clause — **an unfilled `<model-id>` counts as absent, never as a model called `<model-id>`** — and the note that `templates/agents/README.md:69` is already done.
- **To [#48](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/48), which it opened:** the whole workspace-layer question, graduated from the *Single-vs-multi-repo for greenfield* fog patch now that #44 fixed the `11` half. The evidence that made it statable: **`workspace` appears nowhere in `docs/solo/`**, the bootstrap's step 3 writes exactly one `CLAUDE.md`, and `06-claude-md-layers.md` still assigns the new-branch workflow and the main-branch table to a layer the solo path never produces. Explicitly fenced off: where the **layer chain** lives, settled by #10 and routed by #44.
- **To [#17](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/17):** the stray-`-e ` count is **13**, not #16's 14, across 12 files with `PHILOSOPHY.md` holding two — with the list, and a note to recompute rather than trust it, since this is the second consecutive ticket to move the number.
- **To whoever writes the next make:** **a decision about *generated* output can contradict a convention written for *hand-written* output**, and neither file is wrong on its own terms. `templates/agents/README.md:69` said pipeline agents pin exact model ids deliberately; #15 said the generated specialists omit the field. The convention's reason — *cost and judgement should not swing with the session's model* — is sound for a human placing an agent they know, and simply unreachable by a generator that knows only a layer's name. **Grep the conventions, not only the claims**, whenever a ticket decides that something previously typed by hand is now emitted by a flow.
- **To anyone consuming a handoff on this map:** **a handoff's line number decays faster than anything else in it.** #44's body said `04-the-bootstrap.md:94`; the marker was at `:115`, moved by #42 and #43 in the two sessions between. #16's *a file and a line is still a summary* arriving from the cheap end — there the citation was wrong about its content, here merely about its address, and both fail the same way if obeyed literally.

---

## What #18 handed forward

- **To [#16](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/16), whose last blocker this was:** the `PHILOSOPHY.md` §8 replacement text, written out verbatim in a comment, because §8 names **story points and cache-reuse** as the universal units and #18 deleted both. Plus the reason it must move rather than `01-metrics.md`: §8 mandates (*"every pipeline run is costed"*) while the page implementing it excuses (*"this is optional"*), and #18 settled that measuring is optional. Plus two more sites — a **recommendation to leave** `PHILOSOPHY.md:142`'s one-sentence mindset (headline-then-nuance works *within* one file in the way it never works across two, which is exactly why the §8 pair was a defect and this is not), and `README.md:81`, still naming `11-metrics.md`, a path that today points at a different file.
- **To [#8](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/8), which gained a subject and a requirement:** #13's comment had handed #18 *what goes in the generated progress file*; #8's own body and the map's fog both claim it and only #12's gist pointed elsewhere, so **#18 stood down** — split on the verb, *measuring* (read every few months) against *status* (read for thirty seconds before work). The requirement: #5 settled that a charting session dying mid-ticket **posts a progress comment and keeps the claim**; if #8's answer to hole 1 gives the implementation pipeline the same shape, then **sessions per work unit = progress comments + 1**, read straight off the ticket. A nudge, not a constraint — #18's decision survives either way, worst case you count evenings from memory.
- **To the *Memory hygiene for solo* fog patch:** the golden-query eval **survives solo**, and it is the only measurement that keeps a non-negotiable reason — *you cannot notice a memory that never came back*, and being the only reader is no defence against silence. It **starts when the memory index no longer fits on one screen**, not on day one, since seam item 7 seeds exactly two. **Cadence is the patch's**, and `07-guardrails-when-solo.md` says so in its does-not-own table, so the boundary is written rather than assumed.
- **To whoever writes the next make:** **size is a claim about importance.** A new `docs/solo/08` was rejected because an eighth doc devoted to the optional thing tells a reader the opposite of the decision — writing a whole doc about it would have contradicted it. The corollary is the reason nothing was spawned: the escape valve fires on a *long discussion*, and six questions producing one section plus one blockquote is smaller than the ticket that would describe it.
- **To anyone reading a ticket body on this map:** **re-read the source, not the ticket's summary of it.** #18's headline fact was wrong on the day it was typed, and it named the research that refuted it.

---

## What #43 handed forward

- **To [#46](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/46), which it opened:** the whole `jq` question. Landed here because neither half needed a decision — `02-prerequisites.md` gains **`jq`** as required with the failure mode stated, and `templates/hooks/README.md` names the consequence and says the suite cannot tell you. **Left to #46:** whether a guardrail whose dependency is missing may simply not run. Four options, none obviously best — fail closed (and block the `git` commands you need to fix it), drop `jq` (and hand-roll a JSON parse in a security-relevant script), split the rule by hook, or detect once at setup (which is trust again the day `PATH` changes). It also needs a `test-hooks.sh` case that runs a hook with `jq` genuinely unavailable, which the current shim design deliberately prevents.
- **To [#16](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/16), its last make now closed:** four sites with the exact text they must carry, in a comment — `PHILOSOPHY.md:88` (*"AI-infra files are never committed"*, false on `master` now), `PHILOSOPHY.md:90` (*"You push; the agent doesn't"*, now per-repo), `README.md:134`, and **`templates/trackers/local-markdown.md:28`**, which nobody had listed because it **quotes** §5 rather than asserting it — right today, wrong the moment §5 is edited. Plus `12-when-not-to-use.md:96`'s *"git hooks still block push"*, which is in a file #16 already owns.
- **To [#45](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/45), unchanged:** its boundary said *do not touch `block-infra-staging.sh`*. That is done and the two-way sort is landed, so #45 has nothing left to wait for on this side.
- **To whoever writes a hook next:** the parse line is the whole dependency, and it is the third distinct way this directory has shipped a guardrail that reports success while guarding nothing. All three were found by **running** it. The suite proves the *patterns*; it cannot prove the hook runs on your machine, and it says so in its own first line of output.

## What #42 handed forward

- **To [#43](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/43),
  now unblocked — four sites its own body and #15's correction both missed.**
  `templates/claude-md/global.CLAUDE.md:82` (*"Never stage/commit AI-infra files"*), four
  lines below the `:76` it already owns and failing #14's sorting rule the same way — it
  states what is **permitted**, not what a flow does.
  `templates/skills/commit-conventions/SKILL.md:40`, the workspace-wide copy of the same
  claim, which #15 confirmed is a setup-time file rather than a generated one.
  **The `.gitignore` trio** — `templates/views/README.md:78`,
  `templates/skills/charting/SKILL.md:134`,
  `templates/skills/cut-backlog/SKILL.md:252` — all writing a **blanket** `.claude/` ignore
  line. And the **`/test-ticket` §6 knock-on**: `templates/commands/test-ticket.md:23`/`:33`
  and `docs/shared/07-the-flows.md:87` still say *staging only*, which on this path means
  nothing.
- **To #43, one thing already done: `04-the-bootstrap.md:150`.** #15 put it on that ticket's
  list; the same paragraph carried a second falsified claim — *"whether stage 3 ends with a
  commit is not settled here"* — which is reader-facing prose on nobody's list, so the whole
  paragraph was rewritten here rather than split across two tickets. **Do not re-edit it.**
  `04:39` and `04:261` (the step count) are untouched and still #43's.
- **To whoever writes the `.gitignore` exceptions:** deletion is wrong. #36 needs that line
  — the hook stops the viewer entering git, nothing stops it showing as untracked noise —
  so the ignore file has to sort the same way `block-infra-staging.sh` now sorts. If they
  disagree, staging a generated specialist needs `-f` and the flip has bought nothing.
- **Nothing to #16 beyond one fewer edge.** `PHILOSOPHY.md` §5 and §6 were left untouched,
  per this ticket's boundary; what #16 adds is the pointer plus the one sentence saying
  which clause solo removes.
- **Nothing verified live.** This doc ships no executable claim. The link and anchor check
  is the only verification it admits of, and it passed at 0 dead, 0 bad.

## What #15 handed forward

- **To [#44](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/44) (the
  doc):** rework `11-adapting-to-your-stack.md` in place as the explainer — steps 2 and 3
  stop instructing a human and start describing what `/adapt-to-stack` generates and why;
  step 4 and the alignment gate untouched, since neither is generated; the checklist becomes
  checks on the flow's output. **Say plainly that the day-one output is a scaffold.** Add the
  **optional per-layer model** to `repo.CLAUDE.md`'s chain section. Delete
  `04-the-bootstrap.md:94`'s marker for a live link — **the last dead forward link on the
  solo docs**. Fix `11`'s **multi-repo-shaped step 1** (it sends you to the *workspace*
  `CLAUDE.md` for a chain the solo case keeps in `repo.CLAUDE.md`), plus its `# 12` title and
  the stray `-e` at line 113, commenting on #16 and #17 so neither double-handles.
- **To [#45](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/45) (the
  template), blocked by #44:** one skill, `disable-model-invocation: true`, naming no path
  and no tracker. Read `CLAUDE.md`, stop if it is incomplete and **never write it**;
  generate specialists into `.claude/agents/` and standards skills into `.claude/skills/`;
  **never overwrite**; report **created / skipped / disagrees with `CLAUDE.md` / still a
  scaffold** and classify nothing. Fix `/bootstrap`'s catalogue row, which claims the layer
  specialists are something *"nothing else creates"*.
- **To [#43](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/43):**
  the amended hook rule and the four prose sites. See the gotcha above — this is the hand-off
  that a re-grep could never have produced.
- **To [#36](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/36),
  closed:** its decision stands, its stated reason narrows to *the viewer* rather than the
  directory. Recorded as a comment, because a closed ticket's resolution comment is where
  #30 found a stale count hiding and is the one place no grep of the tree reaches.
- **Left open and handed to nobody in particular:** whether a project-scoped
  `.claude/skills/` loads the way `~/.claude/skills/` does, and whether omitting `model:`
  inherits rather than refusing to launch — the shape #27 found the hard way on `tools:`.
  **Nothing in #15 is verified live.**

## What #38 handed forward

- **Every make on this map is landed. What is left is conversations.** #14, #15, #18, #41,
  plus the two side quests — all `grilling` except #23. That changes how to plan a session:
  a make ends when the file is on disk and you can see it coming; a decision ends when you
  and the agent agree, and nobody can predict when. **The banked-decision run that carried
  the last seven sessions is over.**
- **#41 is the one to take if you want the smallest of them**, and it has its alternatives
  already laid out. The question that separates them is **what regenerates the picture six
  weeks later**, when the session that created the tickets is gone and nobody holds the ids.
  That may also be out of scope — the picture is a charting-time convenience, and the
  pipeline may not need it.
- **#41 will touch the same five tracker files #39 did**, whichever way it lands, plus the
  `/cut-backlog` step-7 note. Nothing else consumes *the whole graph*.
- **The four solo templates are now a set, and the front door can describe it.** `charting`,
  `pitch`, `bootstrap`, `cut-backlog` — one per stage, each paired with its `docs/solo/`
  doc, two of them setting `disable-model-invocation: true`. #16 has been waiting to be able
  to say that.
- **Nothing in this session was verified live.** Same standing gap as #35: whether
  `disable-model-invocation: true` keeps a skill out of Claude's reach while leaving the
  slash command typeable is still a claim nobody has run. **#29's cheap half would settle it
  in ten minutes** — copy the template in, then try to get Claude to fire it unasked.

## What #40 handed forward

- ~~**#38 is unblocked and does not have to derive anything.**~~ **Consumed, and it held** —
  the block went into step 7 nearly verbatim, and the only thing it did not cover was the
  scoping question now in #41. Its step-7 block is posted on
  the ticket verbatim: ask for the whole graph, fill the slot in
  `~/.claude/dependency-graph.html`, write `.claude/dependency-graph.html`, ensure the
  ignore line, open it. Plus two facts it needs: a backlog gets the **legend only** (no fog
  sections), and its `blockedBy` comes from the **ticket body**, which the page neither
  knows nor cares about.
- **#18 gets a second, sharper fact.** Regenerating a status view over this map is **one
  request**, not two and not thirty-five. If #18 concludes the map and the backlog should be
  one artifact, the cost objection is gone.
- **#14 has one less collision to referee.** The viewer lands in `.claude/`, where
  `block-infra-staging.sh` refusing to stage it is the enforcement. The open half of #14's
  hook question is still the bootstrap's `CLAUDE.md`, which *should* be committed.
- **Found, not fixed:** the whole-graph GraphQL call uses `first:` caps rather than
  pagination. Correct at 35 children, 100 comments and 20 blockers; a bigger map needs
  `totalCount` checked. Written into `github.md` as the one failure that call can still
  have.

## What #39 handed forward

- ~~**#40 has a real adapter under it now.**~~ **Half right, and #40 found the other half.**
  `github.md` did carry both verbs verbatim and #40 wrote against a documented contract
  rather than derived incantations — but the whole-graph commands returned **no dependency
  edges**, only counts, so the page they paid for would have had no arrows. Now one GraphQL
  call. **A verb can be defined, verified live, and still not carry the thing its caller
  exists to draw.**
- ~~**#38 inherits the vocabulary, and it is now two composed verbs, not one.**~~ **Consumed
  by #38, and the second half was the important one.** The template quotes no count, so
  *twelve small and two composed* never came up. But the parenthetical — *"the phrase 'whole
  graph' reads as parent-scoped and the backlog has no parent"* — turned out to be a real
  hole in the contract, not a wording note, and it is now
  [#41](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/41). **A
  handoff bullet was right about the thing it mentioned in passing and wrong about which
  half mattered** — the same shape as #37's finding, one level up: what a session notes
  offhand is not ranked, and the reader inherits the ranking rather than the note.
- **#18 gets a fact about what a status view costs.** Both status artifacts are generated
  views over the same tickets, and *the whole graph* is what makes regenerating either one
  affordable — a fixed handful of requests rather than one per ticket. (#40 took it further:
  on GitHub it is **one**.) If #18 concludes the map and the backlog should be one artifact,
  this is the verb it would be built on.
- **#16 gains nothing and loses nothing.** The front door does not enumerate verbs. Checked,
  not assumed.
- **Left deliberately untouched: `docs/solo/03-charting.md` and
  `docs/shared/03-setup.md`.** Both name a few verbs in prose — *create*, *close*, *claim*,
  *is this blocked?*, *give me the frontier* — as illustrations, and both point at
  `templates/trackers/` for the full list. Neither states a count, so neither was falsified.
  An illustrative list is not a restatement, and turning one into a maintained copy of the
  vocabulary is how a second store gets built by accident.

## What #37 handed forward

- **The four stage docs exist end to end, which is the thing #16 was waiting to describe.**
  `docs/solo/` is 6 of 6. The capstone is still blocked by #14, #15 and #18 — #37 was never
  one of its edges — but the front door can now link a complete path rather than a partial
  one, and **the stage it must not call *the backlog* is now named *cutting* everywhere on
  `master`.**
- ~~**#38 is down to one blocker and inherits a marker to delete.**~~ **Done — the marker is
  deleted and no flow row was owed, exactly as predicted.** `05-cutting.md` shipped a
  deliberate dead link to `templates/skills/cut-backlog/SKILL.md` with a *still being
  written* blockquote beneath it — the kill-gate and bootstrap pattern, doc first. #38
  deletes the blockquote when the template lands. It also inherits the flow catalogue row,
  **already written**, so unlike #26 and #35 it does not owe one.
- **Found, not fixed — `docs/shared/12-when-not-to-use.md` is titled `# 13`.** Its heading
  still carries its pre-reorg number, from #19's renumber. Nothing links to it by number and
  no decision on this map depends on it, so it was left rather than swept into a rename
  ticket. **#16 owns the front door and is the natural place to catch it.**
- **`01-the-solo-path.md` now states the naming rule for both rows.** #12 found the rule
  broken three rows below where it is stated; the fix is not just the rename but the second
  sentence — *the stage is cutting, and the artifact it produces is the backlog* — so the
  next stage anyone adds has two worked examples instead of one.

---

## What #12 handed forward

- ~~**`docs/solo/05` has a name and an owner at last.**~~ **Landed by #37** —
  `05-cutting.md` is written, and `docs/solo/` is six of six.
- **#38 is the first ticket on this map born blocked**, and by two edges. That is deliberate:
  the viewer (#36) has to exist before step 7 of the template can be written, and the doc (#37)
  has to exist before the template has decisions to read. **The pair order is wired, not
  suggested** — #34 blocked #35 the same way, and that is the only mechanism that survives a
  session picking tickets by frontier order.
- **#18 inherits a fact rather than a question.** The map and the backlog are both in the
  tracker, in different shapes: a tree of children under #1, and a flat ordered set of
  standalone issues beside it that the map's frontier query deliberately cannot see. Whether
  they should be one status artifact is still #18's to decide; what they *are* is now fixed.
- ~~**#14 inherits a second collision.**~~ **Settled by #36 and shipped by #40**: the viewer
  lands in `.claude/`, and `block-infra-staging.sh` refusing to stage it is the enforcement
  rather than the obstacle. **Same hook, opposite verdict from the `CLAUDE.md` case #34
  handed #14** — and the difference is **provenance**, which is #34's point about a hook that
  expresses provenance as paths. #14 still owns the `CLAUDE.md` half.
- **#16 lost a blocker and gained an obligation.** Down to three edges — #14, #15, #18 — and it
  must not describe stage 4 by its old name. The front door is written last precisely so it can
  quote settled vocabulary; this is the first time the vocabulary moved under it.
- **The kill gate's first hard kill is now load-bearing three stages downstream.** *You cannot
  say what the first version is* stops being a judgement about seriousness and becomes a
  **precondition**: without that sentence, stage 4 has no source for its units and its scope
  check has nothing to trace against. Worth stating in `02-the-kill-gate.md` if #37 finds a
  natural place, but **not a licence to reopen #9**.
- **No memory written**, per #5's one-per-map rule. The map is still open.

---

## What #30 handed forward

- **A count inside a closed resolution comment is the one stale number nothing can find.**
  #21 §7 said *"only two seam checks are stack-specific — the other **five** do not vary by
  stack."* True at seven checks; wrong the moment #10 made it eight. `master` was never
  wrong, so no grep would have caught it — the error lived in the **tracker**, in the exact
  artifact this map treats as the durable record of a decision, and the only thing that
  surfaced it was a make ticket transcribing the decision into prose. **Recompute any count
  you are about to write down; do not transcribe it.** This is #35's lesson one layer in:
  #35 found a stale count inside the doc being written, #30 found one inside the ticket
  being read.
- **The take-a-number-at-write-time rule paid for itself.** #30 was forbidden from claiming
  a `docs/solo/` number in advance, which is why `05` is still free for #12 — the last stage
  doc — rather than occupied by the first non-stage one. The cost was #34 shipping two
  deliberately unlinked references for one ticket's duration. **That trade is worth
  repeating**: a reserved number that stays reserved beats a link that resolves one ticket
  earlier.
- **The re-grep found nothing on `master` — the second clean one in three tickets**, and for
  the reason #34 named: the decisions were carried inline in the ticket body, so the session
  was never guessing at what to search for. **Grep-the-concept is cheapest as advice to
  whoever writes the ticket**, and two tickets now say so.
- **#15 has a doc to link instead of a method to restate.** Read-level, mainstream-first,
  propose-and-kill, the three kill checks and the *who calls this?* test all live in
  `docs/solo/06-choosing-the-stack.md` now.
- **Deliberately left, so nobody re-derives it:** `01-the-solo-path.md` does **not** link the
  new doc. Its table indexes *stages*, `03` and `04` both route to it, and adding it to the
  spine's *tail goes last* row would start a pattern #12, #14, #15 and #18 each inherit —
  turning the spine into a link farm. One line to reverse if a later reader disagrees.
- **No memory written**, per #5's one-per-map rule. The map is still open.

---

## What #35 handed forward

- **The bootstrap pair is closed and nothing is owed back.** The marker is deleted, the
  catalogue row and README entry are in, and `04-the-bootstrap.md`'s only remaining dead link
  is `05-the-backlog.md` — #12's, and one `01` has always carried. Renamed by #12 to
  `05-cutting.md`; ~~the link is #37's to repoint~~ — **repointed, and the file it points at
  written, by #37. `04` now has no dead links at all.**
- ~~**#12 should go template-first.**~~ Three pairs were built and the pattern looked
  unambiguous: the only one that never shipped a dead link is charting, the only
  template-first one. **#12 could not take the advice** — its template is blocked by the
  viewer ticket, so the doc goes first and pays the marker a fourth time. The cost of
  doc-first is one commit of a knowingly false marker, now three times honoured — honoured
  because the tracking file said so, not because anything enforces it.
- **A convention got its first application, and the README now shows it working.**
  `disable-model-invocation: true` had a stated rule and zero users, which is how a rule
  quietly becomes decoration. `bootstrap` is the first skill in the set with side effects
  rather than a conversation. **When a convention has no instances, the next thing that
  matches it is worth applying it to loudly** — the README section was retitled, not just
  extended.
- **A skill's `allowed-tools` is not a fence, and this nearly mattered.** The instinct was to
  express the bootstrap's line as a tools restriction. For a *skill*, `allowed-tools` is
  pre-approval for the invoking turn, **not** a restriction — so that would have been a
  guardrail that guards nothing, the same class of error #28 found twice. The line is written
  as a rule in the body instead, which is #27's lesson landing on a skill rather than an
  agent: **describe what must not be accomplished, not the frontmatter you think expresses
  it.**
- **#29's cheap half has a new candidate.** The one claim here worth ten minutes of running:
  does `disable-model-invocation: true` keep the skill out of Claude's reach while leaving
  `/bootstrap` typeable? Nothing on this map has verified it.

---

## What #34 handed forward

- ~~**#35 owes a deletion, not just a file.**~~ **Done** — the marker is gone, one commit
  after it appeared, exactly as #26 did for #25's.
- ~~**#30 owes two link fixes.**~~ **Done** — both `04-the-bootstrap.md` sites now name
  `06-choosing-the-stack.md`, along with the third fix into `03-charting.md`'s tail section.
  **The mechanism worked exactly as intended**: #34 refused to guess a filename, wrote
  *"being written as its own doc"* and linked something that existed, and #30 filled it in
  one ticket later. ~~`04`'s only remaining dead link is **`05-cutting.md`**~~ — **#37 both
  repointed the link and wrote the file it points at. `04` is clean.**
- **#14's question got concrete, and it is a collision rather than a preference.** #10 handed
  it *does stage 3 end with a commit*. #34 found the sharper version: `PHILOSOPHY.md` §5 says
  AI-infra files are **never** committed to a product repo, and
  `templates/hooks/block-infra-staging.sh` blocks staging `CLAUDE.md` and `.claude/` at the
  tool layer — while **step 2 of the bootstrap writes a `CLAUDE.md` into the repo** and step 4
  may write `.claude/`. The stage's own output is unstageable under a hook the playbook ships.
  Stated in the doc as an open line, decided nowhere.
- **`repo.CLAUDE.md` gained a `## Serena` block and a two-shape layer section.** The verdict
  slot is what seam item 4 sends a reader to `CLAUDE.md` *for*; without it the seam pointed at
  a file with nowhere to look. The layer section now offers **A. this repo is the whole chain**
  (the solo shape) or **B. this repo is one layer among siblings** (the shape it only had).
  One line of the header comment was softened with it — *"let Serena find the code details"*
  → *"where Serena applies, let it find the code details"* — because a template asserting
  Serena three lines above a slot that may read **no** is the contradiction #31 named.
- **The re-grep found nothing, and that is the useful result.** Four tickets running had found
  a fifth site the body missed. #34's body listed four and there were four, because **#10
  widened the list while writing the body** rather than leaving the session to widen it. The
  lesson inverts cleanly: *grep the concept, not the wording* is advice for whoever **writes
  the ticket**, and it is cheaper there than in the session that has to act on it.

---

## What #10 handed forward

- ~~**The seam is eight checks, and item 8 is not on master yet.**~~ **Done by #34** — item 8
  is on the seam table, the count *seven* is retired from all four sites, and
  `01-the-solo-path.md` and `03-charting.md` are safe to quote as current again.
- **#34 and #35 carry every decision inline**, the same way #30 carries #21's. Neither
  writing session re-derives anything and neither may decide anything new. **both are done and both
  decided nothing** — though #35 did have to correct one of #34's numbers.
- **#15's boundary is settled and it is a three-way split**: #15 owns *how* the specialists
  are generated, stage 3 owns *when*, the seam owns *whether*. Its *how is the layer chain
  elicited* bullet has a floor on the solo path — **read it from `CLAUDE.md`** — while
  proposing a chain stays right for the agile path, where an existing repo has none declared.
  And its where-do-generated-files-land call now has a **second consequence**: `~/.claude/`
  means step 4 of the bootstrap stops for the human, `<project>/.claude/` means it does not.
  Posted as a comment on #15.
- ~~**#30's one open boundary is answered, and its body is updated.**~~ **Consumed** —
  **ticket 1 names the layer chain**, alongside the stack name and whether tests gate, and
  `06-choosing-the-stack.md` carries it as ticket 1's third decision with the *naming layers
  for an app with no folders* objection answered in place.
- **#14 inherits a named question:** whether stage 3 ends with a commit, and whether the
  agent may make it. `PHILOSOPHY.md` §5 governs *push*; commit-vs-push on a repo you own has
  never been settled, and stage 3 is the first stage that produces something worth committing.
- ~~**#12 should go template-first if it can.**~~ **It could not.** #10 chose doc-first for
  stage 3, and `04-the-bootstrap.md` duly shipped with a dead reference to #35's template for
  one commit — the same cost the kill gate pair paid, honoured because this file said so
  rather than because anything enforces it. It was the right call there (the doc carries the
  decisions and the template reads from it), and #12 turned out to be in the same position
  **plus** a blocker: #38 waits on the viewer, #36. **Template-first needs the mechanics to be
  settled before the design is, which has happened once in four pairs.**
- **The two-memory rule now has an explicit shape, not just a count.** Memory one is *what
  this project is and why*, written by charting when the map closes. Memory two is **only the
  reasoning** — why this stack, why this chain, what was ruled out — and never restates a
  fact that `CLAUDE.md` holds. Anything later that wants to add a day-zero memory has to
  argue against `CLAUDE.md` first.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #33 handed forward

- **The phrase is settled and on master, in all four places:** *a backlog of work units on a
  scaffolded repo that passes the seam.* **#16 must write exactly this** into the front door.
  Anything quoting the solo destination copies it verbatim rather than paraphrasing — four
  identical copies is the property that makes it safe to have four.
- **Seam item 4 is now named `Serena matches the verdict`.** The rename is load-bearing, not
  cosmetic: a check whose *name* asserts one branch restates the flat gate in the part of a
  table a reader actually skims. **Refer to item 4 by the new name.**
- ~~**#10 writes the branch a reader executes**~~ — **done, and it found the gap underneath.**
  Stage 3 writes the *no* branch's reason into `CLAUDE.md`, as step 2 of its checklist. But
  `templates/claude-md/repo.CLAUDE.md` **has no slot for the verdict at all**, so there was
  nowhere for stage 3 to write it. #34 adds the slot.
- **One asymmetry is deliberate, so nobody "fixes" it.** Three of the four sites link to the
  seam; `templates/skills/pitch/SKILL.md` names it without a link, because an installed
  skill lives at `~/.claude/skills/pitch/` and `docs/` is not installed beside it. Its one
  existing link (`../../agents/pitch-judge.md`) resolves in an install; a `docs/solo/` link
  would not. **A template's links must resolve where the template ends up, not where it is
  authored.**
- **Two sites in `03-charting.md` were fixed beyond the ticket's list** — the tail's second
  ticket now writes the Serena index check *if the verdict calls for one*, and stage 3 makes
  seam check 4 *hold on whichever branch the verdict put it*. Neither was a decision; both
  applied #21's existing conditional shape a second time.
- **#17's surface is untouched**, again. `12-when-not-to-use.md` gained one clause and
  nothing else — the stray `-e ` lines, the `# 13` H1 and the stale footer are still there,
  exactly as #25 and #26 left them.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #31 handed forward

- ~~**#10 is unblocked and inherits a fourth pre-answer.**~~ **Resolved.** Seam item 4 is
  **two branches on a verdict decided at the tail**, recorded in the repo's `CLAUDE.md`
  alongside the stack name, and #10 stated it rather than re-deriving it — step 3 of the
  bootstrap checklist is *index Serena **only if** the verdict says yes*. The one thing #10
  found underneath: the `repo.CLAUDE.md` template has no slot for the verdict.
- ~~**#33 owns every edit and must land them together.** Six edits, five files.~~ **Landed**
  — as **eight** edits in one commit, `2fa7e27`. The together-or-not-at-all instruction was
  the right call and the two extra sites are why: a re-grep found them, and half a fix of
  this shape leaves master contradicting itself, which is the defect the ticket existed to
  remove. #16 is down to five edges.
- **The seam is now the single home of the Serena condition.** Anything wanting to say when
  Serena applies should **link to seam item 4, not restate it** — that is why the destination
  string points at the seam instead of naming Serena.
- **The map's Destination is untouched, and the reason is worth keeping.** The string
  `/pitch` writes into a *reader's* map and issue #1's own Destination are **two artifacts
  that happen to share wording.** #21 settled the second; nothing had ever examined the
  first. Do not let a future ticket collapse them back together.
- **Three things were checked and deliberately left alone**, so nobody re-checks them:
  `03-setup.md`'s *Serena is mandatory* (global installation, not a project gate),
  `04-serena.md`'s escape 1 (*"the language/file isn't indexed"* — the mandate always
  governed **how you read code**, not whether a symbol graph must exist), and the charting
  skill's greenfield exception.
- **A third situation now exists and needs a name wherever sparse indexes come up:**
  day-one empty (correct), unfamiliar-and-sparse (stop), **symbol-poor by nature** (correct,
  and permanently so). #14 and #18 both touch judgement on a path with no reviewer and will
  meet it.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #21 handed forward

- ~~**The stack-choice method is settled and banked in #30.**~~ **Landed** —
  `docs/solo/06-choosing-the-stack.md`. Anything wanting to explain read-level,
  mainstream-first, propose-and-kill, the three kill checks, or the *who calls this?* test
  should **link to it, not restate it.** #15 in particular.
- ~~**#10 inherits three pre-answers and must state, not re-derive, all three**~~ — **done**,
  and the **open** question #21 refused is **answered: the stack ticket picks the layer
  chain**, not stage 3. Two reasons, both about when a person can actually decide — stage 3
  is a checklist you execute, and an architecture decision dropped into a checklist gets
  rubber-stamped; and stage 3 now *generates the specialists from the chain*, so deciding it
  there would mean deciding and consuming it in the same step. **Assigning the question to
  #10 rather than #21 was right for the same reason it was right the last time**: #10 is the
  ticket that would have had to live with a bad answer. #30's body carries it now.
- **#15's input is fixed and it is not the map.** It reads `CLAUDE.md` and memory two, both
  on the far side of the seam. **It must never reach back into the map** — the map may be
  closed by the time #15 runs, whereas `CLAUDE.md` is permanent. No new artifact was
  invented at the choosing→generating seam, which was the thing #21 was asked to name.
- ~~**Serena is conditional, and that is #31's to land.**~~ **Landed** — two branches on a
  verdict recorded in `CLAUDE.md`, and #31 did not drift into a destination redraw. The test
  is *will you ever need to
  ask "who calls this?"*. It bites **inside** the current destination — bash, Ansible and
  config-heavy repos are code, are in scope, and are symbol-poor. Do not let #31 drift into
  a destination redraw; its body says so explicitly.
- **The non-code fork is Out of scope on the map, not fog.** Kill gate and charting are
  already general (#5 made charting's destination an input); bootstrap and backlog are
  irreducibly code-shaped — for a spreadsheet project **4 of the 7 seam checks evaporate**,
  and the path's whole premise is handing off to a pipeline of layer specialists and Serena
  edits. So it is a **fork after charting with its own destination**, and the wayfinder
  contract makes that **a fresh effort, not a resumption**. Revisit when map #1 closes.
- **The driver redirected this ticket mid-grilling and was right.** The Serena-as-universal
  -requirement assumption had survived #3, #5, #20 and #22 unexamined. Worth remembering
  that the questions a ticket body lists are not the only ones on the table.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #28 handed forward (off-map)

- **`templates/README.md` exists** and is the directory's contract: what a template asserts,
  and the **nine-check re-verification list** with the doc page that settles each one. Run
  it when a footer version is bumped or after a release touching agents, skills, hooks or
  tools. Anything wanting to explain how templates are held to the harness should **link
  there, not restate it.**
- **Check 6b is the only one that executes anything**, and it exists because the other eight
  all passed while both git guardrails were open. `bash templates/hooks/test-hooks.sh` —
  run it, do not read it.
- **Two guardrails were not guarding, and both are worth a standing suspicion.** Whenever a
  matcher names one way of doing a thing, ask what the other ways are (`Bash` →
  `PowerShell`). Whenever an agent's prose names another agent, check `Agent` is in its
  tools. Neither failure produces an error.
- **The clean results are recorded too**, in the resolution comment — every agent/skill/
  command frontmatter key, every tool name, the MCP config shape, the Serena prefix warning.
  "We checked" is only useful if it says what was checked.
- **`README.md`'s repo-layout block is now stale in three ways**: pre-reorg flat docs, no
  `templates/trackers/`, no `templates/README.md`. Still **#16's**, deliberately untouched.
- **#17's footer work narrowed.** The templates-vs-docs footer question is settled in #28's
  direction, so what is left for #17 is purely the stale `2.1.219` *values* in `docs/`.
- **No memory written.** #5's one-per-map rule does not strictly bind an off-map ticket, but
  the map is open and nothing here is worth banking separately.

## What #27 handed forward

- **The mechanism is `tools: TodoWrite` + `maxTurns: 1`**, and it is **two guarantees on
  different axes** rather than one with a backup. The allowlist means the judge holds
  nothing that can find; the turn budget means it cannot act on a result whatever it holds.
  Neither depends on the other, which is the property `tools: []` was reaching for.
- **`disallowedTools` was considered and rejected here, not overlooked.** It is applied
  *first*, then `tools` resolves against what remains — so an allowlist of one already
  excludes everything and a denylist beside it narrows the same axis twice. It stays correct
  for the opposite shape: inherit broadly, subtract a few.
- **The residual risk is named.** A turn is one assistant message, so if the judge spends
  its single turn calling `TodoWrite` it returns no verdict. Unlikely — the prose forbids it
  and the one tool is not tempting — but **if it is ever seen, the fix is `maxTurns: 2`, not
  removing the field.** Two turns still cannot become a search pass, because the allowlist
  is doing that half.
- **"No tools" is retired from the playbook's vocabulary.** It appears in #9, in the agents
  README twice and in the template itself, and it was never what #9 meant. The replacement is
  **"gathers no evidence"** / **"weighs only"**. The rule underneath: **describe an agent by
  what it must not accomplish, not by the frontmatter you think expresses it** — a capability
  description survives a harness change, a mechanism description rots into a lie.
- **#9 carries a correction comment.** Its resolution comment is what Decisions-so-far
  regenerates from, so an uncorrected one would reprint the error on every rebuild. The
  intent is untouched and was never reopened; only the phrase changed.
- ~~**#28's scope moved in both directions.**~~ **#28 is closed** — it applied the
  transcription list, took the new background-subset suspect seriously enough to make it
  check 3, and inherited the agents anatomy block rather than re-deriving it.
- **Nothing is verified live.** Agent files load at session start, so the mechanism is
  correct-by-reading, not correct-by-running. **The next fresh session should spawn
  `pitch-judge` on a two-line case file** and confirm it launches and returns a verdict.
  Two minutes, and it is the only step that tests the harness rather than the docs. **Now
  owned by [#29](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/29)**,
  where it is the single most important untested claim in the repo.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #26 handed forward

- **The kill gate is complete** — stage doc, skill, agent, catalogue entry, both README
  rows. Nothing about the gate is outstanding.
- ~~**`tools: []` is wrong, and the branch it takes is undetermined.**~~ **Settled by #27** —
  it is the **refuse-to-launch** branch, stated outright on the errors page: subagents
  require at least one tool. **#28 applied `tools: TodoWrite` + `maxTurns: 1`**, so the file
  on disk is correct. #26 was right that both branches were unacceptable and right to
  withdraw the *fails safe* claim.
- **`<IDEAS-FILE-PATH>` is a placeholder that never resolves**, unlike
  `<TRACKER-ADAPTER-PATH>`. It is *supposed* to vary — #9's point was that the reader picks
  somewhere private they already back up. Nobody should ticket it.
- **#16 should expect the solo-only column to keep growing.** Three templates now claim it —
  the `charting` and `pitch` skills, and the `pitch-judge` agent. That is the pattern, not an
  exception.
- **It spun [#27](https://github.com/konstantinos-malavazos/claude-code-playbook/issues/27)
  after closing**, when its own *verify this later* note was verified immediately and turned
  out to be a defect. The decide-or-make rule held: the make stopped rather than deciding
  the fix. `maxTurns: 1` was the leading candidate and **#27 kept it, but not alone** — the
  allowlist half was the part #26 could not have guessed.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #25 handed forward

- **`docs/solo/02-the-kill-gate.md` exists.** Anything wanting to explain question zero, the
  three hard kills, the four anti-sycophancy mechanisms, the park trigger, the ideas file, or
  the spike clash should **link to it, not restate it.**
- **#26 has two obligations.** Delete the doc's *still being written* blockquote when the
  templates land, and do **not** restate the doc — same split as `03-charting.md` and the
  charting template. Everything #26 needs is in its own body plus #9's comment.
- **The anti-sycophancy four are now reader-facing in one place.** #9 asked that later
  tickets designing an honesty mechanism link rather than re-derive. That lands on **#14
  guardrails** and **#18 progress** in particular — both touch honesty on a path with no
  reviewer.
- **The doc decided nothing.** Where #9 left a reader-facing choice open — section order,
  what earns a table — the doc made the call without adjudicating in prose.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #9 handed forward

- **The gate is `/pitch`, and it is a skill plus a doc.** A doc alone cannot stop you nodding
  at your own checklist, and the gate has real AFK work a reader cannot do quickly. `/idea`
  was **rejected on principle** — this map ruled idea *generation* out of scope and that name
  promises exactly the thing the playbook refuses to do.
- **Question zero is the piece nothing on the map had.** *What does this idea's value rest
  on* — novelty, execution, or the building itself. It decides which later questions are
  allowed to kill **and** how the search agents are briefed, and it is asked **first** so you
  commit before you know which question is loaded. Without it the gate is uniformly harsh,
  which means it is uniformly ignored.
- **Sycophancy is beaten structurally.** Instructing a model to be harsh produces performative
  meanness that readers learn to ignore. What works: cold subagents that never heard your
  enthusiasm, the agent committing to its verdict **before** you give yours, a mandatory
  case-for-killing, and `pitch-judge` on an **anonymised case file**. Any later ticket
  designing an honesty mechanism should **link here, not re-derive it.**
- **A transcript cannot be anonymised** — one side asks every question and one side says *let
  me go and search*, so the judge identifies who is who in two lines. Hence a **case file**:
  no dialogue, verdicts labelled 1 and 2 in random order. Worth remembering for any future
  blind-review design.
- **The asymmetry that keeps the teeth:** the judge counts in **both** directions and breaks
  ties, but a hard kill that has fired **cannot be un-fired by anyone**. It can fire one the
  other two missed.
- **#25 and #26 carry every decision inline**, the same way #5 rewrote #11. Neither writing
  session has to re-derive anything, and neither may decide anything new.
- **The two cold searches are `/research` subagents**, not new agent templates — #5's
  points-at-skills rule. Only `pitch-judge` needed inventing.
- **A patch of fog closed without a ticket.** *Where ideas wait before the gate* is answered by
  the ideas file: unjudged entries are the inbox. Removed from **Not yet specified**.
- **#10 inherits nothing new**, but it should know the gate now produces a **seeded** issue #1
  — Destination, the premise, the smallest version, and the hard part as the first `research`
  ticket. Bootstrap still scaffolds and never creates.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #13 handed forward

- **`templates/trackers/` exists** — a contract README, three working adapters (GitHub,
  Jira, local markdown) and GitLab as a documented *shape*. Anything needing the verb list,
  the audience rule, or a tracker's traps should **link there, not restate them.**
- **The fixed path is `~/.claude/tracker.md`.** `<TRACKER-ADAPTER-PATH>` is resolved and
  concrete in the charting template; `03-charting.md` gained a link to the adapter README
  but still speaks only abstract verbs, which was #22's call and still holds.
- **#16's scope sharpened, and it is now a factual defect.** The README is the only file in
  the repo still saying the playbook assumes Jira — its tagline and opening sentence both
  do. #13 left them deliberately (positioning, not a noun swap, and #16 owns the rewrite)
  and **posted the specific line numbers and the reasoning as a comment on #16.**
- **#10 gets seam item 5 pre-answered.** *"The tracker adapter is installed"* means **verify
  this project's tracker matches the installed adapter**, not *go and install one* —
  installing is global, happens once at setup step 5, and the gate necessarily used a
  tracker to create the map before bootstrap ever runs. **State it; do not re-derive it.**
- **#23 now owns the only placeholder left** in the charting template.
- **The ticket's own file list was wrong twice, both times in the safe direction.**
  `ticket-analyzer.md` was already tracker-agnostic and `templates/commands/` never
  mentioned Jira. Worth remembering that a ticket body written weeks earlier describes the
  repo as it *was* — **re-grep before trusting a file list**, the same way every path in a
  ticket body needs re-resolving after the reorg.
- **No memory written**, per #5's one-per-map rule. The map is still open.

## What #22 handed forward

- **`docs/solo/03-charting.md` exists.** It is the reader-facing home for the charting
  stage. Anything wanting to explain the destination-vs-stopping-point distinction, the
  tail and its escape, the two endings, or what a charting session feels like should
  **link to it, not restate it.**
- **Two things were authored there that no ticket had settled.** The **cleared-vs-abandoned
  test** — *"would this fact have changed the gate's verdict, if you had known it at the
  gate?"*, explicitly not *"is this hard"* — and that **charting cannot reopen the kill
  gate**; the way to un-decide *build* is to abandon. Both are reader-facing guidance, not
  contract, and both are open to being pushed back on.
- ~~**#10** gets a promise it must keep: the doc tells readers the tail's checks are *what
  stage 3 runs to prove it is done.*~~ **Kept** — step 7 of the bootstrap checklist runs
  exactly those checks, and #10 added the part `03-charting.md` could not know: **all of
  them run, one report, and stage 3 classifies nothing.**
- **#21** must extend the tail rather than re-derive it — the rule, the reason product
  decisions go first, and the offline-question escape are all written out already.
- **#8** has a hook: the doc says a dying session posts a progress comment and keeps the
  claim, then defers resuming to "its own doc".
- **`<TRACKER-ADAPTER-PATH>` was deliberately left unnamed**, against what this file
  previously said #22 would supply. #13 owns the installed path; the doc speaks only the
  abstract verbs, so nothing breaks when #13 sets the value. **`<LABEL-PREFIX>` was left out
  entirely** — reader's own convention, and label naming is skill internals, out of place in
  a stage doc.
- **No memory written.** Same as #11 — #5's one-per-map rule, and the map is still open.

## What #11 handed forward

- **`templates/skills/charting/SKILL.md` exists.** Any later ticket that wants to explain
  fog of war, decide-or-make, the leading-gist rule, the ticket types, or the tracker verbs
  should **link to it, not restate it.** That is now the single source for the mechanics.
- ~~**#22** supplies the destination (`backlog + scaffolded + indexed`) and the solo-path
  values for `<TRACKER-ADAPTER-PATH>` and `<LABEL-PREFIX>`.~~ **Done, but only half of it.**
  #22 supplied the destination; it left both placeholders alone. See *What #22 handed
  forward* above for why.
- ~~**#13** owns `<TRACKER-ADAPTER-PATH>` and every verb name.~~ **Done** — the path is
  `~/.claude/tracker.md` and no verb was renamed, so the charting template needed only the
  one placeholder swapped.
- ~~**#23** owns `<PROTOTYPE-SKILL-OR-NONE>`. When the prototype template ships, the whole
  change is swapping that one cell in the types table.~~ **Done** — and the prediction was
  exactly right about the charting template: one cell, `/prototype`. **#11's three
  placeholders are now all closed or permanent.** What it could not predict is that the
  *rest* of the change ran to six files, none of them charting's.
- **No memory was written, on purpose.** #5 decided memory is one per map, at close. The
  map is open, so this ticket banks nothing. Expect the same for every remaining ticket.

## What #5 handed forward

- **#11** was rewritten, relabelled and retitled. It is now *Write the charting skill
  template*, labelled `wayfinder:task` (a **make**, not a grilling — the first application of
  decide-or-make to the existing map), and its body carries all eight contract decisions
  inline so the writing session does not have to re-derive them. Its stale flow-catalogue
  path was corrected to `docs/shared/07-the-flows.md`.
- **#8** must read #5's §8 before resolving. Charting owns the progress comment and the
  retained claim; everything after the map closes is #8's.
- **#22** must take the destination *from the solo path*, not from the skill. `03-charting.md`
  is where `backlog + scaffolded + indexed` gets stated, and it must not restate the seam.
- **Two new tickets, both side quests.** #23 *Write the prototype skill template* closes the
  one ticket type charting names with an empty shelf. #24 *The playbook's own
  domain-modeling skill* decides where a settled term lives — memory, `CLAUDE.md`, or the
  map's Notes — given the repo has no `CONTEXT.md` or ADR concept and already has two homes
  for durable knowledge.
- **A scope call left open for the driver.** #23 and #24 are arguably *tools the path uses*
  rather than the path itself. They were kept in scope on the ground that a reader hitting an
  empty shelf is a real defect — but ruling them out and spinning them into a separate effort
  is a legitimate call that has not been foreclosed.

## What #20 handed forward

- **#22 must not restate the seam** — `01-the-solo-path.md` owns it in full.
- **The stage docs inherit a house-style precedent**: table of question + exit condition, one
  ASCII diagram, a "why this doc exists" closer, `2.1.220` footer, and links out of
  `docs/solo/` written as `../shared/…`.

## What #4 handed forward

- **#13 the adapter templates** grew: a GitLab *shape* doc, a generated progress file for the
  local adapter, the `.scratch/` rename plus a `PHILOSOPHY.md` note about committing ticket
  files, the two-fields fix for `Status:`, and the GitHub command traps above. **Surgical
  means names and verbs, not voice.** One pass across the list, not one ticket per doc.
- **#12 the backlog ticket** creates work units through the contract's verbs only.

## What #3 handed forward

- **#8** has four named phases — and the backwards step means "which phase am I in" is not
  monotonic.
- **#9**'s build artifact is a **private repo with the map as issue #1**, agent-created.
- **#10** **scaffolds, never creates**; its exit test is the tail's stack-specific checks.
- **#12** runs **after** bootstrap, against a real indexed repo.
- **#14** — the `PHILOSOPHY.md` §5 exception granted at the gate is **one instance, not a
  precedent**. Interacts with #4's restatement of §5 as *"is anyone watching?"*.
- **#15** still starts from a stack already chosen; the choosing is #21.

---

## Standing context

`PHILOSOPHY.md` was written out of a workflow at a company where the driver does **not** own
the code or the projects — which is why it is so cautious. Its rules are **defaults with a
reason, not laws**. On a personal project, ask what a rule was protecting (usually *"other
people are watching"* or *"someone else owns this"*) and re-derive rather than obeying blindly
or deleting it. Note that this repo itself is **public**, so *"nobody is watching"* is not true
even here.

---

## Out of scope (settled — do not relitigate)

- Deployment / hosting / CI / release.
- Idea generation — helping you *find* what to build.
- Vendoring third-party skills into `templates/` (quality, not licensing).
