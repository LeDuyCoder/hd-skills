[CmdletBinding()]
param()

# Agent selection, custom agents, deselection cleanup, project targets, and obsidian.ps1, in a throwaway profile.
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hd-skill-agents-' + [guid]::NewGuid().ToString('N'))
$envNames = @('USERPROFILE', 'APPDATA', 'HD_SKILL_HOME', 'HD_SKILL_VAULT', 'HD_SKILL_MACHINE_ID', 'HD_SKILL_AGENTS')
$saved = @{}
foreach ($name in $envNames) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$powershellExe = (Get-Process -Id $PID).Path

function Invoke-ChildScript([string] $Path, [string[]] $Arguments) {
    $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
    $result = [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output | Out-String) }
    if ($result.ExitCode -ne 0) { throw "$(Split-Path -Leaf $Path) $($Arguments -join ' ') failed: $($result.Output)" }
    return $result
}
function Get-Snapshot([string] $Root) {
    $snapshot = [System.Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in Get-ChildItem -LiteralPath $Root -Force -Recurse) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        $relative = $item.FullName.Substring($Root.TrimEnd('\').Length).TrimStart('\')
        if ($relative -match '^\.hd-skill(?:\\|$)') { continue }
        $snapshot[$relative] = if ($item.PSIsContainer) { 'dir' } else { ([IO.File]::ReadAllText($item.FullName)).Trim() }
    }
    return ,$snapshot
}
function Assert-Same($Before, $After, [string] $Stage) {
    $diff = @($Before.Keys + $After.Keys | Select-Object -Unique | Where-Object { -not $Before.ContainsKey($_) -or -not $After.ContainsKey($_) -or $Before[$_] -cne $After[$_] })
    if ($diff.Count -gt 0) { throw "$Stage changed: $($diff -join ', ')" }
}
function Assert-True([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }

try {
    $profile = Join-Path $tempRoot 'profile'
    $appData = Join-Path $profile 'AppData\Roaming'
    New-Item -ItemType Directory -Path $appData, (Join-Path $profile '.codex'), (Join-Path $profile '.claude') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $profile '.claude\CLAUDE.md'), "User Claude rule.`n", [Text.UTF8Encoding]::new($false))
    [Environment]::SetEnvironmentVariable('USERPROFILE', $profile, 'Process')
    [Environment]::SetEnvironmentVariable('APPDATA', $appData, 'Process')
    [Environment]::SetEnvironmentVariable('HD_SKILL_HOME', (Join-Path $profile '.hd-skill\repo'), 'Process')
    [Environment]::SetEnvironmentVariable('HD_SKILL_VAULT', $null, 'Process')
    [Environment]::SetEnvironmentVariable('HD_SKILL_AGENTS', $null, 'Process')
    [Environment]::SetEnvironmentVariable('HD_SKILL_MACHINE_ID', 'sim-agents', 'Process')
    $baseline = Get-Snapshot $profile
    $install = Join-Path $repoRoot 'install.ps1'

    # 1. Explicit selection; Codex and Cursor share ~\.agents\skills and are installed once.
    $first = Invoke-ChildScript $install @('-RepoRoot', $repoRoot, '-Apply', '-NonInteractive', '-Agents', 'claude,codex,cursor')
    Assert-True (Test-Path -LiteralPath (Join-Path $profile '.claude\skills\hd\SKILL.md')) 'Claude skills were not installed.'
    Assert-True (Test-Path -LiteralPath (Join-Path $profile '.agents\skills\hd\SKILL.md')) 'Shared .agents skills were not installed.'
    Assert-True ([IO.File]::ReadAllText((Join-Path $profile '.claude\CLAUDE.md')).Contains('# BEGIN hd-skill')) 'CLAUDE.md has no hd-skill block.'
    $state = Get-Content -LiteralPath (Join-Path $profile '.hd-skill\install-state.json') -Raw | ConvertFrom-Json
    $agentTargets = @($state.skills | Where-Object { $_.target -like '*\.agents\skills\hd' })
    Assert-True ($agentTargets.Count -eq 1) 'The shared .agents\skills folder was installed more than once.'
    $config = Get-Content -LiteralPath (Join-Path $profile '.hd-skill\config.json') -Raw | ConvertFrom-Json
    Assert-True ((@($config.selectedAgents) -join ',') -eq 'claude,codex,cursor') "selectedAgents was not saved: $(@($config.selectedAgents) -join ',')"
    Write-Host '[PASS] -Agents installs Claude and shared .agents targets once, and saves the selection.'

    # 2. Rerun without -Agents keeps the saved selection and changes nothing.
    $afterFirst = Get-Snapshot $profile
    Invoke-ChildScript $install @('-RepoRoot', $repoRoot, '-Apply', '-NonInteractive') | Out-Null
    Assert-Same $afterFirst (Get-Snapshot $profile) 'Rerun without -Agents'
    Write-Host '[PASS] The saved agent selection is reused on the next install.'

    # 3. Custom agent from agents.custom.json; deselected Claude loses its skills and rule block.
    $custom = @{ agents = @(@{ id = 'mytool'; name = 'My Tool'; detect = @{ paths = @('.mytool'); commands = @() }; global = @{ skillsPath = '.mytool\skills'; rulesPath = '.mytool\RULES.md'; rulesSource = 'rules\AGENTS.md' }; project = @{ skillsPath = '.mytool\skills'; rulesPath = 'MYTOOL.md' } }) }
    [IO.File]::WriteAllText((Join-Path $profile '.hd-skill\agents.custom.json'), ($custom | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    Invoke-ChildScript $install @('-RepoRoot', $repoRoot, '-Apply', '-NonInteractive', '-Agents', 'codex,mytool') | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $profile '.mytool\skills\hd\SKILL.md')) 'Custom agent skills were not installed.'
    Assert-True ([IO.File]::ReadAllText((Join-Path $profile '.mytool\RULES.md')).Contains('# BEGIN hd-skill')) 'Custom agent rules were not written.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $profile '.claude\skills\hd'))) 'Deselected Claude skills were left behind.'
    Assert-True ([IO.File]::ReadAllText((Join-Path $profile '.claude\CLAUDE.md')).Trim() -ceq 'User Claude rule.') 'Deselected Claude rule block was not removed cleanly.'
    $doctor = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'doctor.ps1') -RepoRoot $repoRoot 2>&1 | Out-String
    Assert-True ($doctor -notmatch 'FAIL') "Doctor reported failures: $doctor"
    Write-Host '[PASS] Custom agents install, deselected agents are cleaned up, doctor passes.'

    # 4. obsidian.ps1 creates a vault folder with an index and refreshes the global install.
    $vault = Join-Path $profile 'Notes folder\DevBrain'
    Invoke-ChildScript (Join-Path $repoRoot 'obsidian.ps1') @('-VaultPath', $vault, '-NonInteractive') | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $vault '00-INDEX.md')) 'obsidian.ps1 did not create 00-INDEX.md.'
    $config = Get-Content -LiteralPath (Join-Path $profile '.hd-skill\config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($config.contextMode -eq 'vault' -and $config.vaultPath -eq [IO.Path]::GetFullPath($vault)) "Vault was not saved: $($config.vaultPath)"
    Assert-True ((@($config.selectedAgents) -join ',') -eq 'codex,mytool') 'obsidian.ps1 lost the agent selection.'
    Write-Host '[PASS] obsidian.ps1 connects a new vault and keeps the agent selection.'

    # 5. Uninstall returns the profile to its baseline (vault notes are user data and stay).
    Invoke-ChildScript (Join-Path $repoRoot 'uninstall.ps1') @('-RepoRoot', $repoRoot, '-Apply') | Out-Null
    $afterUninstall = Get-Snapshot $profile
    foreach ($key in @($afterUninstall.Keys | Where-Object { $_ -like 'Notes *' })) { [void]$afterUninstall.Remove($key) }
    Assert-Same $baseline $afterUninstall 'Uninstall'
    Write-Host '[PASS] Uninstall restores the profile, including the pre-existing CLAUDE.md.'

    # 6. Project install writes .claude\skills + CLAUDE.md beside .agents\skills + AGENTS.md, and switching back cleans up.
    $projectDir = Join-Path $tempRoot 'demo project'
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $projectDir 'AGENTS.md'), "User project rule.`n", [Text.UTF8Encoding]::new($false))
    $projectBaseline = Get-Snapshot $projectDir
    $projectInstall = Join-Path $repoRoot 'install-project.ps1'
    Invoke-ChildScript $projectInstall @('-RepoRoot', $repoRoot, '-ProjectPath', $projectDir, '-Apply', '-Agents', 'claude,codex') | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $projectDir '.claude\skills\hd\SKILL.md')) 'Project Claude skills missing.'
    Assert-True (Test-Path -LiteralPath (Join-Path $projectDir '.agents\skills\hd\SKILL.md')) 'Project .agents skills missing.'
    Assert-True ([IO.File]::ReadAllText((Join-Path $projectDir 'CLAUDE.md')).Contains('<!-- BEGIN hd-skill -->')) 'Project CLAUDE.md block missing.'
    Invoke-ChildScript $projectInstall @('-RepoRoot', $repoRoot, '-ProjectPath', $projectDir, '-Apply', '-Agents', 'codex') | Out-Null
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $projectDir '.claude'))) 'Deselected project Claude skills were left behind.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $projectDir 'CLAUDE.md'))) 'CLAUDE.md created by hd-skill was not removed.'
    Invoke-ChildScript $projectInstall @('-RepoRoot', $repoRoot, '-ProjectPath', $projectDir, '-Apply', '-Uninstall') | Out-Null
    Assert-Same $projectBaseline (Get-Snapshot $projectDir) 'Project uninstall'
    Write-Host '[PASS] Project install handles Claude targets, deselection, and uninstall.'
}
finally {
    foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    if (Test-Path -LiteralPath $tempRoot) {
        foreach ($link in Get-ChildItem -LiteralPath $tempRoot -Recurse -Force -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { try { [IO.Directory]::Delete($link.FullName, $false) } catch { } }
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
