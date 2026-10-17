---
project: "{{project_slug}}"
module: session
paths:
  - "{{paths_changed_or_inspected}}"
last_verified_commit: "{{commit}}"
updated: "{{date}}"
tags:
  - project
  - session
summary: "{{task_and_current_state_in_one_sentence}}"
---

# Session {{date}} — {{task_title}}

## Goal and result

State the request and what changed or was learned.

## Files and verification

- Files changed or inspected:
- Commands run and exact outcomes:
- Checks not run and why:

## Decisions and open issues

- Decisions (link an ADR when one was created):
- Open questions, risks, or blockers:

## Next action

Give the next agent one concrete starting action and the files/notes to read. Never repeat secrets or large source snippets.
