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
| read | `gh api repos/<owner>/<repo>/issues/<n> --jq '.title, .body'` — **not `gh issue view`**, see traps |
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

**`<db-id>` is the issue's numeric database id, never its `#number`.** Get it with
`gh api repos/<owner>/<repo>/issues/<n> --jq .id`.

## The frontier

One call. Open, unblocked, unclaimed children of the map, in map order:

```bash
gh api repos/<owner>/<repo>/issues/<map>/sub_issues --paginate \
  --jq '.[] | select(.state=="open") | select(.assignees|length==0)
            | select(.issue_dependencies_summary.blocked_by==0) | "#\(.number)\t\(.title)"'
```

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

## Notes

**Blocking is native here, and that is worth using.** GitHub renders issue dependencies in
its own UI, so the frontier is visible to a human who never opens the map. This is the one
tracker where the blocking edge is both stored *and* trustworthy — but the verb is still
*is this blocked?*, so skills stay portable.

**The claim is still advisory.** GitHub silently ignores an assignee write from a caller
without push access and returns success anyway. Always read the claim back before working.
