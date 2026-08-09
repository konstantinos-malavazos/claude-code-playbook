---
name: wait-what
description: Stop. That last message did not land — re-pitch it.
disable-model-invocation: true
---

# Wait, what? — the last message did not land

Stop and re-pitch it:

- **Context first.** One or two sentences on what we are deciding, before anything else.
- **Simplified Technical English** ([ASD-STE100](https://www.asd-ste100.org/)) — short
  sentences, one idea each, plain verbs, no term the design has not defined yet.
- **The names this effort already settled** — the map's `Notes` or the repo's `CLAUDE.md`
  where either exists, otherwise the words this conversation has already used. Never a second
  word for a thing that already has one.

**Do not rephrase. Re-explain from the concrete thing** — the file, the map section, the
line. The same abstraction in different words fails twice.

> Prior art: Matt Pocock's `wait-what` skill (MIT). Same move; this one reads vocabulary off
> the map's `Notes` rather than a `CONTEXT.md`, which this playbook does not use.
