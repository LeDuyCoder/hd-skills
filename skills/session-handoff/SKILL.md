---
name: session-handoff
description: Prepare a concise, actionable handoff for the next coding session. Use before ending a task, pausing work, or transferring repository work to another agent.
---

# Write a useful next-session handoff

## Procedure

1. Summarize the user's goal and the result achieved, including any incomplete work.
2. Record modified and inspected paths, commands run, exact verification outcomes, and checks not run with their reason.
3. Capture decisions and open issues. Link a relevant ADR or gotcha note when one exists; do not duplicate long details.
4. Give one concrete next action with the exact relevant note and source paths to open first.
5. Before reading or writing context, run the shared `Resolve-HdSkillConfig.ps1` with `-RepoRoot <repo>` and use its JSON `vaultPath` and `machineId`. Do not assume a vault location.
6. Create or update `projects/<project>/sessions/<yyyy-MM-dd>_<machineId>.md` using `vault-template\projects\_template\sessions\session-template.md` as the field guide. Preserve the agreed frontmatter fields: `project`, `module`, `paths`, `last_verified_commit`, `updated`, `tags`, and `summary`.
7. If the task changed behavior or architecture notes, use `context-update` for affected notes and verify every claim against the diff. Never invent a verification commit or claim a check passed when it did not.
8. Exclude secrets, tokens, connection strings, customer data, and large code blocks.

## Pass condition

The session note lets a new agent resume without rereading the whole conversation: it states current status, evidence, unresolved work, and the first next action. If no writable context store exists, return the handoff in the final response and say the note could not be saved.
