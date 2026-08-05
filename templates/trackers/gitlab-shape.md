# Tracker shape: GitLab

**This is not an adapter. It is the shape of one.**

The verbs are stated; the commands are yours to write and verify. GitLab ships this way for
one reason: **its API documentation is demonstrably wrong about blocking**, and nothing
here could be confirmed against a live instance. Shipping commands nobody has run is worse
than shipping none — a wrong command in an adapter fails at the worst possible moment,
mid-session, on someone else's map.

To use GitLab, fill this in against your own instance, verify every line, and install the
result at `~/.claude/tracker.md`.

**Is this a shared place?** Same question as any hosted tracker — `<yes | no>`.

---

## The two traps to verify first

These are the reason this file exists. Check both before writing a single command.

### 1. Blocking is Premium-only, and the docs do not say so

The issue-links API carries a blanket **Free / Premium / Ultimate** availability badge.
It is wrong. On the Free tier, creating a `blocks` link returns **403**, while `relates_to`
on the same endpoint succeeds — so the failure looks like a permissions problem with your
token rather than a tier limit, and you will go and re-scope the token for nothing.

**If you are on Free, blocking has no native representation at all.** Fall back to a
`Blocked by: #<n>` line in the description and answer *is this blocked?* by reading each
listed issue's state — the same way the local-markdown adapter does. That fallback is not
a downgrade of the contract; it is the contract working.

### 2. Parent → child is GraphQL-only

The REST API has no usable one-level hierarchy for issues. Epics are a separate object on
paid tiers with their own endpoints, and plain issue hierarchy is only reachable through
GraphQL. Budget for a GraphQL client, or express the parent as a `Part of #<map>` line in
the description and find children by search.

---

## The shape to fill in

| Verb | GitLab surface | Verified? |
|---|---|---|
| create | `glab issue create` | ☐ |
| read | `glab issue view <n>` **and its notes** — `read` means the issue *and* its comments; find the flag or endpoint that returns them and verify it does | ☐ |
| list | `glab issue list -F json` | ☐ |
| comment | `glab issue note` — GitLab calls comments **notes** | ☐ |
| close | `glab issue close` — takes **no** closing comment; note first, then close | ☐ |
| reopen | `glab issue reopen` | ☐ |
| edit body | `glab issue update --description` | ☐ |
| link child to parent | **GraphQL, or a `Part of #<map>` line** — see trap 2 | ☐ |
| label | `glab issue update --label` / `--unlabel` | ☐ |
| claim | `glab issue update --assignee` | ☐ |
| mark blocked | **Premium only** — see trap 1 | ☐ |
| is this blocked? | read each blocker's state | ☐ |
| **the frontier** | list children, drop blocked and claimed, first in map order | ☐ |
| **the whole graph** | every child with state, claim, blockers, description and notes | ☐ |

## The two composed verbs, and the third trap hiding in them

Both composed verbs assemble many tickets at once, so both are where a per-issue request
loop turns a cheap view into an expensive one. Before you settle for one call per ticket,
check two things against your instance:

- **Does listing issues return descriptions**, or only titles and metadata?
- **Is there a project-wide notes endpoint**, or is it strictly per-issue? GitHub has a
  repo-wide one; whether GitLab has an equivalent is exactly the sort of thing this file
  will not guess at.
- **Do the blocking links come back as ids, or as a count?** GitHub's REST payload gives a
  count — enough for *is this blocked?* and useless for drawing the graph, which is what
  sends its whole graph to GraphQL. A count here would mean a request per blocked issue.
  Ask *by what?*, never *how many?*

Neither answer changes the verb. They change whether it is affordable to call it often,
which is the whole reason it is a verb.

## Smaller differences worth knowing

- **GitLab creates labels on the fly.** GitHub does not. If you port a command sequence
  between them, the GitHub side needs an explicit label-create step and the GitLab side
  does not — this asymmetry is easy to miss in exactly one direction.
- **Issues and merge requests are numbered separately**, so `#42` is unambiguous once you
  know which surface is meant. GitHub shares one number space across both.
- **Merge requests are the PR analogue** — `glab mr` mirrors `gh pr`, with `note` and
  `--message` in place of `comment` and `--body`.

## When you finish

You will have written a real adapter. Consider contributing it back in place of this file.
