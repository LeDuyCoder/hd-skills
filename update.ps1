[CmdletBinding()]
param(
    [Parameter()] [string] $RepoRoot = $PSScriptRoot,
    [Parameter()] [string] $VaultPath,
    [Parameter()] [ValidateSet('Junction', 'Copy')] [string] $Mode = 'Junction',
    [Parameter()] [switch] $DryRun = $true,
    [Parameter()] [switch] $NonInteractive,
    [Parameter()] [switch] $WithMcp,
    [Parameter()] [switch] $Apply
)

$ErrorActionPreference = 'Stop'
if ($Apply) { $DryRun = $false }
$repo = [IO.Path]::GetFullPath($RepoRoot)
if ($DryRun) {
    Write-Host "[PLAN] git pull --ff-only in $repo"
    $args = @{ RepoRoot = $repo; Mode = $Mode; DryRun = $true; NonInteractive = $NonInteractive }
    if ($VaultPath) { $args.VaultPath = $VaultPath }
    if ($WithMcp) { $args.WithMcp = $true }
    & (Join-Path $repo 'install.ps1') @args
    exit $LASTEXITCODE
}
$previousErrorAction = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $pullOutput = @(& git -C $repo pull --ff-only 2>&1)
    $pullExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorAction }
foreach ($line in $pullOutput) { Write-Host $line }
if ($pullExitCode -ne 0) { throw 'git pull --ff-only failed; inspect local changes and upstream before reinstalling.' }
& (Join-Path $repo 'scripts\validate.ps1') -RootPath (Join-Path $repo 'skills')
if ($LASTEXITCODE -ne 0) { throw 'Validation failed after pull; installation was not changed.' }
$installArgs = @{ RepoRoot = $repo; Mode = $Mode; Apply = $true; NonInteractive = $NonInteractive }
if ($VaultPath) { $installArgs.VaultPath = $VaultPath }
if ($WithMcp) { $installArgs.WithMcp = $true }
& (Join-Path $repo 'install.ps1') @installArgs
if ($LASTEXITCODE -ne 0) { throw 'Reinstallation failed after the repository update.' }
Write-Host '[UPDATED] Repository pulled, validated, and reinstalled; machine config remains in place.'
