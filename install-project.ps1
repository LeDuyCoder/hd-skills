[CmdletBinding()]
param(
    [Parameter()] [string] $ProjectPath = (Get-Location).Path,
    [Parameter()] [string] $RepoRoot = $PSScriptRoot,
    [Parameter()] [switch] $DryRun = $true,
    [Parameter()] [switch] $Apply,
    [Parameter()] [switch] $Uninstall,
    [Parameter()] [switch] $Force
)

$ErrorActionPreference = 'Stop'
if ($Apply) { $DryRun = $false }
$repo = [IO.Path]::GetFullPath($RepoRoot)
if (-not (Test-Path -LiteralPath (Join-Path $repo 'config.schema.json') -PathType Leaf)) { throw "Not an hd-skill repository: $repo" }
$project = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\')
if (-not (Test-Path -LiteralPath $project -PathType Container)) { throw "Project directory does not exist: $project" }
if ($project -eq $repo.TrimEnd('\')) { throw 'ProjectPath is the hd-skill repository itself; run this from the project you want to equip.' }
$runtimeRoot = Join-Path $project '.hd-skill'
$statePath = Join-Path $runtimeRoot 'project-install.json'
$agentsPath = Join-Path $project 'AGENTS.md'
$beginMarker = '<!-- BEGIN hd-skill -->'
$endMarker = '<!-- END hd-skill -->'

function Get-FileHashHex([string] $Path) {
    $stream = [IO.File]::OpenRead($Path)
    try { $algorithm = [Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() } finally { $algorithm.Dispose() } }
    finally { $stream.Dispose() }
}
function Get-ExistingText([string] $Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
    return ''
}
function Write-Utf8NoBom([string] $Path, [string] $Text) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}
function Get-BlockBounds([string] $Text) {
    $hasBegin = $Text.Contains($beginMarker)
    if ($hasBegin -ne $Text.Contains($endMarker)) { throw "AGENTS.md has an incomplete hd-skill marker block; repair it first: $agentsPath" }
    if (-not $hasBegin) { return $null }
    $start = $Text.IndexOf($beginMarker, [StringComparison]::Ordinal)
    $finish = $Text.IndexOf($endMarker, $start, [StringComparison]::Ordinal)
    if ($finish -lt 0) { throw 'The hd-skill END marker precedes its BEGIN marker in AGENTS.md.' }
    return @($start, ($finish + $endMarker.Length))
}
function Merge-MarkedBlock([string] $Existing, [string] $Block) {
    $bounds = Get-BlockBounds $Existing
    if ($bounds) { return $Existing.Substring(0, $bounds[0]) + $Block + $Existing.Substring($bounds[1]) }
    $separator = if ([string]::IsNullOrEmpty($Existing)) { '' } elseif ($Existing.EndsWith("`n")) { [Environment]::NewLine } else { [Environment]::NewLine + [Environment]::NewLine }
    return $Existing + $separator + $Block + [Environment]::NewLine
}
function Remove-MarkedBlock([string] $Existing) {
    $bounds = Get-BlockBounds $Existing
    if (-not $bounds) { return $Existing }
    $after = $Existing.Substring($bounds[1]) -replace '^\r?\n', ''
    return ($Existing.Substring(0, $bounds[0]).TrimEnd() + [Environment]::NewLine + $after).TrimStart()
}
function Remove-EmptyParents([string] $Path, [string] $StopAt) {
    $current = Split-Path -Parent $Path
    while ($current -and $current.Length -gt $StopAt.Length -and (Test-Path -LiteralPath $current -PathType Container) -and -not (Get-ChildItem -LiteralPath $current -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $current -Force
        $current = Split-Path -Parent $current
    }
}

$previousState = $null
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    try { $previousState = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Project install state is invalid JSON at '$statePath'; repair or remove it before continuing." }
}
$recorded = @{}
if ($previousState) { foreach ($entry in @($previousState.files)) { $recorded[[string]$entry.path] = [string]$entry.hash } }
$agentsBefore = Get-ExistingText $agentsPath
Write-Host ("Project: {0}" -f $project)

if ($Uninstall) {
    if (-not $previousState) { Write-Host 'hd-skill is not installed in this project (no .hd-skill\project-install.json).'; return }
    $removals = @(); $kept = @()
    foreach ($relative in $recorded.Keys | Sort-Object) {
        $target = Join-Path $project $relative
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { continue }
        if ($Force -or (Get-FileHashHex $target) -eq $recorded[$relative]) { $removals += $target } else { $kept += $target }
    }
    $agentsAfter = Remove-MarkedBlock $agentsBefore
    foreach ($target in $removals) { Write-Verbose "remove $target" }
    if ($removals.Count -gt 0) { Write-Host ("[PLAN] remove {0} managed file(s) (-Verbose lists them)" -f $removals.Count) }
    foreach ($target in $kept) { Write-Warning "Locally modified, kept (use -Force to remove): $target" }
    if ($agentsAfter -cne $agentsBefore) { Write-Host "[PLAN] remove hd-skill block from $agentsPath" }
    Write-Host "[PLAN] remove $statePath"
    if ($DryRun) { Write-Host 'Dry run complete: nothing was changed. Use -Apply to uninstall.'; return }
    foreach ($target in $removals) { Remove-Item -LiteralPath $target -Force; Remove-EmptyParents $target $project }
    if ($agentsAfter -cne $agentsBefore) {
        if ([string]::IsNullOrWhiteSpace($agentsAfter) -and -not $previousState.agentsFileExisted) { Remove-Item -LiteralPath $agentsPath -Force }
        else { Write-Utf8NoBom $agentsPath $agentsAfter }
    }
    Remove-Item -LiteralPath $statePath -Force
    Remove-EmptyParents $statePath $project
    Write-Host '[UNINSTALLED] hd-skill was removed from this project.'
    return
}

& (Join-Path $repo 'scripts\validate.ps1') -RootPath (Join-Path $repo 'skills')
if ($LASTEXITCODE -ne 0) { throw 'Skill/config validation failed; project installation stopped.' }

$desired = [ordered]@{}
foreach ($skill in Get-ChildItem -LiteralPath (Join-Path $repo 'skills') -Directory | Sort-Object Name) {
    foreach ($file in Get-ChildItem -LiteralPath $skill.FullName -File -Recurse | Sort-Object FullName) {
        $relative = $file.FullName.Substring($skill.FullName.TrimEnd('\').Length).TrimStart('\')
        $desired[(Join-Path ".agents\skills\$($skill.Name)" $relative)] = $file.FullName
    }
}
$desired['.hd-skill\scripts\Resolve-HdSkillConfig.ps1'] = Join-Path $repo 'scripts\Resolve-HdSkillConfig.ps1'
$desired['.hd-skill\scripts\Detect-Environment.ps1'] = Join-Path $repo 'scripts\Detect-Environment.ps1'
$desired['.hd-skill\config.defaults.json'] = Join-Path $repo 'config.defaults.json'
$desired['.hd-skill\config.schema.json'] = Join-Path $repo 'config.schema.json'

$copies = @(); $removals = @(); $conflicts = @(); $kept = @(); $stateFiles = @()
foreach ($relative in $desired.Keys) {
    $source = $desired[$relative]
    $target = Join-Path $project $relative
    $sourceHash = Get-FileHashHex $source
    $stateHash = $sourceHash
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { $copies += [pscustomobject]@{ source = $source; target = $target } }
    else {
        $targetHash = Get-FileHashHex $target
        if ($targetHash -ne $sourceHash) {
            if ($Force -or ($recorded.ContainsKey($relative) -and $recorded[$relative] -eq $targetHash)) { $copies += [pscustomobject]@{ source = $source; target = $target } }
            elseif ($recorded.ContainsKey($relative)) { $kept += $target; $stateHash = $recorded[$relative] }
            else { $conflicts += $target }
        }
    }
    $stateFiles += [pscustomobject]@{ path = $relative; hash = $stateHash }
}
foreach ($relative in $recorded.Keys | Where-Object { -not $desired.Contains($_) } | Sort-Object) {
    $target = Join-Path $project $relative
    if ((Test-Path -LiteralPath $target -PathType Leaf) -and (Get-FileHashHex $target) -eq $recorded[$relative]) { $removals += $target }
}
if ($conflicts.Count -gt 0) {
    foreach ($target in $conflicts) { Write-Warning "Existing file is not managed by hd-skill: $target" }
    throw 'Refusing to overwrite unmanaged project files. Move them aside, or rerun with -Force to replace them.'
}

$ruleContent = (Get-Content -LiteralPath (Join-Path $repo 'rules\AGENTS.md') -Raw -Encoding UTF8).Trim()
$agentsAfter = Merge-MarkedBlock $agentsBefore ("$beginMarker`n$ruleContent`n$endMarker")
$agentsExisted = if ($previousState) { [bool]$previousState.agentsFileExisted } else { Test-Path -LiteralPath $agentsPath -PathType Leaf }
$state = [ordered]@{ version = 1; repositoryPath = $repo; agentsFileExisted = $agentsExisted; files = $stateFiles }
$stateText = ($state | ConvertTo-Json -Depth 6) + [Environment]::NewLine

foreach ($copy in $copies) { Write-Verbose ("copy {0} -> {1}" -f $copy.source, $copy.target) }
if ($copies.Count -gt 0) { Write-Host ("[PLAN] copy {0} file(s) into {1} and {2} (-Verbose lists them)" -f $copies.Count, (Join-Path $project '.agents\skills'), $runtimeRoot) }
foreach ($target in $removals) { Write-Host "[PLAN] remove retired file $target" }
foreach ($target in $kept) { Write-Warning "Locally modified, kept (use -Force to overwrite): $target" }
if ($agentsAfter -cne $agentsBefore) { Write-Host "[PLAN] update hd-skill block in $agentsPath" }
if ($DryRun) { Write-Host 'Dry run complete: nothing was changed. Use -Apply to install into this project.'; return }

if ($agentsBefore -and $agentsAfter -cne $agentsBefore) {
    $profileRoot = [Environment]::GetEnvironmentVariable('USERPROFILE')
    if ([string]::IsNullOrWhiteSpace($profileRoot)) { $profileRoot = [Environment]::GetFolderPath('UserProfile') }
    $backupRoot = Join-Path $profileRoot ('.hd-skill\backups\project-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Copy-Item -LiteralPath $agentsPath -Destination (Join-Path $backupRoot 'AGENTS.md') -Force
    Write-Host ("[BACKUP] {0}" -f (Join-Path $backupRoot 'AGENTS.md'))
}
foreach ($copy in $copies) {
    $parent = Split-Path -Parent $copy.target
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item -LiteralPath $copy.source -Destination $copy.target -Force
}
foreach ($target in $removals) { Remove-Item -LiteralPath $target -Force; Remove-EmptyParents $target $project }
if ($agentsAfter -cne $agentsBefore) { Write-Utf8NoBom $agentsPath $agentsAfter }
Write-Utf8NoBom $statePath $stateText
Write-Host ("[INSTALLED] {0} skills in {1}; rules in {2}" -f (@(Get-ChildItem -LiteralPath (Join-Path $repo 'skills') -Directory).Count), (Join-Path $project '.agents\skills'), $agentsPath)
