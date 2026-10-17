---
name: context-update
description: Update project memory after a coding task. Use when repository behavior, commands, architecture, decisions, gotchas, or useful session state changed, and append a concise handoff for the next task.
---

# Update project memory from verified work

## Procedure

1. Choose the same store used by `context-load`: readable `D:\Obsidian\DevBrain\`, otherwise `<repo>\.context\`. If neither is available, report that memory was not updated; do not block code delivery.
2. Review the actual diff and verification results. Identify which existing notes' `paths` overlap modified source or configuration. Do not rewrite unrelated notes.
3. Update the affected overview, architecture, module, or gotcha notes. Keep each summary to one or two factual sentences, use relative repository paths, and keep examples short. Never paste secrets, tokens, connection strings, customer data, or long code.
4. Set `updated` to today's local date. Set `last_verified_commit` to the current Git HEAD only for notes whose listed paths you checked against that revision. If the repository is uncommitted, write `unverified` and list the uncommitted paths in the session note; do not claim a commit that does not exist.
5. Add an ADR when the task made a consequential architectural choice. Include context, the selected option, alternatives, and consequences; link it from the overview or architecture note. Do not create an ADR for a routine implementation detail.
6. Create or append `projects/<project>/sessions/YYYY-MM-DD.md` using the session template. Record the task/result, changed files, checks and exact outcomes, decisions/open issues, and one concrete next action.
7. If this task added a project, add its overview link and one-line purpose to `00-INDEX.md`. Preserve the 150-line index limit by removing stale/duplicate entries before adding more.
8. Read the changed notes back and check frontmatter, paths, dates, and claims against the diff. Mention what memory changed in the final response.

## Pass condition

Every edited note contains only information supported by the task evidence, all affected path lists and verification commits are truthful, and the dated session note provides a usable next step. If no memory changed, explain why.
