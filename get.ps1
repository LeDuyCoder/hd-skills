# One-line entry point for hd-skill. Interactive:
#   irm https://raw.githubusercontent.com/LeDuyCoder/hd-skills/master/get.ps1 | iex
# With options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hd-skills/master/get.ps1))) -Scope Project -Agents claude,codex
# This file runs inside the caller's session, so it never calls `exit` and keeps its settings in a child scope.
param(
    [string] $Scope = $env:HD_SKILL_SCOPE,
    [string[]] $Agents,
    [string] $ProjectPath = (Get-Location).Path,
    [string] $VaultPath,
    [string] $RepositoryUrl = 'https://github.com/LeDuyCoder/hd-skills.git',
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
            Write-Host '  [1] Global  - every project on this machine (agent user folders)'
            Write-Host ("  [2] Project - only this folder: {0}" -f $project)
            Write-Host '                (.agents\skills, .claude\skills, AGENTS.md ... can be committed for the team)'
            try { $choice = Read-Host 'Choose 1 or 2 [1]' }
            catch { throw 'No console input is available. Pass -Scope Global or -Scope Project, or set $env:HD_SKILL_SCOPE.' }
            $Scope = switch ($choice.Trim()) { '' { 'Global' } '1' { 'Global' } '2' { 'Project' } default { throw "Unknown choice '$choice'." } }
        }
    }
    if ($Scope -notin @('Global', 'Project')) { throw "Scope must be Global or Project, not '$Scope'." }

    $profileRoot = [Environment]::GetEnvironmentVariable('USERPROFILE')
    if ([string]::IsNullOrWhiteSpace($profileRoot)) { $profileRoot = [Environment]::GetFolderPath('UserProfile') }
    $repoHome = if ($env:HD_SKILL_HOME) { [IO.Path]::GetFullPath($env:HD_SKILL_HOME) } else { Join-Path $profileRoot '.hd-skill\repo' }

    # Shows every agent from agents.json (plus agents.custom.json) and returns the ids the user picked,
    # or $null to keep the current choice (saved selection, otherwise detected agents).
    function Select-HdAgents([string] $Source) {
        $detected = & (Join-Path $Source 'scripts\Detect-Environment.ps1') -RepoRoot $Source 3>$null | ConvertFrom-Json
        $registry = @($detected.registry)
        if ($registry.Count -eq 0) { return $null }
        $current = $null
        if ($Scope -eq 'Global') {
            $configPath = Join-Path $profileRoot '.hd-skill\config.json'
            if (Test-Path -LiteralPath $configPath -PathType Leaf) {
                try { $saved = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json; if ($saved.PSObject.Properties.Name -contains 'selectedAgents') { $current = @($saved.selectedAgents) } } catch { $current = $null }
            }
        }
        else {
            $projectState = Join-Path $project '.hd-skill\project-install.json'
            if (Test-Path -LiteralPath $projectState -PathType Leaf) {
                try { $saved = Get-Content -LiteralPath $projectState -Raw -Encoding UTF8 | ConvertFrom-Json; if ($saved.PSObject.Properties.Name -contains 'agents') { $current = @($saved.agents) } } catch { $current = $null }
            }
        }
        if ($null -eq $current) {
            $current = @($registry | Where-Object { [bool]$detected.agents.([string]$_.id) } | ForEach-Object { [string]$_.id })
            if ($current.Count -eq 0 -and $Scope -eq 'Project') { $current = @('codex') }
        }
        Write-Host ''
        Write-Host 'hd-skill: which AI agents should get the skills?'
        for ($i = 0; $i -lt $registry.Count; $i++) {
            $entry = $registry[$i]
            $mark = if ([string]$entry.id -in $current) { 'x' } else { ' ' }
            $note = if ([bool]$detected.agents.([string]$entry.id)) { 'detected' } else { '' }
            Write-Host ("  [{0}] [{1}] {2,-20} {3,-12} {4}" -f ($i + 1), $mark, $entry.name, $entry.id, $note)
        }
        Write-Host '  Custom agents: add them to %USERPROFILE%\.hd-skill\agents.custom.json (see README).'
        while ($true) {
            try { $answer = Read-Host 'Numbers separated by commas (e.g. 1,3), a = all, Enter = keep [x]' }
            catch { return $null }
            $answer = $answer.Trim()
            if ($answer -eq '') { return $null }
            if ($answer -in @('a', 'all')) { return @($registry | ForEach-Object { [string]$_.id }) }
            $picked = @(); $valid = $true
            foreach ($token in ($answer -split '[,;\s]+' | Where-Object { $_ })) {
                $number = 0
                if ([int]::TryParse($token, [ref]$number) -and $number -ge 1 -and $number -le $registry.Count) { $picked += [string]$registry[$number - 1].id }
                else { $valid = $false }
            }
            if ($valid -and $picked.Count -gt 0) { return @($picked | Select-Object -Unique) }
            Write-Host 'Please enter numbers from the list.'
        }
    }

    $tempClone = $null
    if (Test-Path -LiteralPath $repoHome) {
        $origin = git -C $repoHome remote get-url origin
        # The repository was renamed from hs-skills; older checkouts still point at the old URL, which GitHub redirects.
        $acceptedOrigins = @($RepositoryUrl, $RepositoryUrl.Replace('/hd-skills', '/hs-skills'))
        if ($LASTEXITCODE -ne 0 -or $origin.Trim() -notin $acceptedOrigins) { throw "The existing checkout at '$repoHome' does not use $RepositoryUrl; inspect it before continuing." }
        $source = $repoHome
        if (-not $DryRun -and -not $Uninstall) {
            git -C $repoHome pull --ff-only --quiet
            if ($LASTEXITCODE -ne 0) { throw "git pull --ff-only failed in '$repoHome'; inspect local changes before retrying." }
        }
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
        if ($Scope -eq 'Global' -and $Uninstall) {
            $uninstallArgs = @{ RepoRoot = $source }
            if (-not $DryRun) { $uninstallArgs.Apply = $true }
            & (Join-Path $source 'uninstall.ps1') @uninstallArgs
            return
        }
        if (-not $source) {
            git clone $RepositoryUrl $repoHome
            if ($LASTEXITCODE -ne 0) { throw "git clone failed from '$RepositoryUrl'." }
            $source = $repoHome
        }
        if (-not $Uninstall -and -not $Agents -and -not $env:HD_SKILL_AGENTS -and -not $NonInteractive) { $Agents = Select-HdAgents $source }

        if ($Scope -eq 'Global') {
            # bootstrap.ps1 pulls, validates, and installs for the selected (or detected) agents.
            $bootstrapArgs = @{ RepoRoot = $source; RepositoryUrl = $RepositoryUrl; Mode = 'Junction'; NonInteractive = $NonInteractive }
            if ($DryRun) { $bootstrapArgs.DryRun = $true }
            if ($Agents) { $bootstrapArgs.Agents = $Agents }
            if ($VaultPath) { $bootstrapArgs.VaultPath = $VaultPath }
            if ($WithMcp) { $bootstrapArgs.WithMcp = $true }
            & (Join-Path $source 'bootstrap.ps1') @bootstrapArgs
        }
        else {
            $projectArgs = @{ RepoRoot = $source; ProjectPath = $project }
            if (-not $DryRun) { $projectArgs.Apply = $true }
            if ($Uninstall) { $projectArgs.Uninstall = $true }
            if ($Agents) { $projectArgs.Agents = $Agents }
            & (Join-Path $source 'install-project.ps1') @projectArgs
        }
        if (-not $Uninstall -and -not $DryRun) {
            Write-Host ''
            Write-Host 'Next: connect an Obsidian vault (optional):'
            Write-Host '  irm https://raw.githubusercontent.com/LeDuyCoder/hd-skills/master/obsidian.ps1 | iex'
        }
    }
    finally {
        if ($tempClone -and (Test-Path -LiteralPath $tempClone)) { Remove-Item -LiteralPath $tempClone -Recurse -Force }
    }
}
