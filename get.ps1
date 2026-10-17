# One-line entry point for hd-skill. Interactive:
#   irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/get.ps1 | iex
# With options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/get.ps1))) -Scope Project
# This file runs inside the caller's session, so it never calls `exit` and keeps its settings in a child scope.
param(
    [string] $Scope = $env:HD_SKILL_SCOPE,
    [string] $ProjectPath = (Get-Location).Path,
    [string] $VaultPath,
    [string] $RepositoryUrl = 'https://github.com/LeDuyCoder/hs-skills.git',
    [switch] $DryRun,
    [switch] $Uninstall,
    [switch] $NonInteractive,
    [switch] $WithMcp
)

& {
    $ErrorActionPreference = 'Stop'
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git for Windows is required. Install it from https://git-scm.com/download/win and rerun.' }
    $project = [IO.Path]::GetFullPath($ProjectPath)

    if ([string]::IsNullOrWhiteSpace($Scope)) {
        if ($NonInteractive) { $Scope = 'Global' }
        else {
            Write-Host ''
            Write-Host 'hd-skill: where should the skills be installed?'
            Write-Host '  [1] Global  - every project on this machine (Codex + Antigravity user folders)'
            Write-Host ("  [2] Project - only this folder: {0}" -f $project)
            Write-Host '                (.agents\skills + AGENTS.md, can be committed for the team)'
            try { $choice = Read-Host 'Choose 1 or 2 [1]' }
            catch { throw 'No console input is available. Pass -Scope Global or -Scope Project, or set $env:HD_SKILL_SCOPE.' }
            $Scope = switch ($choice.Trim()) { '' { 'Global' } '1' { 'Global' } '2' { 'Project' } default { throw "Unknown choice '$choice'." } }
        }
    }
    if ($Scope -notin @('Global', 'Project')) { throw "Scope must be Global or Project, not '$Scope'." }

    $profileRoot = [Environment]::GetEnvironmentVariable('USERPROFILE')
    if ([string]::IsNullOrWhiteSpace($profileRoot)) { $profileRoot = [Environment]::GetFolderPath('UserProfile') }
    $repoHome = if ($env:HD_SKILL_HOME) { [IO.Path]::GetFullPath($env:HD_SKILL_HOME) } else { Join-Path $profileRoot '.hd-skill\repo' }
    $tempClone = $null
    if (Test-Path -LiteralPath $repoHome) {
        $origin = git -C $repoHome remote get-url origin
        if ($LASTEXITCODE -ne 0 -or $origin.Trim() -ne $RepositoryUrl) { throw "The existing checkout at '$repoHome' does not use $RepositoryUrl; inspect it before continuing." }
        $source = $repoHome
    }
    elseif ($DryRun -or $Uninstall) {
        if ($Uninstall -and $Scope -eq 'Global') { throw "hd-skill is not installed globally ($repoHome is missing)." }
        $tempClone = Join-Path ([IO.Path]::GetTempPath()) ('hd-skill-' + [guid]::NewGuid().ToString('N'))
        git clone --quiet --depth 1 $RepositoryUrl $tempClone
        if ($LASTEXITCODE -ne 0) { throw "git clone failed from '$RepositoryUrl'." }
        $source = $tempClone
    }
    else { $source = $null }

    try {
        if ($Scope -eq 'Global') {
            if ($Uninstall) {
                $uninstallArgs = @{ RepoRoot = $source }
                if (-not $DryRun) { $uninstallArgs.Apply = $true }
                & (Join-Path $source 'uninstall.ps1') @uninstallArgs
                return
            }
        }
        if (-not $source) {
            git clone $RepositoryUrl $repoHome
            if ($LASTEXITCODE -ne 0) { throw "git clone failed from '$RepositoryUrl'." }
            $source = $repoHome
        }
        if ($Scope -eq 'Global') {
            # bootstrap.ps1 pulls, validates, and installs for the detected agents.
            $bootstrapArgs = @{ RepoRoot = $source; RepositoryUrl = $RepositoryUrl; Mode = 'Junction'; NonInteractive = $NonInteractive }
            if ($DryRun) { $bootstrapArgs.DryRun = $true }
            if ($VaultPath) { $bootstrapArgs.VaultPath = $VaultPath }
            if ($WithMcp) { $bootstrapArgs.WithMcp = $true }
            & (Join-Path $source 'bootstrap.ps1') @bootstrapArgs
            return
        }

        if (-not $DryRun -and -not $Uninstall -and $source -eq $repoHome) {
            git -C $repoHome pull --ff-only --quiet
            if ($LASTEXITCODE -ne 0) { throw "git pull --ff-only failed in '$repoHome'; inspect local changes before retrying." }
        }
        $projectArgs = @{ RepoRoot = $source; ProjectPath = $project }
        if (-not $DryRun) { $projectArgs.Apply = $true }
        if ($Uninstall) { $projectArgs.Uninstall = $true }
        & (Join-Path $source 'install-project.ps1') @projectArgs
    }
    finally {
        if ($tempClone -and (Test-Path -LiteralPath $tempClone)) { Remove-Item -LiteralPath $tempClone -Recurse -Force }
    }
}
