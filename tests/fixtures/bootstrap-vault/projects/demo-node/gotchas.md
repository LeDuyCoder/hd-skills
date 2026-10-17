---
project: demo-node
module: gotchas
paths:
  - src/greeting.js
  - src/index.js
last_verified_commit: 3b413f587c950a0f1183b7bd4e5b8f9a0c015984
updated: 2026-10-17
tags:
  - project
  - gotchas
summary: "The CLI must compare file URLs using pathToFileURL because Windows process paths are not URL strings."
---

# demo-node gotchas

## Windows CLI entry check

- Symptom: `npm run start` exits without printing the greeting.
- Cause / evidence: concatenating `file://` with `process.argv[1]` does not produce the canonical `import.meta.url` for a Windows path.
- Safe fix: compare with `pathToFileURL(process.argv[1]).href`, guarded for a missing argument.
- Verified: `npm --prefix tests/fixtures/demo-node start` prints `Hello, world!`.
