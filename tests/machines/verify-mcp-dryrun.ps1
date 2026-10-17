[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$machineDefinitions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'machines.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$unicodeProfileName = [string](($machineDefinitions | Where-Object { $_.name -eq 'unicode-spaces-paths' } | Select-Object -First 1).profileFolder)
$npxCommand = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
if (-not $npxCommand) { $npxCommand = Get-Command npx -ErrorAction SilentlyContinue }
if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not $npxCommand) { Write-Host '[SKIP] Node.js/npx unavailable; MCP remains opt-in and was not installed.'; exit 0 }
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hd-skill-mcp-dryrun-' + [guid]::NewGuid().ToString('N'))
$saved = @{}
foreach ($name in @('USERPROFILE', 'APPDATA', 'HD_SKILL_HOME', 'HD_SKILL_VAULT', 'HD_SKILL_MACHINE_ID')) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    $profile = Join-Path $tempRoot $unicodeProfileName
    $appData = Join-Path $profile 'Documents lưu trữ\Roaming'
    $vault = Join-Path $profile 'DevBrain'
    New-Item -ItemType Directory -Path $profile, $appData, $vault, (Join-Path $profile '.codex'), (Join-Path $profile '.gemini') -Force | Out-Null
    $obsidian = Join-Path $appData 'obsidian'
    New-Item -ItemType Directory -Path $obsidian -Force | Out-Null
    $vaultMap = @{}
    $vaultMap[$vault] = @{ path = $vault; ts = 1; open = $true }
    @{ vaults = $vaultMap } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $obsidian 'obsidian.json') -Encoding UTF8
    [Environment]::SetEnvironmentVariable('USERPROFILE', $profile, 'Process')
    [Environment]::SetEnvironmentVariable('APPDATA', $appData, 'Process')
    [Environment]::SetEnvironmentVariable('HD_SKILL_HOME', (Join-Path $profile 'repo home'), 'Process')
    [Environment]::SetEnvironmentVariable('HD_SKILL_VAULT', $null, 'Process')
    [Environment]::SetEnvironmentVariable('HD_SKILL_MACHINE_ID', 'mcp-test-001', 'Process')
    $before = @(Get-ChildItem -LiteralPath $profile -Force -Recurse -File | ForEach-Object { $_.FullName })
    $output = & (Join-Path $repoRoot 'install.ps1') -RepoRoot $repoRoot -DryRun -NonInteractive -WithMcp -Mode Copy 2>&1 6>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "MCP install dry-run failed: $output" }
    if ($output.IndexOf('pinned package version 1.0.0', [StringComparison]::OrdinalIgnoreCase) -lt 0 -or $output.IndexOf('config.toml', [StringComparison]::OrdinalIgnoreCase) -lt 0 -or $output.IndexOf('mcp_config.json', [StringComparison]::OrdinalIgnoreCase) -lt 0) { throw 'MCP dry-run did not include both agent configs and the pinned server version.' }
    $after = @(Get-ChildItem -LiteralPath $profile -Force -Recurse -File | ForEach-Object { $_.FullName })
    if (Compare-Object $before $after) { throw 'MCP dry-run wrote files to the simulated profile.' }
    Write-Host '[PASS] Optional MCP dry-run renders both agent configuration plans with a pinned server and a Unicode vault path; no files were written.'
}
finally {
    foreach ($name in @('USERPROFILE', 'APPDATA', 'HD_SKILL_HOME', 'HD_SKILL_VAULT', 'HD_SKILL_MACHINE_ID')) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
