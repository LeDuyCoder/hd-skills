[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hd-skill-bootstrap-' + [guid]::NewGuid().ToString('N'))
$sourceRepo = Join-Path $tempRoot 'source with spaces'
$profile = Join-Path $tempRoot 'profile'
$appData = Join-Path $profile 'Moved Documents\Roaming'
$targetRepo = Join-Path $profile 'hd skill home\repo'
$saved = @{}
foreach ($name in @('USERPROFILE', 'APPDATA', 'HD_SKILL_HOME', 'HD_SKILL_VAULT', 'HD_SKILL_MACHINE_ID')) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$powershellExe = (Get-Process -Id $PID).Path
try {
    New-Item -ItemType Directory -Path $sourceRepo, $profile, $appData, (Join-Path $profile '.codex') -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $repoRoot -Force | Where-Object { $_.Name -ne '.git' }) {
        Copy-Item -LiteralPath $item.FullName -Destination $sourceRepo -Recurse -Force
    }
    $null = & git -C $sourceRepo init -q 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the local bootstrap source repository.' }
    $null = & git -C $sourceRepo config user.name 'hd-skill bootstrap test'
    $null = & git -C $sourceRepo config user.email 'bootstrap@example.invalid'
    $null = & git -C $sourceRepo config core.autocrlf false
    $null = & git -C $sourceRepo add --all 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Could not stage the local bootstrap source repository.' }
    $null = & git -C $sourceRepo commit -qm 'fixture source' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the local bootstrap source commit.' }

    [Environment]::SetEnvironmentVariable('USERPROFILE', $profile, 'Process')
    [Environment]::SetEnvironmentVariable('APPDATA', $appData, 'Process')
    [Environment]::SetEnvironmentVariable('HD_SKILL_HOME', $targetRepo, 'Process')
    [Environment]::SetEnvironmentVariable('HD_SKILL_VAULT', $null, 'Process')
    [Environment]::SetEnvironmentVariable('HD_SKILL_MACHINE_ID', 'boot-001', 'Process')
    $bootstrapOutput = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'bootstrap.ps1') -RepoRoot $sourceRepo -RepositoryUrl $sourceRepo -NonInteractive -Mode Copy 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Bootstrap clone/install failed: $bootstrapOutput" }
    if (-not (Test-Path -LiteralPath (Join-Path $targetRepo 'install.ps1') -PathType Leaf)) { throw 'Bootstrap did not clone the source into HD_SKILL_HOME.' }
    $machineConfig = Get-Content -LiteralPath (Join-Path $profile '.hd-skill\config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($machineConfig.hdSkillHome -ne [IO.Path]::GetFullPath($targetRepo)) { throw 'Bootstrap did not persist the selected HD_SKILL_HOME.' }

    $doctorOutput = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $targetRepo 'doctor.ps1') -RepoRoot $targetRepo 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $doctorOutput -match 'FAIL') { throw "Doctor failed after bootstrap: $doctorOutput" }
    $beforeUpdateConfig = [IO.File]::ReadAllText((Join-Path $profile '.hd-skill\config.json'))
    $updateOutput = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $targetRepo 'update.ps1') -RepoRoot $targetRepo -Apply -NonInteractive -Mode Copy 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Update failed for a local origin: $updateOutput" }
    if ([IO.File]::ReadAllText((Join-Path $profile '.hd-skill\config.json')) -cne $beforeUpdateConfig) { throw 'Update changed the machine-specific config.' }
    Write-Host '[PASS] Fresh bootstrap cloned a local Git origin, installed detected skills, doctor passed, and update preserved machine config.'

    $uninstallOutput = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $targetRepo 'uninstall.ps1') -RepoRoot $targetRepo -Apply 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Uninstall after bootstrap failed: $uninstallOutput" }
}
finally {
    foreach ($name in @('USERPROFILE', 'APPDATA', 'HD_SKILL_HOME', 'HD_SKILL_VAULT', 'HD_SKILL_MACHINE_ID')) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    if (Test-Path -LiteralPath $tempRoot) {
        foreach ($junctionRoot in @((Join-Path $profile '.agents\skills'), (Join-Path $profile '.gemini\config\skills'))) {
            if (Test-Path -LiteralPath $junctionRoot -PathType Container) {
                foreach ($entry in Get-ChildItem -LiteralPath $junctionRoot -Force) { if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { try { [IO.Directory]::Delete($entry.FullName, $false) } catch { } } }
            }
        }
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
