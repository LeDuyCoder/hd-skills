---
name: context-bootstrap
description: Build a first-pass context store for a new repository. Use when onboarding an unfamiliar project or when asked to generate project overview, architecture, module notes, and stack-specific skill proposals.
---

# Bootstrap project context

## Procedure

1. Locate the repository root, then run the shared `Resolve-HdSkillConfig.ps1` before reading project files. Use its JSON `vaultPath`, `contextMode`, and `machineId`; resolve the script from the installed user-level hd-skill home. Do not assume any vault location.
2. Inspect manifests before reading broad source trees. Run `scripts\detect-stack.ps1 -RepoPath <repo>` to identify candidate stacks. The detector reports recognized manifests; a monorepo may have several stacks.
3. Run `scripts\bootstrap-context.ps1 -RepoPath <repo> -OutputRoot <resolved-vaultPath> -ProjectName <name>`. The helper invokes the resolver itself before reading or writing. Use the repo fallback only when that is what the resolver selected or when the selected vault is inaccessible.
4. The script creates a structural first pass: `00-INDEX.md`, `overview.md`, `architecture.md`, module inventory notes under `modules\`, `gotchas.md`, a decisions index, and a machine-specific session note. It does not invent an ADR. Existing notes are never overwritten; resolve any collision by rereading the current note and updating only the relevant section.
5. Read relevant entry points, core modules, configuration, tests, and manifests. Replace inventory statements with verified responsibilities, APIs, dependencies, and data flows. Do not infer runtime direction from folder names.
6. Include only commands found in project manifests or actually run. Record verified PowerShell forms and prerequisites in `overview.md`; do not invent build or test commands.
7. Compare `last_verified_commit` against actual Git history after reviewing source. If there is no commit, use `unverified`. List relative repository paths for evidence and identify the project by a normalized Git remote or relative name, never a local absolute path.
8. Review stack knowledge separately. Link an existing `stacks/<stack>.md` when relevant. Propose a project-specific stack skill under `<repo>\.agents\skills\` only if repeatable conventions are not covered by shared skills.
9. Update `00-INDEX.md` with the project link, keep it below 150 lines, and ensure generated paths are Markdown-friendly and relative.

## Stack detection

The helper recognizes `package.json`, `composer.json`, `pyproject.toml`, `requirements.txt`, `*.csproj`, `go.mod`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `Cargo.toml`, `mix.exs`, and `Gemfile`. A manifest signals a candidate, not proof that every dependency is actively used. Record all candidates and confirm the actual stack in the source.

## Safety and pass condition

- Never include secrets, tokens, connection strings, or customer data.
- Do not copy source files or long snippets into notes.
- Do not overwrite an existing vault note automatically.
- Pass when the index points to the project overview, overview commands are sourced, architecture and module responsibilities cite inspected paths, and generated claims are marked unverified where evidence is missing.
