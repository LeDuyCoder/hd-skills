[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$validator = Join-Path $repoRoot 'scripts\validate.ps1'
$pwsh = Get-Command 'pwsh' -ErrorAction SilentlyContinue
$powershellExe = if ($null -ne $pwsh) { $pwsh.Source } else { (Get-Process -Id $PID).Path }
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('hd-skill-m1-' + [guid]::NewGuid().ToString('N'))
$emptyRoot = Join-Path $tempRoot 'empty'
$warningRoot = Join-Path $tempRoot 'warning'
$invalidRoot = Join-Path $tempRoot 'invalid'
$badMetaDir = Join-Path $invalidRoot 'bad-meta'
$badSyntaxDir = Join-Path $invalidRoot 'bad-syntax'
$badBomDir = Join-Path $invalidRoot 'bad-bom'
$duplicateOne = Join-Path $invalidRoot 'duplicate-a\same-name'
$duplicateTwo = Join-Path $invalidRoot 'duplicate-b\same-name'

New-Item -ItemType Directory -Path $emptyRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $warningRoot 'long-description') -Force | Out-Null
New-Item -ItemType Directory -Path $badMetaDir, $badSyntaxDir, $badBomDir, $duplicateOne, $duplicateTwo -Force | Out-Null

try {
    $emptyOutput = & $powershellExe -NoProfile -File $validator -RootPath $emptyRoot 2>&1
    if ($LASTEXITCODE -ne 0 -or ($emptyOutput -join "`n") -notmatch '0 skill\(s\)') {
        throw "Empty tree check failed. Exit=$LASTEXITCODE Output=$($emptyOutput -join ' | ')"
    }
    Write-Host '[PASS] Empty skill tree returns success.'

    $longDescription = 'x' * 301
    $warningContent = "---`nname: long-description`ndescription: $longDescription`n---`n# Warning only`n"
    [IO.File]::WriteAllText((Join-Path $warningRoot 'long-description\SKILL.md'), $warningContent, [Text.UTF8Encoding]::new($false))
    $warningOutput = & $powershellExe -NoProfile -File $validator -RootPath $warningRoot 2>&1
    $joinedWarning = $warningOutput -join "`n"
    if ($LASTEXITCODE -ne 0 -or $joinedWarning -notmatch '\[WARN\].*300' -or $joinedWarning -notmatch 'Validation passed') {
        throw "Description warning check failed. Exit=$LASTEXITCODE Output=$joinedWarning"
    }
    Write-Host '[PASS] Description over 300 characters warns without failing validation.'

    $badSyntax = @'
---
name wrong-name
---
# Invalid frontmatter
'@
    [IO.File]::WriteAllText((Join-Path $badSyntaxDir 'SKILL.md'), $badSyntax, [Text.UTF8Encoding]::new($false))
    $badMeta = @'
---
name: another-name
---
# Invalid metadata
'@
    $longBody = "`n" + ((1..301 | ForEach-Object { "line $_" }) -join "`n")
    [IO.File]::WriteAllText((Join-Path $badMetaDir 'SKILL.md'), ($badMeta + $longBody), [Text.UTF8Encoding]::new($false))
    $bomContent = "---`nname: bad-bom`ndescription: Has UTF-8 BOM`n---`n# Bad encoding marker`n"
    [IO.File]::WriteAllText((Join-Path $badBomDir 'SKILL.md'), $bomContent, [Text.UTF8Encoding]::new($true))
    $duplicateContent = "---`nname: same-name`ndescription: Repeated skill name fixture`n---`n# Duplicate`n"
    [IO.File]::WriteAllText((Join-Path $duplicateOne 'SKILL.md'), $duplicateContent, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $duplicateTwo 'SKILL.md'), $duplicateContent, [Text.UTF8Encoding]::new($false))
    $invalidOutput = & $powershellExe -NoProfile -File $validator -RootPath $invalidRoot 2>&1
    $joinedOutput = $invalidOutput -join "`n"
    if ($LASTEXITCODE -eq 0 -or $joinedOutput -notmatch 'invalid frontmatter syntax' -or $joinedOutput -notmatch 'required frontmatter field ''description''' -or $joinedOutput -notmatch 'must match skill folder' -or $joinedOutput -notmatch 'body has' -or $joinedOutput -notmatch 'UTF-8 BOM' -or $joinedOutput -notmatch 'duplicate skill name') {
        throw "Invalid sample check failed. Exit=$LASTEXITCODE Output=$joinedOutput"
    }
    Write-Host '[PASS] Invalid samples report malformed frontmatter, missing description, folder/name mismatch, duplicate name, body length, and UTF-8 BOM.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
