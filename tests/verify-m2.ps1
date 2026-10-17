[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixtureRoot = Join-Path $PSScriptRoot 'fixtures\demo-node'
$bootstrapper = Join-Path $repoRoot 'skills\context-bootstrap\scripts\bootstrap-context.ps1'
$detector = Join-Path $repoRoot 'skills\context-bootstrap\scripts\detect-stack.ps1'
$freshnessChecker = Join-Path $repoRoot 'skills\context-audit\scripts\check-freshness.ps1'
$pwsh = Get-Command 'pwsh' -ErrorAction SilentlyContinue
$powershellExe = if ($null -ne $pwsh) { $pwsh.Source } else { (Get-Process -Id $PID).Path }
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hd-skill-m2-' + [guid]::NewGuid().ToString('N'))

try {
    $detection = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $detector -RepoPath $fixtureRoot 2>&1
    if ($LASTEXITCODE -ne 0 -or ($detection | Out-String) -notmatch 'Node.js / JavaScript or TypeScript') {
        throw "Stack detection failed. Exit=$LASTEXITCODE Output=$($detection -join ' | ')"
    }
    Write-Host '[PASS] Fixture stack detected from package.json.'

    $detectReport = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $bootstrapper -RepoPath $fixtureRoot -ProjectName demo-node -DetectOnly 2>&1
    $detectText = $detectReport | Out-String
    if ($LASTEXITCODE -ne 0 -or $detectText -notmatch 'Available package scripts: start, test') {
        throw "Manifest command detection failed. Exit=$LASTEXITCODE Output=$detectText"
    }
    Write-Host '[PASS] Declared package scripts detected without inventing build/lint commands.'

    $outputRoot = Join-Path $tempRoot 'vault'
    $runOutput = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $bootstrapper -RepoPath $fixtureRoot -OutputRoot $outputRoot -ProjectName demo-node 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Bootstrap failed. Exit=$LASTEXITCODE Output=$($runOutput -join ' | ')" }
    $projectNotes = Join-Path $outputRoot 'projects\demo-node'
    $overviewPath = Join-Path $projectNotes 'overview.md'
    $overview = [IO.File]::ReadAllText($overviewPath, [Text.UTF8Encoding]::new($false, $true))
    $architecture = [IO.File]::ReadAllText((Join-Path $projectNotes 'architecture.md'), [Text.UTF8Encoding]::new($false, $true))
    $moduleNote = [IO.File]::ReadAllText((Join-Path $projectNotes 'modules\src.md'), [Text.UTF8Encoding]::new($false, $true))
    $decisions = [IO.File]::ReadAllText((Join-Path $projectNotes 'decisions\README.md'), [Text.UTF8Encoding]::new($false, $true))
    $sessionPath = Join-Path $projectNotes ('sessions\' + (Get-Date -Format 'yyyy-MM-dd') + '.md')
    $session = [IO.File]::ReadAllText($sessionPath, [Text.UTF8Encoding]::new($false, $true))
    $index = [IO.File]::ReadAllText((Join-Path $outputRoot '00-INDEX.md'), [Text.UTF8Encoding]::new($false, $true))
    if ($overview -notmatch 'npm run start' -or $overview -notmatch 'npm run test' -or $overview -match 'npm run (build|lint)' -or $overview -notmatch 'node-project-workflows') {
        throw 'Overview is missing declared commands or contains an invented command/skill suggestion.'
    }
    if ($architecture -notmatch '```mermaid' -or $moduleNote -notmatch 'src/index.js' -or $index -notmatch 'projects/demo-node/overview' -or $session -notmatch 'context bootstrap') {
        throw 'One or more generated notes are missing expected content.'
    }
    foreach ($file in Get-ChildItem -LiteralPath $projectNotes -Filter '*.md' -File -Recurse) {
        $note = [IO.File]::ReadAllText($file.FullName, [Text.UTF8Encoding]::new($false, $true))
        if ($note -notmatch '(?ms)^---\r?\n(?=.*?^project:\s*\S)(?=.*?^module:\s*\S)(?=.*?^paths:)(?=.*?^last_verified_commit:\s*\S)(?=.*?^updated:\s*\d{4}-\d{2}-\d{2})(?=.*?^tags:)(?=.*?^summary:\s*\S).*?^---\r?\n') {
            throw "Generated project note is missing standard frontmatter: $($file.FullName)"
        }
    }
    if ($decisions -notmatch '(?ms)^---\r?\n.*?^module: decisions.*?^---\r?\n') { throw 'Decision index must carry standard note frontmatter.' }
    foreach ($file in Get-ChildItem -LiteralPath $outputRoot -File -Recurse) {
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            throw "Generated note contains a UTF-8 BOM: $($file.FullName)"
        }
    }
    Write-Host '[PASS] Bootstrap generated UTF-8 notes, index, overview commands, Mermaid architecture, module inventory, gotchas, decisions index, and session note.'

    $auditRepo = Join-Path $tempRoot 'audit-repo'
    New-Item -ItemType Directory -Path (Join-Path $auditRepo 'src') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $auditRepo 'src\greeting.js'), 'export const greet = () => "hello";' + "`n", [Text.UTF8Encoding]::new($false))
    $null = & git -C $auditRepo init -q 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the temporary audit repository.' }
    $null = & git -C $auditRepo config core.autocrlf false
    $null = & git -C $auditRepo -c user.name='hd-skill test' -c user.email='test@example.invalid' add -- src/greeting.js 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Could not stage the temporary source file.' }
    $null = & git -C $auditRepo -c user.name='hd-skill test' -c user.email='test@example.invalid' commit -qm 'add greeting' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Could not commit the temporary source file.' }
    $firstCommit = (& git -C $auditRepo rev-parse HEAD).Trim()
    $auditNote = Join-Path $tempRoot 'audit-note.md'
    $auditDate = Get-Date -Format 'yyyy-MM-dd'
    $auditText = "---`nproject: audit`nmodule: src`npaths:`n  - src/greeting.js`nlast_verified_commit: $firstCommit`nupdated: $auditDate`ntags:`n  - audit`nsummary: Audit helper fixture.`n---`n# Audit fixture`n"
    [IO.File]::WriteAllText($auditNote, $auditText, [Text.UTF8Encoding]::new($false))
    $freshOutput = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $freshnessChecker -RepoPath $auditRepo -NotePath $auditNote 2>&1
    if ($LASTEXITCODE -ne 0 -or ($freshOutput | Out-String) -notmatch '\[FRESH\]') {
        throw "Freshness check failed on unchanged paths. Exit=$LASTEXITCODE Output=$($freshOutput -join ' | ')"
    }
    [IO.File]::AppendAllText((Join-Path $auditRepo 'src\greeting.js'), "export const farewell = () => 'bye';`n", [Text.UTF8Encoding]::new($false))
    $null = & git -C $auditRepo -c user.name='hd-skill test' -c user.email='test@example.invalid' add -- src/greeting.js 2>&1
    $null = & git -C $auditRepo -c user.name='hd-skill test' -c user.email='test@example.invalid' commit -qm 'change greeting' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Could not commit the temporary source change.' }
    $staleOutput = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $freshnessChecker -RepoPath $auditRepo -NotePath $auditNote 2>&1
    if ($LASTEXITCODE -ne 2 -or ($staleOutput | Out-String) -notmatch '\[STALE\]') {
        throw "Freshness check failed to flag a changed path. Exit=$LASTEXITCODE Output=$($staleOutput -join ' | ')"
    }
    Write-Host '[PASS] Git freshness checker distinguishes unchanged paths from a later path-specific commit.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
