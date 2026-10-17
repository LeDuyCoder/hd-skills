---
name: systematic-debugging
description: Find the cause of a reproducible software failure by gathering evidence and testing focused hypotheses.
---

# Debug from evidence

1. Start with `context-load` and confirm whether relevant notes are fresh for the affected paths.
2. Capture the exact symptom, reproduction steps, input, environment, and full useful error output. Preserve the failing state when possible.
3. Read the project overview for the supported run and test commands. Reproduce with those commands instead of substituting a guessed workflow.
4. Trace the failure from the observable boundary toward the responsible code. Check recent relevant changes, configuration, and assumptions.
5. List plausible causes, then run the smallest experiment that distinguishes them. Change one variable at a time and record what the result proves.
6. Fix the demonstrated cause. Add a regression test when the behavior is testable, then rerun the reproduction and relevant checks.
7. If evidence is insufficient, state what is known and the next diagnostic step instead of presenting a guess as the cause.
8. Call `context-update` when the verified cause or recovery is likely to help future work; record reproducible gotchas only.

## Pass condition

The reported cause is supported by a reproduction or discriminating evidence, the fix addresses that cause, and verification results are exact.
