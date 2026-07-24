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

## When Serena, when grep, when read

- **Serena** — any *code-structure* question in a language it indexes: locating a
  symbol, its references/implementations/declaration, what it does, or reading before a
  surgical edit.
- **grep** — text that isn't a symbol (config strings, log messages, TODO markers) or
  files in a language Serena doesn't index.
- **whole-file read** — small files, non-code files, or when you genuinely need the full
  context of a short file.

Encode this as a rule in your global CLAUDE.md and (optionally) a `check-code` skill so
the agent reaches for Serena *before* grep by default.

---

## How it plugs into the flow

Serena is **project-scoped** (`<workspace>/.mcp.json`) because it indexes a working
copy. Every agent that reads code — the gatherer, the planner, the specialists, the
reviewers — uses Serena first. Combined with Forgetful (which recalls *what/why* and
often *which symbols matter*), the loop is: memory says "look at `ToBetFeesModel`" →
Serena jumps straight to it → surgical edit. No file spelunking.

Config snippet: [`../templates/mcp/project.mcp.json.snippet`](../templates/mcp/project.mcp.json.snippet).
-e 
---
> **Last verified against:** Claude Code `[run \`claude --version\` and insert here]` — July 2026
