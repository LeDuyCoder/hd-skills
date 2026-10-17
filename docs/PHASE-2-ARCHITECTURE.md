# Phase 2 — Installation architecture

**Status:** Approved architecture. Multi-machine requirements below supersede earlier fixed per-user path assumptions.  
**Target:** One Windows source of truth for Codex and Antigravity, PowerShell 7, project-specific overrides committed with their repositories.

## 1. Source of truth and discovery

```text
%USERPROFILE%\.agents\skills\                 # canonical global skills; Codex reads directly
%USERPROFILE%\.gemini\config\skills\           # Antigravity global junction/copies to canonical skills
<repo>\.agents\skills\                         # project-specific skills; commit to the repo
%USERPROFILE%\.codex\AGENTS.md                  # concise Codex global instructions
%USERPROFILE%\.gemini\config\GEMINI.md          # concise Antigravity global instructions
<repo>\AGENTS.md                                # shared project instructions, read by both agents
```

Antigravity's documented current global path is `~/.gemini/config/skills/`. The installer should create one directory junction from that path to `%USERPROFILE%\.agents\skills` when no conflicting target exists. A `-Copy` mode can mirror files for backup/cloud-sync tools that do not handle junctions. An older Antigravity path such as `~/.gemini/antigravity/skills/` should be offered only after a detection or user-selected compatibility mode; it is not the current default in the docs checked on 2026-10-17.

Use `New-Item -ItemType Junction -Path ... -Target ...` in PowerShell. Before creating it, resolve both absolute paths, verify the target directory, and refuse to replace a non-empty destination. Do not require administrator privileges. Uninstall should remove only the managed junction, never recursively delete the canonical source.

## 2. Proposed repository tree

```text
.
├── README.md
├── docs/
│   ├── PHASE-1-RESEARCH.md
│   └── PHASE-2-ARCHITECTURE.md
├── install.ps1                         # Phase 5 implementation
├── uninstall.ps1                       # Phase 5 implementation
├── validate.ps1                         # Phase 5 implementation
├── config/
│   ├── codex-config.example.toml        # optional filesystem MCP example
│   ├── antigravity-mcp.example.json     # optional filesystem MCP example
│   ├── global-codex-AGENTS.md            # copied to ~/.codex/AGENTS.md
│   └── global-antigravity-GEMINI.md      # copied to ~/.gemini/config/GEMINI.md
├── skills/
│   ├── context-load/
│   ├── context-update/
│   ├── context-audit/
│   ├── session-handoff/
│   ├── context-bootstrap/
│   ├── planning/
│   ├── tdd/
│   ├── systematic-debugging/
│   ├── verification-before-done/
│   ├── code-review/
│   ├── refactoring/
│   ├── security-review/
│   ├── git-workflow/
│   ├── pull-request/
│   ├── fix-ci/
│   ├── dependency-upgrade/
│   ├── windows-shell/
│   ├── skill-improve/
│   └── stack-skill-generator/
└── templates/
    ├── project-AGENTS.md
    └── stack-skill/
```

Every skill folder contains `SKILL.md`; only when needed it contains `references/` and `scripts/*.ps1`. Shared skills use only `name` and `description` frontmatter. Stack-specific material is generated into `<repo>\.agents\skills\` from `templates\stack-skill\`, not added to the global pack.

## 3. Always-on rules

Global Codex file: `config\global-codex-AGENTS.md` → `%USERPROFILE%\.codex\AGENTS.md`.  
Global Antigravity file: `config\global-antigravity-GEMINI.md` → `%USERPROFILE%\.gemini\config\GEMINI.md`.

Both files stay below 3,000 characters and carry the same core instructions:

1. At the start of a coding task, invoke `context-load` before broad codebase exploration. It reads `00-INDEX.md`, the project overview, then only the relevant note and verifies freshness before trusting it.
2. At the end, invoke `context-update` to update affected notes and append a session handoff. Record decisions as ADRs. Do not copy large code blocks into the vault.
3. If vault access fails, use the repository's `.context\` fallback with the same shape.
4. Do not write secrets, tokens, connection strings, or customer data into the vault.

The names above are proposed skill names; their files are part of Phase 3 and are intentionally not created yet. Project repositories can use one root `AGENTS.md`; Antigravity reads this format and Codex reads it natively. If a project needs an Antigravity-only instruction, add a concise `GEMINI.md` beside it. Avoid duplicating the same content in both project files.

## 4. Optional Obsidian filesystem MCP templates

The default is native file tools. These examples are optional for clients that cannot read the vault directly. They scope MCP access to one vault and contain no credentials. `D:\Obsidian\DevBrain` is a placeholder and must be replaced with the chosen absolute vault path. Use a reviewed, pinned package version before an unattended install.

### Codex — `~/.codex/config.toml`

```toml
[mcp_servers.devbrain]
enabled = false
command = "cmd"
args = ["/c", "npx", "-y", "@modelcontextprotocol/server-filesystem", "D:\\Obsidian\\DevBrain"]
```

Enable by setting `enabled = true` after reviewing the package and allowed path. The server exposes write-capable tools as well as reads; use the client's tool approval or allowlist settings to govern writes. Codex MCP keys documented here are `command`, `args`, `env`, `url`, and related `mcp_servers` fields.

### Antigravity — `~/.gemini/config/mcp_config.json`

```json
{
  "mcpServers": {
    "devbrain": {
      "command": "cmd",
      "args": [
        "/c",
        "npx",
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "D:\\Obsidian\\DevBrain"
      ],
      "disabled": true
    }
  }
}
```

Enable by changing `disabled` to `false` after reviewing the same controls. JSON backslashes are doubled; spaces in paths are safe because the path is one argument in the array. Do not embed API keys or tokens in either file. For the Local REST API route, keep the API key in a protected environment variable and use a server-specific configuration approved in a later implementation phase.

## 5. Installer behavior proposal

`install.ps1` should support `-WhatIf`/dry-run, `-Copy`, and an explicit `-ConfigureMcp` switch. Default installation should:

1. Check PowerShell 7 and resolve `%USERPROFILE%` paths.
2. Create missing directories and install the canonical skill folders without overwriting existing folders.
3. Create or validate the Antigravity junction; back up any managed global rule/config file before changing it.
4. Leave MCP disabled unless `-ConfigureMcp` is passed and a vault path is provided. Never replace an existing config wholesale; merge only the named server entry after parsing and preserve other entries.
5. Check that Obsidian and the selected vault path exist when the user enables vault integration. Report direct-file access and `.context\` fallback instructions.
6. Print each action and a final status; return a non-zero exit code on a failed check.

`uninstall.ps1` should remove the managed junction and the package's own installed global rules only after verifying their contents or a package marker. It must not delete the canonical skills source, project skills, the Obsidian vault, or unrelated MCP entries. Backups stay available for manual recovery.

## 6. Verification criteria for the implementation phase

| Check | Pass condition |
|---|---|
| PowerShell compatibility | All `.ps1` files parse and run under PowerShell 7 on Windows; no bash-only syntax or Unix paths. |
| Skill metadata | Every `SKILL.md` has exactly one valid `name` and `description`; skill names are unique; description is at most the project's 300-character lint target; body is under 300 lines. |
| Junction | The Antigravity skill path resolves to the canonical directory; a test skill appears at both paths; copy mode mirrors it. |
| Rules | Global Codex and Antigravity rules are each under 3,000 characters and include load-first/update-last and secret exclusions. |
| MCP config | TOML example parses with a TOML parser; JSON passes `ConvertFrom-Json`; on Windows `cmd /c npx ...` starts the optional filesystem server with only the vault path allowed. |
| Backup/idempotence | Re-running install preserves pre-existing content and unrelated MCP entries; uninstall removes only managed links/files. |
| Memory fallback | When the vault is inaccessible, context skills locate or create `.context\` without blocking the coding task. |

## Review gate

The Phase 1 and Phase 2 architecture, including the Multi-machine section below, has been approved. Implementation proceeds against this document. Real-machine installation follows the explicit backup, dry-run, no-MCP, and no-real-vault constraints in the active implementation request.

# Multi-machine

This section supersedes any fixed per-user paths in the earlier installation sketch. The repository contains only shared skills, rules, templates, and scripts. Machine-specific paths and selections live in `%USERPROFILE%\.hd-skill\config.json`, which is outside the repository. The installer never assumes that the profile, Documents, vault, or repository is on drive C; all paths are resolved at runtime and must support spaces and Unicode.

## Configuration resolution

Resolve settings in this order: command-line parameters to `install.ps1` (for example `-VaultPath`), environment variables (`HD_SKILL_HOME`, `HD_SKILL_VAULT`), `%USERPROFILE%\.hd-skill\config.json`, runtime discovery, then repository `config.defaults.json`. Persist first-run discoveries to the machine config and print the resolved values for the operator to review. `config.schema.json` defines and validates the machine config. Keep local project-name-to-path mappings in that config; never put local absolute project paths in shared notes.

`Resolve-HdSkillConfig.ps1` is the shared runtime entry point for context skills. It emits JSON containing `vaultPath`, `contextMode` (`vault` or `repo`), installed `agents`, and a stable per-machine `machineId`. It applies the same environment, machine-config, discovery, and defaults precedence. Context skills call it before any context-store read or write. If no vault can be resolved, use the repository `.context\` store. The global rules only instruct agents to run the resolver; they do not embed a vault path.

## Discovery and installation targets

- Obsidian discovery reads `%APPDATA%\obsidian\obsidian.json`. Prefer a vault matching configured `vaultName` (default `DevBrain`). If several vaults exist but none matches, prompt for a choice; in `-NonInteractive` mode, use repository `.context\` and report the fallback. Obsidian is optional.
- Detect Codex from the `codex` command and `%USERPROFILE%\.codex\`, recording its version when available. Detect Antigravity from `%USERPROFILE%\.gemini\` and its existing skill/MCP locations. Install only for agents detected on this machine. Report other Antigravity paths that already exist; do not create compatibility junctions to legacy locations.
- Report whether Git, Node/npm/npx, and PowerShell 7 are available, with installation guidance for missing tools. Never install prerequisites automatically.
- Use a shared skill source under the detected `HD_SKILL_HOME` (or the bootstrap-selected repository location). Link or copy only detected agent skill directories. Re-running install must converge on the same links/files and configuration without duplicate rules or MCP entries. Before changing agent configuration, make a timestamped backup and replace only the bounded `BEGIN/END hd-skill` block.
- MCP is opt-in. Generate each agent's configuration from a checked-in template and the resolved machine paths; pin server versions. The default installation does not enable MCP.

`bootstrap.ps1` clones or pulls the repository into `HD_SKILL_HOME`, resolves and summarizes machine settings, then invokes installation. It supports `-DryRun`, `-NonInteractive`, `-Mode Junction|Copy`, and `-WithMcp`; a fresh bootstrap uses `-RepositoryUrl` when there is no existing checkout or configured remote. `install.ps1`, `update.ps1`, and `uninstall.ps1` default to no-write dry runs; use `-Apply` for their mutations. `update.ps1` pulls the shared repository, validates it, and reinstalls while preserving machine config. Uninstall removes only hd-skill-owned links/copies and managed configuration blocks. `doctor.ps1` reports config validity, vault access, install link/copy integrity, agent visibility, optional MCP startup, and local versus remote repository revisions; each failed check includes a repair command or action.

## Shared repository and vault synchronization

Synchronize the hd-skill repository with Git. hd-skill does not synchronize vault contents. Document supported operator-managed vault choices: Obsidian Sync, a vault Git workflow, or OneDrive/Google Drive. Keep `.context\` as a local/repository fallback with the same note structure.

Session notes use `<yyyy-MM-dd>_<machineId>.md` so separate machines do not overwrite one another. `context-update` edits only the relevant note section, checks the note's `updated` value before writing, and rereads/reconciles when the stored note is newer than the version it inspected. Shared project notes identify repositories by a repo-relative path or normalized Git remote (for example `github.com/owner/repo`), not by a machine-specific absolute path. Local checkout paths belong only in that machine's config.

## Multi-machine verification gate

Before releasing the installer, exercise three isolated machine profiles under `tests\machines\`: (a) Codex, Antigravity, and Obsidian; (b) Codex only and no Obsidian; and (c) paths containing spaces and Vietnamese characters. Point environment variables at each temporary profile. For each profile run bootstrap dry-run, install, a second install, doctor, and uninstall. Verify the second install makes no changes and uninstall restores the starting state. Record the results in `docs\PROGRESS.md` and commit the completed implementation as `feat(multi-machine): ...`.
