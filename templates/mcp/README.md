# MCP config snippets

Three files, three destinations. **Each snippet is valid JSON with no comments in it** —
copy the body straight into your file, nothing to strip. Everything that used to be a `//`
line lives here, under the entry it explains.

| Snippet | Merge into | Scope |
|---|---|---|
| [`global.claude.json.snippet`](global.claude.json.snippet) | `~/.claude.json` | every project |
| [`project.mcp.json.snippet`](project.mcp.json.snippet) | `<workspace>/.mcp.json` | one working copy |
| [`settings.json.snippet`](settings.json.snippet) | `~/.claude/settings.json` | model, env, hooks wiring |

Merge the `mcpServers` entries into your existing file rather than replacing it, and keep
secrets in environment variables.

## Rules for every server entry

**`"type"` is REQUIRED** — `stdio` | `http` | `sse` | `ws`. An entry with a `url` and no
`type` is read as a **stdio** server and skipped with an error naming it.

**`${VAR}` expands from your environment.** If the variable is UNSET and has no
`:-default`, the config still loads and the literal `${VAR}` text is used — the server
starts with a garbage token and only `claude mcp list` warns. Use `${VAR:-default}` where a
fallback makes sense.

**Run `claude mcp list` after every edit.** It names each config file and its state, so it
catches both halves of what goes wrong here: a file that doesn't parse is reported as
`[Failed to parse]` with its path, and an unexpanded `${VAR}` draws a warning. It does
**not** validate `~/.claude/settings.json` — that file's own check is a real session.

---

## `~/.claude.json` — global servers

Global scope is for servers that aren't tied to one working copy:

- **`forgetful`** (memory) is global — your knowledge spans projects.
- **`tracker`** is global — the same tracker across projects.

Serena is **project** scope instead (below), because it indexes a working copy.

### `tracker`

**Name the key `tracker`, not after your vendor.** The guardrail hooks match on
`mcp__tracker__*`, and the adapter at `~/.claude/tracker.md` is what knows the vendor.
Omit this server entirely if your tracker is local markdown files.

### `db` — optional, not in the snippet

A read-only staging DB server for data sampling:

```json
"db": { "type": "stdio", "command": "...", "env": { "CONN": "${STG_DB_CONN}" } }
```

---

## `<workspace>/.mcp.json` — project servers

These are tied to THIS working copy. Enable them in
`<workspace>/.claude/settings.local.json` via `"enabledMcpjsonServers"` (or
`"enableAllProjectMcpServers": true`).

### `serena`

**Only needed if you did NOT install the `serena` plugin** (see
[`docs/shared/03-setup.md`](../../docs/shared/03-setup.md) step 2). The plugin route is
simpler and is the recommended default; if you use it, **delete this entry** — two
registrations means two tool namespaces, which means confusion.

**Tool prefix — this must match what your agents' `tools:` lists say:**

| Route | Prefix |
|---|---|
| this `.mcp.json` entry (key `serena`) | `mcp__serena__find_symbol` |
| the plugin install | `mcp__plugin_serena_serena__find_symbol` |

A prefix that doesn't resolve fails **silently**: the agent gets no code tools and falls
back to reading whole files. Verify with `/mcp`.

### `gitlab` / `github`

Pick ONE git host, or keep both if your org uses both. The snippet ships `gitlab`; the
GitHub equivalent is:

```json
"github": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}" }
}
```

---

## `~/.claude/settings.json` — model, env, hooks

### `model` and `effortLevel`

`effortLevel` takes `"low"` | `"medium"` | `"high"` | `"xhigh"`.

**There is no `theme` key in this snippet, on purpose.** It could not be confirmed in the
settings key reference, and an unrecognised key here is ignored **silently** — a line that
does nothing looks exactly like one that works. Set your theme with `/config` instead.

### `env`

Environment variables available to MCP config (`${VAR}`) and to hooks. **Never inline
secrets** — tokens should come from your real environment, not be written here.

### `hooks`

The `hooks` block in the snippet is the same content as
[`../hooks/settings-hooks.snippet.json`](../hooks/settings-hooks.snippet.json). Keep only
the hooks you actually installed into `~/.claude/hooks/`; what each one does is in
[`../hooks/README.md`](../hooks/README.md).
