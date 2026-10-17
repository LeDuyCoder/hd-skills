[CmdletBinding()]
param(
    [Parameter()] [string] $RepoRoot = $PSScriptRoot,
    [Parameter()] [switch] $DryRun = $true,
    [Parameter()] [switch] $Apply
)

$ErrorActionPreference = 'Stop'
if ($Apply) { $DryRun = $false }
$repo = [IO.Path]::GetFullPath($RepoRoot)
$profileRoot = [Environment]::GetEnvironmentVariable('USERPROFILE')
if ([string]::IsNullOrWhiteSpace($profileRoot)) { $profileRoot = [Environment]::GetFolderPath('UserProfile') }
$statePath = Join-Path $profileRoot '.hd-skill\install-state.json'
if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { Write-Host '[OK] No hd-skill install state exists.'; exit 0 }
$state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$machineConfigPath = Join-Path $profileRoot '.hd-skill\config.json'
$actions = [System.Collections.Generic.List[object]]::new()

function Get-FileHashHex([string] $Path) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($algorithm.ComputeHash([IO.File]::ReadAllBytes($Path))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}
function Write-Utf8NoBom([string] $Path, [string] $Text) { [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false)) }
function Get-TextWithoutManagedBlock([string] $Text, [bool] $OriginalEndedWithNewline) {
    $begin = '# BEGIN hd-skill'
    $end = '# END hd-skill'
    $start = $Text.IndexOf($begin, [StringComparison]::Ordinal)
    if ($start -lt 0) { return $Text }
    $endStart = $Text.IndexOf($end, $start, [StringComparison]::Ordinal)
    if ($endStart -lt 0) { throw 'Managed hd-skill block has no END marker; preserving the file and stopping removal.' }
    $finish = $endStart + $end.Length
    $prefix = $Text.Substring(0, $start)
    if (-not $OriginalEndedWithNewline) {
        if ($prefix.EndsWith("`r`n")) { $prefix = $prefix.Substring(0, $prefix.Length - 2) }
        elseif ($prefix.EndsWith("`n") -or $prefix.EndsWith("`r")) { $prefix = $prefix.Substring(0, $prefix.Length - 1) }
    }
    $suffix = $Text.Substring($finish)
    if ($suffix.StartsWith("`r`n")) { $suffix = $suffix.Substring(2) }
    elseif ($suffix.StartsWith("`n") -or $suffix.StartsWith("`r")) { $suffix = $suffix.Substring(1) }
    return $prefix + $suffix
}
function Add-BackupAction([string] $Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { $actions.Add([pscustomobject]@{ type = 'backup'; path = $Path }) }
}

foreach ($skill in @($state.skills)) {
    if (-not (Test-Path -LiteralPath $skill.target)) { continue }
    if ($skill.mode -eq 'Junction') {
        $item = Get-Item -LiteralPath $skill.target -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
            Write-Warning "Preserving changed non-junction path: $($skill.target)"
            continue
        }
        $actions.Add([pscustomobject]@{ type = 'remove-junction'; path = $skill.target })
    }
    else {
        foreach ($file in @($skill.files)) {
            $targetFile = Join-Path $skill.target $file.path
            if ((Test-Path -LiteralPath $targetFile -PathType Leaf) -and (Get-FileHashHex $targetFile) -eq $file.hash) {
                Add-BackupAction $targetFile
                $actions.Add([pscustomobject]@{ type = 'remove-file'; path = $targetFile })
            }
        }
        $actions.Add([pscustomobject]@{ type = 'prune-copy'; path = $skill.target })
    }
}

$globalFilePlans = @()
foreach ($file in @($state.globalFiles)) {
    if (-not (Test-Path -LiteralPath $file.path -PathType Leaf)) { continue }
    $before = [IO.File]::ReadAllText($file.path, [Text.Encoding]::UTF8)
    if ($file.kind -eq 'text') {
        $after = Get-TextWithoutManagedBlock $before ([bool]$file.originalEndedWithNewline)
    }
    elseif ($file.kind -eq 'json') {
        $document = Get-Content -LiteralPath $file.path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        if ($document.mcpServers -and ($document.mcpServers.PSObject.Properties.Name -contains 'hd-skill-filesystem')) {
            $server = $document.mcpServers.'hd-skill-filesystem'
            if ($server.command -eq 'cmd' -and @($server.args) -contains '@modelcontextprotocol/server-filesystem@1.0.0') {
                $document.mcpServers.PSObject.Properties.Remove('hd-skill-filesystem')
            }
        }
        if ($document.mcpServers -and $document.mcpServers.PSObject.Properties.Count -eq 0) { $document.PSObject.Properties.Remove('mcpServers') }
        $after = ($document | ConvertTo-Json -Depth 20) + [Environment]::NewLine
    }
    else { continue }
    $globalFilePlans += [pscustomobject]@{ path = $file.path; before = $before; after = $after; existed = [bool]$file.existed }
    if ($after -cne $before) { Add-BackupAction $file.path; $actions.Add([pscustomobject]@{ type = 'restore-config'; path = $file.path; existed = [bool]$file.existed; after = $after }) }
}

foreach ($shared in @($state.sharedFiles)) {
    if (-not $shared.existed -and (Test-Path -LiteralPath $shared.target -PathType Leaf) -and (Get-FileHashHex $shared.target) -eq $shared.hash) {
        Add-BackupAction $shared.target
        $actions.Add([pscustomobject]@{ type = 'remove-file'; path = $shared.target })
    }
}
if (@($state.sharedFiles | Where-Object { $_.target -like '*\scripts\*' }).Count -gt 0) { $actions.Add([pscustomobject]@{ type = 'prune-empty'; path = (Join-Path (Join-Path $profileRoot '.hd-skill') 'scripts') }) }
foreach ($root in @($state.createdDirectories | Sort-Object Length -Descending)) { $actions.Add([pscustomobject]@{ type = 'prune-empty'; path = $root }) }
if ($state.machineConfigCreated -and (Test-Path -LiteralPath $machineConfigPath -PathType Leaf)) {
    $hash = Get-FileHashHex $machineConfigPath
    if ($hash -eq $state.machineConfigHash) { Add-BackupAction $machineConfigPath; $actions.Add([pscustomobject]@{ type = 'remove-file'; path = $machineConfigPath }) }
    else { Write-Warning "Machine config changed since installation and was preserved: $machineConfigPath" }
}
Add-BackupAction $statePath
$actions.Add([pscustomobject]@{ type = 'remove-file'; path = $statePath })

foreach ($action in $actions) {
    if ($action.type -eq 'backup') { Write-Host "[BACKUP-PLAN] $($action.path) -> %USERPROFILE%\.hd-skill\backups\<timestamp>\$(Split-Path -Leaf $action.path)" }
    else { Write-Host "[PLAN] $($action.type): $($action.path)" }
}
if ($DryRun) { Write-Host 'Dry run complete: no installation file, link, or configuration was changed. Use -Apply to uninstall.'; exit 0 }

$backupRoot = Join-Path (Join-Path $profileRoot '.hd-skill\backups') (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
$backupIndex = 0
foreach ($action in $actions | Where-Object type -eq 'backup') {
    if (-not (Test-Path -LiteralPath $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null }
    $backupIndex++
    Copy-Item -LiteralPath $action.path -Destination (Join-Path $backupRoot ('{0:D2}-{1}' -f $backupIndex, (Split-Path -Leaf $action.path))) -Force
}
foreach ($action in $actions) {
    switch ($action.type) {
        'remove-junction' { [IO.Directory]::Delete($action.path, $false) }
        'remove-file' { if (Test-Path -LiteralPath $action.path -PathType Leaf) { Remove-Item -LiteralPath $action.path -Force } }
        'prune-empty' {
            $candidate = $action.path
            if ((Test-Path -LiteralPath $candidate -PathType Container) -and @(Get-ChildItem -LiteralPath $candidate -Force).Count -eq 0) { Remove-Item -LiteralPath $candidate -Force }
        }
        'prune-copy' {
            $candidate = $action.path
            if (Test-Path -LiteralPath $candidate -PathType Container) {
                foreach ($directory in Get-ChildItem -LiteralPath $candidate -Directory -Recurse | Sort-Object FullName -Descending) {
                    if (@(Get-ChildItem -LiteralPath $directory.FullName -Force).Count -eq 0) { Remove-Item -LiteralPath $directory.FullName -Force }
                }
                if (@(Get-ChildItem -LiteralPath $candidate -Force).Count -eq 0) { Remove-Item -LiteralPath $candidate -Force }
            }
        }
        'restore-config' {
            if (-not $action.existed -and [string]::IsNullOrWhiteSpace($action.after)) { Remove-Item -LiteralPath $action.path -Force }
            elseif (-not $action.existed -and $action.path -match '\.json$' -and $action.after -match '^\s*\{\s*\}\s*$') { Remove-Item -LiteralPath $action.path -Force }
            else { Write-Utf8NoBom $action.path $action.after }
        }
    }
}
if (Test-Path -LiteralPath $statePath -PathType Leaf) { Remove-Item -LiteralPath $statePath -Force }
Write-Host "[UNINSTALLED] Managed skill links/copies and marked rules were removed. User-created or modified files were preserved. Backups: $backupRoot"
