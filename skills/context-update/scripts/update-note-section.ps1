[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RepoPath,
    [Parameter(Mandatory)] [string] $NotePath,
    [Parameter(Mandatory)] [string] $SectionHeading,
    [Parameter(Mandatory)] [string] $ObservedUpdated,
    [Parameter(Mandatory)] [AllowEmptyString()] [string] $Replacement
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepoPath)
$note = [IO.Path]::GetFullPath($NotePath)
$resolverCandidates = @()
# A project install keeps its own runtime at <project>\.hd-skill; <project>\.agents\skills\<skill>\scripts is four levels below it.
$resolverCandidates += [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\.hd-skill\scripts\Resolve-HdSkillConfig.ps1'))
if ($env:USERPROFILE) { $resolverCandidates += Join-Path $env:USERPROFILE '.hd-skill\scripts\Resolve-HdSkillConfig.ps1' }
if ($env:HD_SKILL_HOME) { $resolverCandidates += Join-Path $env:HD_SKILL_HOME 'scripts\Resolve-HdSkillConfig.ps1' }
$resolverCandidates += [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\scripts\Resolve-HdSkillConfig.ps1'))
$resolverPath = $resolverCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $resolverPath) { throw 'Resolve-HdSkillConfig.ps1 was not found. Install hd-skill or set HD_SKILL_HOME.' }
$null = & $resolverPath -RepoRoot $repo | ConvertFrom-Json -ErrorAction Stop
if (-not (Test-Path -LiteralPath $note -PathType Leaf)) { throw "Note does not exist: $note" }

$observedTime = [DateTimeOffset]::MinValue
if (-not [DateTimeOffset]::TryParse($ObservedUpdated, [ref]$observedTime)) { throw "ObservedUpdated is not a parseable timestamp: $ObservedUpdated" }
$heading = $SectionHeading.Trim()
if ($heading -notmatch '^#{1,6}\s+\S') { throw 'SectionHeading must be a Markdown heading such as ## Architecture.' }
$null = $heading -match '^(#+)'
$headingLevel = $Matches[1].Length
$directory = Split-Path -Parent $note
$tempNote = Join-Path $directory ('.' + [IO.Path]::GetFileName($note) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
$backupNote = $tempNote + '.bak'
$lock = $null

try {
    try { $lock = [IO.File]::Open($note, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch [IO.IOException] { throw "Note is being written by another process; retry after rereading it: $note" }
    $reader = [IO.StreamReader]::new($lock, [Text.Encoding]::UTF8, $true, 4096, $true)
    $currentText = $reader.ReadToEnd()
    $reader.Dispose()
    if ($currentText -match '(?m)^updated:\s*(.+?)\s*$') {
        $currentTime = [DateTimeOffset]::MinValue
        if ([DateTimeOffset]::TryParse($Matches[1].Trim().Trim('"', "'"), [ref]$currentTime) -and $currentTime -gt $observedTime) {
            Write-Host "[CONFLICT] Note updated at $($currentTime.ToString('o')) after the version you read ($ObservedUpdated). Reread the note and reconcile before retrying."
            exit 3
        }
    }
    else { throw 'Note frontmatter has no updated field.' }

    $lines = [regex]::Split($currentText, "`r`n|`n|`r")
    $headingIndex = [Array]::IndexOf($lines, $heading)
    if ($headingIndex -lt 0) { throw "Section heading not found: $heading" }
    $nextHeading = $lines.Count
    for ($i = $headingIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^(#{1,6})\s+' -and $Matches[1].Length -le $headingLevel) { $nextHeading = $i; break }
    }
    $replacementLines = [regex]::Split($Replacement, "`r`n|`n|`r")
    $newLines = @()
    if ($headingIndex -gt 0) { $newLines += $lines[0..$headingIndex] } else { $newLines += $lines[$headingIndex] }
    if ($Replacement.Length -gt 0) { $newLines += $replacementLines }
    if ($nextHeading -lt $lines.Count) { $newLines += $lines[$nextHeading..($lines.Count - 1)] }
    $newText = $newLines -join [Environment]::NewLine
    $newText = [regex]::Replace($newText, '(?m)^updated:\s*.*$', ('updated: ' + [DateTimeOffset]::Now.ToString('o')), 1)
    [IO.File]::WriteAllText($tempNote, $newText, [Text.UTF8Encoding]::new($false))
    $lock.Dispose()
    $lock = $null
    [IO.File]::Replace($tempNote, $note, $backupNote)
    if (Test-Path -LiteralPath $backupNote) { Remove-Item -LiteralPath $backupNote -Force }
    Write-Host "[UPDATED] Only section '$heading' and its updated timestamp were changed."
}
finally {
    if ($lock) { $lock.Dispose() }
    if (Test-Path -LiteralPath $tempNote) { Remove-Item -LiteralPath $tempNote -Force }
    if (Test-Path -LiteralPath $backupNote) { Remove-Item -LiteralPath $backupNote -Force }
}
