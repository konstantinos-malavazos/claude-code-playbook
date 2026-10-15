# 04 — Serena: eyes on the code (pillar one)

**What it is:** an MCP server that wraps a Language Server (the engine behind "Go to
definition" in your IDE). Claude asks for a *symbol* and gets back exactly that symbol
with its precise `file:line`, instead of reading the whole file and guessing names.

Serena is open-source and language-agnostic (it speaks the Language Server Protocol, so
any language with an LSP is covered: TypeScript, Python, Go, Rust, C#, Java, …).

---

## Why it matters

| Question | Without Serena | With Serena |
|---|---|---|
| "Where is `processPayment` and what does it do?" | read 3–5 candidate files (~10k+ tokens), guess the name, maybe read the wrong file first | `find_symbol(include_body=true)` → the exact body + `file:line` (~a few hundred tokens) |
| "What's the shape of this 400-line file?" | read all 400 lines | `get_symbols_overview` → every class/method by name (~a few hundred tokens) |
| "Who calls this function?" | grep the string, sift false positives | `find_referencing_symbols` → the real call sites, semantically |
| Editing | hunt for the line range by eye | exact `start_line`/`end_line` for a surgical edit |

The typical result is **several times fewer tokens for a better answer**. It also kills
the guess-the-name round trip. Serena tells you the symbol is *actually* called
`KnownRegionsV2`, not `KnownRegions`.

---

## The core tools (what to reach for)

| Intent | Serena tool |
|---|---|
| "What's in this file / package?" | `get_symbols_overview` |
| "Show me the implementation of X" | `find_symbol` (with `include_body`) |
| "Who calls / references X?" | `find_referencing_symbols` |
| "Where is X declared?" | `find_declaration` |
| "What implements this interface?" | `find_implementations` |
| Surgical edit of one symbol | `replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol` |

---

## Mandatory, not preferred

In this playbook Serena is **not** a "reach for it first" nicety. The rule is:

> **Serena is the only sanctioned way to read code, and the only sanctioned way to change
> it.**

Both directions matter. Reading by symbol is what makes the agent accurate. *Writing* by
symbol (`replace_symbol_body`, `insert_after_symbol`, `rename_symbol`,
`safe_delete_symbol`) is what stops the classic failure modes — an `Edit` applied to a
stale line range, a find/replace rename that misses a call site or hits a comment, a
deletion whose references nobody checked. `get_diagnostics_for_file` then closes the loop
before the build runs.

Claude Code's own auto mode complicates this: it nudges the agent toward Bash — `cat`,
`grep`, `sed`, quick scripts — treating `Read`/`Edit`/`Write` as the fallback. That nudge
is meant for non-code artifacts, and the template states the boundary outright: on a code
file, the Serena rule above wins. The conflict is worth naming explicitly because the
auto-mode instruction is injected by the harness at runtime, so it never shows up in a
repo's `settings.json` for a human to spot — and after the fact, a grep-derived answer
reads exactly like a symbol-verified one. Stating the precedence up front is what keeps
that difference visible instead of silently eroding.

### The only escapes
1. The language/file isn't indexed by Serena.
2. The target is a non-symbol string (config keys, log messages, TODO markers) — try
   `search_for_pattern` first, grep only if it can't reach it.
3. Serena errors on the path.

An agent taking an escape must **say which one**. For a write, an unusable Serena means
**stop and surface it** — never a silent downgrade to `Edit`. And sparse Serena results
are a finding about your index, not permission to go back to file spelunking.

One Serena answer is not a failure: **"No active project"**, which can come when more than one
Serena project is registered. The agent activates the project for the repo it is working in
with `activate_project`, retries once, and stops only if that fails.

`Read`/`Grep`/`Glob` stay in every agent's tool list, because agents must read handoffs,
docs and config. They just aren't a code path.

Where this is encoded: the **Serena is MANDATORY** section of
[`../../templates/claude-md/global.CLAUDE.md`](../../templates/claude-md/global.CLAUDE.md), and
the [`code-access`](../../templates/skills/code-access/SKILL.md) skill, which every agent that
declares Serena tools preloads through its `skills:` frontmatter. Each agent under
[`../../templates/agents/`](../../templates/agents/README.md) keeps only its job-specific part:
which tool it checks for, and where it halts.

---

## How it plugs into the flow

Serena is **project-scoped** (`<workspace>/.mcp.json`) because it indexes a working
copy. Every agent that touches code — the gatherer, the planner, the specialists, the
reviewers — names Serena's tools outright in its frontmatter and preloads the mandatory
protocol, the `code-access` skill. The specialists' *edits* go through it too. Forgetful recalls *what/why*
and often *which symbols matter*, so the loop is: memory says "look at `ToBetFeesModel`" →
Serena jumps straight to it → surgical edit. No file spelunking.

Config snippet: [`../../templates/mcp/project.mcp.json.snippet`](../../templates/mcp/project.mcp.json.snippet)
— paste it as-is. The plugin-vs-entry choice and the tool-prefix trap are in
[`../../templates/mcp/README.md`](../../templates/mcp/README.md).

## Gotchas

- **A type-qualified lookup comes back empty → retry with the bare member name.** Generic
  type parameters change a symbol's name path, so `Type/Member` can miss where `Member`
  alone finds it.
- **An empty result is not proof of absence.** It is a finding to report, with what you
  searched for. Never read it as "nothing calls this".
- **Restore or build dependencies before indexing.** A language server that cannot resolve
  a package reports its references as missing, and the gap looks like dead code.
- **Some language servers ignore `ignored_paths` when they discover projects**, so an
  excluded folder can still be indexed. It varies by version, so record the Serena version
  you saw it on: `uvx --from git+https://github.com/oraios/serena serena --version`, or the
  plugin's version.
- **Serena's line numbers are 0-based** — `body_location`, and the `>N:` lines in
  reference snippets. Add one before you quote a `file:line`.
- **An agent's `skills:` preload — what the `code-access` skill rides on — needs no `Skill`
  grant, but a skill that sets `disable-model-invocation: true` is not preloaded at all**,
  and nothing warns you. Observed on Claude Code `2.1.300`.

## Optional: replace the connect-time prompt

When Serena connects, it sends a short prompt that tells the agent to call
`initial_instructions` before any coding task. The playbook's agents already carry their
protocol in the `code-access` skill, so that call only spends context. You can override the
prompt — a manual, optional step:

1. `serena prompts create-override system_prompt.yml` creates your own copy of the file
   that holds `connection_prompt`. `serena prompts list-overrides` shows where it went.
2. In that copy, replace the `connection_prompt` text with something like:

   ```
   You have Serena's semantic code tools. Use them to read and change code: find a symbol
   before you read a file, and check its references before you change a signature.
   ```

Run `serena` the same way you installed it (`uvx --from git+https://github.com/oraios/serena
serena …` when it is not on your PATH). The installer does **not** write into `~/.serena`,
so this step is yours.

---
> **Last verified against:** Claude Code `2.1.226` — August 2026
