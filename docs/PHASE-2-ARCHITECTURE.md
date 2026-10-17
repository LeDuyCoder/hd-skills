# Phase 2 — Installation architecture

**Status:** Proposal for review; no installer, skills, or user configuration has been installed.  
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

This completes the design for Phases 1 and 2 only. The next phase would create the Obsidian note templates and context skills, after the user approves this architecture and any requested changes.

