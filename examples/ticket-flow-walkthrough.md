# Example — a `/start-ticket` run, narrated

A generic, sanitized walkthrough so you can picture the flow before you build it. The
ticket, stack, and names are invented; substitute your own. Assume a three-layer chain:
**data model → backend API → frontend**.

---

**You type:**
```
/start-ticket PROJ-482
```
> PROJ-482: "Users can set a display timezone; times in the activity feed render in it."

---

### 1. `@ticket-analyzer`
Reads PROJ-482, writes `handoffs/PROJ-482/ticket-analyzer.md`:
- **Goal:** per-user timezone preference, applied to activity-feed timestamps.
- **Acceptance criteria:** [ ] preference persists · [ ] feed renders in it · [ ] default = account region.
- **Topic terms for the gatherer:** `User`, `ActivityFeed`, timestamp formatting, user-preferences.
- **Open questions:** what's the default when the region is unknown?

### 2. `@context-gatherer` (throwaway context)
- **Memory query** → finds a prior memory: *"timestamp rendering was centralized into
  `formatFeedTime()` last quarter; don't format in components."*
- **Code-nav** → `find_symbol formatFeedTime`, `find_referencing_symbols` → 6 call sites,
  all in the feed. `User` model has no `timezone` column yet.
- Writes `context-gatherer.md`: blast radius = the `User` table, the prefs API, and
  `formatFeedTime`. Flag: *don't reintroduce per-component formatting.*

### 3. `@planner`
Reads both briefs, does a pinpoint read of `formatFeedTime`, writes `planner.md`:
- **slice-count: 1** (small, sequential).
- **Steps:** add `timezone` to `User` (migration) → expose it on the prefs API + thread it
  into `formatFeedTime` → add a settings control + pass the value through.
- **Track allocation:** data-model → backend → frontend, in that order.
- **Open question for grilling:** default when region unknown?
- **Final commit message:** `feat(profile): per-user display timezone for activity feed [PROJ-482]`
- Cuts the branch `PROJ-482_display-timezone` (fetch → main → pull --rebase → branch).

### 3b. Grilling gate
> Planner asks you: *"Default timezone when the user's region is unknown — UTC, or the
> server's local zone?"* You answer **UTC**. (Cheap to reverse; no deferral needed.)

### 4. Layer specialists, in order
- **data-model specialist:** adds the `timezone` column via a migration; handoff records
  *"column `timezone` (string, IANA name, nullable, default NULL → treat as UTC)."*
  Amends → 1 commit. Tests green.
- **backend specialist:** reads that contract; exposes `timezone` on the prefs endpoint;
  threads it into `formatFeedTime(ts, tz)`. Handoff records the API field name. Amends.
- **frontend specialist:** adds the settings dropdown; passes the saved value through.
  Amends.
- **alignment check** (3 layers touched): column `timezone` ↔ API field `timezone` ↔ UI
  binding all agree. ✅

### 5–6. Review
- `@reviewer`: all ACs met, tests pass, branch is **1 commit**, convention OK. Drafts the
  PR description. Provisional: APPROVE.
- `@senior-reviewer`: checks consumers of `formatFeedTime` across repos — the change is
  backward-compatible (tz optional). No downstream break. Appends: APPROVE.
- Final verdict: **APPROVE**.

### 7. Land
- Orchestrator consolidates one durable memory: *"Per-user timezone lives on `User.timezone`
  (IANA, null=UTC); feed formatting stays centralized in `formatFeedTime(ts, tz)`; default
  unknown-region = UTC (decided PROJ-482)."*
- Handoff files evaporate at session end.
- **You** push the branch and open the PR.

---

### What to notice
- The **memory hit in step 2** stopped a whole class of mistake (formatting in
  components) before design even started.
- The **planner never touched code or memory**; the **reviewers never touched code**.
- The branch is **one commit**; the only durable artifact besides the code is **one
  memory** — which will answer the *next* timezone question in one query.
