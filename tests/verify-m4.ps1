[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$rulePaths = @((Join-Path $repoRoot 'rules\AGENTS.md'), (Join-Path $repoRoot 'rules\GEMINI.md'))
$contents = @()
foreach ($path in $rulePaths) {
    $content = [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false, $true))
    $count = $content.Length
    Write-Host ("{0}: {1} characters (<3000: {2})" -f (Split-Path -Leaf $path), $count, ($count -lt 3000))
    if ($count -ge 3000) { throw "Rule file exceeds its 3,000-character limit: $path" }
    if ($content -match '(?i)\b[A-Z]:\\') { throw "Rule file contains a fixed drive path: $path" }
    if ($content -notmatch 'Resolve-HdSkillConfig\.ps1') { throw "Rule file does not direct agents to the resolver: $path" }
    $contents += $content
}
if ($contents[0] -cne $contents[1]) { throw 'AGENTS.md and GEMINI.md must retain identical core guidance.' }
Write-Host '[PASS] Both always-on rules have identical core content and satisfy the path and length constraints.'
