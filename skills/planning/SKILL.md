---
name: planning
description: Turn a coding request into a scoped, verifiable implementation plan before making changes.
---

# Plan repository work

## Procedure

1. Start with `context-load` so the runtime resolver selects the right project store before broad exploration.
2. Restate the requested outcome, observable acceptance conditions, constraints, and any explicit stop points. Ask only for information that materially changes the design and cannot be inferred safely.
3. Inspect relevant code, manifests, and existing tests. Separate facts from assumptions and identify the smallest coherent change that meets the request.
4. Read the project overview and use its recorded commands for test, lint, type-check, and build steps. Do not invent or hard-code project commands.
5. Order tasks by dependency. Include affected files or modules, verification for each step, and risks that need early resolution.
6. Keep the plan concise and concrete. Start implementation when the user asked for execution; do not stop at a plan unless asked to plan only.
7. At the end, call `context-update` when the plan changed durable architecture, decisions, or next steps. A routine plan with no lasting value needs no note update.

## Pass condition

The plan maps each acceptance condition to a specific implementation step and evidence check, and respects the user's authorization and stop points.
