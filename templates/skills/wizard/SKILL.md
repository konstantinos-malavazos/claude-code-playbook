---
name: wizard
description: >-
  Generate an interactive bash wizard that walks a human through a manual procedure only
  they can perform — provisioning infrastructure, credentials and CI secrets, an unfamiliar
  third-party dashboard, a one-off migration or cutover. Use when the blocking work is
  manual and tedious to re-explain every time. NOT for a step an agent can perform itself.
---

# Wizard — a script that walks the human through what only they can do

It opens each URL, says exactly what to click and copy, captures the values, writes them
where they belong, confirms at every stage, and shows how many stages are left.

> Prior art: Matt Pocock's `wizard` skill (MIT). `template.sh` is included **verbatim**; this
> file is a re-derivation that lands the script under the repo's own guardrails.

## The library is not yours to edit

`template.sh` ships beside this skill and already solves the UX — stage progress, confirmation
gates, cross-platform URL opening, hidden secret entry, idempotent `.env` upserts,
`gh secret` / `gh variable` writes, a closing summary. Everything above the `STAGES` marker is
identical in every wizard, and that sameness **is** the point.

**Without `template.sh` this skill does nothing.** Install both files or neither.

## Scope it from the repo, not from the user

Read before you ask. For setup: `.env`, `.env.example`, `.env.*`, the README,
`docker-compose*`, framework config, and `.github/workflows/*` — **every `secrets.*` and
`vars.*` reference is a value the wizard must produce.** For a migration: the current state,
the target state, and the irreversible actions between them.

Then show the user the ordered stages and the value each produces, and confirm. They may add,
drop or reorder.

**Done when** every stage is named in order, and for each captured value you know where the
human gets it, where it is written (`.env`, a CI secret, both, or nowhere — some stages are
pure actions), and whether it is secret.

## Never invent a UI step

Where you do not know the current dashboard or the exact command, **say so and ask, or check
the docs**. A stage naming a button that does not exist strands the human halfway through a
procedure they cannot finish and cannot judge — the one failure a wizard makes worse than no
wizard.

## Author the stages

Copy `template.sh` to the target path, replace the example stage with one `stage` per step in
dependency order, and set `TOTAL_STAGES`. The helpers are `stage`, `say`/`step`, `open_url`,
`ask`/`ask_secret`, `write_env`, `set_secret`/`set_var`, `pause`/`confirm`.

Hold the bar the template sets: open the URL **before** asking for its value, `ask_secret` for
anything secret, `write_env` every persisted value, `set_secret` only what CI actually needs,
and `confirm` before anything irreversible. Each stage clears the screen, so keep it to one
focused task — anything the human still needs must not scroll away.

## Verify, then hand off — do not run it

`bash -n <script>`, `shellcheck` if it is installed, `chmod +x`.

**Do not run it end to end yourself.** It opens browsers and blocks on human input. Trace it
statically instead: every value from scoping is captured and lands where scoping said, and
every `set_secret` name matches a `secrets.*` reference in CI exactly.

## Where it lives, and what it must never hold

Ephemeral by default — a scratch path or `scripts/`, deleted when the job is done. Commit it
only when the user wants a repeatable setup path, and then link it from the README so the next
person runs the script instead of re-asking an AI.

**The script holds no captured values, ever.** Secrets are entered at run time through
`ask_secret` and land in `.env` or the CI store. A wizard with a key baked into it is a
credential in version control wearing a helpful costume.

## Stop condition

Stop when the script parses, every scoped value traces to where it lands, and the user has
been told how to run it. **Running it is theirs.**
