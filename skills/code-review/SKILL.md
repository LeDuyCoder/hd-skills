---
name: code-review
description: Review a change for concrete correctness, security, and maintainability defects with evidence from the diff.
---

# Review a change

1. Start with `context-load`. Treat stale or vague notes as pointers, then confirm behavior in source.
2. Inspect the complete diff, changed call sites, relevant tests, and the project's overview. Do not review unseen base assumptions as facts.
3. Look for defects that affect users: wrong behavior, missing error handling, data loss, unsafe input handling, compatibility breaks, or untested critical branches.
4. Validate suspected findings against code paths and tests. Prefer a minimal reproduction or targeted check when it can confirm impact.
5. Report only actionable findings. Order by severity and give file and line, triggering condition, impact, and a concrete fix. If no material finding is supported, say so and state any coverage limitation.
6. Do not make unrelated edits during a review unless the user also asked for fixes.
7. Call `context-update` only if the review establishes a durable project rule or reproducible gotcha.

## Pass condition

Findings are specific, reproducible from the cited code, and distinguish real defects from preference or speculation.
