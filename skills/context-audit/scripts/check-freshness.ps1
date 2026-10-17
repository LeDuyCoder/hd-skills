[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RepoPath,

    [Parameter(Mandatory = $true)]
    [string] $NotePath
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepoPath)
$note = [IO.Path]::GetFullPath($NotePath)
if (-not (Test-Path -LiteralPath $repo -PathType Container)) { throw "Repository does not exist: $repo" }
if (-not (Test-Path -LiteralPath $note -PathType Leaf)) { throw "Note does not exist: $note" }
$content = [IO.File]::ReadAllText($note, [Text.UTF8Encoding]::new($false, $true))
$lines = [regex]::Split($content, "`r`n|`n|`r")
if ($lines.Count -lt 3 -or $lines[0] -ne '---') { throw "No YAML frontmatter found in $note" }
$end = [Array]::IndexOf($lines, '---', 1)
if ($end -lt 0) { throw "Frontmatter closing delimiter missing in $note" }
$commit = $null
$paths = [System.Collections.Generic.List[string]]::new()
$insidePaths = $false
for ($i = 1; $i -lt $end; $i++) {
    if ($lines[$i] -match '^last_verified_commit:\s*(.+?)\s*$') {
        $commit = $Matches[1].Trim().Trim('"', "'")
        $insidePaths = $false
        continue
    }
    if ($lines[$i] -match '^paths:\s*$') { $insidePaths = $true; continue }
    if ($insidePaths -and $lines[$i] -match '^\S') { $insidePaths = $false }
    if ($insidePaths -and $lines[$i] -match '^\s+-\s+(.+?)\s*$') {
        $pathValue = $Matches[1].Trim().Trim('"', "'").Replace('/', '\')
        if (-not [string]::IsNullOrWhiteSpace($pathValue)) { $paths.Add($pathValue) }
    }
}
if ([string]::IsNullOrWhiteSpace($commit) -or $commit -eq 'unverified') {
    Write-Host '[STALE] Note has no verified Git commit.'
    exit 2
}
if ($paths.Count -eq 0) { Write-Host '[STALE] Note has no tracked paths.'; exit 2 }
$null = & git -C $repo rev-parse --verify "$commit^{commit}" 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "[STALE] Commit '$commit' is not present in this repository."; exit 2 }
$head = (& git -C $repo rev-parse HEAD 2>$null)
if ($LASTEXITCODE -ne 0) { throw 'Could not read repository HEAD.' }
$head = $head.Trim()
$gitArgs = @('-C', $repo, 'log', '--format=%H', "$commit..$head", '--') + @($paths)
$changes = @(& git @gitArgs 2>$null)
if ($LASTEXITCODE -ne 0) { throw 'git log failed while checking note paths.' }
if ($changes.Count -gt 0) {
    Write-Host "[STALE] $($changes.Count) commit(s) changed tracked paths after $commit."
    foreach ($path in $paths) { Write-Host "  path: $path" }
    exit 2
}
Write-Host "[FRESH] No commits changed the listed paths after $commit (HEAD $head)."
exit 0
