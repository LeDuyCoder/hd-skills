[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RepoPath,

    [Parameter()]
    [string] $OutputRoot,

    [Parameter()]
    [string] $ProjectName,

    [Parameter()]
    [switch] $DetectOnly
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepoPath)
if (-not (Test-Path -LiteralPath $repo -PathType Container)) { throw "Repository does not exist: $repo" }
if ([string]::IsNullOrWhiteSpace($ProjectName)) { $ProjectName = Split-Path -Leaf $repo }
$slug = ($ProjectName.ToLowerInvariant() -replace '[^a-z0-9]+', '-') -replace '(^-|-$)', ''
if ([string]::IsNullOrWhiteSpace($slug)) { throw 'ProjectName must contain at least one ASCII letter or digit.' }

$detector = Join-Path $PSScriptRoot 'detect-stack.ps1'
$stackRows = @(& $detector -RepoPath $repo)
$stackLabels = @($stackRows | ForEach-Object { $_.Stack } | Where-Object { $_ -ne 'Unknown' } | Sort-Object -Unique)
if ($stackLabels.Count -eq 0) { $stackLabels = @('Unknown (no recognized manifest)') }
$manifestPaths = @($stackRows | Where-Object { $_.Manifest -ne 'No recognized manifest found' } | ForEach-Object { $_.Manifest })

if ($DetectOnly) {
    Write-Host "Project: $ProjectName ($slug)"
    Write-Host "Detected stack(s): $($stackLabels -join '; ')"
    Write-Host "Manifest(s): $(if ($manifestPaths.Count) { $manifestPaths -join ', ' } else { 'none' })"
    if (Test-Path -LiteralPath (Join-Path $repo 'package.json')) {
        $package = Get-Content -LiteralPath (Join-Path $repo 'package.json') -Raw | ConvertFrom-Json
        $scriptNames = @($package.scripts.PSObject.Properties.Name)
        Write-Host "Available package scripts: $(if ($scriptNames.Count) { $scriptNames -join ', ' } else { 'none' })"
    }
    exit 0
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = Join-Path $repo '.context' }
$vault = [IO.Path]::GetFullPath($OutputRoot)
$projectDir = Join-Path (Join-Path $vault 'projects') $slug
$moduleDir = Join-Path $projectDir 'modules'
$decisionDir = Join-Path $projectDir 'decisions'
$sessionDir = Join-Path $projectDir 'sessions'
$repoRelative = (Split-Path -Leaf $repo)
$date = Get-Date -Format 'yyyy-MM-dd'
$commit = 'unverified'
$gitRoot = (& git -C $repo rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
    $head = (& git -C $repo rev-parse HEAD 2>$null)
    $workingTree = @(& git -C $repo status --short --untracked-files=all -- . 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($head) -and $workingTree.Count -eq 0) { $commit = $head.Trim() }
}

$commands = [System.Collections.Generic.List[object]]::new()
$packagePath = Join-Path $repo 'package.json'
$description = "Repository notes generated from detected manifests and source layout for $ProjectName."
if (Test-Path -LiteralPath $packagePath -PathType Leaf) {
    $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
    if (-not [string]::IsNullOrWhiteSpace([string]$package.description)) { $description = [string]$package.description }
    $runner = 'npm run'
    if ([string]$package.packageManager -like 'pnpm@*' -or (Test-Path -LiteralPath (Join-Path $repo 'pnpm-lock.yaml'))) { $runner = 'pnpm run' }
    elseif ([string]$package.packageManager -like 'yarn@*' -or (Test-Path -LiteralPath (Join-Path $repo 'yarn.lock'))) { $runner = 'yarn' }
    elseif ([string]$package.packageManager -like 'bun@*' -or (Test-Path -LiteralPath (Join-Path $repo 'bun.lock')) -or (Test-Path -LiteralPath (Join-Path $repo 'bun.lockb'))) { $runner = 'bun run' }
    $scriptMap = @{ start = 'Run'; dev = 'Run'; test = 'Test'; lint = 'Lint'; typecheck = 'Type-check'; 'type-check' = 'Type-check'; build = 'Build' }
    foreach ($scriptName in $package.scripts.PSObject.Properties.Name) {
        if ($scriptMap.ContainsKey($scriptName)) {
            $commands.Add([pscustomobject]@{ Task = $scriptMap[$scriptName]; Command = "$runner $scriptName"; Source = 'package.json scripts and detected package manager' })
        }
    }
}

$sourceRoot = Join-Path $repo 'src'
$sourceExtensions = @('.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx', '.py', '.php', '.cs', '.go', '.java', '.kt', '.rs')
$sourceFiles = @()
if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
    $sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse | Where-Object { $_.Extension.ToLowerInvariant() -in $sourceExtensions } | Sort-Object FullName)
}
$moduleGroups = @()
if ($sourceFiles.Count -gt 0) {
    $moduleGroups = @($sourceFiles | Group-Object {
        $relative = $_.FullName.Substring($sourceRoot.TrimEnd('\').Length).TrimStart('\')
        $first = ($relative -split '[\\/]')[0]
        if ($first.Contains('.')) { 'src' } else { $first }
    } | Sort-Object Name)
}

New-Item -ItemType Directory -Path $moduleDir, $decisionDir, $sessionDir -Force | Out-Null
function Write-Utf8File([string] $Path, [string] $Text) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path -LiteralPath $Path) { throw "Refusing to overwrite existing note: $Path" }
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

$stackText = ($stackLabels | ForEach-Object { "- $_" }) -join "`n"
$manifestText = if ($manifestPaths.Count) { ($manifestPaths | ForEach-Object { "- ``$_``" }) -join "`n" } else { '- No recognized manifest found; inspect repository configuration manually.' }
$overviewPathYaml = if ($manifestPaths.Count) { ($manifestPaths | ForEach-Object { "  - ""$_""" }) -join "`n" } else { '  - README.md' }
$commandRows = if ($commands.Count) {
    ($commands | Sort-Object Task, Command | ForEach-Object { "| $($_.Task) | ``$($_.Command)`` | $($_.Source) |" }) -join "`n"
} else { '| — | No task commands were declared in a supported manifest. | No command was inferred. |' }
$moduleRows = if ($moduleGroups.Count) {
    ($moduleGroups | ForEach-Object { $moduleSlug = ($_.Name.ToLowerInvariant() -replace '[^a-z0-9]+', '-') -replace '(^-|-$)', ''; "| $($_.Name) | Bootstrap inventory; responsibility needs source review. | [[modules/$moduleSlug]] |" }) -join "`n"
} else { '| — | No source modules were detected under `src\`. | — |' }
$flowNodes = if ($moduleGroups.Count) { ($moduleGroups | ForEach-Object { $node = ($_.Name -replace '[^A-Za-z0-9_]', '_'); "    $node[$($_.Name)]" }) -join "`n" } else { '    Source[No src/ source files detected]' }
$stackSkillSlug = if ($stackLabels.Count -eq 1 -and $stackLabels[0] -like 'Node.js*') { 'node-project-workflows' } elseif ($stackLabels.Count -eq 1 -and $stackLabels[0] -like 'Python*') { 'python-project-workflows' } elseif ($stackLabels.Count -eq 1 -and $stackLabels[0] -like '.NET*') { 'dotnet-project-workflows' } elseif ($stackLabels.Count -eq 1 -and $stackLabels[0] -like 'Go*') { 'go-project-workflows' } else { 'project-stack-workflows' }

$overview = @"
---
project: $slug
module: overview
paths:
$overviewPathYaml
last_verified_commit: $commit
updated: $date
tags:
  - project
  - overview
summary: "$($description.Replace('"', "'"))"
---

# $ProjectName overview

## Purpose and status

$description

These notes were bootstrapped from repository manifests and file layout. Confirm behavior and commands against source before relying on them.

## Detected stack and manifests

$stackText

Manifest files:
$manifestText

## Windows prerequisites

- PowerShell 7 is the assumed shell for project automation in this skills pack.
- Runtime and tool versions were not inferred unless recorded in a manifest; verify them before setup.

## Commands

| Task | PowerShell command | Source / verification |
|---|---|---|
$commandRows

## Repository map

- Repository root: ``$repoRelative``
- Source inventory: $($sourceFiles.Count) supported-language source file(s) under ``src\``.
- Module inventory is linked from [[architecture]].

## Current constraints

- This first-pass note records detected metadata only. Inspect code and update responsibilities, runtime versions, and missing commands.
- No command absent from project manifests was invented.

## Stack-specific skill proposal

- Candidate name: ``$stackSkillSlug``.
- Trigger: changing this project's $($stackLabels -join ', ') code when its local setup or conventions matter.
- Scope: use commands declared by the project, verified module boundaries, and repository-specific conventions.
- Create ``<repo>\.agents\skills\$stackSkillSlug\`` only if source review finds stable conventions not already covered by shared skills. No project skill was generated automatically.

## Related notes

- Architecture: [[architecture]]
- Gotchas: [[gotchas]]
"@
Write-Utf8File (Join-Path $projectDir 'overview.md') $overview

$fence = ('`' * 3)
$architecture = @"
---
project: $slug
module: architecture
paths:
  - src/
last_verified_commit: $commit
updated: $date
tags:
  - project
  - architecture
summary: "First-pass component map for $ProjectName based on $($sourceFiles.Count) source file(s); verify data flow from code."
---

# $ProjectName architecture

## System boundary

Detected stack: $($stackLabels -join ', '). Entry points and external boundaries must be confirmed by reading the source and runtime configuration.

## Component map

__FENCE__mermaid
flowchart TD
    Project["$ProjectName"] --> SourceModules
    SourceModules["Source modules under src/"]
$flowNodes
__FENCE__

The diagram groups files by their first-level directory under ``src\``. It does not claim runtime call direction.

## Module inventory

| Module | Initial observation | Note |
|---|---|---|
$moduleRows

## Data flow and important paths

Not established by manifest/file-name scanning. Trace the entry point and side effects before adding arrows or documenting runtime behavior.
"@
$architecture = $architecture.Replace('__FENCE__', $fence)
Write-Utf8File (Join-Path $projectDir 'architecture.md') $architecture

foreach ($group in $moduleGroups) {
    $moduleSlug = ($group.Name.ToLowerInvariant() -replace '[^a-z0-9]+', '-') -replace '(^-|-$)', ''
    $paths = foreach ($file in $group.Group) { $file.FullName.Substring($repo.TrimEnd('\').Length).TrimStart('\').Replace('\', '/') }
    $pathYaml = ($paths | ForEach-Object { "  - ""$_""" }) -join "`n"
    $fileList = ($paths | ForEach-Object { "- ``$_``" }) -join "`n"
    $moduleNote = @"
---
project: $slug
module: $moduleSlug
paths:
$pathYaml
last_verified_commit: $commit
updated: $date
tags:
  - project
  - module
summary: "Bootstrap inventory for $($group.Name): $($group.Count) source file(s); behavior has not yet been inspected."
---

# $($group.Name) module

## Responsibility

This note records file placement only. Read the listed files and replace this statement with the module's actual responsibility.

## Files found

$fileList

## Public API, side effects, and dependencies

Not established by filename scanning. Verify exports, callers, and external dependencies from source.
"@
    Write-Utf8File (Join-Path $moduleDir "$moduleSlug.md") $moduleNote
}

$gotchas = @"
---
project: $slug
module: gotchas
paths:
  - package.json
last_verified_commit: $commit
updated: $date
tags:
  - project
  - gotchas
summary: "No project-specific traps have been verified yet; add only reproducible issues with evidence."
---

# $ProjectName gotchas

No project-specific gotchas have been verified during manifest scanning. Add an entry only after reproducing a trap and confirming its fix.
"@
Write-Utf8File (Join-Path $projectDir 'gotchas.md') $gotchas

$decisionsIndex = @"
# Decisions

No architectural decision has been recorded by bootstrap. Add a numbered ADR when a consequential choice is made, including the context, selected option, alternatives, and consequences.
"@
Write-Utf8File (Join-Path $decisionDir 'README.md') $decisionsIndex

$session = @"
---
project: $slug
module: session
paths:
  - package.json
last_verified_commit: $commit
updated: $date
tags:
  - project
  - session
summary: "Bootstrap generated an initial repository map for $ProjectName."
---

# Session $date — context bootstrap

## Goal and result

Detected $($stackLabels -join ', ') and generated first-pass project notes from manifests and the ``src\`` file inventory.

## Files and verification

- Repository: ``$repo``
- Source files counted under ``src\``: $($sourceFiles.Count)
- The generated notes are structural and require source review before they can be treated as verified behavior.

## Decisions and open issues

- No architectural decisions were inferred.
- Confirm runtime versions, entry points, data flow, and commands not declared in manifests.

## Next action

Read ``overview.md`` and inspect the listed source modules, then replace bootstrap observations with verified responsibilities and APIs.
"@
Write-Utf8File (Join-Path $sessionDir "$date.md") $session

$indexPath = Join-Path $vault '00-INDEX.md'
if (-not (Test-Path -LiteralPath $indexPath)) {
    $index = @"
---
project: index
module: all
paths:
  - projects/
last_verified_commit: $commit
updated: $date
tags:
  - context
  - index
summary: "Project map generated by context-bootstrap."
---

# Project index

## Projects

- [[projects/$slug/overview|$ProjectName]] — $description
"@
    Write-Utf8File $indexPath $index
}
else {
    $existingIndex = [IO.File]::ReadAllText($indexPath, [Text.UTF8Encoding]::new($false, $true))
    if ($existingIndex -notmatch [regex]::Escape("projects/$slug/overview")) {
        $indexLine = "- [[projects/$slug/overview|$ProjectName]] - $description"
        $updatedIndex = $existingIndex.TrimEnd() + [Environment]::NewLine + $indexLine + [Environment]::NewLine
        [IO.File]::WriteAllText($indexPath, $updatedIndex, [Text.UTF8Encoding]::new($false))
    }
}

Write-Host "Bootstrap complete: $projectDir"
Write-Host "Detected stack(s): $($stackLabels -join '; ')"
Write-Host "Source files inventoried: $($sourceFiles.Count)"
Write-Host 'Generated overview, architecture, module inventory, gotchas, decisions index, and session note.'
