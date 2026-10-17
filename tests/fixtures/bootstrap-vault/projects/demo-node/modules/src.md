---
project: demo-node
module: src
paths:
  - "src/greeting.js"
  - "src/index.js"
  - "tests/smoke.js"
last_verified_commit: 3b413f587c950a0f1183b7bd4e5b8f9a0c015984
updated: 2026-10-17
tags:
  - project
  - module
summary: "run(name) delegates to greet(name); greet trims a stringified value and returns a greeting."
---

# src module

## Responsibility

The source module exposes `run(name)` from `index.js` and `greet(name)` from `greeting.js`. The smoke test imports `run()` directly.

## Files found

- `src/greeting.js`
- `src/index.js`
- `tests/smoke.js`

## Public API, side effects, and dependencies

| Symbol | Contract / behavior | Callers |
|---|---|---|
| `run(name = 'world')` | Returns `greet(name)` without I/O. | CLI entry and `tests/smoke.js` |
| `greet(name)` | Converts to string, trims whitespace, substitutes `world` for empty text, then formats `Hello, <name>!`. | `run()` |

`index.js` imports `greet` using a relative ES module import. There are no third-party dependencies. Direct CLI execution uses `pathToFileURL(process.argv[1])` so Windows paths compare correctly with `import.meta.url`.
