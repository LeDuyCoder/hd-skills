---
name: security-review
description: Examine code or a change for exploitable security weaknesses and explain evidence, impact, and practical fixes.
---

# Review security properties

1. Start with `context-load`; resolve the project context and verify security-relevant notes against source.
2. Identify assets, trust boundaries, entry points, and attacker-controlled inputs in the requested scope.
3. Trace authentication and authorization, validation and encoding, filesystem/process use, secret handling, cryptographic choices, dependency exposure, and error/log behavior where relevant.
4. Confirm each suspected issue through a reachable code path or focused safe test. Separate confirmed findings from questions requiring deployment context.
5. Report findings by severity with affected path and line, preconditions, impact, and a concrete mitigation. Do not include live secrets in notes or output.
6. Recommend checks using commands recorded in the project overview or manifests; do not invent project commands.
7. Call `context-update` only for verified durable security constraints or recurring traps.

## Pass condition

Every finding has a plausible attack path and specific impact; uncertainty and scope limits are explicit.
