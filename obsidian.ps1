# Connects hd-skill to an Obsidian vault (the shared context store). Interactive:
#   irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/obsidian.ps1 | iex
# With options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/LeDuyCoder/hs-skills/master/obsidian.ps1))) -VaultPath 'D:\Notes\DevBrain'
# From a checkout: & .\obsidian.ps1 [-VaultPath <path>] [-WithMcp] [-DryRun] [-NonInteractive]
# Like get.ps1 it may run inside the caller's session, so it never calls `exit`.
param(
    [string] $VaultPath,
    [string] $RepositoryUrl = 'https://github.com/LeDuyCoder/hs-skills.git',
    [switch] $WithMcp,
    [switch] $DryRun,
    [switch] $NonInteractive
)

& {
    $ErrorActionPreference = 'Stop'
    $profileRoot = [Environment]::GetEnvironmentVariable('USERPROFILE')
    if ([string]::IsNullOrWhiteSpace($profileRoot)) { $profileRoot = [Environment]::GetFolderPath('UserProfile') }
    $hdHome = Join-Path $profileRoot '.hd-skill'
    $repoHome = if ($env:HD_SKILL_HOME) { [IO.Path]::GetFullPath($env:HD_SKILL_HOME) } else { Join-Path $hdHome 'repo' }

    # Use this checkout when run as a file; otherwise the shared checkout, cloned on first use.
    $repo = $null
    if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'config.schema.json') -PathType Leaf)) { $repo = $PSScriptRoot }
    elseif (Test-Path -LiteralPath (Join-Path $repoHome 'config.schema.json') -PathType Leaf) {
        $repo = $repoHome
        if (-not $DryRun -and (Get-Command git -ErrorAction SilentlyContinue)) {
            git -C $repoHome pull --ff-only --quiet
            if ($LASTEXITCODE -ne 0) { Write-Warning "git pull --ff-only failed in '$repoHome'; continuing with the current checkout." }
        }
    }
    else {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git for Windows is required. Install it from https://git-scm.com/download/win and rerun.' }
        if ($DryRun) { throw "hd-skill is not installed yet ($repoHome is missing). Run the install command first." }
        git clone --quiet $RepositoryUrl $repoHome
        if ($LASTEXITCODE -ne 0) { throw "git clone failed from '$RepositoryUrl'." }
        $repo = $repoHome
    }
    $repo = [IO.Path]::GetFullPath($repo)

    $detected = & (Join-Path $repo 'scripts\Detect-Environment.ps1') -RepoRoot $repo 3>$null | ConvertFrom-Json
    $vaults = @($detected.obsidian.vaults | Where-Object { $_.path })
    $configPath = Join-Path $hdHome 'config.json'
    $machineConfig = $null
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try { $machineConfig = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw "Machine config '$configPath' is invalid JSON; repair it before connecting a vault." }
    }

    # 1. Pick the vault.
    if (-not $VaultPath -and $NonInteractive) {
        $preferredName = if ($machineConfig -and $machineConfig.vaultName) { [string]$machineConfig.vaultName } else { 'DevBrain' }
        $match = @($vaults | Where-Object { [string]$_.name -ieq $preferredName })
        if ($match.Count -gt 0) { $VaultPath = [string]$match[0].path }
        elseif ($vaults.Count -eq 1) { $VaultPath = [string]$vaults[0].path }
        else { throw 'Pass -VaultPath: no single Obsidian vault could be chosen without asking.' }
    }
    if (-not $VaultPath) {
        $suggested = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'DevBrain'
        Write-Host ''
        Write-Host 'hd-skill: which Obsidian vault should hold the project notes?'
        for ($i = 0; $i -lt $vaults.Count; $i++) { Write-Host ("  [{0}] {1,-20} {2}" -f ($i + 1), $vaults[$i].name, $vaults[$i].path) }
        if ($vaults.Count -eq 0) { Write-Host '  (Obsidian has no registered vaults on this machine.)' }
        Write-Host '  [n] Create a new vault folder'
        Write-Host '  [p] Type the path of an existing folder'
        $defaultChoice = if ($vaults.Count -gt 0) { '1' } else { 'n' }
        while (-not $VaultPath) {
            try { $choice = (Read-Host "Choose [$defaultChoice]").Trim() }
            catch { throw 'No console input is available. Pass -VaultPath <folder>.' }
            if ($choice -eq '') { $choice = $defaultChoice }
            $number = 0
            if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $vaults.Count) { $VaultPath = [string]$vaults[$number - 1].path }
            elseif ($choice -in @('n', 'N')) {
                $typed = (Read-Host "New vault folder [$suggested]").Trim().Trim('"')
                $VaultPath = if ($typed) { $typed } else { $suggested }
            }
            elseif ($choice -in @('p', 'P')) { $VaultPath = (Read-Host 'Folder path').Trim().Trim('"') }
            else { Write-Host 'Please choose a number, n, or p.' }
        }
    }
    $vault = [IO.Path]::GetFullPath($VaultPath)
    $registered = @($vaults | Where-Object { [IO.Path]::GetFullPath([string]$_.path).TrimEnd('\') -ieq $vault.TrimEnd('\') }).Count -gt 0

    # 2. Plan the vault folder and its starting index.
    $indexPath = Join-Path $vault '00-INDEX.md'
    $createFolder = -not (Test-Path -LiteralPath $vault -PathType Container)
    $createIndex = -not (Test-Path -LiteralPath $indexPath -PathType Leaf)
    $installState = Join-Path $hdHome 'install-state.json'
    $globalInstall = Test-Path -LiteralPath $installState -PathType Leaf
    $useMcp = [bool]$WithMcp -or [bool]($machineConfig -and $machineConfig.mcpEnabled)
    Write-Host ''
    Write-Host ("Vault: {0}" -f $vault)
    if ($createFolder) { Write-Host '[PLAN] create the vault folder' }
    if ($createIndex) { Write-Host '[PLAN] create 00-INDEX.md and projects\ (existing notes are never overwritten)' }
    Write-Host ("[PLAN] save vaultPath in {0}" -f $configPath)
    if ($globalInstall) { Write-Host ('[PLAN] refresh the global install for this vault{0}' -f $(if ($useMcp) { ' (with filesystem MCP)' } else { '' })) }
    if ($DryRun) { Write-Host 'Dry run complete: nothing was changed.'; return }

    # 3. Apply.
    if ($createFolder) { New-Item -ItemType Directory -Path $vault -Force | Out-Null }
    if (-not (Test-Path -LiteralPath (Join-Path $vault 'projects') -PathType Container)) { New-Item -ItemType Directory -Path (Join-Path $vault 'projects') -Force | Out-Null }
    if ($createIndex) {
        $template = [IO.File]::ReadAllText((Join-Path $repo 'vault-template\00-INDEX.md'), [Text.Encoding]::UTF8)
        $text = $template.Replace('{{timestamp}}', [DateTimeOffset]::Now.ToString('o'))
        [IO.File]::WriteAllText($indexPath, $text, [Text.UTF8Encoding]::new($false))
    }
    if ($globalInstall) {
        $state = Get-Content -LiteralPath $installState -Raw -Encoding UTF8 | ConvertFrom-Json
        $installArgs = @{ RepoRoot = $repo; VaultPath = $vault; Mode = $(if ($state.mode) { [string]$state.mode } else { 'Junction' }); Apply = $true; NonInteractive = $true }
        if ($useMcp) { $installArgs.WithMcp = $true }
        & (Join-Path $repo 'install.ps1') @installArgs
        if ($LASTEXITCODE -ne 0) { throw 'Refreshing the global install failed; the vault folder is ready but the config may be unchanged.' }
    }
    else {
        & (Join-Path $repo 'scripts\Resolve-HdSkillConfig.ps1') -RepoRoot $repo -VaultPath $vault -NonInteractive -PersistConfig | Out-Null
        if ($WithMcp) { Write-Warning 'MCP is written by the installer; run the install command with -WithMcp after installing globally.' }
    }

    Write-Host ''
    Write-Host ("[CONNECTED] hd-skill now stores project notes in {0}" -f $vault)
    if (-not $registered) { Write-Host '  Open it in Obsidian once: Open folder as vault -> choose the folder above.' }
    Write-Host '  In a project, run /hd init (Codex: $hd init) to create its first notes.'
}
