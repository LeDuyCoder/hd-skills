# hd-skill shared agent rules

- At the start of project work, use `context-load` before broad repository exploration. It runs the shared `Resolve-HdSkillConfig.ps1` for the current repository and selects the configured context store; never guess or embed a machine-specific vault path.
- At the end, use `context-update` when the task changed durable project behavior, architecture, commands, decisions, or verified gotchas. Use `session-handoff` when work is paused or transferred.
- Read project test, lint, type-check, build, and run commands from that project's overview and manifests. Do not invent commands based only on a stack name.
- Treat context notes as an index, not source-of-truth code. Verify stale or consequential claims against the repository.
- Do not write secrets, tokens, connection strings, or customer data into context notes.
- Preserve user changes and follow the task's explicit authorization boundaries. Report checks accurately and identify any that were not run.
