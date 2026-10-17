---
name: windows-shell
description: Write and troubleshoot PowerShell commands and scripts for Windows paths, encoding, processes, and permissions.
---

# Work in Windows shells

1. Start with `context-load` when operating inside a project; use its resolver-selected context path.
2. Use PowerShell syntax and native Windows tools. Do not assume Bash, Unix path separators, or shell-specific quoting.
3. Pass user-controlled paths with `-LiteralPath` or as a single argument. Build paths with `Join-Path` and resolve with `[IO.Path]::GetFullPath`; do not split on spaces or assume drive C.
4. For text files, choose an explicit encoding. Use UTF-8 without BOM for shared Markdown/JSON unless a consumer requires otherwise; preserve existing line endings when editing user files.
5. Check command exit status and distinguish Windows PowerShell 5.1 from PowerShell 7 when APIs or encoding defaults differ. Do not install tools or alter system/user environment without authorization.
6. When a port, process, or permission fails, inspect the exact process and ACL state before changing it. Prefer a narrow reversible fix.
7. Run relevant project commands from `overview.md`; never guess a build or test script from the stack name.
8. Call `context-update` for a verified Windows-specific project quirk that is likely to recur.

## Pass condition

Commands preserve paths with spaces and Unicode, use explicit encoding and scope, and state shell-version assumptions accurately.
