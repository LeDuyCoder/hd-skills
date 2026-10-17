---
name: context-load
description: Load project context before exploring a codebase. Use at the start of coding, debugging, review, or handoff tasks when a DevBrain vault or repository .context memory may exist.
---

# Load only relevant project memory

## Procedure

1. Locate the repository root with `git rev-parse --show-toplevel`. If this is not a Git repository, use the current workspace root and say that Git freshness checks are unavailable.
2. Check whether `D:\Obsidian\DevBrain\00-INDEX.md` is readable through the agent's native file tools. If the vault is not accessible, use `<repo>\.context\00-INDEX.md`. Do not enable MCP automatically. If neither exists, state that no context store was found and continue with normal code exploration.
3. Read the index first. Keep it below 150 lines. Follow the selected project's overview link and read only that `overview.md`.
4. Identify the task's likely module and changed/inspected paths. Open only the corresponding module note, relevant ADR, gotcha, or stack note.
5. For each note that will guide a code change, compare `last_verified_commit` with current repository history for the paths in its frontmatter. When available, run the sibling `context-audit\scripts\check-freshness.ps1` from the project skill directory (`<repo>\.agents\skills\context-audit\...`) or the global skill directory (`%USERPROFILE%\.agents\skills\context-audit\...`), passing `-RepoPath <repo> -NotePath <note>`. If it reports stale, inspect the changed source paths and refresh your understanding before relying on that note.
6. Treat notes as an index and memory aid, not as source-of-truth code. Confirm exact APIs, behavior, and current commands in the repository whenever a note is missing, stale, ambiguous, or contradicted by code.
7. Report the project notes read and any stale/missing notes briefly, then proceed with the user's task.

## Selection rules

- Prefer `00-INDEX.md` → project `overview.md` → one or two relevant notes.
- Do not read every project or stack note by default.
- Avoid repeating large code blocks into context. Note file paths and concise behavior instead.
- If vault and `.context\` both exist, use the configured vault and report the duplicate fallback without merging them automatically.

## Pass condition

Before broad exploration, you know the project root, selected context root, relevant project note, and whether its code-path evidence is current. When no store is readable, record that fact and continue without blocking the task.
