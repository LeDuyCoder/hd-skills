---
name: skill-improve
description: Improve a shared or project skill after a repeated failure or a concrete instruction gap, using evidence and a focused change.
---

# Improve a skill from evidence

1. Start with `context-load` for the repository whose skill is being changed.
2. Identify the exact skill instruction and a repeated failure, ambiguity, or missed behavior. Use an observed request/result or reproducible test, not a hypothetical preference.
3. Decide whether the correction belongs in the skill, its reference, a reusable script, project notes, or nowhere. Keep project-specific facts out of global skills.
4. Make the smallest clear edit. Keep the trigger description discriminating, body below the repository limit, and references discoverable.
5. Validate all skills and exercise any modified helper. Compare the change against unrelated task flows to avoid over-constraining the skill.
6. Record the evidence and rationale in a concise change note or project gotcha when it will help future maintainers.
7. Call `context-update` when the improvement establishes a durable convention or changes shared skill behavior.

## Pass condition

The edit addresses demonstrated evidence, preserves unrelated workflows, and passes the repository skill validator.
