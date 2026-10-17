# Phase 1 — Research and decisions

**Checked:** 2026-10-17  
**Scope:** Codex CLI/IDE and Google Antigravity on Windows 10/11 with PowerShell 7.  
**Status:** Research complete for review. Platform paths and limits can change; verify against the linked docs when implementation begins.

## 1. Current platform requirements

| Area | Codex CLI / IDE | Google Antigravity | Design consequence |
|---|---|---|---|
| Skill format | A skill is a directory with `SKILL.md`; frontmatter requires `name` and `description`. Optional `scripts/`, `references/`, and `assets/` are supported. | Same folder and `SKILL.md` format with `name` and `description`. Antigravity discovers skills in `.agents/skills/` and global `~/.gemini/config/skills/`. | Use only the shared fields in portable skills. Do not require vendor-specific metadata. |
| Global skill path | `$HOME/.agents/skills/` (Codex documents `$HOME/.agents/skills`; `$CODEX_HOME` applies to Codex configuration, but is not the documented skill root). | `~/.gemini/config/skills/<skill>/SKILL.md`. | Keep the source of truth at `%USERPROFILE%\.agents\skills`; link each skill folder into Antigravity's global skills directory. |
| Project skill path | `.agents/skills/` in the current directory and ancestors up to the repository root. Codex follows symlinked skill folders. | `.agents/skills/` in a workspace. | Commit project-specific skills at `<repo>\.agents\skills\`. |
| Global instructions | `~/.codex/AGENTS.md` (or `AGENTS.override.md`). Only the first non-empty global file is read. | `~/.gemini/config/GEMINI.md` or `AGENTS.md`; modular files may go in `~/.gemini/config/rules/*.md`. | Keep global instructions in each tool's own config tree. A single shared global path does not exist. |
| Project instructions | `AGENTS.md` is discovered from repo root down to working directory; one file per directory. | Reads `AGENTS.md`, `GEMINI.md`, and `.agents/rules/*.md` in workspace directories. | Prefer one root `AGENTS.md` with portable content; both platforms read it. Add a separate `GEMINI.md` only for Antigravity-specific behavior. |
| MCP config | User config is `~/.codex/config.toml`; stdio entries use `[mcp_servers.<name>]`, `command`, `args`, and optional `env`. | Global `~/.gemini/config/mcp_config.json`; workspace `.agents/mcp_config.json`; top-level `mcpServers` object with `command`/`args` for stdio. | Provide separate sample files. Never share one config file between the clients. |

Sources: [Codex skills](https://developers.openai.com/codex/skills/), [Codex AGENTS.md](https://developers.openai.com/codex/agent-configuration/agents-md), [Codex MCP](https://developers.openai.com/codex/mcp/), [Antigravity skills](https://antigravity.google/docs/skills?app=antigravity-ide), [Antigravity rules](https://antigravity.google/docs/rules/), [Antigravity MCP](https://antigravity.google/docs/mcp/).

### Limits and conventions

- Codex's initial skill metadata list uses at most 2% of context or 8,000 characters when the context size is unknown. It shortens descriptions first and can omit skills when many are installed. The docs do **not** specify a fixed per-description character limit. Keep descriptions short, specific, and front-load trigger terms; adopt 300 characters as this project's validation ceiling, not as a platform limit.
- Codex instruction files have a default combined 32 KiB limit. Antigravity rule files are limited to 24,000 bytes each, with a 20,000-token shared budget for active global and always-on rules. The requested `<3,000 characters` global rule target is a sensible project convention, not a product limit.
- Keep each skill body below 300 lines as requested. This is a repository authoring rule, not a Codex or Antigravity hard limit. Put detailed material in `references/` and deterministic Windows work in `.ps1` scripts.
- Antigravity's `.agents/rules/` scan is flat; every rule there requires YAML frontmatter with a valid `trigger`. `AGENTS.md` and `GEMINI.md` are plain Markdown and always active in their scope. Prefer the simpler shared root `AGENTS.md` for the common startup/shutdown reminders.
- No reliable first-party evidence found for a Codex `description` hard limit. Do not bake a claimed 1,024-character rule into the validator unless later docs establish it.

Sources: [Codex skills and metadata budget](https://developers.openai.com/codex/skills/), [Codex instruction limits](https://developers.openai.com/codex/agent-configuration/agents-md), [Antigravity rule locations and limits](https://antigravity.google/docs/rules/).

## 2. Existing skill collections

| Collection | Useful patterns to inherit | What to avoid copying wholesale |
|---|---|---|
| [obra/superpowers](https://github.com/obra/superpowers) | Focused composable workflows for planning, TDD, systematic debugging, verification, and code review; concrete steps and evidence gates. | Its methodology assumes particular workflow preferences and includes implementations for multiple agent hosts. Keep this pack neutral about language, shell, and host. |
| [anthropics/skills](https://github.com/anthropics/skills) | Portable `SKILL.md` plus optional references/scripts; progressive disclosure; useful examples of scoped specialist procedures. | Some large document skills are source-available with distinct terms; review each license and platform-specific behavior before reuse. |
| [google/skills](https://github.com/google/skills) | Google-maintained examples and instructions for distributing skills across several harnesses. | Mostly Google product/domain skills; use as a format and packaging reference, not as the coding workflow library. |
| [composio-community/awesome-codex-skills](https://github.com/composio-community/awesome-codex-skills) | Discovery index and examples of practical Codex-focused skills, concise metadata, and skill installer UX. | Community quality varies; inspect source, dependencies, license, and any network/tool permissions before adoption. |

**Adopt:** small single-purpose skills; progressive disclosure; clear trigger descriptions; imperative steps with outputs and pass conditions; optional scripts for repeatable actions; references for variants.

**Drop:** bash-only commands, language assumptions in shared workflows, hidden agent-specific frontmatter, duplicate boilerplate, unconditional testing commands, and unreviewed third-party scripts.

## 3. Obsidian access choices

| Option | Read / search / write | Windows setup and maintenance | Assessment |
|---|---|---|---|
| Native agent file tools, no MCP | Read and write notes if the vault is within the agent's accessible filesystem. Search with built-in file search / `rg`; Obsidian's own index is not involved. | No server or plugin. Access depends on each agent's workspace and sandbox permissions. | **Default recommendation.** Fewest moving parts. The context skills should work directly on Markdown and fall back to repo `.context\` if the vault is inaccessible. |
| Filesystem MCP (`@modelcontextprotocol/server-filesystem`) | Directory listing/tree, text read, search, create, write, edit, and move. Limited to directories passed at startup, but includes write-capable tools. It does not expose Obsidian-specific metadata or commands. | Both clients support stdio. On Windows, the server's published example launches `npx` with `cmd /c`. No Obsidian plugin/API key. Requires Node/npm and package retrieval/update management. | Optional when native tools cannot reach the vault. If installed, pass only the vault path; consider client tool allowlisting/approval for writes. |
| Local REST API plugin plus an Obsidian MCP server (e.g. [mcp-obsidian](https://github.com/MarkusPfundstein/mcp-obsidian) or [cyanheads/obsidian-mcp-server](https://github.com/cyanheads/obsidian-mcp-server)) | Vault listing, reads, search, and note edits through the plugin API; some servers provide frontmatter/tag/section operations. | Requires Obsidian running with a community plugin enabled, plugin API key, and compatible local endpoint/certificate configuration. Extra plugin/server upgrades and secret handling. | Use only if Obsidian-aware search, metadata, commands, or active-vault behavior materially improves the workflow. More setup than Markdown notes need. |

Sources: [Filesystem MCP server](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem), [MarkusPfundstein MCP Obsidian](https://github.com/MarkusPfundstein/mcp-obsidian), [cyanheads Obsidian MCP](https://github.com/cyanheads/obsidian-mcp-server).

### Decision matrix requested in the brief

| Inherit | Omit | Improve | Obsidian choice |
|---|---|---|---|
| Standard skill folders/frontmatter, short rules, modular workflows, references/scripts, repo-specific skill support, context freshness checks, session handoff, secret exclusion. | Bash assumptions, hard-coded stack commands, sprawling always-on rules, mandatory MCP/plugin dependency, copied code in notes. | Use `.agents/skills` as the common project path; distinguish documented platform limits from house limits; verify notes against changed paths; keep MCP optional and vault-scoped; preserve a `.context\` fallback. | No MCP by default. Use direct Markdown file tools; optionally configure the filesystem MCP for vault access across clients. Adopt Local REST API MCP only if Obsidian-native features become a requirement. |

## Known gaps for later verification

1. Antigravity supports the current global skill path `~/.gemini/config/skills/`; historical guides and app releases have used other paths. The installer should detect the installed product/version and validate discovery. Do not create a legacy junction target without evidence it is used.
2. First-party docs do not publish a per-skill description maximum for Codex or Antigravity. The pack's 300-character limit is a conservative lint rule only.
3. MCP package behavior and package versions can change. Pin or explicitly review versions when the installer is implemented; avoid `@latest` in a long-lived unattended setup.
4. Direct vault access depends on the actual Codex/Antigravity security boundary. If a client cannot reach the vault, enable the optional scoped filesystem MCP or use repo-local `.context\`.

