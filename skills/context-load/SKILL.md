---
name: context-load
description: Load project context before exploring a codebase. Use at the start of coding, debugging, review, or handoff when a configured vault or repository fallback may contain project notes.
---

# Load only relevant project memory

## Procedure

1. Locate the repository root with `git rev-parse --show-toplevel`. If this is not a Git repository, use the current workspace root and say that Git freshness checks are unavailable.
2. Before reading context, run `Resolve-HdSkillConfig.ps1` from the installed shared scripts directory and pass `-RepoRoot <repo>`. The installer places shared scripts under the user-level hd-skill home; if `USERPROFILE` is available, locate it with `Join-Path $env:USERPROFILE '.hd-skill\scripts\Resolve-HdSkillConfig.ps1'`. Read its JSON `vaultPath`, `contextMode`, `agents`, and `machineId`. Do not infer a vault path or enable MCP automatically.
3. Use native file tools to read `<vaultPath>\00-INDEX.md`. If `contextMode` is `repo`, the resolver has selected the repository `.context\` fallback. If the selected store is inaccessible, report that and continue with code exploration without writing to another store implicitly.
4. Read the index first. Keep it below 150 lines. Follow the selected project's overview link and read only that `overview.md`.
5. Identify the task's likely module and changed/inspected paths. Open only the corresponding module note, relevant ADR, gotcha, or stack note.
6. For each note that will guide a code change, compare `last_verified_commit` with current repository history for the paths in its frontmatter. Run the installed `context-audit` helper with `-RepoPath <repo> -NotePath <note>`. If it reports stale, inspect changed source paths and refresh your understanding before relying on that note.
7. Treat notes as an index and memory aid, not as source-of-truth code. Confirm APIs, behavior, and current commands in the repository whenever a note is missing, stale, ambiguous, or contradicted by code.
8. Report the project notes read and any stale/missing notes briefly, then proceed with the user's task.

## Selection rules

- Prefer `00-INDEX.md` → project `overview.md` → one or two relevant notes.
- Do not read every project or stack note by default.
- Avoid repeating large code blocks into context. Note file paths and concise behavior instead.
- If vault and `.context\` both exist, use the resolver-selected store and report the other store without merging them automatically.

## Pass condition

Before broad exploration, you know the project root, selected context root, relevant project note, and whether its code-path evidence is current. When no store is readable, record that fact and continue without blocking the task.
