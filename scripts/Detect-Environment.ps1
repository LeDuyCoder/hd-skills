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
    codex = [pscustomobject]@{ installed = $codexDetected; home = $codexHome; command = if ($codexCommand) { $codexCommand.Source } else { $null }; version = $codexVersion }
    antigravity = [pscustomobject]@{ installed = $antigravityDetected; home = $geminiHome; skillsPath = (Join-Path $geminiHome 'config\skills'); legacySkillsPath = (Join-Path $geminiHome 'antigravity\skills') }
    obsidian = [pscustomobject]@{ configPath = $obsidianConfigPath; vaults = @($vaults) }
    tools = [pscustomobject]$tools
    missingToolGuidance = [pscustomobject]$missingToolGuidance
    machineId = $machineId
} | ConvertTo-Json -Depth 8 -Compress
