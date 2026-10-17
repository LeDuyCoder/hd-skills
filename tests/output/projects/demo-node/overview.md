---
project: demo-node
module: overview
paths:
  - "package.json"
last_verified_commit: f9557bba520037e9698c2f38751d91869dba2791
updated: 2026-10-17T09:40:31.7060593+07:00
tags:
  - project
  - overview
summary: "A tiny greeting library used to verify context bootstrap output."
---

# demo-node overview

## Purpose and status

A tiny greeting library used to verify context bootstrap output.

These notes were bootstrapped from repository manifests and file layout. Confirm behavior and commands against source before relying on them.

## Detected stack and manifests

- Node.js / JavaScript or TypeScript

Manifest files:
- `package.json`

## Windows prerequisites

- PowerShell 7 is the assumed shell for project automation in this skills pack.
- Runtime and tool versions were not inferred unless recorded in a manifest; verify them before setup.

## Commands

| Task | PowerShell command | Source / verification |
|---|---|---|
| Run | `npm run start` | package.json scripts and detected package manager |
| Test | `npm run test` | package.json scripts and detected package manager |

## Repository map

- Repository identity (remote or relative name): `tests/fixtures/demo-node`
- Source inventory: 2 supported-language source file(s) under `src\`.
- Module inventory is linked from [[architecture]].

## Current constraints

- This first-pass note records detected metadata only. Inspect code and update responsibilities, runtime versions, and missing commands.
- No command absent from project manifests was invented.

## Stack-specific skill proposal

- Candidate name: `node-project-workflows`.
- Trigger: changing this project's Node.js / JavaScript or TypeScript code when its local setup or conventions matter.
- Scope: use commands declared by the project, verified module boundaries, and repository-specific conventions.
- Create `<repo>\.agents\skills\node-project-workflows\` only if source review finds stable conventions not already covered by shared skills. No project skill was generated automatically.

## Related notes

- Architecture: [[architecture]]
- Gotchas: [[gotchas]]