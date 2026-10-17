# Progress

## Baseline

- Started Git in `E:\hd-skill` as requested.
- Added `.gitignore` for local `.context\` notes, temporary outputs, and private configuration.
- The two approved phase documents are present under `docs\`.
- Commit: `0d3fd55 docs: record approved research and architecture`.
- Verification: the initial commit contains both approved phase documents and `.gitignore`.
- Environment: ordinary shell startup still fails after `git init` because ownership/permissions differ. Git operations and PowerShell checks work through the approved workspace-only elevated route. PowerShell 7 (`pwsh`) is not installed here, so verification currently runs under Windows PowerShell 5.1; the scripts are written for PowerShell 7 and use syntax supported by both.

## M1 — Repository structure and validator

- Status: complete and verified.
- Implemented: required top-level directories; `.gitignore`; `scripts\validate.ps1`; `tests\verify-m1.ps1`.
- Verification: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-m1.ps1` passed. It confirmed empty-tree success, >300-character description warning without failure, and correct errors for malformed frontmatter, missing description, folder/name mismatch, duplicate name, >300 body lines, and UTF-8 BOM.
- Commits: `dc30e3f feat(m1): add portable skill validator`; `d5d12d6 feat(m1): verify duplicate skill names`.
- Added `config.schema.json` for machine-specific settings and `config.defaults.json` with portable defaults (no machine paths). Extended `validate.ps1` to verify strict UTF-8/no BOM, schema shape, and defaults against the schema's supported JSON Schema constraints.
- Verification: `tests\verify-m1.ps1` passed empty-tree, description warning, and invalid skill sample checks; validation of all 5 current skills plus config schema/defaults passed. One PowerShell collection binding issue and one null/default-schema traversal issue were fixed during test iteration.
- Commit: pending.
- Remaining: none.

## M2 — Context memory system

- Status: complete and hardened for multi-machine use.
- Implemented: note templates for index, overview, architecture, module, ADR, gotchas, session, and stack; context-load/update/bootstrap/audit/session-handoff skills; stack detector, context bootstrap generator, freshness checker, and section-scoped concurrent update helper. All five context skills invoke the shared runtime resolver before context access. Sessions use `<date>_<machineId>.md`; note timestamps are ISO 8601 with offsets. Repository identities and note paths are relative or remote-based, with no machine-local absolute path in generated notes.
- Verification: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-m2.ps1` passed stack detection, package script extraction, note generation, standard note frontmatter, no-BOM UTF-8 output, and fresh/stale Git path checks. `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -RootPath .\skills` passed (5 skills, 0 warnings). `npm --prefix .\tests\fixtures\demo-node test` passed; `npm --prefix .\tests\fixtures\demo-node start` printed `Hello, world!`. All 7 reviewed generated notes have valid frontmatter/UTF-8, the index is 18 lines, and every note passes path-scoped freshness against fixture commit `3b413f5`.
- Commits: `540c834 feat(m2): add context memory skills`; `3b413f5 fix(m2): make fixture entry check Windows-safe`; `45b9471 feat(m2): standardize generated note metadata`; final reviewed fixture output and progress are committed as `feat(m2): record reviewed bootstrap fixture notes`.
- Current generated output: reviewed fixture notes are in `tests\output\projects\demo-node\`.
- M2 hardening verification: `tests\verify-m2.ps1` passed bootstrap, standard metadata, UTF-8 without BOM, path portability, module note quality, Git freshness, section-only edits, and refusal of stale writes. M1 validation and all three machine profiles passed afterward.
- Earlier M2 commits: `540c834`, `3b413f5`, `45b9471`, `758ebf7`; this hardening is included in the current M2 commit.

## Decisions made during implementation

- MCP remains opt-in and disabled in examples; no user-level MCP config is modified.
- The only Antigravity junction target is `%USERPROFILE%\.gemini\config\skills\`; legacy locations are reported if detected, never created automatically.
- Description length over 300 characters is a warning, not a validation error.
- The fixture verification will use a small JavaScript/Node project; `context-bootstrap` reports only commands declared in `package.json` rather than inventing commands.
- The `.context\` directory is Git-ignored for local fallback memory.
- The approved workspace-only Git trust exception is recorded in the sandbox account's global Git config because the repository owner differs from the execution account; regular shell startup still fails, so validation and Git commands ran through the approved elevated path.
- Tests run under Windows PowerShell 5.1 because PowerShell 7 is not present. Compatibility fixes were retained where they improve stock Windows execution.

## Remaining work — resumed implementation goal

The approved Multi-machine amendment is in `docs\PHASE-2-ARCHITECTURE.md`. The worktree was inspected before resuming; existing M1 and M2 artifacts and their commits are present. Remaining work, in execution order:

1. M1 completion: add `config.schema.json` and `config.defaults.json`, extend validation to check the schema, rerun M1 tests, update this file, and commit. **Complete:** commit `549fa27`.
2. Multi-machine foundation: implement shared config resolution and environment detection, add three isolated machine fixtures and tests, record verification, and commit. **Complete:** commit `f9557bb`.
3. M2 hardening: make the five existing context skills resolve configuration before store access, make generated notes portable and conflict-aware, refine templates, run bootstrap on the fixture, assess generated note quality, and commit. **Complete.**
4. M3 skills: add planning, TDD, debugging, verification, review, refactoring, security, Git, PR, CI, dependency, Windows, skill-improve, and stack-skill-generator skills; ensure resolver use and project-derived commands; validate and commit. **Complete.**
5. M4 rules: write Codex and Antigravity global rules and a character-count check; verify both below 3,000 characters; commit. **Complete.**
6. M5 lifecycle and installer: implement bootstrap/install/update/uninstall/doctor, pinned optional MCP templates, and three simulated-machine end-to-end cycles including dry-run, idempotence, diagnosis, and restoration; validate and commit. **Complete.**
7. M6 real-machine install and evaluation: save and inspect the dry-run log, back up every external config before any edit, install non-interactively without MCP and without touching the real vault, run doctor, then run three comparative fixture tasks and record estimates in `docs\EVAL.md`.
8. README: complete Vietnamese setup, use, extension, vault-sync, uninstall, and troubleshooting guidance; run final audits and commit.

No real-machine installation or vault write has occurred. PowerShell 7 is absent; verification is currently using Windows PowerShell 5.1 unless a portable/test-only PowerShell 7 executable becomes available. M6 actions remain constrained by the approved backup and no-MCP/no-real-vault rules.

### Multi-machine foundation progress

- Implemented `scripts\Detect-Environment.ps1` and `scripts\Resolve-HdSkillConfig.ps1`. Resolution supports parameter/environment/machine-config/discovery/default precedence, detects Codex and Antigravity, reads Obsidian vault metadata, supports repository fallback, returns JSON, and can persist first-run machine settings without a BOM.
- Added `tests\machines\machines.json` and `verify-machines.ps1` for three isolated Windows profiles. Profiles cover both agents plus named Obsidian vault, Codex-only/no-vault fallback, and Unicode/spaced paths. The harness verifies first-run persistence and stable repeated resolution.
- Verification: `validate.ps1` passed all 5 skills and schema/defaults; the three simulated-machine profiles passed. During testing the PowerShell parser rejected an interpolated warning string, and the Unicode case initially used an intentionally unmatched vault leaf; both were corrected and the suite passed afterward.
- Decision records: D-001 (avoid selecting a differently named sole vault), D-002 (stable compact machine ID), and D-003 (dependency-free schema subset) are in `docs\DECISIONS.md`.
- Status: complete and committed as `f9557bb feat(multi-machine): resolve machine configuration`.

### M3 — Process and quality skills

- Status: all 14 requested skills implemented and verified; included in this milestone commit.
- Added: planning, tdd, systematic-debugging, verification-before-done, code-review, refactoring, security-review, git-workflow, pull-request, fix-ci, dependency-upgrade, windows-shell, skill-improve, and stack-skill-generator.
- Every skill begins through `context-load` (which calls the shared resolver) and calls `context-update` when durable context changed. Project test/lint/build instructions require reading the project's overview/manifests rather than using a stack-wide hard-coded command.
- Verification: validator passed all 19 skills; `tests\verify-m3.ps1` confirmed the full M3 set, context lifecycle guidance, and no rooted drive paths or hard-coded project commands. M2 and all three machine profile checks passed after adding the new skills.

### M4 — Always-on agent rules

- Status: both rules implemented and verified.
- Added identical core instructions in `rules\AGENTS.md` and `rules\GEMINI.md`. They direct agents to use context-load/resolver before exploration, read project commands from overview/manifests, update durable context, and protect secrets and user changes.
- Verification: `tests\verify-m4.ps1` printed 995 characters for each file, confirmed both are identical, each is under 3,000 characters, contains resolver guidance, and has no fixed drive path. Full skill validation and M3 checks passed.

### M5 — Bootstrap, installer, update, uninstall, and doctor

- Status: implemented and verified on three isolated profiles; no real user profile was changed.
- Added `bootstrap.ps1`, `install.ps1`, `update.ps1`, `uninstall.ps1`, and `doctor.ps1`. Direct install/update/uninstall commands default to dry-run and require `-Apply`; bootstrap applies by default and supports read-only `-DryRun`.
- Install detects only present agents, installs each skill by Junction or Copy, copies the shared resolver/schema/defaults into the machine-local hd-skill home, merges bounded rule blocks, persists machine config, and records ownership for safe uninstall. Repeated installs converge without file or directory changes. Existing config files are backed up before edits. MCP remains opt-in and uses a pinned 1.0.0 template.
- Uninstall removes only recorded junctions/copies and managed config entries, restores pre-existing rule text exactly, preserves modified/unmanaged files, and leaves timestamped backups available.
- Doctor validates machine config, resolver-selected vault/fallback, copied files/junction targets, detected agent visibility, optional MCP startup, and local/remote Git state; failures include repair guidance.
- Verification: full regression passed: PowerShell scripts parsed; validator passed 19 skills and config files; M1–M4 suites passed; three machine profiles passed bootstrap dry-run, default install dry-run, install, second install with no changes, update dry-run, doctor, default uninstall dry-run, and uninstall returning all non-backup files/directories to baseline. The junction test deliberately redirected one skill and doctor detected it. Optional MCP dry-run planned both agent configs with a Unicode path and pinned version 1.0.0 without writing files. A separate local-origin test cloned through bootstrap, installed, passed doctor, and updated while preserving machine config.
- Decisions D-005 through D-008 record strict-JSON ownership, explicit apply switch, the MCP pin, and the repository URL prompt.
