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
| "Where is `loadSettings` and what does it do?" | read 3–5 candidate files (~10k+ tokens), guess the name, maybe read the wrong file first | `find_symbol(include_body=true)` → the exact body + `file:line` (~a few hundred tokens) |
| "What's the shape of this 400-line file?" | read all 400 lines | `get_symbols_overview` → every class/method by name (~a few hundred tokens) |
| "Who calls this function?" | grep the string, sift false positives | `find_referencing_symbols` → the real call sites, semantically |
| Editing | hunt for the line range by eye | exact `start_line`/`end_line` for a surgical edit |

The typical result is **several times fewer tokens for a better answer**. It also kills
the guess-the-name round trip. Serena tells you the symbol is *actually* called
`SettingsSchemaV2`, not `SettingsSchema`.

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
and often *which symbols matter*, so the loop is: memory says "look at `ReportBuilder`" →
Serena jumps straight to it → surgical edit. No file spelunking.

Config snippet: [`../../templates/mcp/project.mcp.json.snippet`](../../templates/mcp/project.mcp.json.snippet)
— paste it as-is. The plugin-vs-entry choice and the tool-prefix trap are in
[`../../templates/mcp/README.md`](../../templates/mcp/README.md).

## Route C — one server per repo

Routes A and B run **one** Serena server for everything. With many or large repos that one
server gets slow: its cache grows, a cold start can time out, and every agent waits in the
same queue. Route C gives each repo its own server, started only when you need it. It is
optional. Most people never need it.

**Setting it up — the installer does the work:**

1. Set up Route A or B first ([03-setup.md](03-setup.md#step-2--stand-up-serena-eyes)), then
   run the installer and answer **C** at the Serena question.
2. The installer looks for git repos in the folder your playbook clone sits in, gives each
   a key and a pair of ports, and shows you the list. It saves the list to
   `~/.claude/serena-repos.json` and wires every Serena agent to those servers.
3. Your repos live somewhere else? Run the installer with that folder named, for example
   `SERENA_REPOS_DIR=/c/code bash install.sh`.
4. Cloned a new repo later? Run `bash install.sh serena-wire` (PowerShell:
   `powershell -ExecutionPolicy Bypass -File .\install.ps1 serena-wire`). New repos are added to the end of the list; nothing already
   in it changes.
5. Something in the list is wrong? Fix that line in `~/.claude/serena-repos.json`, or delete
   the file, then run `bash install.sh serena-wire` again.

**Using it:**

- Start the servers for the repos you are about to work in:
  `bash ~/.claude/serena/serena-up.sh <key> [<key> …]`. Add `--edit` when an agent will
  change code (PowerShell:
  `powershell -ExecutionPolicy Bypass -File ~/.claude/serena/serena-up.ps1`, same arguments). The keys are
  the names in `serena-repos.json`. The first start of a repo can take a few minutes while
  Serena indexes it.
- `serena-up` waits until each server answers a real code question. If it prints
  **`symbols not verified`**, the server is running but no source file in that repo gave
  back any symbols — normal for a repo of docs only; for a code repo, check that its
  language is one Serena supports.
- Stop them when you are done: `bash ~/.claude/serena/serena-down.sh`. When a new session
  starts, Claude is told about any still running from before and passes it on to you.
- An agent whose server is not running stops and names the exact `serena-up` command.

What changes for the agents: each one gets its own `mcp__serena-<key>__…` tools per repo,
there is no `activate_project`, and the main session reads code through `@serena-lookup`
instead of calling Serena itself. Agents a repo generates for itself (under
`<repo>/.claude/agents/`) are wired with `bash install.sh serena-wire <repo>/.claude/agents`;
Claude Code loads their servers only after you trust that folder. Trust it once by opening
Claude Code there in a normal window: a headless `claude -p` run never asks, so its agents
start without their servers and halt. `update` keeps the wiring
it recorded, and `remove` leaves your repo list and the server state alone. You can turn the
Serena plugin off once route C works; route C does not use it.

The connect-time prompt below applies to route C servers too, and is still a manual step.

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
