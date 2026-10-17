[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$definitions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'machines.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hd-skill-install-' + [guid]::NewGuid().ToString('N'))
$envNames = @('USERPROFILE', 'APPDATA', 'HD_SKILL_HOME', 'HD_SKILL_VAULT', 'HD_SKILL_MACHINE_ID', 'COMPUTERNAME')
$saved = @{}
foreach ($name in $envNames) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$powershellExe = (Get-Process -Id $PID).Path

function Get-ProfileSnapshot([string] $Root, [switch] $IgnoreBackups) {
    $snapshot = [System.Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $snapshot }
    foreach ($item in Get-ChildItem -LiteralPath $Root -Force -Recurse) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        $relative = $item.FullName.Substring($Root.TrimEnd('\').Length).TrimStart('\')
        if ([string]::IsNullOrEmpty($relative)) { continue }
        if ($IgnoreBackups -and $relative -match '^\.hd-skill(?:\\|$)') { continue }
        if ($item.PSIsContainer) { $snapshot['D:' + $relative] = 'dir' }
        else {
            $bytes = [IO.File]::ReadAllBytes($item.FullName)
            $algorithm = [Security.Cryptography.SHA256]::Create()
            try { $hash = [BitConverter]::ToString($algorithm.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
            finally { $algorithm.Dispose() }
            $snapshot['F:' + $relative] = $hash
        }
    }
    return ,$snapshot
}
function Assert-SameSnapshot($Before, $After, [string] $Stage) {
    if ($Before.Count -ne $After.Count) {
        $added = @($After.Keys | Where-Object { -not $Before.ContainsKey($_) }) -join ', '
        $removed = @($Before.Keys | Where-Object { -not $After.ContainsKey($_) }) -join ', '
        throw "$Stage changed the profile inventory ($($Before.Count) -> $($After.Count)). Added: $added. Removed: $removed."
    }
    foreach ($key in $Before.Keys) { if (-not $After.ContainsKey($key) -or $Before[$key] -cne $After[$key]) { throw "$Stage changed profile item $key." } }
}
function Invoke-ChildScript([string] $Path, [string[]] $Arguments) {
    $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output | Out-String) }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $machineNumber = 0
    foreach ($definition in $definitions) {
        $machineNumber++
        $profile = Join-Path $tempRoot $definition.profileFolder
        $appData = Join-Path $profile 'OneDrive Documents\Roaming Data'
        New-Item -ItemType Directory -Path (Join-Path $profile 'AppData\Roaming') -Force | Out-Null
        $skillHomeParent = Join-Path $profile 'hd skills home with spaces'
        $skillHome = Join-Path $skillHomeParent 'repo'
        New-Item -ItemType Directory -Path $profile, $appData, $skillHomeParent -Force | Out-Null
        if ('codex' -in $definition.agents) {
            New-Item -ItemType Directory -Path (Join-Path $profile '.codex') -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $profile '.codex\AGENTS.md'), "User Codex rule.`n", [Text.UTF8Encoding]::new($false))
        }
        if ('antigravity' -in $definition.agents) {
            $geminiConfig = Join-Path $profile '.gemini\config'
            New-Item -ItemType Directory -Path $geminiConfig -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $geminiConfig 'GEMINI.md'), 'User Gemini rule.', [Text.UTF8Encoding]::new($false))
            New-Item -ItemType Directory -Path (Join-Path $profile '.gemini\antigravity\skills') -Force | Out-Null
        }
        if ($definition.vault) {
            $vault = Join-Path $profile ($definition.vault)
            New-Item -ItemType Directory -Path $vault -Force | Out-Null
            $obsidian = Join-Path $appData 'obsidian'
            New-Item -ItemType Directory -Path $obsidian -Force | Out-Null
            $vaultMap = @{}
            $vaultMap[$vault] = @{ path = $vault; ts = 1; open = $true }
            @{ vaults = $vaultMap } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $obsidian 'obsidian.json') -Encoding UTF8
        }
        [Environment]::SetEnvironmentVariable('USERPROFILE', $profile, 'Process')
        [Environment]::SetEnvironmentVariable('APPDATA', $appData, 'Process')
        [Environment]::SetEnvironmentVariable('HD_SKILL_HOME', $skillHome, 'Process')
        [Environment]::SetEnvironmentVariable('HD_SKILL_VAULT', $null, 'Process')
        [Environment]::SetEnvironmentVariable('HD_SKILL_MACHINE_ID', ('sim-' + $machineNumber.ToString('000')), 'Process')
        [Environment]::SetEnvironmentVariable('COMPUTERNAME', ('SIM-' + $machineNumber.ToString('000')), 'Process')

        $mode = if ($machineNumber -eq 1) { 'Junction' } else { 'Copy' }
        $beforeDryRun = Get-ProfileSnapshot $profile
        $bootstrap = Invoke-ChildScript (Join-Path $repoRoot 'bootstrap.ps1') @('-RepoRoot', $repoRoot, '-DryRun', '-NonInteractive', '-Mode', $mode)
        if ($bootstrap.ExitCode -ne 0 -or $bootstrap.Output -notmatch 'Bootstrap dry run complete') { throw "Bootstrap dry-run failed for $($definition.name): $($bootstrap.Output)" }
        $normalizedBootstrapOutput = $bootstrap.Output -replace '\\\\', '\'
        $expectedHomePattern = '"hdSkillHome"\s*:\s*"' + [regex]::Escape([IO.Path]::GetFullPath($skillHome)) + '"'
        if ($normalizedBootstrapOutput -notmatch $expectedHomePattern) { throw "Bootstrap dry-run used the wrong HD_SKILL_HOME for $($definition.name): $($bootstrap.Output)" }
        Assert-SameSnapshot $beforeDryRun (Get-ProfileSnapshot $profile) "Bootstrap dry-run for $($definition.name)"
        Write-Host "[PASS] $($definition.name): bootstrap -DryRun used the configured HD_SKILL_HOME and made no profile changes."

        $defaultInstall = Invoke-ChildScript (Join-Path $repoRoot 'install.ps1') @('-RepoRoot', $repoRoot, '-NonInteractive', '-Mode', $mode)
        if ($defaultInstall.ExitCode -ne 0 -or $defaultInstall.Output -notmatch 'Dry run complete') { throw "Default install was not read-only for $($definition.name): $($defaultInstall.Output)" }
        Assert-SameSnapshot $beforeDryRun (Get-ProfileSnapshot $profile) "Default install dry-run for $($definition.name)"

        $install = Invoke-ChildScript (Join-Path $repoRoot 'install.ps1') @('-RepoRoot', $repoRoot, '-Apply', '-NonInteractive', '-Mode', $mode)
        if ($install.ExitCode -ne 0) { throw "Install failed for $($definition.name): $($install.Output)" }
        $firstInstall = Get-ProfileSnapshot $profile
        $again = Invoke-ChildScript (Join-Path $repoRoot 'install.ps1') @('-RepoRoot', $repoRoot, '-Apply', '-NonInteractive', '-Mode', $mode)
        if ($again.ExitCode -ne 0) { throw "Second install failed for $($definition.name): $($again.Output)" }
        Assert-SameSnapshot $firstInstall (Get-ProfileSnapshot $profile) "Second install for $($definition.name)"
        Write-Host "[PASS] $($definition.name): second install made no changes."

        $updateDryRun = Invoke-ChildScript (Join-Path $repoRoot 'update.ps1') @('-RepoRoot', $repoRoot, '-DryRun', '-NonInteractive', '-Mode', $mode)
        if ($updateDryRun.ExitCode -ne 0 -or $updateDryRun.Output -notmatch 'git pull --ff-only') { throw "Update dry-run failed for $($definition.name): $($updateDryRun.Output)" }
        Assert-SameSnapshot $firstInstall (Get-ProfileSnapshot $profile) "Update dry-run for $($definition.name)"
        Write-Host "[PASS] $($definition.name): update -DryRun made no changes."

        if ($mode -eq 'Junction') {
            $state = Get-Content -LiteralPath (Join-Path $profile '.hd-skill\install-state.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $probe = $state.skills | Where-Object { $_.agent -eq 'codex' } | Select-Object -First 1
            $wrongSource = Join-Path $repoRoot 'skills\tdd'
            [IO.Directory]::Delete($probe.target, $false)
            New-Item -ItemType Junction -Path $probe.target -Target $wrongSource | Out-Null
            $tamperedDoctor = Invoke-ChildScript (Join-Path $repoRoot 'doctor.ps1') @('-RepoRoot', $repoRoot)
            if ($tamperedDoctor.ExitCode -eq 0 -or $tamperedDoctor.Output -notmatch 'Junction is missing or points away') { throw 'Doctor did not detect a junction pointed at the wrong skill source.' }
            [IO.Directory]::Delete($probe.target, $false)
            New-Item -ItemType Junction -Path $probe.target -Target $probe.source | Out-Null
            Write-Host "[PASS] $($definition.name): doctor detects and recovers from a misdirected junction."
        }

        $doctor = Invoke-ChildScript (Join-Path $repoRoot 'doctor.ps1') @('-RepoRoot', $repoRoot)
        if ($doctor.ExitCode -ne 0 -or $doctor.Output -match 'FAIL') { throw "Doctor failed for $($definition.name): $($doctor.Output)" }
        Write-Host "[PASS] $($definition.name): doctor reports no failed checks."

        $uninstallDryRun = Invoke-ChildScript (Join-Path $repoRoot 'uninstall.ps1') @('-RepoRoot', $repoRoot)
        if ($uninstallDryRun.ExitCode -ne 0 -or $uninstallDryRun.Output -notmatch 'Dry run complete') { throw "Default uninstall was not read-only for $($definition.name): $($uninstallDryRun.Output)" }
        Assert-SameSnapshot $firstInstall (Get-ProfileSnapshot $profile) "Default uninstall dry-run for $($definition.name)"

        $uninstall = Invoke-ChildScript (Join-Path $repoRoot 'uninstall.ps1') @('-RepoRoot', $repoRoot, '-Apply')
        if ($uninstall.ExitCode -ne 0) { throw "Uninstall failed for $($definition.name): $($uninstall.Output)" }
        $afterUninstall = Get-ProfileSnapshot $profile -IgnoreBackups
        Assert-SameSnapshot $beforeDryRun $afterUninstall "Uninstall for $($definition.name)"
        $globalCodex = Join-Path $profile '.codex\AGENTS.md'
        if ((Test-Path -LiteralPath $globalCodex -PathType Leaf) -and [IO.File]::ReadAllText($globalCodex) -cne "User Codex rule.`n") { throw "Uninstall changed pre-existing Codex rules for $($definition.name)." }
        $globalGemini = Join-Path $profile '.gemini\config\GEMINI.md'
        if ((Test-Path -LiteralPath $globalGemini -PathType Leaf) -and [IO.File]::ReadAllText($globalGemini) -cne 'User Gemini rule.') { throw "Uninstall changed pre-existing Antigravity rules for $($definition.name)." }
        if (Test-Path -LiteralPath (Join-Path $profile '.hd-skill\install-state.json')) { throw "Uninstall left install state for $($definition.name)." }
        if (@(Get-ChildItem -LiteralPath (Join-Path $profile '.gemini\antigravity\skills') -Directory -ErrorAction SilentlyContinue).Count -ne 0) { throw 'Installer touched the legacy Antigravity skill path.' }
        Write-Host "[PASS] $($definition.name): uninstall removed managed artifacts and preserved existing global rules; backups retained."
    }
}
finally {
    foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    if (Test-Path -LiteralPath $tempRoot) {
        foreach ($profile in Get-ChildItem -LiteralPath $tempRoot -Directory -Force) {
            foreach ($targetRoot in @((Join-Path $profile.FullName '.agents\skills'), (Join-Path $profile.FullName '.gemini\config\skills'))) {
                if (Test-Path -LiteralPath $targetRoot -PathType Container) {
                    foreach ($entry in Get-ChildItem -LiteralPath $targetRoot -Force) {
                        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { try { [IO.Directory]::Delete($entry.FullName, $false) } catch { } }
                    }
                }
            }
        }
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
