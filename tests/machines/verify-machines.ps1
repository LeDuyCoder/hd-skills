[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$definitions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'machines.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hd-skill-machines-' + [guid]::NewGuid().ToString('N'))
$envNames = @('USERPROFILE', 'APPDATA', 'HD_SKILL_HOME', 'HD_SKILL_VAULT', 'HD_SKILL_MACHINE_ID')
$saved = @{}
foreach ($name in $envNames) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $machineNumber = 0
    foreach ($definition in $definitions) {
        $machineNumber++
        $profile = Join-Path $tempRoot $definition.profileFolder
        $appData = Join-Path $tempRoot ($definition.profileFolder + '\AppData')
        $repoHome = Join-Path $tempRoot ($definition.profileFolder + '\repo home')
        New-Item -ItemType Directory -Path $profile, $appData, $repoHome -Force | Out-Null
        if ('codex' -in $definition.agents) { New-Item -ItemType Directory -Path (Join-Path $profile '.codex') -Force | Out-Null }
        if ('antigravity' -in $definition.agents) { New-Item -ItemType Directory -Path (Join-Path $profile '.gemini') -Force | Out-Null }
        $expectedVault = $null
        if ($definition.vault) {
            $expectedVault = Join-Path $tempRoot ($definition.profileFolder + '\' + $definition.vault)
            New-Item -ItemType Directory -Path $expectedVault -Force | Out-Null
            $obsidianDir = Join-Path $appData 'obsidian'
            New-Item -ItemType Directory -Path $obsidianDir -Force | Out-Null
            $vaultMap = @{}
            $vaultMap[$expectedVault] = @{ path = $expectedVault; ts = 1; open = $true }
            @{ vaults = $vaultMap } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $obsidianDir 'obsidian.json') -Encoding UTF8
        }

        [Environment]::SetEnvironmentVariable('USERPROFILE', $profile, 'Process')
        [Environment]::SetEnvironmentVariable('APPDATA', $appData, 'Process')
        [Environment]::SetEnvironmentVariable('HD_SKILL_HOME', $repoHome, 'Process')
        [Environment]::SetEnvironmentVariable('HD_SKILL_VAULT', $null, 'Process')
        [Environment]::SetEnvironmentVariable('HD_SKILL_MACHINE_ID', ('test-' + $machineNumber.ToString('000')), 'Process')

        $resolver = Join-Path $repoRoot 'scripts\Resolve-HdSkillConfig.ps1'
        $resolved = (& $resolver -RepoRoot $repoRoot -NonInteractive -PersistConfig | ConvertFrom-Json)
        if ($resolved.contextMode -ne $definition.expectedMode) { throw "$($definition.name): expected contextMode '$($definition.expectedMode)', received '$($resolved.contextMode)'" }
        if ([bool]$resolved.agents.codex -ne ('codex' -in $definition.agents)) { throw "$($definition.name): Codex detection mismatch" }
        if ([bool]$resolved.agents.antigravity -ne ('antigravity' -in $definition.agents)) { throw "$($definition.name): Antigravity detection mismatch" }
        if ($expectedVault -and $resolved.vaultPath -ne [IO.Path]::GetFullPath($expectedVault)) { throw "$($definition.name): vault path mismatch: $($resolved.vaultPath)" }
        if (-not $expectedVault -and $resolved.vaultPath -ne (Join-Path $repoRoot '.context')) { throw "$($definition.name): repository fallback mismatch" }
        $savedConfig = Get-Content -LiteralPath (Join-Path $profile '.hd-skill\config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($savedConfig.machineId -ne ('test-' + $machineNumber.ToString('000'))) { throw "$($definition.name): first-run config was not persisted" }
        $again = (& $resolver -RepoRoot $repoRoot -NonInteractive | ConvertFrom-Json)
        if ($again.contextMode -ne $resolved.contextMode -or $again.machineId -ne $resolved.machineId) { throw "$($definition.name): persisted config is not stable on the second resolution" }
        Write-Host "[PASS] $($definition.name): agents, context mode, and resolved path"
    }
}
finally {
    foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
