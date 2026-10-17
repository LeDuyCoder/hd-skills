[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RepoPath
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepoPath)
if (-not (Test-Path -LiteralPath $repo -PathType Container)) { throw "Repository does not exist: $repo" }

$checks = @(
    @{ File = 'package.json'; Label = 'Node.js / JavaScript or TypeScript' },
    @{ File = 'composer.json'; Label = 'PHP / Composer' },
    @{ File = 'pyproject.toml'; Label = 'Python / pyproject.toml' },
    @{ File = 'requirements.txt'; Label = 'Python / pip requirements' },
    @{ File = 'go.mod'; Label = 'Go' },
    @{ File = 'Cargo.toml'; Label = 'Rust / Cargo' },
    @{ File = 'mix.exs'; Label = 'Elixir / Mix' },
    @{ File = 'Gemfile'; Label = 'Ruby / Bundler' },
    @{ File = 'pom.xml'; Label = 'Java / Maven' },
    @{ File = 'build.gradle'; Label = 'JVM / Gradle' },
    @{ File = 'build.gradle.kts'; Label = 'JVM / Gradle Kotlin DSL' }
)
$results = [System.Collections.Generic.List[object]]::new()
foreach ($check in $checks) {
    $path = Join-Path $repo $check.File
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $results.Add([pscustomobject]@{ Stack = $check.Label; Manifest = $check.File })
    }
}
$csprojFiles = @(Get-ChildItem -LiteralPath $repo -Filter '*.csproj' -File -Recurse -ErrorAction SilentlyContinue)
if ($csprojFiles.Count -gt 0) {
    foreach ($file in $csprojFiles) {
        $relative = $file.FullName.Substring($repo.TrimEnd('\').Length).TrimStart('\')
        $results.Add([pscustomobject]@{ Stack = '.NET / C#'; Manifest = $relative })
    }
}
if ($results.Count -eq 0) {
    [pscustomobject]@{ Stack = 'Unknown'; Manifest = 'No recognized manifest found' }
}
else {
    $results | Sort-Object Stack, Manifest
}
