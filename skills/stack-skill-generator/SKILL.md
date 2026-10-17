---
name: stack-skill-generator
description: Create a project-specific skill for a verified stack workflow that is repeated and not covered by shared skills.
---

# Generate a stack skill

1. Start with `context-load` so the resolver selects project memory before exploring the stack.
2. Inspect manifests and source to confirm the stack, package manager, tool versions, and conventions. A manifest alone is a candidate signal, not proof of a workflow.
3. Read the shared skill templates and check existing project skills under `<repo>\.agents\skills\` for overlap.
4. Create a focused skill only for stable, repeated project conventions. Put project-specific commands in that skill only when verified from the project; keep machine paths out.
5. Use a lowercase hyphenated folder and matching `name`. Write a specific description and concise instructions with a clear pass condition. Move substantial optional detail to a linked reference.
6. Validate the skill with the shared validator and exercise its instructions against a realistic project task when practical.
7. Call `context-update` to record the new skill's purpose and trigger in project notes when those notes are maintained.

## Pass condition

The skill adds verified project value beyond the shared pack, remains discoverable, and passes metadata and body-length checks.
