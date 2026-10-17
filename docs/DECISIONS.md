# Implementation decisions

This file records reversible implementation choices that resolve details not fully specified in the approved Phase 1 and Phase 2 documents.

## D-001 — A single unmatched Obsidian vault does not replace the configured vault

- Decision: auto-select a vault only when its name matches `vaultName`. When exactly one vault has a different name, use the repository `.context\` fallback and tell the operator to set `-VaultPath` or `vaultName`.
- Reason: the configured default `DevBrain` is deliberate; silently selecting a differently named vault could write project notes into the wrong personal store.
- Reversal: set `vaultName` or pass `-VaultPath`; no vault content is modified by discovery.

## D-002 — Machine IDs use a persisted display label plus a local fingerprint

- Decision: use the Windows `MachineGuid` as the SHA-256 input when readable, otherwise use computer and user names. Keep only a short computer label and six hash characters; allow `HD_SKILL_MACHINE_ID` for isolated tests. Persist the result in the machine config on first install.
- Reason: session filenames need a stable, short, non-path identifier that does not change when a user moves their profile or Documents folder.
- Reversal: edit the machine-local `machineId` field; existing session notes remain untouched.

## D-003 — JSON config validation uses the repository schema's supported portable subset

- Decision: `validate.ps1` validates JSON Schema metadata and recursively enforces types, required properties, enums, constants, string length/pattern, and additional-property rules for the machine config defaults.
- Reason: the repository must validate under stock Windows PowerShell without installing a schema-validation module.
- Reversal: replace the internal validator with a full JSON Schema implementation if a dependency-free implementation becomes available; the checked-in schema remains the contract.

## D-004 — Note updates use ISO timestamps and a section-scoped locked replacement

- Decision: generated `updated` metadata uses ISO 8601 timestamps with a local offset. The context update helper locks the note, rereads its timestamp, refuses writes based on an older observation, changes only one heading section plus the timestamp, and replaces the file from a same-directory temporary file.
- Reason: day-only timestamps cannot order two edits on the same day, and broad rewrites increase the chance of losing another machine's note changes.
- Reversal: retain the timestamps and section boundaries while changing the lock or replacement implementation if cross-platform evidence requires it.

## D-005 — Strict JSON MCP settings use a namespaced owned entry

- Decision: the Antigravity MCP config remains valid JSON. Its hd-skill server is inserted under the unique `mcpServers.hd-skill-filesystem` key, which is the ownership boundary used for idempotent replacement and uninstall. Text and TOML files use literal `# BEGIN hd-skill` / `# END hd-skill` markers.
- Reason: literal comment markers would make strict JSON invalid. The installer backs up the original file and preserves all other JSON properties when it merges or removes the owned entry.
- Reversal: use a marker syntax only if the target client officially supports JSON-with-comments and validates it consistently.

## D-006 — Mutating lifecycle scripts require `-Apply`

- Decision: install, update, and uninstall default to dry-run behavior. `-Apply` is required for changes; bootstrap performs installation by default because it is the explicit one-line onboarding command, while `-DryRun` makes bootstrap read-only.
- Reason: a missed switch should not silently change a profile. M6 real installation explicitly uses `-Apply` after reviewing the saved dry-run output.
- Reversal: keep the dry-run default for direct install/update/uninstall commands; bootstrap can retain its explicit apply-by-default behavior.

## D-007 — Pin the optional filesystem MCP package to a reviewed release

- Decision: the generated optional MCP configuration uses `@modelcontextprotocol/server-filesystem@1.0.0` and never uses `@latest`.
- Reason: the npm package page reports version 1.0.0 as the current tagged release checked on 2026-10-17; pinning makes repeat installations deterministic. Source: [npm package page](https://www.npmjs.com/package/%40modelcontextprotocol/server-filesystem?activeTab=versions).
- Reversal: update the pinned version only after reviewing release behavior and updating the template/tests together.

## D-008 — Fresh bootstrap accepts a repository URL instead of inventing one

- Decision: when there is no local checkout or configured `HD_SKILL_HOME` Git remote, `bootstrap.ps1` needs `-RepositoryUrl`. The README uses the repository owner-provided remote `https://github.com/LeDuyCoder/hs-skills.git`.
- Reason: the workspace had no origin when the initial bootstrap was implemented; the repository owner has since supplied the canonical URL, so new users can paste a ready-to-run command.
- Reversal: change the README URL if the owner moves the repository; local bootstrap remains available for tests and existing checkouts.
