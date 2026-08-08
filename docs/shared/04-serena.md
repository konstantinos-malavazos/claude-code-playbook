# 04 — Serena: eyes on the code (pillar one)

**What it is:** an MCP server that wraps a Language Server (the engine behind "Go to
definition" in your IDE). Claude asks for a *symbol* and gets back exactly that symbol
with its precise `file:line` — instead of reading the whole file and guessing names.

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

The typical result is **several times fewer tokens for a better answer**, plus it kills
the guess-the-name round trip — Serena tells you the symbol is *actually* called
`KnownCompaniesRtbc`, not `KnownCompanies`.

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

Both directions matter. Reading by symbol is what makes the agent accurate; *writing* by
symbol (`replace_symbol_body`, `insert_after_symbol`, `rename_symbol`,
`safe_delete_symbol`) is what stops the classic failure modes — an `Edit` applied to a
stale line range, a find/replace rename that misses a call site or hits a comment, a
deletion whose references nobody checked. `get_diagnostics_for_file` then closes the loop
before the build runs.

### The only escapes
1. The language/file isn't indexed by Serena.
2. The target is a non-symbol string (config keys, log messages, TODO markers) — try
   `search_for_pattern` first, grep only if it can't reach it.
3. Serena errors on the path.

An agent taking an escape must **say which one**. For a write, an unusable Serena means
**stop and surface it** — never a silent downgrade to `Edit`. And sparse Serena results
are a finding about your index, not permission to go back to file spelunking.

`Read`/`Grep`/`Glob` stay in every agent's tool list — agents must read handoffs, docs and
config. They just aren't a code path.

Where this is encoded: the **Serena is MANDATORY** section of
[`../../templates/claude-md/global.CLAUDE.md`](../../templates/claude-md/global.CLAUDE.md), and
a *Code access protocol (MANDATORY)* block in every code-touching agent under
[`../../templates/agents/`](../../templates/agents/README.md).

---

## How it plugs into the flow

Serena is **project-scoped** (`<workspace>/.mcp.json`) because it indexes a working
copy. Every agent that touches code — the gatherer, the planner, the specialists, the
reviewers — names Serena's tools outright in its frontmatter and carries the mandatory
protocol block; the specialists' *edits* go through it too. Combined with Forgetful (which recalls *what/why* and
often *which symbols matter*), the loop is: memory says "look at `ToBetFeesModel`" →
Serena jumps straight to it → surgical edit. No file spelunking.

Config snippet: [`../../templates/mcp/project.mcp.json.snippet`](../../templates/mcp/project.mcp.json.snippet).
---
> **Last verified against:** Claude Code `2.1.226` — August 2026
