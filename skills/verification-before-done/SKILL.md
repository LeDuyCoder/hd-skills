---
name: verification-before-done
description: Verify a code change with project-defined checks and report evidence before claiming completion.
---

# Verify before reporting done

1. Begin with `context-load` to resolve and inspect relevant project context.
2. Read the project's `overview.md` and current manifests for the applicable test, lint, type-check, build, or run commands. Never assume a command exists because another stack uses it.
3. Inspect the diff and identify the behavior changed, affected paths, and likely regressions. Select checks that cover those conditions.
4. Run the focused check first, then broader relevant checks. Capture exit codes and meaningful output. If a check cannot run, state the concrete reason and do not claim it passed.
5. Check the final working tree and generated artifacts. Confirm no secret, unrelated edit, or accidental machine-specific path was added.
6. Report what changed and list each verification result. Distinguish executed checks from checks inferred from code inspection.
7. Call `context-update` when verification revealed a lasting project command, constraint, decision, or gotcha.

## Pass condition

Every completion claim has a corresponding command result or clearly labeled inspection evidence, and unrun checks are disclosed.
