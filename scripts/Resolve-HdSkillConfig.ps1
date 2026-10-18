[CmdletBinding()]
param(
    [Parameter()] [string] $RepoRoot = (Join-Path $PSScriptRoot '..'),
    [Parameter()] [string] $VaultPath,
    [Parameter()] [string[]] $Agents,
    [Parameter()] [string] $HdSkillHome,
    [Parameter()] [string] $ConfigPath,
    [Parameter()] [switch] $PersistConfig,
    [Parameter()] [switch] $NonInteractive
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepoRoot)
$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$profileRoot = [Environment]::GetEnvironmentVariable('USERPROFILE')
if ([string]::IsNullOrWhiteSpace($profileRoot)) { $profileRoot = [Environment]::GetFolderPath('UserProfile') }
$machineConfigPath = if ($ConfigPath) { [IO.Path]::GetFullPath($ConfigPath) } else { Join-Path $profileRoot '.hd-skill\config.json' }
$defaultsPath = Join-Path $toolRoot 'config.defaults.json'
$schemaPath = Join-Path $toolRoot 'config.schema.json'
if (-not (Test-Path -LiteralPath $defaultsPath -PathType Leaf) -or -not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
    throw "Repository configuration files are missing under '$repo'. Run validate.ps1 and restore config.defaults.json/config.schema.json."
}
$defaults = Get-Content -LiteralPath $defaultsPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$machineConfig = $null
if (Test-Path -LiteralPath $machineConfigPath -PathType Leaf) {
    try { $machineConfig = Get-Content -LiteralPath $machineConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Machine config '$machineConfigPath' is invalid JSON. Fix it or move it aside: $($_.Exception.Message)" }
    foreach ($requiredKey in @('schemaVersion', 'vaultName', 'vaultPath', 'contextMode', 'agents', 'machineId', 'projects', 'mcpEnabled')) {
        if (-not ($machineConfig.PSObject.Properties.Name -contains $requiredKey)) { throw "Machine config '$machineConfigPath' is missing '$requiredKey'. Repair it from config.schema.json." }
    }
    if ($machineConfig.schemaVersion -ne 1) { throw "Unsupported machine config schemaVersion '$($machineConfig.schemaVersion)'." }
}
$detected = (& (Join-Path $PSScriptRoot 'Detect-Environment.ps1') -RepoRoot $repo | ConvertFrom-Json -ErrorAction Stop)
$resolvedHome = if ($HdSkillHome) { $HdSkillHome } elseif ($env:HD_SKILL_HOME) { $env:HD_SKILL_HOME } elseif ($machineConfig -and $machineConfig.hdSkillHome) { $machineConfig.hdSkillHome } else { $toolRoot }
$resolvedHome = [IO.Path]::GetFullPath($resolvedHome)

$effectiveVaultPath = $null
$vaultSource = 'none'
if ($VaultPath) { $effectiveVaultPath = $VaultPath; $vaultSource = 'parameter' }
elseif ($env:HD_SKILL_VAULT) { $effectiveVaultPath = $env:HD_SKILL_VAULT; $vaultSource = 'environment' }
elseif ($machineConfig -and $machineConfig.vaultPath) { $effectiveVaultPath = [string]$machineConfig.vaultPath; $vaultSource = 'machine-config' }

$vaultName = if ($machineConfig -and $machineConfig.vaultName) { [string]$machineConfig.vaultName } else { [string]$defaults.vaultName }
$contextMode = if ($machineConfig -and $machineConfig.contextMode) { [string]$machineConfig.contextMode } else { [string]$defaults.contextMode }
# Agent selection: -Agents, then HD_SKILL_AGENTS, then the saved selectedAgents; without any of them, detected agents are used.
$knownAgentIds = @($detected.registry | ForEach-Object { [string]$_.id })
$selectedAgents = $null
$requestedAgents = if ($Agents) { $Agents } elseif ($env:HD_SKILL_AGENTS) { @($env:HD_SKILL_AGENTS) } else { $null }
if ($requestedAgents) {
    $selectedAgents = @($requestedAgents | ForEach-Object { ([string]$_) -split '[,;\s]+' } | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Select-Object -Unique)
    if ($selectedAgents -contains 'detected' -or $selectedAgents -contains 'auto') { $selectedAgents = $null }
    elseif ($selectedAgents -contains 'all') { $selectedAgents = $knownAgentIds }
}
elseif ($machineConfig -and ($machineConfig.PSObject.Properties.Name -contains 'selectedAgents') -and $null -ne $machineConfig.selectedAgents) {
    $selectedAgents = @($machineConfig.selectedAgents | ForEach-Object { [string]$_ })
}
if ($null -ne $selectedAgents) {
    $unknownAgents = @($selectedAgents | Where-Object { $_ -notin $knownAgentIds })
    if ($unknownAgents.Count -gt 0) { throw ("Unknown agent id(s): {0}. Known agents: {1}. Add custom agents to %USERPROFILE%\.hd-skillgents.custom.json." -f ($unknownAgents -join ', '), ($knownAgentIds -join ', ')) }
}
$agentMap = [ordered]@{}
foreach ($agentId in $knownAgentIds) {
    $agentMap[$agentId] = if ($null -ne $selectedAgents) { $agentId -in $selectedAgents } else { [bool]$detected.agents.$agentId }
}

if (-not $effectiveVaultPath) {
    $vaults = @($detected.obsidian.vaults)
    $matching = @($vaults | Where-Object { [string]$_.name -ieq $vaultName })
    if ($matching.Count -gt 0) {
        $effectiveVaultPath = [string]$matching[0].path
        $vaultSource = 'obsidian-name-match'
    }
    elseif ($vaults.Count -gt 1 -and -not $NonInteractive) {
        Write-Host ("Select an Obsidian vault (no vault is named {0}):" -f $vaultName)
        for ($i = 0; $i -lt $vaults.Count; $i++) { Write-Host ("[{0}] {1} - {2}" -f ($i + 1), $vaults[$i].name, $vaults[$i].path) }
        $choice = 0
        while ($choice -lt 1 -or $choice -gt $vaults.Count) {
            $rawChoice = Read-Host 'Vault number'
            [void][int]::TryParse($rawChoice, [ref]$choice)
        }
        $effectiveVaultPath = [string]$vaults[$choice - 1].path
        $vaultSource = 'interactive-selection'
    }
    elseif ($vaults.Count -gt 1) {
        Write-Warning ("Several Obsidian vaults were found but none matches {0}; using repository .context because -NonInteractive is set." -f $vaultName)
    }
    elseif ($vaults.Count -eq 1) {
        Write-Warning ("The only Obsidian vault does not match {0}; using repository .context. Set -VaultPath to choose it explicitly." -f $vaultName)
    }
}

if ($effectiveVaultPath) {
    $effectiveVaultPath = [IO.Path]::GetFullPath($effectiveVaultPath)
    if (Test-Path -LiteralPath $effectiveVaultPath -PathType Container) {
        $contextMode = 'vault'
    }
    else {
        Write-Warning ("Resolved vault path {0} is unavailable; using repository .context." -f $effectiveVaultPath)
        $effectiveVaultPath = $null
        $contextMode = 'repo'
        $vaultSource = 'repository-fallback'
    }
}
if (-not $effectiveVaultPath) {
    $effectiveVaultPath = Join-Path $repo '.context'
    $contextMode = 'repo'
    if ($vaultSource -eq 'none') { $vaultSource = 'repository-fallback' }
}

$machineId = if ($machineConfig -and $machineConfig.machineId -and $machineConfig.machineId -ne 'unconfigured') { [string]$machineConfig.machineId } else { [string]$detected.machineId }
$config = [ordered]@{
    schemaVersion = 1
    vaultName = $vaultName
    vaultPath = if ($contextMode -eq 'vault') { $effectiveVaultPath } else { $null }
    contextMode = $contextMode
    agents = $agentMap
    machineId = $machineId
    projects = if ($machineConfig -and $machineConfig.projects) { $machineConfig.projects } else { $defaults.projects }
    mcpEnabled = [bool]($machineConfig -and $machineConfig.mcpEnabled)
    hdSkillHome = $resolvedHome
}
if ($null -ne $selectedAgents) { $config.selectedAgents = @($selectedAgents) }
if ($PersistConfig) {
    $configDir = Split-Path -Parent $machineConfigPath
    if (-not (Test-Path -LiteralPath $configDir -PathType Container)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $serializedConfig = $config | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($machineConfigPath, $serializedConfig, [Text.UTF8Encoding]::new($false))
}

[pscustomobject]@{
    vaultPath = $effectiveVaultPath
    contextMode = $contextMode
    agents = [pscustomobject]$agentMap
    selectedAgents = $selectedAgents
    machineId = $machineId
    hdSkillHome = $resolvedHome
    configPath = $machineConfigPath
    vaultSource = $vaultSource
    detected = $detected
    config = [pscustomobject]$config
} | ConvertTo-Json -Depth 10 -Compress
