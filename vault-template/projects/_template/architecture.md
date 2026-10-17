---
project: "{{project_slug}}"
module: architecture
paths:
  - "{{repo_relative_paths_for_architecture}}"
last_verified_commit: "{{commit}}"
updated: "{{date}}"
tags:
  - project
  - architecture
summary: "{{one_or_two_sentence_architecture_summary}}"
---

# {{project_name}} architecture

## System boundary

Describe the process boundary, external services, storage, and main entry points.

## Component and data flow

```mermaid
flowchart LR
    User[User or caller] --> Entry[Entry point]
    Entry --> Core[Core module]
    Core --> Storage[(Storage or external service)]
```

Replace this example with components and arrows found in the source. Label assumptions and asynchronous boundaries.

## Important flows

1. Name the triggering input.
2. Follow the data through the relevant modules.
3. Record side effects and failure handling.

## Module notes

| Module | Responsibility | Note |
|---|---|---|

## Boundaries and risks

Record coupling, runtime configuration, or areas where a small change has broad effects.
