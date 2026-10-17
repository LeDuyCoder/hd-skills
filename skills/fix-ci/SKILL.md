---
name: fix-ci
description: Diagnose and repair a failing continuous integration job using its logs and repository-defined checks.
---

# Repair a CI failure

1. Begin with `context-load` and inspect fresh notes for the failing workflow paths.
2. Capture the failing job, step, runner image, tool versions, command, exit code, and relevant log lines. Separate the first failure from cascading errors.
3. Read the workflow and project overview. Reproduce the exact failing command locally when the required environment is available; use the workflow's declared command rather than a guessed substitute.
4. Identify whether the cause is code, test assumptions, configuration, dependency resolution, or runner drift. Change one demonstrated cause at a time.
5. Add or adjust a regression check when appropriate, and run the same command plus affected project checks.
6. Report the cause, fix, exact verification, and any environment mismatch that remains.
7. Call `context-update` for a verified runner quirk or durable workflow rule.

## Pass condition

The repair addresses the earliest confirmed failure and is checked with the relevant workflow command or an explicitly described equivalent.
