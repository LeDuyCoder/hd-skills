---
project: "{{project_slug}}"
module: "{{module_slug}}"
paths:
  - "{{repo_relative_path}}"
last_verified_commit: "{{commit}}"
updated: "{{date}}"
tags:
  - project
  - module
summary: "{{one_or_two_sentence_module_summary}}"
---

# {{module_name}}

## Responsibility

State the behavior this module owns and what it deliberately leaves to other modules.

## Key files and symbols

| Path | Symbol / purpose | Notes |
|---|---|---|

## Inputs, outputs, and side effects

Describe important public functions, events, HTTP/API contracts, persistence, and errors. Link to source files instead of copying code.

## Dependencies

List direct internal and external dependencies that affect changes here.

## Change impact

Name tests and neighboring modules likely to be affected.
