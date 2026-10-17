---
project: demo-node
module: overview
paths:
  - "package.json"
  - "src/index.js"
  - "src/greeting.js"
  - "tests/smoke.js"
last_verified_commit: 3b413f587c950a0f1183b7bd4e5b8f9a0c015984
updated: 2026-10-17
tags:
  - project
  - overview
summary: "A tiny greeting library used to verify context bootstrap output."
---

# demo-node overview

## Purpose and status

A tiny greeting library used to verify context bootstrap output.

This is a dependency-free Node.js ES module that exports a greeting helper and a `run` wrapper. The package provides a small CLI entry point and a smoke test; no Node engine version is declared.

## Detected stack and manifests

- Node.js / JavaScript or TypeScript

Manifest files:
- `package.json`

## Windows prerequisites

- Node.js and npm are needed to run the package scripts; the manifest does not pin a runtime version.
- The shared skills use PowerShell 7 for automation, but this fixture has no PowerShell-specific runtime requirement.

## Commands

| Task | PowerShell command | Source / verification |
|---|---|---|
| Run | `npm run start` | `package.json`; verified to print `Hello, world!` |
| Test | `npm run test` | `package.json`; verified smoke assertions pass |

## Repository map

- Repository root: `demo-node`
- `src/index.js` exports `run(name)` and starts the CLI when launched directly.
- `src/greeting.js` exports the string normalization and greeting formatter.
- `tests/smoke.js` checks default and named output.
- Architecture and module notes describe the data flow.

## Current constraints

- No dependency installation command is needed for the current dependency-free fixture.
- Runtime compatibility beyond the tested installed Node version has not been established.

## Stack-specific skill proposal

- Candidate name: `node-project-workflows`.
- Trigger: changing this project's Node.js ES module code when its package scripts or Windows CLI entry point matter.
- Scope: use commands declared by the project, verified module boundaries, and repository-specific conventions.
- No project-specific skill is needed for this small fixture; its conventions fit the shared skills. Reconsider only if this project develops repeated setup or debugging rules.

## Related notes

- Architecture: [[architecture]]
- Gotchas: [[gotchas]]
