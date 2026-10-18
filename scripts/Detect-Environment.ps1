[CmdletBinding()]
param(
    [Parameter()] [string] $RepoRoot = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
$profileRoot = [Environment]::GetEnvironmentVariable('USERPROFILE')
if ([string]::IsNullOrWhiteSpace($profileRoot)) { $profileRoot = [Environment]::GetFolderPath('UserProfile') }
$appDataRoot = [Environment]::GetEnvironmentVariable('APPDATA')
if ([string]::IsNullOrWhiteSpace($appDataRoot)) { $appDataRoot = Join-Path $profileRoot 'AppData\Roaming' }

$codexCommand = Get-Command codex -ErrorAction SilentlyContinue
$codexHome = Join-Path $profileRoot '.codex'
$geminiHome = Join-Path $profileRoot '.gemini'
$codexSkillsPath = Join-Path $profileRoot '.agents\skills'
$geminiSkillsPath = Join-Path $geminiHome 'config\skills'
$geminiMcpPath = Join-Path $geminiHome 'config\mcp_config.json'
$codexDetected = [bool]($codexCommand -or (Test-Path -LiteralPath $codexHome -PathType Container))
$antigravityDetected = Test-Path -LiteralPath $geminiHome -PathType Container
$codexVersion = $null
if ($codexCommand) {
    try {
        $versionOutput = @(& $codexCommand.Source --version 2>$null)
        if ($LASTEXITCODE -eq 0 -and $versionOutput.Count -gt 0) { $codexVersion = [string]$versionOutput[0] }
    }
    catch { $codexVersion = $null }
}

# Agent registry: agents.json beside the tool root, then the user's agents.custom.json (same id replaces, new id appends).
$registry = [System.Collections.Generic.List[object]]::new()
$registrySources = @(
    (Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) 'agents.json'),
    (Join-Path $profileRoot '.hd-skill\agents.custom.json')
)
foreach ($registryPath in $registrySources) {
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { continue }
    try { $registryDocument = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
    catch { Write-Warning "Unable to parse agent registry '$registryPath': $($_.Exception.Message)"; continue }
    foreach ($entry in @($registryDocument.agents)) {
        if (-not $entry -or [string]::IsNullOrWhiteSpace([string]$entry.id) -or [string]$entry.id -notmatch '^[a-z0-9][a-z0-9_-]{0,31}$') { Write-Warning "Skipping an agent without a valid lowercase id in '$registryPath'."; continue }
        if (-not $entry.global -or [string]::IsNullOrWhiteSpace([string]$entry.global.skillsPath)) { Write-Warning "Skipping agent '$($entry.id)' in '$registryPath': global.skillsPath is required."; continue }
        $existingIndex = -1
        for ($i = 0; $i -lt $registry.Count; $i++) { if ($registry[$i].id -eq $entry.id) { $existingIndex = $i } }
        if ($existingIndex -ge 0) { $registry[$existingIndex] = $entry } else { $registry.Add($entry) }
    }
}
if ($registry.Count -eq 0) {
    $registry.Add([pscustomobject]@{ id = 'codex'; name = 'OpenAI Codex'; detect = [pscustomobject]@{ paths = @('.codex'); commands = @('codex') }; global = [pscustomobject]@{ skillsPath = '.agents\skills'; rulesPath = '.codex\AGENTS.md'; rulesSource = 'rules\AGENTS.md' }; project = [pscustomobject]@{ skillsPath = '.agents\skills'; rulesPath = 'AGENTS.md' }; mcp = 'codex-toml'; invoke = '$hd' })
    $registry.Add([pscustomobject]@{ id = 'antigravity'; name = 'Google Antigravity'; detect = [pscustomobject]@{ paths = @('.gemini'); commands = @() }; global = [pscustomobject]@{ skillsPath = '.gemini\config\skills'; rulesPath = '.gemini\config\GEMINI.md'; rulesSource = 'rules\GEMINI.md' }; project = [pscustomobject]@{ skillsPath = '.agents\skills'; rulesPath = 'AGENTS.md' }; mcp = 'antigravity-json'; invoke = '/hd' })
}
$agentDetection = [ordered]@{}
foreach ($entry in $registry) {
    $found = $false
    foreach ($relative in @($entry.detect.paths)) { if ($relative -and (Test-Path -LiteralPath (Join-Path $profileRoot $relative))) { $found = $true } }
    foreach ($commandName in @($entry.detect.commands)) { if ($commandName -and (Get-Command $commandName -ErrorAction SilentlyContinue)) { $found = $true } }
    if ($entry.id -eq 'codex') { $found = $codexDetected }
    if ($entry.id -eq 'antigravity') { $found = $antigravityDetected }
    $agentDetection[[string]$entry.id] = $found
}

$vaults = @()
$obsidianConfigPath = Join-Path $appDataRoot 'obsidian\obsidian.json'
if (Test-Path -LiteralPath $obsidianConfigPath -PathType Leaf) {
    try {
        $obsidianConfig = Get-Content -LiteralPath $obsidianConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $vaultEntries = $obsidianConfig.vaults
        if ($vaultEntries -is [pscustomobject]) {
            foreach ($entry in $vaultEntries.PSObject.Properties) {
                $vaultPath = [string]$entry.Name
                if ($entry.Value.path) { $vaultPath = [string]$entry.Value.path }
                if ([string]::IsNullOrWhiteSpace($vaultPath)) { continue }
                $vaults += [pscustomobject]@{ name = (Split-Path -Leaf $vaultPath); path = $vaultPath }
            }
        }
    }
    catch { Write-Warning "Unable to parse Obsidian vault list at '$obsidianConfigPath': $($_.Exception.Message)" }
}

$tools = [ordered]@{
    git = [bool](Get-Command git -ErrorAction SilentlyContinue)
    node = [bool](Get-Command node -ErrorAction SilentlyContinue)
    npx = [bool](Get-Command npx -ErrorAction SilentlyContinue)
    powershell7 = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
}
$missingToolGuidance = @{}
if (-not $tools.git) { $missingToolGuidance.git = 'Install Git for Windows from https://git-scm.com/download/win.' }
if (-not $tools.node -or -not $tools.npx) { $missingToolGuidance.node = 'Install a supported Node.js LTS release from https://nodejs.org/ to get node and npx.' }
if (-not $tools.powershell7) { $missingToolGuidance.powershell7 = 'Install PowerShell 7 from https://aka.ms/powershell; Windows PowerShell 5.1 can run current compatibility checks.' }

$machineId = [Environment]::GetEnvironmentVariable('HD_SKILL_MACHINE_ID')
if ([string]::IsNullOrWhiteSpace($machineId)) {
    $machineSeed = $null
    try { $machineSeed = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction Stop).MachineGuid }
    catch { $machineSeed = $null }
    if ([string]::IsNullOrWhiteSpace($machineSeed)) { $machineSeed = '{0}|{1}' -f $env:COMPUTERNAME, $env:USERNAME }
    $identity = [string]$machineSeed
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { $hash = $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity)) }
    finally { $sha256.Dispose() }
    $computerLabel = $env:COMPUTERNAME -replace '[^A-Za-z0-9_-]', '-'
    if ($computerLabel.Length -gt 20) { $computerLabel = $computerLabel.Substring(0, 20) }
    if ([string]::IsNullOrWhiteSpace($computerLabel)) { $computerLabel = 'machine' }
    $machineId = ($computerLabel.ToLowerInvariant() + '-' + ([BitConverter]::ToString($hash).Replace('-', '').Substring(0, 6).ToLowerInvariant()))
    if ($machineId.Length -gt 32) { $machineId = $machineId.Substring(0, 32) }
}

[pscustomobject]@{
    profileRoot = $profileRoot
    appDataRoot = $appDataRoot
    repoRoot = [IO.Path]::GetFullPath($RepoRoot)
    codex = [pscustomobject]@{ installed = $codexDetected; home = $codexHome; skillsPath = $codexSkillsPath; mcpConfigPath = (Join-Path $codexHome 'config.toml'); command = if ($codexCommand) { $codexCommand.Source } else { $null }; version = $codexVersion }
    antigravity = [pscustomobject]@{ installed = $antigravityDetected; home = $geminiHome; skillsPath = $geminiSkillsPath; skillsDirectoryExists = (Test-Path -LiteralPath $geminiSkillsPath -PathType Container); existingSkillNames = if (Test-Path -LiteralPath $geminiSkillsPath -PathType Container) { @(Get-ChildItem -LiteralPath $geminiSkillsPath -Directory | ForEach-Object Name) } else { @() }; mcpConfigPath = $geminiMcpPath; mcpConfigured = (Test-Path -LiteralPath $geminiMcpPath -PathType Leaf); legacySkillsPath = (Join-Path $geminiHome 'antigravity\skills') }
    registry = @($registry)
    agents = [pscustomobject]$agentDetection
    obsidian = [pscustomobject]@{ configPath = $obsidianConfigPath; vaults = @($vaults) }
    tools = [pscustomobject]$tools
    missingToolGuidance = [pscustomobject]$missingToolGuidance
    machineId = $machineId
} | ConvertTo-Json -Depth 8 -Compress
