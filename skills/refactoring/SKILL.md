---
name: refactoring
description: Improve internal code structure while preserving externally observable behavior.
---

# Refactor safely

1. Begin with `context-load` and check relevant notes against the current code.
2. Identify the structural problem and the behavior that must remain unchanged. Inspect callers, side effects, and existing tests before editing.
3. Read `overview.md` for project checks and conventions. Add or improve characterization tests if important behavior is not covered.
4. Make small structural changes with no unrelated feature or formatting churn. Keep interfaces stable unless the request explicitly changes them.
5. Run focused tests after each meaningful change and the applicable project checks before completion.
6. Compare the final diff for unintended behavior changes and report any limitation in test coverage.
7. Call `context-update` if the refactor changes module boundaries, architecture, or a reusable convention.

## Pass condition

The code is easier to understand or maintain, relevant checks pass, and intended behavior remains unchanged.
