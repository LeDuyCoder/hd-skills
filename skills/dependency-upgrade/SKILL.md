---
name: dependency-upgrade
description: Upgrade a requested dependency with compatible lockfile changes, release evidence, and focused regression checks.
---

# Upgrade dependencies

1. Start with `context-load` and read the project overview for runtime and package-manager constraints.
2. Identify the requested dependency, current resolved version, direct or transitive role, supported runtime range, and relevant lockfile.
3. Consult maintained release notes or official package metadata when version behavior matters. Do not upgrade unrelated packages or replace the package manager.
4. Use the repository's declared package manager and scripts. Update the lockfile through that package manager rather than editing generated lock data by hand.
5. Inspect the resulting manifest and lockfile diff. Run focused tests and project-defined lint/build checks that cover the upgrade.
6. Report version changes, compatibility evidence, verification, and any known migration requirement.
7. Call `context-update` if the upgrade changes supported runtime constraints or reveals a lasting compatibility issue.

## Pass condition

The requested dependency is upgraded deliberately, generated metadata is consistent, and compatibility claims have evidence.
