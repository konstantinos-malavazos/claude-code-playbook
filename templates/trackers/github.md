# Tracker adapter: GitHub

Install at `~/.claude/tracker.md`. Tickets are GitHub issues; the `gh` CLI does the work.
`gh` infers the repo from `git remote -v` when run inside a clone.

**Is this a shared place?** `<yes for any repo other people can see — including a PUBLIC
personal repo | no for a private solo repo>`. This answer decides whether writes need
approval; see the audience rule in [`README.md`](README.md).

---

## The verbs

| Verb | Command |
|---|---|
| create | `gh issue create --title "..." --body "..."` (heredoc for multi-line) |
| read | **two calls, one verb** — `gh api repos/<owner>/<repo>/issues/<n> --jq '.title, .body'` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments --paginate --jq '.[].body'`. The body alone is the question with the answer missing; see [`README.md`](README.md). **Not `gh issue view`**, see traps |
| list | `gh issue list --state open --limit 200 --json number,title,labels` |
| comment | `gh issue comment <n> --body "..."` |
| close | `gh issue close <n>` |
| reopen | `gh issue reopen <n>` |
| edit body | `gh issue edit <n> --body-file <file>` |
| link child to parent | `gh api repos/<owner>/<repo>/issues/<parent>/sub_issues -X POST -F sub_issue_id=<child-db-id>` |
| label | `gh issue edit <n> --add-label "..."` / `--remove-label "..."` |
| claim | `gh api repos/<owner>/<repo>/issues/<n>/assignees -X POST -f "assignees[]=<user>"`, then read it back |
| mark blocked | `gh api repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -X POST -F issue_id=<blocker-db-id>` |
| is this blocked? | `gh api repos/<owner>/<repo>/issues/<n> --jq '.issue_dependencies_summary.blocked_by == 0'` — `true` means takeable |
| retitle | `gh issue edit <n> --title "..."` — sub-issue and dependency links are by id, so retitling never breaks one |
| delete a ticket | `gh issue delete <n>` — **needs admin on the repo and cannot be undone.** Leave a line on the map saying the number existed and why it is gone; GitHub never reuses it |

**`<db-id>` is the issue's numeric database id, never its `#number`.** Get it with
`gh api repos/<owner>/<repo>/issues/<n> --jq .id`.

## The frontier

One call. Open, unblocked, unclaimed children of the map, in map order:

```bash
gh api repos/<owner>/<repo>/issues/<map>/sub_issues --paginate \
  --jq '.[] | select(.state=="open") | select(.assignees|length==0)
            | select(.issue_dependencies_summary.blocked_by==0) | "#\(.number)\t\(.title)"'
```

## The whole graph

Every child with its state, claim, blockers, body **and** comments — what a generated view,
an audit, or a rebuild of the map's decision list needs. **Two scopings, one verb: the
children of a parent, or a named set of tickets.** Both are **one GraphQL call. Not REST:**

**Scoped by parent** — a map and its children:

```bash
gh api graphql -f query='
{ repository(owner:"<owner>", name:"<repo>") {
    issue(number:<map>) { number title url body
      subIssues(first:100) { nodes {
        number title state url body
        assignees(first:5){ nodes { login } }
        labels(first:10){ nodes { name } }
        blockedBy(first:20){ nodes { number } }
        comments(first:100){ nodes { author { login } createdAt body } }
      } } } } }'
```

**Scoped by a named set** — a backlog of work units, which has no parent to scope by.
**Aliasing is what makes a named set as cheap as a parent:** one alias per issue number,
the same fields under each, still one request.

```bash
gh api graphql -f query='
{ repository(owner:"<owner>", name:"<repo>") {
    i2: issue(number:2) { number title state url body
      assignees(first:5){ nodes { login } }
      labels(first:10){ nodes { name } }
      blockedBy(first:20){ nodes { number } }
      comments(first:100){ nodes { author { login } createdAt body } } }
    i3: issue(number:3) { … }
    i4: issue(number:4) { … }
  } }'
```

Verified live on this repo: three issues, every field including the `blockedBy` edges, in
**0.545 s, one request.** The plain way for a dozen units is `read` twice each plus one
`…/dependencies/blocked_by` per unit — because `issue_dependencies_summary` is counts —
which is **about 36 requests against one.** The alias keys are yours; the caller reshapes
with `--jq` as it would for the parent-scoped form.

**REST cannot answer this verb, and it fails by looking like it has.** The
`…/sub_issues` payload carries `issue_dependencies_summary`, which is **four counts** —
`blocked_by`, `blocking`, `total_blocked_by`, `total_blocking`. Counts answer *is this
blocked?* and nothing else: they never say **which** tickets, so a caller drawing arrows
gets a graph with no edges, and one that tries anyway is back to a
`…/issues/<n>/dependencies/blocked_by` request per ticket. GraphQL exposes `blockedBy` as
a real connection, which is what makes one call enough.

Verified live on a 35-child map: **1.3 s, ~520 KB, 48 comments, 16 blocked-by edges, one
request.** The REST shape is 2 calls for bodies and comments plus one per blocked child,
and the naive shape — read each ticket, then read its comments — is 70.

**The `first:` arguments are caps, not pagination.** They are set above the sizes any map
here reaches; ask for `totalCount` beside any connection you suspect of overflowing, and
page it if it does. A silently truncated graph is the one failure this call can still have.

`gh api` takes a `--jq` filter, so a caller that wants the answer in its own shape — a
generated view's data slot, say — gets the fetch *and* the reshape in this one call.

Two REST calls remain useful when you want comments and **no** graph — the repo-wide
`gh api repos/<owner>/<repo>/issues/comments --paginate` endpoint returns every comment in
the repo in one paginated call, joined on `issue_url`.

## Traps — all of these have bitten, all are verified

| Trap | What actually happens | Do this instead |
|---|---|---|
| **`gh issue list --json` cannot see hierarchy** | `parent` and `subIssues` fail with `Unknown JSON field`. There is no flag that fixes it. | The `gh api …/sub_issues` call above. It is the *only* working frontier query. |
| **`-f` on an id field** | Sends the id as a string; the API rejects it with `is not of type integer`. | `-F`, which sends a number. Applies to both sub-issue and dependency writes. |
| **`gh issue list --limit` defaults to 30** | Silent truncation — no warning, no error, just a short list. | Set `--limit` explicitly, always. |
| **`gh api` with a leading slash on Git Bash for Windows** | `/repos/…` is rewritten to `C:/Program Files/Git/repos/…` and 404s. | Omit the leading slash: `repos/…`. |
| **`gh` will not auto-create labels** | Applying an unknown label fails. (GitLab creates on the fly; GitHub does not.) | `gh label create` first. |
| **`total_blocked_by` never decreases** | It counts closed blockers too, so it is never `0` on a ticket that was ever blocked. | Use `issue_dependencies_summary.blocked_by`, which is open blockers only. |
| **`gh issue view <n>` can print nothing** | Observed on Windows: no output, no error, exit 0. | Read through `gh api …` as in the table above. |
| **`issue_dependencies_summary` is counts, not ids** | Four integers. It answers *is this blocked?* and cannot answer *by what?*, so a REST-only whole graph draws boxes and no arrows. | GraphQL `blockedBy`, as in the whole-graph call above. |
| **`gh api …/issues/<n>` carries no comments** | The payload's `comments` field is a **count** and `comments_url` is a link — the comment bodies are not there. On a closed ticket that is the question without the answer, and it fails silently. | The two-call `read` above. Never treat one call as a read. |
| **`blocked_by` lags a close** | Verified: closing a blocker and immediately reading the blocked ticket returned `blocked_by: 1` while **GraphQL `blockedBy` showed every blocker already closed** — the same instant, two endpoints, two answers. It settled to `0` about thirty seconds later with no intervening write. So *is this blocked?* can report a blocker that no longer exists, and the frontier query silently hides a ticket that just became takeable. | Re-read before believing a non-zero count you did not expect, and check `blockedBy` states when it matters. **The summary is eventually consistent; the graph is not.** |

## Notes

**Blocking is native here, and that is worth using.** GitHub renders issue dependencies in
its own UI, so the frontier is visible to a human who never opens the map. This is the one
tracker where the blocking edge is both stored *and* trustworthy — but the verb is still
*is this blocked?*, so skills stay portable.

**The claim is still advisory.** GitHub silently ignores an assignee write from a caller
without push access and returns success anyway. Always read the claim back before working.
