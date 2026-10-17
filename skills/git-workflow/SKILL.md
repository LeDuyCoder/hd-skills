---
name: git-workflow
description: Perform safe, reviewable Git operations such as inspecting changes, staging, committing, and resolving routine conflicts.
---

# Use Git safely

1. Begin with `context-load` before repository exploration.
2. Inspect `git status`, branch, upstream, and the relevant diff before changing the index or history.
3. Stage only paths belonging to the requested change. Review the staged diff before committing.
4. Use a concise commit message that describes the change. Do not amend, rebase shared history, force-push, or discard user changes unless explicitly requested.
5. For conflicts, inspect both sides and repository intent. Preserve unrelated user work and run relevant project checks from `overview.md` after resolution.
6. Report commit identifiers, branch state, and any operation not completed. Never claim a push or remote update without its command result.
7. Call `context-update` when a durable branching, commit, or release convention was established.

## Pass condition

Only requested changes are staged or committed, history-changing actions remain authorized, and the resulting Git state is reported accurately.
