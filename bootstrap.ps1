[CmdletBinding()]
param(
    [Parameter()] [string] $RepoRoot = $PSScriptRoot,
    [Parameter()] [string] $RepositoryUrl,
    [Parameter()] [string] $VaultPath,
    [Parameter()] [ValidateSet('Junction', 'Copy')] [string] $Mode = 'Junction',
    [Parameter()] [switch] $DryRun,
    [Parameter()] [switch] $NonInteractive,
    [Parameter()] [switch] $WithMcp,
    [Parameter()] [switch] $Apply
)

$ErrorActionPreference = 'Stop'
$profileRoot = [Environment]::GetEnvironmentVariable('USERPROFILE')
if ([string]::IsNullOrWhiteSpace($profileRoot)) { $profileRoot = [Environment]::GetFolderPath('UserProfile') }
$targetHome = [Environment]::GetEnvironmentVariable('HD_SKILL_HOME')
if ([string]::IsNullOrWhiteSpace($targetHome)) { $targetHome = Join-Path $profileRoot '.hd-skill\repo' }
$targetHome = [IO.Path]::GetFullPath($targetHome)
$sourceRoot = if ($RepoRoot -and (Test-Path -LiteralPath (Join-Path $RepoRoot 'config.schema.json') -PathType Leaf)) { [IO.Path]::GetFullPath($RepoRoot) } else { $null }
$targetExists = Test-Path -LiteralPath $targetHome -PathType Container
$isGitRepo = $targetExists -and (Test-Path -LiteralPath (Join-Path $targetHome '.git'))
if ($targetExists -and -not $isGitRepo) { throw "HD_SKILL_HOME exists but is not a Git checkout: $targetHome" }
if (-not $targetExists -and -not $RepositoryUrl -and -not $sourceRoot) {
    throw 'A repository URL is required for a fresh machine. Pass -RepositoryUrl with the shared Git remote.'
}
$source = if ($isGitRepo) { $targetHome } elseif ($sourceRoot) { $sourceRoot } else { $RepositoryUrl }
Write-Host ("HD_SKILL_HOME: {0}" -f $targetHome)
if ($isGitRepo) { Write-Host "[PLAN] git pull --ff-only in $targetHome" }
else { Write-Host "[PLAN] clone $source into $targetHome" }
if ($DryRun) {
    $installSource = if ($isGitRepo) { $targetHome } elseif ($sourceRoot) { $sourceRoot } else { $null }
    if ($installSource) {
        $installArgs = @{ RepoRoot = $installSource; Mode = $Mode; DryRun = $true; NonInteractive = $NonInteractive }
        if ($VaultPath) { $installArgs.VaultPath = $VaultPath }
        if ($WithMcp) { $installArgs.WithMcp = $true }
        $previousSkillHome = $env:HD_SKILL_HOME
        try {
            $env:HD_SKILL_HOME = $targetHome
            & (Join-Path $installSource 'install.ps1') @installArgs
        }
        finally { $env:HD_SKILL_HOME = $previousSkillHome }
        if ($LASTEXITCODE -ne 0) { throw 'Install dry-run failed.' }
    }
    Write-Host 'Bootstrap dry run complete: no clone, pull, install, or machine configuration was changed.'
    exit 0
}

if (-not $isGitRepo) {
    $parent = Split-Path -Parent $targetHome
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $cloneSource = if ($RepositoryUrl) { $RepositoryUrl } else { $sourceRoot }
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $cloneOutput = @(& git clone $cloneSource $targetHome 2>&1)
        $cloneExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousErrorAction }
    foreach ($line in $cloneOutput) { Write-Host $line }
    if ($cloneExitCode -ne 0) { throw "git clone failed from '$cloneSource'." }
}
else {
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $pullOutput = @(& git -C $targetHome pull --ff-only 2>&1)
        $pullExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousErrorAction }
    foreach ($line in $pullOutput) { Write-Host $line }
    if ($pullExitCode -ne 0) { throw 'git pull --ff-only failed; inspect local changes and upstream before retrying.' }
}
$installScript = Join-Path $targetHome 'install.ps1'
& (Join-Path $targetHome 'scripts\validate.ps1') -RootPath (Join-Path $targetHome 'skills')
if ($LASTEXITCODE -ne 0) { throw 'Repository validation failed after clone/pull.' }
$env:HD_SKILL_HOME = $targetHome
$installArgs = @{ RepoRoot = $targetHome; Mode = $Mode; Apply = $true; NonInteractive = $NonInteractive }
if ($VaultPath) { $installArgs.VaultPath = $VaultPath }
if ($WithMcp) { $installArgs.WithMcp = $true }
& $installScript @installArgs
if ($LASTEXITCODE -ne 0) { throw 'Installation failed after repository update.' }
Write-Host '[BOOTSTRAP COMPLETE] Shared repository is current, validated, and installed for detected agents.'
