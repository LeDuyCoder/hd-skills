[CmdletBinding()]
param(
    [Parameter()] [string] $RootPath = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
$files = Get-ChildItem -LiteralPath $RootPath -Filter '*.ps1' -File -Recurse
$failed = [System.Collections.Generic.List[string]]::new()
foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in @($parseErrors)) { $failed.Add("$($file.FullName): $($parseError.Message) at $($parseError.Extent.StartLineNumber)") }
}
if ($failed.Count -gt 0) { $failed | ForEach-Object { Write-Host "[ERROR] $_" }; exit 1 }
Write-Host "[PASS] All $($files.Count) PowerShell scripts parse."
