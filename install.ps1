[CmdletBinding()]
param(
    [Parameter()] [string] $RepoRoot = $PSScriptRoot,
    [Parameter()] [string] $VaultPath,
    [Parameter()] [string[]] $Agents,
    [Parameter()] [ValidateSet('Junction', 'Copy')] [string] $Mode = 'Junction',
    [Parameter()] [switch] $WithMcp,
    [Parameter()] [switch] $NonInteractive,
    [Parameter()] [switch] $DryRun = $true,
    [Parameter()] [switch] $Apply
)

$ErrorActionPreference = 'Stop'
if ($Apply) { $DryRun = $false }
$repo = [IO.Path]::GetFullPath($RepoRoot)
if (-not (Test-Path -LiteralPath (Join-Path $repo 'config.schema.json') -PathType Leaf)) { throw "Not an hd-skill repository: $repo" }
$validator = Join-Path $repo 'scripts\validate.ps1'
& $validator -RootPath (Join-Path $repo 'skills')
if ($LASTEXITCODE -ne 0) { throw 'Skill/config validation failed; installation stopped.' }
$resolver = Join-Path $repo 'scripts\Resolve-HdSkillConfig.ps1'
$resolveArgs = @{ RepoRoot = $repo; NonInteractive = $NonInteractive }
if ($VaultPath) { $resolveArgs.VaultPath = $VaultPath }
if ($Agents) { $resolveArgs.Agents = $Agents }
$resolved = (& $resolver @resolveArgs | ConvertFrom-Json -ErrorAction Stop)
$profileRoot = [string]$resolved.detected.profileRoot
$machineConfigPath = [string]$resolved.configPath
$machineConfigDirectory = Split-Path -Parent $machineConfigPath
$statePath = Join-Path $machineConfigDirectory 'install-state.json'
$agentSpecs = @()
foreach ($entry in @($resolved.detected.registry)) {
    if (-not $resolved.agents.([string]$entry.id)) { continue }
    $agentSpecs += [pscustomobject]@{
        name = [string]$entry.id
        displayName = if ($entry.name) { [string]$entry.name } else { [string]$entry.id }
        skillsPath = (Join-Path $profileRoot ([string]$entry.global.skillsPath))
        rulesPath = if ($entry.global.rulesPath) { Join-Path $profileRoot ([string]$entry.global.rulesPath) } else { $null }
        rulesSource = if ($entry.global.rulesSource) { Join-Path $repo ([string]$entry.global.rulesSource) } else { Join-Path $repo 'rules\AGENTS.md' }
        mcp = [string]$entry.mcp
    }
}
$warnings = @()
foreach ($legacyPath in @($resolved.detected.antigravity.legacySkillsPath)) {
    if (Test-Path -LiteralPath $legacyPath) { $warnings += "Legacy Antigravity location exists and was left unchanged: $legacyPath" }
}
foreach ($toolName in @('git', 'node', 'npx', 'powershell7')) {
    if (-not $resolved.detected.tools.$toolName) {
        $guidance = $resolved.detected.missingToolGuidance.PSObject.Properties[$toolName]
        if ($guidance) { $warnings += [string]$guidance.Value }
    }
}
if ($agentSpecs.Count -eq 0) { $warnings += 'No supported coding agent was detected; no skill target will be installed.' }
if ($WithMcp -and $resolved.contextMode -ne 'vault') { throw 'WithMcp requires a readable configured Obsidian vault; native file access remains the default.' }
if ($WithMcp -and (-not $resolved.detected.tools.node -or -not $resolved.detected.tools.npx)) { throw 'WithMcp requires node and npx. Install Node.js LTS manually, then retry.' }
if ($WithMcp) {
    foreach ($agent in $agentSpecs | Where-Object { -not $_.mcp }) {
        $hint = if ($agent.name -eq 'claude') { " Run: claude mcp add --scope user hd-skill-filesystem -- cmd /c npx -y @modelcontextprotocol/server-filesystem@1.0.0 `"$($resolved.vaultPath)`"" } else { ' Add the filesystem MCP server in that agent''s own settings.' }
        $warnings += "hd-skill does not write MCP config for $($agent.displayName).$hint"
    }
}

function Get-FileHashHex([string] $Path) {
    $stream = [IO.File]::OpenRead($Path)
    try { $algorithm = [Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() } finally { $algorithm.Dispose() } }
    finally { $stream.Dispose() }
}
function Get-TextHashHex([string] $Text) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($algorithm.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}
function Write-Utf8NoBom([string] $Path, [string] $Text) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}
function Merge-MarkedBlock([string] $Existing, [string] $Block) {
    $begin = '# BEGIN hd-skill'
    $end = '# END hd-skill'
    $hasBegin = $Existing.Contains($begin)
    $hasEnd = $Existing.Contains($end)
    if ($hasBegin -ne $hasEnd) { throw 'A global text file has an incomplete hd-skill marker block; repair it before installation.' }
    if ($hasBegin) {
        $start = $Existing.IndexOf($begin, [StringComparison]::Ordinal)
        $finish = $Existing.IndexOf($end, $start, [StringComparison]::Ordinal) + $end.Length
        if ($finish -lt $end.Length) { throw 'The hd-skill END marker precedes its BEGIN marker.' }
        return $Existing.Substring(0, $start) + $Block.TrimEnd() + $Existing.Substring($finish)
    }
    $separator = if ([string]::IsNullOrEmpty($Existing) -or $Existing.EndsWith("`n") -or $Existing.EndsWith("`r")) { '' } else { [Environment]::NewLine }
    return $Existing + $separator + $Block.TrimEnd() + [Environment]::NewLine
}
function Remove-MarkedBlock([string] $Text, [bool] $OriginalEndedWithNewline) {
    $begin = '# BEGIN hd-skill'
    $end = '# END hd-skill'
    $start = $Text.IndexOf($begin, [StringComparison]::Ordinal)
    if ($start -lt 0) { return $Text }
    $endStart = $Text.IndexOf($end, $start, [StringComparison]::Ordinal)
    if ($endStart -lt 0) { throw 'Managed hd-skill block has no END marker; repair it before changing the agent selection.' }
    $prefix = $Text.Substring(0, $start)
    if (-not $OriginalEndedWithNewline) { $prefix = $prefix -replace '(?:\r\n|\n|\r)$', '' }
    $suffix = $Text.Substring($endStart + $end.Length) -replace '^(?:\r\n|\n|\r)', ''
    return $prefix + $suffix
}
function Get-ExistingText([string] $Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
    return ''
}
function Get-McpJsonText([string] $Path, [string] $Vault) {
    $document = [ordered]@{}
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $loaded = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        foreach ($property in $loaded.PSObject.Properties) { $document[$property.Name] = $property.Value }
    }
    if (-not $document.Contains('mcpServers')) { $document.mcpServers = [ordered]@{} }
    $servers = [ordered]@{}
    $existingServers = $document.mcpServers
    if ($existingServers -is [pscustomobject]) { foreach ($property in $existingServers.PSObject.Properties) { $servers[$property.Name] = $property.Value } }
    elseif ($existingServers -is [System.Collections.IDictionary]) { foreach ($key in $existingServers.Keys) { $servers[[string]$key] = $existingServers[$key] } }
    $templatePath = Join-Path $repo 'config\mcp-antigravity.json.template'
    $template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    $jsonVault = $Vault.Replace('\', '\\').Replace('"', '\"')
    $template = $template.Replace('{{vaultPathJson}}', $jsonVault)
    $managedServer = (ConvertFrom-Json -InputObject $template -ErrorAction Stop).'hd-skill-filesystem'
    if ($servers.Contains('hd-skill-filesystem')) {
        $prior = $servers['hd-skill-filesystem']
        if ($prior.command -ne 'cmd' -or @($prior.args) -notcontains '@modelcontextprotocol/server-filesystem@1.0.0') { throw 'mcp_config.json already contains an unrelated hd-skill-filesystem server entry.' }
    }
    $servers['hd-skill-filesystem'] = $managedServer
    $document.mcpServers = $servers
    return ($document | ConvertTo-Json -Depth 20) + [Environment]::NewLine
}

$previousState = $null
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    try { $previousState = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Install state is invalid JSON at '$statePath'; preserve it and repair before reinstalling." }
    if ($previousState.mode -ne $Mode) { throw "Installed mode is '$($previousState.mode)'; uninstall first before switching to '$Mode'." }
}
$stateSkills = @()
$createdDirectories = @()
if ($previousState) { $createdDirectories = @($previousState.createdDirectories | Where-Object { $_ }) }
$configChanges = [System.Collections.Generic.List[object]]::new()
$managedSkillChanges = [System.Collections.Generic.List[object]]::new()
$sharedTargetRoot = Join-Path $machineConfigDirectory 'scripts'
$sharedSourceFiles = @(
    (Join-Path $repo 'scripts\Resolve-HdSkillConfig.ps1'),
    (Join-Path $repo 'scripts\Detect-Environment.ps1'),
    (Join-Path $repo 'config.schema.json'),
    (Join-Path $repo 'config.defaults.json'),
    (Join-Path $repo 'agents.json')
)
$sharedState = @()
foreach ($source in $sharedSourceFiles) {
    $target = if ((Split-Path -Leaf $source) -like '*.json') { Join-Path $machineConfigDirectory (Split-Path -Leaf $source) } else { Join-Path $sharedTargetRoot (Split-Path -Leaf $source) }
    $existingHash = if (Test-Path -LiteralPath $target -PathType Leaf) { Get-FileHashHex $target } else { $null }
    $oldEntry = @($previousState.sharedFiles | Where-Object { $_.target -eq $target } | Select-Object -First 1)
    $sharedExisted = if ($oldEntry.Count -gt 0) { [bool]$oldEntry[0].existed } else { [bool]$existingHash }
    if ($existingHash -and -not $oldEntry -and $existingHash -ne (Get-FileHashHex $source)) { throw "Unmanaged file conflicts with an hd-skill runtime file: $target" }
    $needsCopy = -not $existingHash -or $existingHash -ne (Get-FileHashHex $source)
    if ($needsCopy) { $managedSkillChanges.Add([pscustomobject]@{ action = 'copy runtime file'; source = $source; target = $target }) }
    $sharedState += [pscustomobject]@{ source = $source; target = $target; hash = (Get-FileHashHex $source); existed = $sharedExisted }
}

$seenSkillRoots = @{}
$seenRuleFiles = @{}
foreach ($agent in $agentSpecs) {
  # Several agents can read the same folder (for example ~\.agents\skills); install it once.
  $sharedRoot = $seenSkillRoots.ContainsKey($agent.skillsPath.ToLowerInvariant())
  $seenSkillRoots[$agent.skillsPath.ToLowerInvariant()] = $true
  if (-not $sharedRoot) {
    $ancestor = $agent.skillsPath
    while ($ancestor -and $ancestor.TrimEnd('\') -ne $profileRoot.TrimEnd('\')) {
        if (-not (Test-Path -LiteralPath $ancestor -PathType Container) -and $ancestor -notin $createdDirectories) { $createdDirectories += $ancestor }
        $ancestor = Split-Path -Parent $ancestor
    }
    foreach ($sourceDirectory in Get-ChildItem -LiteralPath (Join-Path $repo 'skills') -Directory | Sort-Object Name) {
        $source = $sourceDirectory.FullName
        $target = Join-Path $agent.skillsPath $sourceDirectory.Name
        $prior = @($previousState.skills | Where-Object { $_.target -eq $target } | Select-Object -First 1)
        if (Test-Path -LiteralPath $target) {
            if (-not $prior) { throw "Refusing to replace an unmanaged skill at '$target'. Move it or choose a different user profile." }
            if ($Mode -eq 'Junction') {
                $item = Get-Item -LiteralPath $target -Force
                $existingTarget = if ($item.PSObject.Properties.Name -contains 'Target') { [string]$item.Target } else { $null }
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { throw "Managed junction path is no longer a reparse point: $target" }
                if ($existingTarget -and [IO.Path]::GetFullPath($existingTarget) -ne [IO.Path]::GetFullPath($source)) { throw "Managed junction points to another source: $target. Run uninstall.ps1 -Apply before reinstalling." }
                $targetInfo = [pscustomobject]@{ agent = $agent.name; name = $sourceDirectory.Name; source = $source; target = $target; mode = $Mode; files = @() }
            }
            else {
                $fileStates = @()
                foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse) {
                    $relative = $file.FullName.Substring($source.TrimEnd('\').Length).TrimStart('\')
                    $targetFile = Join-Path $target $relative
                    $targetHash = if (Test-Path -LiteralPath $targetFile -PathType Leaf) { Get-FileHashHex $targetFile } else { $null }
                    $oldFile = @($prior[0].files | Where-Object { $_.path -eq $relative } | Select-Object -First 1)
                    if ($targetHash -and -not $oldFile) { throw "Copy install found an unmanaged file collision: $targetFile" }
                    if ($targetHash -ne (Get-FileHashHex $file.FullName)) { $managedSkillChanges.Add([pscustomobject]@{ action = 'copy skill file'; source = $file.FullName; target = $targetFile }) }
                    $fileStates += [pscustomobject]@{ path = $relative; hash = (Get-FileHashHex $file.FullName) }
                }
                $targetInfo = [pscustomobject]@{ agent = $agent.name; name = $sourceDirectory.Name; source = $source; target = $target; mode = $Mode; files = $fileStates }
            }
        }
        else {
            $managedSkillChanges.Add([pscustomobject]@{ action = "create $Mode skill"; source = $source; target = $target })
            $files = @()
            if ($Mode -eq 'Copy') {
                $files = @(Get-ChildItem -LiteralPath $source -File -Recurse | ForEach-Object { [pscustomobject]@{ path = $_.FullName.Substring($source.TrimEnd('\').Length).TrimStart('\'); hash = (Get-FileHashHex $_.FullName) } })
            }
            $targetInfo = [pscustomobject]@{ agent = $agent.name; name = $sourceDirectory.Name; source = $source; target = $target; mode = $Mode; files = $files }
        }
        $stateSkills += $targetInfo
    }
  }
    if (-not $agent.rulesPath -or $seenRuleFiles.ContainsKey($agent.rulesPath.ToLowerInvariant())) { continue }
    $seenRuleFiles[$agent.rulesPath.ToLowerInvariant()] = $agent.rulesPath
    $ruleContent = (Get-Content -LiteralPath $agent.rulesSource -Raw -Encoding UTF8).TrimEnd()
    $ruleBlock = "# BEGIN hd-skill`n$ruleContent`n# END hd-skill"
    $ruleBefore = Get-ExistingText $agent.rulesPath
    $ruleAfter = Merge-MarkedBlock $ruleBefore $ruleBlock
    if ($ruleAfter -cne $ruleBefore) { $configChanges.Add([pscustomobject]@{ kind = 'text'; path = $agent.rulesPath; before = $ruleBefore; after = $ruleAfter; existed = (Test-Path -LiteralPath $agent.rulesPath -PathType Leaf) }) }
}

# Skills and rule blocks of agents that are no longer selected.
$retiredSkills = @()
$currentTargets = @{}
foreach ($entry in $stateSkills) { $currentTargets[([string]$entry.target).ToLowerInvariant()] = $true }
if ($previousState) {
    foreach ($prior in @($previousState.skills)) {
        if ($currentTargets.ContainsKey(([string]$prior.target).ToLowerInvariant()) -or -not (Test-Path -LiteralPath $prior.target)) { continue }
        if ($prior.mode -eq 'Junction') {
            $item = Get-Item -LiteralPath $prior.target -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { $warnings += "Preserving changed non-junction path of a deselected agent: $($prior.target)"; continue }
            $retiredSkills += [pscustomobject]@{ mode = 'Junction'; target = $prior.target; files = @() }
        }
        else {
            $matchingFiles = @($prior.files | Where-Object { $file = Join-Path $prior.target $_.path; (Test-Path -LiteralPath $file -PathType Leaf) -and (Get-FileHashHex $file) -eq $_.hash } | ForEach-Object { Join-Path $prior.target $_.path })
            $retiredSkills += [pscustomobject]@{ mode = 'Copy'; target = $prior.target; files = $matchingFiles }
        }
    }
    $priorRuleFiles = if ($previousState.PSObject.Properties.Name -contains 'ruleFiles') { @($previousState.ruleFiles) } else { @($previousState.globalFiles | Where-Object { $_.kind -eq 'text' -and $_.path -like '*.md' } | ForEach-Object { $_.path }) }
    foreach ($rulePath in $priorRuleFiles) {
        if (-not $rulePath -or $seenRuleFiles.ContainsKey(([string]$rulePath).ToLowerInvariant()) -or -not (Test-Path -LiteralPath $rulePath -PathType Leaf)) { continue }
        $priorEntry = @($previousState.globalFiles | Where-Object { $_.path -eq $rulePath } | Select-Object -First 1)
        $endedWithNewline = if ($priorEntry.Count -gt 0) { [bool]$priorEntry[0].originalEndedWithNewline } else { $true }
        $before = Get-ExistingText $rulePath
        $after = Remove-MarkedBlock $before $endedWithNewline
        if ($after -cne $before) { $configChanges.Add([pscustomobject]@{ kind = 'text'; path = $rulePath; before = $before; after = $after; existed = $true }) }
    }
}

$mcpChanges = @()
if ($WithMcp) {
    if (@($agentSpecs | Where-Object { $_.mcp -eq 'codex-toml' }).Count -gt 0) {
        $tomlPath = Join-Path $profileRoot '.codex\config.toml'
        $template = Get-Content -LiteralPath (Join-Path $repo 'config\mcp-codex.toml.template') -Raw -Encoding UTF8
        $escapedVault = $resolved.vaultPath.Replace('\', '\\').Replace('"', '\"')
        $block = $template.Replace('{{vaultPathToml}}', $escapedVault).TrimEnd()
        $before = Get-ExistingText $tomlPath
        if (-not $before.Contains('# BEGIN hd-skill') -and $before -match '(?m)^\[mcp_servers\.hd_skill_context\]\s*$') { throw 'Codex config already has an unmanaged hd_skill_context MCP entry.' }
        $after = Merge-MarkedBlock $before $block
        if ($after -cne $before) { $configChanges.Add([pscustomobject]@{ kind = 'text'; path = $tomlPath; before = $before; after = $after; existed = (Test-Path -LiteralPath $tomlPath -PathType Leaf) }) }
    }
    if (@($agentSpecs | Where-Object { $_.mcp -eq 'antigravity-json' }).Count -gt 0) {
        $jsonPath = Join-Path $profileRoot '.gemini\config\mcp_config.json'
        $before = Get-ExistingText $jsonPath
        $after = Get-McpJsonText $jsonPath $resolved.vaultPath
        if ($after -cne $before) { $configChanges.Add([pscustomobject]@{ kind = 'json'; path = $jsonPath; before = $before; after = $after; existed = (Test-Path -LiteralPath $jsonPath -PathType Leaf) }) }
    }
}

$resolved.config.mcpEnabled = [bool]$WithMcp
$machineConfigText = ($resolved.config | ConvertTo-Json -Depth 12) + [Environment]::NewLine
$oldMachineConfig = Get-ExistingText $machineConfigPath
if ($machineConfigText.Trim() -cne $oldMachineConfig.Trim()) { $configChanges.Add([pscustomobject]@{ kind = 'json'; path = $machineConfigPath; before = $oldMachineConfig; after = $machineConfigText; existed = (Test-Path -LiteralPath $machineConfigPath -PathType Leaf) }) }
$machineConfigCreated = if ($previousState) { [bool]$previousState.machineConfigCreated } else { -not (Test-Path -LiteralPath $machineConfigPath -PathType Leaf) }
$globalFileMap = @{}
if ($previousState) { foreach ($entry in @($previousState.globalFiles)) { $globalFileMap[$entry.path] = $entry } }
foreach ($change in $configChanges | Where-Object { $_.path -ne $machineConfigPath }) {
    if (-not $globalFileMap.ContainsKey($change.path)) { $globalFileMap[$change.path] = [pscustomobject]@{ path = $change.path; kind = $change.kind; existed = $change.existed; originalEndedWithNewline = [bool]($change.before -match '(?:\r\n|\n|\r)$') } }
}
$state = [ordered]@{ version = 1; mode = $Mode; repositoryPath = $repo; agents = @($agentSpecs | ForEach-Object { $_.name }); ruleFiles = @($seenRuleFiles.Values | Sort-Object); skills = $stateSkills; createdDirectories = @($createdDirectories | Select-Object -Unique | Sort-Object Length -Descending); sharedFiles = $sharedState; globalFiles = @($globalFileMap.Values | Sort-Object path); machineConfigCreated = $machineConfigCreated; machineConfigHash = (Get-TextHashHex $machineConfigText) }
$stateText = ($state | ConvertTo-Json -Depth 20) + [Environment]::NewLine
if ($stateText.Trim() -cne (Get-ExistingText $statePath).Trim()) { $configChanges.Add([pscustomobject]@{ kind = 'json'; path = $statePath; before = (Get-ExistingText $statePath); after = $stateText; existed = (Test-Path -LiteralPath $statePath -PathType Leaf) }) }

Write-Host ("Resolved machine configuration (`"{0}`")" -f $machineConfigPath)
$resolved.config | ConvertTo-Json -Depth 10 | Write-Host
foreach ($warning in $warnings) { Write-Warning $warning }
Write-Host ("Agents: {0}" -f $(if ($agentSpecs.Count -gt 0) { ($agentSpecs | ForEach-Object { '{0} ({1})' -f $_.displayName, $_.skillsPath }) -join '; ' } else { 'none' }))
foreach ($change in $managedSkillChanges) { Write-Host ("[PLAN] {0}: {1} -> {2}" -f $change.action, $change.source, $change.target) }
foreach ($retired in $retiredSkills) { Write-Host ("[PLAN] remove skill of deselected agent: {0}" -f $retired.target) }
foreach ($change in $configChanges) { Write-Host ("[PLAN] update config: {0}" -f $change.path) }
if ($WithMcp) { Write-Host '[PLAN] optional filesystem MCP is enabled with pinned package version 1.0.0 and the resolved vault only.' }
if ($DryRun) {
    $backupPlan = @($configChanges | Where-Object existed | ForEach-Object { $_.path }) + @($managedSkillChanges | Where-Object { Test-Path -LiteralPath $_.target -PathType Leaf } | ForEach-Object { $_.target })
    foreach ($path in $backupPlan | Sort-Object -Unique) { Write-Host ("[BACKUP-PLAN] {0} -> %USERPROFILE%\.hd-skill\backups\<timestamp>\{1}" -f $path, (Split-Path -Leaf $path)) }
    Write-Host 'Dry run complete: no directories, files, links, backups, or configuration were changed. Use -Apply to install.'
    exit 0
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$backupRoot = Join-Path (Join-Path $machineConfigDirectory 'backups') $timestamp
$backupIndex = 0
$backupTargets = @($configChanges | Where-Object existed | ForEach-Object { $_.path }) + @($managedSkillChanges | Where-Object { Test-Path -LiteralPath $_.target -PathType Leaf } | ForEach-Object { $_.target })
foreach ($path in $backupTargets | Sort-Object -Unique) {
    if (-not (Test-Path -LiteralPath $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null }
    $backupIndex++
    $safeName = ('{0:D2}-{1}' -f $backupIndex, (Split-Path -Leaf $path))
    Copy-Item -LiteralPath $path -Destination (Join-Path $backupRoot $safeName) -Force
    Write-Host ("[BACKUP] {0}" -f (Join-Path $backupRoot $safeName))
}

foreach ($change in $managedSkillChanges) {
    $parent = Split-Path -Parent $change.target
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if ($change.action -eq 'copy runtime file' -or $change.action -eq 'copy skill file') {
        $targetParent = Split-Path -Parent $change.target
        if (-not (Test-Path -LiteralPath $targetParent -PathType Container)) { New-Item -ItemType Directory -Path $targetParent -Force | Out-Null }
        Copy-Item -LiteralPath $change.source -Destination $change.target -Force
    }
    elseif ($change.action -eq 'create Junction skill') { New-Item -ItemType Junction -Path $change.target -Target $change.source | Out-Null }
    elseif ($change.action -eq 'create Copy skill') { Copy-Item -LiteralPath $change.source -Destination $change.target -Recurse -Force }
}
foreach ($retired in $retiredSkills) {
    if ($retired.mode -eq 'Junction') { [IO.Directory]::Delete($retired.target, $false); continue }
    foreach ($file in $retired.files) { Remove-Item -LiteralPath $file -Force }
    foreach ($directory in @(Get-ChildItem -LiteralPath $retired.target -Directory -Recurse | Sort-Object FullName -Descending)) { if (@(Get-ChildItem -LiteralPath $directory.FullName -Force).Count -eq 0) { Remove-Item -LiteralPath $directory.FullName -Force } }
    if (@(Get-ChildItem -LiteralPath $retired.target -Force).Count -eq 0) { Remove-Item -LiteralPath $retired.target -Force }
}
foreach ($change in $configChanges) { Write-Utf8NoBom $change.path $change.after }
Write-Host ("[INSTALLED] mode={0}; agents={1}; backupRoot={2}" -f $Mode, (($agentSpecs | ForEach-Object { $_.name }) -join ', '), $backupRoot)
