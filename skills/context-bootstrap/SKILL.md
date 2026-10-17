---
name: context-bootstrap
description: Build a first-pass context store for a new repository. Use when onboarding an unfamiliar project or when asked to generate project overview, architecture, module notes, and stack-specific skill proposals.
---

# Bootstrap project context

## Procedure

1. Locate the repository root and inspect manifests before reading broad source trees. Run `scripts\detect-stack.ps1 -RepoPath <repo>` to identify candidate stacks. The detector reports all recognized manifests; a monorepo may have several stacks.
2. Run `scripts\bootstrap-context.ps1 -RepoPath <repo> -OutputRoot <vault-root> -ProjectName <name>`. Use `D:\Obsidian\DevBrain` only when it is readable and writable; otherwise target `<repo>\.context\`.
3. The script creates a structural first pass: `00-INDEX.md`, `overview.md`, `architecture.md`, module inventory notes under `modules\`, `gotchas.md`, a decisions index, and a dated session note. It does not invent an ADR. Existing notes are never overwritten; resolve any collision by reading and updating them deliberately.
4. Read the relevant entry points, core modules, configuration, tests, and manifests. Replace inventory statements with verified responsibilities, APIs, dependencies, and data flows. Do not infer runtime direction from folder names.
5. Include only commands that appear in project manifests or that you actually ran. Record the exact PowerShell form, prerequisites, and pass result in `overview.md`. Do not invent a universal test/lint/build command.
6. Compare `last_verified_commit` against actual Git history after reviewing source. If there is no commit, use `unverified`. List relative paths for the source evidence each note describes.
7. Review stack knowledge separately. Link an existing `stacks/<stack>.md` when relevant. Propose a project-specific stack skill under `<repo>\.agents\skills\` only if the project has repeatable conventions not covered by the shared skills. Describe the proposed skill's trigger and scope; do not silently generate unrelated global skills.
8. Update `00-INDEX.md` with the project link, check it remains under 150 lines, and ensure all generated paths use Markdown-friendly relative paths.

## Stack detection

The helper recognizes `package.json`, `composer.json`, `pyproject.toml`, `requirements.txt`, `*.csproj`, `go.mod`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `Cargo.toml`, `mix.exs`, and `Gemfile`. A manifest signals a candidate, not proof that every dependency is actively used. Record all candidates and confirm the actual stack in the source.

## Safety and pass condition

- Never include secrets, tokens, connection strings, or customer data.
- Do not copy source files or long snippets into notes.
- Do not overwrite an existing vault note automatically.
- Pass when the index points to the project overview, overview commands are sourced, architecture and module responsibilities cite inspected paths, and generated claims are marked unverified where evidence is missing.
