---
name: review-guidelines
description: >-
  The house review standard — the rules every code review in this workspace judges against,
  on top of each layer's own standards skill. Loaded by the repo-reviewer agent before it
  walks a diff. Ships unfilled: until the marker line below is deleted, the reviewer ignores
  this file and judges with its own built-in severity terms.
---

STATUS: NOT FILLED IN YET — delete this line when the sections below hold your standard.

# House review standard

Write the rules a reviewer here should hold every change to, whatever the language. Rules
for one language or layer belong in that layer's generated standards skill, not here.

## House rules

- (Your rules. One line each: what a reviewer checks, and what counts as a miss.)

## Severity, as this team uses it

The review output is built on these four tags. Keep the tags; say what each means here.

- `[BLOCKER]` —
- `[MAJOR]` —
- `[MINOR]` —
- `[NIT]` —

## Keeping your version

Once you edit this file, the installer keeps it on every later run and lists it as kept.
Keep yours. Copying the shipped file over it puts the empty stub back.
