[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$requiredSkills = @(
    'planning', 'tdd', 'systematic-debugging', 'verification-before-done', 'code-review',
    'refactoring', 'security-review', 'git-workflow', 'pull-request', 'fix-ci',
    'dependency-upgrade', 'windows-shell', 'skill-improve', 'stack-skill-generator'
)
foreach ($name in $requiredSkills) {
    $path = Join-Path (Join-Path $repoRoot 'skills') (Join-Path $name 'SKILL.md')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required M3 skill is missing: $name" }
    $text = [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false, $true))
    if ($text -notmatch '(?im)^name:\s*' + [regex]::Escape($name) + '\s*$') { throw "$name metadata does not match its folder." }
    if ($text -notmatch '(?i)context-load' -or $text -notmatch '(?i)context-update') { throw "$name must include context-load and context-update guidance." }
    if ($text -match '(?i)(?:npm run (?:test|build|lint)|dotnet (?:test|build)|pytest(?:\s|$)|cargo (?:test|build))') { throw "$name hard-codes a project build or test command." }
    if ($text -match '(?m)(?:^|\s)[A-Za-z]:\\') { throw "$name contains a rooted drive path." }
}
Write-Host "[PASS] All $($requiredSkills.Count) M3 skills exist, use context lifecycle guidance, and avoid fixed build commands/drive paths."
