# Tracker adapter: Jira

Install at `~/.claude/tracker.md`. Tickets are Jira issues, reached through the Jira MCP
server registered in
[`../mcp/global.claude.json.snippet`](../mcp/global.claude.json.snippet) (what each entry
means: [`../mcp/README.md`](../mcp/README.md)).

**Is this a shared place?** **Yes** — corporate Jira is the case the audience rule was
written for. Every write needs explicit approval, with the exact payload shown first. This
is also enforced at the tool layer by
[`../hooks/block-mcp-writes.sh`](../hooks/block-mcp-writes.sh).

> **Tool names depend on which Jira MCP server you installed.** They are written below as
> `mcp__tracker__<verb>`, which assumes you named the server key `tracker` as
> [`../mcp/README.md`](../mcp/README.md) requires. The guardrail hooks match on that
> prefix. The **verb halves** are the
> part that varies by server. Confirm the real names with `/mcp` before trusting any of
> them: a wrong tool name fails the same silent way a wrong Serena prefix does.

---

## The verbs

| Verb | How |
|---|---|
| create | `mcp__tracker__create_issue` — project, issue type, summary, description |
| read | `mcp__tracker__get_issue` by key, **plus its comments** — one call if your server takes a fields/expand argument (ask for `comment`), otherwise a second `mcp__tracker__get_comments`. Confirm which with `/mcp`; see [`README.md`](README.md) |
| list | `mcp__tracker__search` with JQL |
| comment | `mcp__tracker__add_comment` |
| close | transition to your done status — **not** a `close` call; see below |
| reopen | transition back to an open status |
| edit body | `mcp__tracker__update_issue` on the description field |
| link child to parent | set the `parent` field (or the epic link on older instances) |
| label | `mcp__tracker__update_issue` on `labels` |
| claim | `mcp__tracker__assign_issue`, then read it back |
| mark blocked | an **issue link** of type `Blocks` / `is blocked by` |
| is this blocked? | read the issue's links, then **read the state of each blocker** |
| retitle | `mcp__tracker__update_issue` on the summary field. The key is the identity, so links survive |
| delete a ticket | **the one verb this adapter fakes outright.** Most Jira MCP servers expose no delete tool, and the *Delete Issues* permission is usually withheld anyway. So: transition to done, label it `<LABEL-PREFIX>:void`, and record the key on the map. Check `/mcp` before assuming you have a real delete. If you do, it is still the wrong default on a shared tracker |

## The frontier

Two steps, because JQL cannot express it in one. JQL can filter on *having* a link type. It
cannot filter on the **state of the linked issue**. So the adapter narrows server-side and
finishes client-side:

```
parent = <MAP-KEY> AND statusCategory != Done AND assignee IS EMPTY ORDER BY created ASC
```

Then, for each result, read its `is blocked by` links and drop any whose blocker is not
`statusCategory = Done`. First survivor in map order wins.

**This two-step is invisible to the caller.** A skill asks for the frontier and gets a list.
That the adapter did the blocked-filter itself is the adapter's business. That is the
contract working as designed.

## The whole graph

Every ticket with state, claim, blockers, description **and** comments. **Two scopings, one
verb** — the children of a parent, or a named set of tickets — and one JQL search carries
the first four either way. Only the scoping clause changes.

Scoped by parent — a map and its children:

```
parent = <MAP-KEY> ORDER BY created ASC
```

Scoped by a named set — a backlog of work units, which has no parent to scope by:

```
key in (<KEY-1>, <KEY-2>, <KEY-3>) ORDER BY created ASC
```

JQL has `key in` natively, so the second scoping costs a clause, not a call.

Jira is comfortable here: `issuelinks` returns the linked issues' **keys**, so a caller
drawing the graph gets real edges. GitHub's REST payload returns a count instead, which is
why its whole graph goes through GraphQL — the same verb, a different amount of trouble.

**Return each blocker's status with its key.** On the parent scoping you can work it out
from the result — every blocker of a child is another child, so its status is already
there. On a named set you cannot: `key in (…)` returns exactly the keys you named, a
blocker outside that list is simply absent, and a caller that treats an absent blocker as
still open draws a ticket blocked by something that closed weeks ago. Jira's own
`issuelinks` carries the linked issue's `fields.status`, but **whether your MCP server
passes that through is a `/mcp` check, not an assumption** — where it does not, read the
status of each blocker the search did not return. Same client-side finish the frontier
already does here, and invisible to the caller for the same reason.

Comments are the part that varies. **If your server exposes the search's fields or expand
argument, ask for `comment` and the whole graph is a single call.** Jira returns comments
inline with the issue, which no other tracker here does. If it does not, you are down to
one comment read per ticket, and Jira has no repo-wide comments endpoint to fall back on
the way GitHub does. Check with `/mcp` before you assume either.

That check is worth making once and writing down, because this verb exists for callers that
regenerate a view on every run. On the expensive branch, cache the result within the
session rather than asking twice.

## Traps

| Trap | Why it bites |
|---|---|
| **Closing is a transition, not a verb** | Jira has no universal `close`. Every workflow names its own done status, and an invalid transition id fails loudly. Look up the available transitions for the issue, then apply the one your project uses. Record which status you settled on here: `<YOUR-DONE-STATUS>`. |
| **`statusCategory` beats `status`** | `status` is a per-workflow string that varies by project; `statusCategory` is one of three fixed values. Filter on the category and your JQL survives a workflow rename. |
| **`parent` vs. the epic link** | Newer Jira uses a real `parent` field; older instances use a custom epic-link field whose id differs per instance. Check which one your instance answers to before writing hierarchy. |
| **Issue keys are not stable across a project move** | `PROJ-123` becomes `NEW-45` and the old key becomes a redirect. Rare, but it is the one case where "identity is a stable id" needs the *issue id*, not the key. |
| **Labels cannot contain spaces** | Jira silently splits or rejects them depending on the endpoint. Use kebab-case. |

## Notes

**Blocking is native and universal here.** Unlike GitLab, the `Blocks` link type is
available on every Jira tier, and Jira renders it in its own UI. The verb is still *is this
blocked?* — the adapter still has to go and read each blocker's status, because the link
alone does not tell you whether the blocker is done.

**The claim is real, but still read it back.** Jira assignment is a genuine server-side
write with permissions behind it. A caller lacking assign permission gets an error rather
than GitHub's silent no-op. Read it back anyway. The habit is what makes the skills
portable.
