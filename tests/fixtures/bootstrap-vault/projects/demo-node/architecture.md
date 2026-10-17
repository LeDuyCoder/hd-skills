---
project: demo-node
module: architecture
paths:
  - package.json
  - src/index.js
  - src/greeting.js
  - tests/smoke.js
last_verified_commit: 3b413f587c950a0f1183b7bd4e5b8f9a0c015984
updated: 2026-10-17
tags:
  - project
  - architecture
summary: "The CLI and tests call run() from src/index.js, which delegates formatting to greet() in src/greeting.js."
---

# demo-node architecture

## System boundary

Node.js ES module. The CLI entry point is `src/index.js`; the package has no external dependencies or persistent storage.

## Component map

```mermaid
flowchart LR
    CLI["npm run start"] --> Run["run() in src/index.js"]
    Tests["tests/smoke.js"] --> Run
    Run --> Greet["greet() in src/greeting.js"]
    Greet --> Result["Hello, name!"]
```

The arrows follow the direct imports and calls in the source. `run()` supplies its default name; `greet()` normalizes the value and formats the string.

## Module inventory

| Module | Initial observation | Note |
|---|---|---|
| `src/index.js` | CLI entry point and public `run(name)` wrapper. | [[modules/src]] |
| `src/greeting.js` | Converts input to trimmed text and formats the greeting. | [[modules/src]] |
| `tests/smoke.js` | Checks default and named `run()` results. | [[modules/src]] |

## Data flow and important paths

The CLI path writes one line to stdout. The imported `run()` path has no I/O; `greet()` has no external side effects.
