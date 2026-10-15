---
name: code-access
description: >-
  The code access protocol every Serena agent runs under — Serena is the only way to read
  or change code, the three escapes, the tool-list check that halts an agent whose Serena
  tools were stripped, the "No active project" retry, and the paragraph every
  implementation dispatch carries. Preloaded into each Serena agent through its `skills:`
  frontmatter; a dispatching command reads its Dispatch paragraph. Not for general coding
  questions.
---

# Code access

Serena is the **only** sanctioned way to read code and the only sanctioned way to change it.
This is a rule, not a preference. Your own agent file adds what is specific to your job: the
tools you check for, where you halt, and any extra write or evidence rules. Where it says
more than this skill, it wins for your job.

## Reading

- Any code-structure question — where is X, who calls Y, what implements Z, what does this
  body do, read-before-edit — goes through `find_symbol`, `find_referencing_symbols`,
  `find_implementations`, `find_declaration` and `get_symbols_overview`.
- `Read`/`Grep`/`Glob` are for **non-code artifacts only**: handoffs, docs, config, data,
  build manifests. A `Read` or `Grep` in your `tools:` line is not permission to read code
  with it.
- Cite what Serena returned: the symbol and its real `file:line`. A name you inferred from a
  filename, a grep hit or a brief is not a citation. Serena's line numbers — `body_location`
  and the `>N:` lines in reference snippets — are 0-based: add one before you quote a
  `file:line`.
- An empty result is a finding to report, not proof of absence, and never permission to
  grep instead.

## The three escapes — name the one you used

1. The language or file is not indexed by Serena.
2. The target is a non-symbol string — a log line, a config key, a TODO. Try
   `search_for_pattern` first.
3. Serena errors on that path.

Anything else is not an escape. Every time you take one, say which, in your handoff or
reply.

## Check your tools before step 1

Your frontmatter names your Serena tools, but a name that does not resolve — a wrong
`mcp__` prefix, an unfilled placeholder — is **stripped at launch with no error and no
notice**. So look at your own tool list before you do anything else. Your agent file names
the tool to check for (your **halt check tool**). When it names none, check for
`find_symbol`.

If that tool is missing, write the HALTED block below where your agent file says to halt
(your **halt destination**: a heading in your own handoff, or your reply when you write no
file), and stop there. Do not fall back to `Read`/`Grep`: a result you produced without
Serena reads exactly like one you produced with it, and nobody downstream can tell.

```
## <halt destination heading>
The code access protocol could not be followed. Tools present: <tools present>.
Nothing was produced. Fix the tool names (see templates/agents/README.md) and re-run.
```

Your agent file may add a line saying what it did **not** do — no branch cut, no file
edited — so the reader knows nothing half-done exists.

## "No active project" is not a halt

That answer can come when more than one Serena project is registered. It does not mean
your tools are missing. Call `activate_project` with the project for the repo you are
working in (its folder name, or its path), then retry the call once. Halt only if the
activation fails or the retried call still fails, and then say in your HALTED block that
activation was tried and failed, instead of naming missing tools.

## Dispatch paragraph

Every command that hands work to an implementation agent pastes the paragraph below into
the dispatch prompt — the first dispatch and every re-dispatch: a review fix, a drift fix,
a route-back, an alignment return. Fill `<live tools>` with the Serena tool names that
resolve in the session right now. Paste it as it stands; do not paraphrase it.

> **Serena, in this run.** Your live Serena tools are: `<live tools>`. Find every symbol
> with `find_symbol` or `get_symbols_overview` before any `Read` or grep. Call
> `find_referencing_symbols` before you change any signature, and update every caller it
> returns. Rename with `rename_symbol`, never a find-and-replace sweep. Run
> `get_diagnostics_for_file` on each file you changed, before the build. If a tool named
> here is missing from your own tool list, say so in your first message. The plan's file
> list says **where** to change code, not **who depends on it** — Serena answers that.
