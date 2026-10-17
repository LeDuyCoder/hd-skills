---
project: "{{project_slug}}"
module: decision
paths:
  - "{{affected_repo_paths}}"
last_verified_commit: "{{commit}}"
updated: "{{timestamp}}"
tags:
  - project
  - adr
  - status-accepted
summary: "{{decision_in_one_sentence}}"
---

# ADR-{{number}}: {{decision_title}}

- Status: proposed | accepted | superseded | rejected
- Date: {{date}}

## Context

What constraint or problem requires a decision?

## Decision

State the selected option in a sentence, then explain the key implementation implications.

## Alternatives considered

List plausible alternatives and why they were not selected.

## Consequences

Record benefits, costs, migration needs, and conditions that would justify revisiting this decision.
