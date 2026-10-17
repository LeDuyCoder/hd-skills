[CmdletBinding()]
param(
    [Parameter()] [string] $RepoRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepoRoot)
$profileRoot = [Environment]::GetEnvironmentVariable('USERPROFILE')
if ([string]::IsNullOrWhiteSpace($profileRoot)) { $profileRoot = [Environment]::GetFolderPath('UserProfile') }
$statePath = Join-Path $profileRoot '.hd-skill\install-state.json'
$checks = [System.Collections.Generic.List[object]]::new()
function Add-Check([string] $Name, [string] $Status, [string] $Detail, [string] $Fix = '') {
    $checks.Add([pscustomobject]@{ Check = $Name; Status = $Status; Detail = $Detail; Fix = $Fix })
}
function Get-HashHex([string] $Path) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($algorithm.ComputeHash([IO.File]::ReadAllBytes($Path))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}

$state = $null
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    try { $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
    catch { Add-Check 'Install state' 'FAIL' $_.Exception.Message 'Run uninstall.ps1 -Apply, then install.ps1 -Apply.' }
}
else { Add-Check 'Install state' 'WARN' 'No managed installation state was found.' 'Run install.ps1 -Apply.' }

$resolved = $null
try {
    $resolved = (& (Join-Path $repo 'scripts\Resolve-HdSkillConfig.ps1') -RepoRoot $repo -NonInteractive | ConvertFrom-Json -ErrorAction Stop)
    $machineConfig = Get-Content -LiteralPath $resolved.configPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $required = @('schemaVersion', 'vaultName', 'vaultPath', 'contextMode', 'agents', 'machineId', 'projects', 'mcpEnabled')
    $missing = @($required | Where-Object { -not ($machineConfig.PSObject.Properties.Name -contains $_) })
    $allowedKeys = $required + @('hdSkillHome')
    $unknown = @($machineConfig.PSObject.Properties.Name | Where-Object { $_ -notin $allowedKeys })
    $projectValuesValid = $true
    foreach ($projectProperty in $machineConfig.projects.PSObject.Properties) { if ($projectProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($projectProperty.Value)) { $projectValuesValid = $false } }
    $validTypes = ($machineConfig.vaultName -is [string] -and -not [string]::IsNullOrWhiteSpace($machineConfig.vaultName)) -and
        (($null -eq $machineConfig.vaultPath) -or $machineConfig.vaultPath -is [string]) -and
        ($machineConfig.contextMode -in @('vault', 'repo')) -and
        ($machineConfig.agents.codex -is [bool] -and $machineConfig.agents.antigravity -is [bool]) -and
        ($machineConfig.machineId -is [string] -and $machineConfig.machineId -match '^[A-Za-z0-9][A-Za-z0-9_-]{1,31}$') -and
        ($machineConfig.projects -is [pscustomobject] -and $projectValuesValid) -and
        ($machineConfig.mcpEnabled -is [bool])
    if ($machineConfig.schemaVersion -eq 1 -and $missing.Count -eq 0 -and $unknown.Count -eq 0 -and $validTypes) { Add-Check 'Configuration' 'PASS' "Valid v1 machine config at $($resolved.configPath)." }
    else { Add-Check 'Configuration' 'FAIL' "Invalid machine config; missing fields: $($missing -join ', ')." 'Repair the file using config.schema.json and config.defaults.json.' }
}
catch { Add-Check 'Configuration' 'FAIL' $_.Exception.Message 'Run install.ps1 -Apply to generate the machine config, or repair the JSON file.' }

if ($resolved) {
    if ($resolved.contextMode -eq 'vault') {
        if (Test-Path -LiteralPath $resolved.vaultPath -PathType Container) { Add-Check 'Vault access' 'PASS' "Configured vault is accessible: $($resolved.vaultPath)" }
        else { Add-Check 'Vault access' 'FAIL' "Configured vault cannot be accessed: $($resolved.vaultPath)" 'Set HD_SKILL_VAULT to the current vault folder or use the repository fallback.' }
    }
    else { Add-Check 'Vault access' 'PASS' "Repository context fallback is selected: $($resolved.vaultPath) (created on first context write)." }
}

if ($state) {
    $linksOk = $true
    foreach ($entry in @($state.skills)) {
        if (-not (Test-Path -LiteralPath $entry.target)) { $linksOk = $false; Add-Check "Skill $($entry.agent)/$($entry.name)" 'FAIL' "Installed path is missing: $($entry.target)" 'Run install.ps1 -Apply with the saved mode.'; continue }
        if ($entry.mode -eq 'Junction') {
            $item = Get-Item -LiteralPath $entry.target -Force
            $targetValue = $null
            if ($item.PSObject.Properties.Name -contains 'Target') { $targetValue = [string]$item.Target }
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0 -or ($targetValue -and [IO.Path]::GetFullPath($targetValue) -ne [IO.Path]::GetFullPath($entry.source))) {
                $linksOk = $false
                Add-Check "Skill $($entry.agent)/$($entry.name)" 'FAIL' 'Junction is missing or points away from the managed source.' 'Run uninstall.ps1 -Apply, then install.ps1 -Mode Junction -Apply.'
            }
            else { Add-Check "Skill $($entry.agent)/$($entry.name)" 'PASS' "Junction resolves to the hd-skill source ($($entry.target))." }
        }
        else {
            $mismatch = @($entry.files | Where-Object { -not (Test-Path -LiteralPath (Join-Path $entry.target $_.path) -PathType Leaf) -or (Get-HashHex (Join-Path $entry.target $_.path)) -ne $_.hash })
            if ($mismatch.Count -gt 0) { $linksOk = $false; Add-Check "Skill $($entry.agent)/$($entry.name)" 'FAIL' "$($mismatch.Count) copied file(s) differ from the managed manifest." 'Run install.ps1 -Mode Copy -Apply to refresh managed copies.' }
            else { Add-Check "Skill $($entry.agent)/$($entry.name)" 'PASS' 'All managed copy files match the manifest.' }
        }
    }
    foreach ($agentName in @('codex', 'antigravity')) {
        $agentInstalled = [bool]$resolved.agents.$agentName
        if (-not $agentInstalled) { Add-Check "$agentName visibility" 'SKIP' 'Agent is not installed on this machine.'; continue }
        $entries = @($state.skills | Where-Object { $_.agent -eq $agentName })
        if ($entries.Count -gt 0 -and @($entries | Where-Object { Test-Path -LiteralPath $_.target }).Count -eq $entries.Count) { Add-Check "$agentName visibility" 'PASS' "$($entries.Count) shared skills are present in the detected skill directory." }
        else { Add-Check "$agentName visibility" 'FAIL' 'One or more skills are missing from the detected agent directory.' 'Run install.ps1 -Apply.' }
    }
    if ($machineConfig.mcpEnabled) {
        $npx = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
        if (-not $npx) { $npx = Get-Command npx -ErrorAction SilentlyContinue }
        if (-not $npx) { Add-Check 'MCP startup' 'FAIL' 'npx is unavailable.' 'Install Node.js LTS manually and run doctor.ps1 again.' }
        else {
            $startupError = Join-Path ([IO.Path]::GetTempPath()) ('hd-skill-mcp-' + [guid]::NewGuid().ToString('N') + '.err')
            try {
                $argsText = '-y @modelcontextprotocol/server-filesystem@1.0.0 "' + $resolved.vaultPath.Replace('"', '\"') + '"'
                $process = Start-Process -FilePath $npx.Source -ArgumentList $argsText -WindowStyle Hidden -PassThru -RedirectStandardError $startupError
                Start-Sleep -Seconds 3
                if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force; Add-Check 'MCP startup' 'PASS' 'Pinned filesystem server stayed alive during its startup probe.' }
                else { $errorText = if (Test-Path -LiteralPath $startupError) { Get-Content -LiteralPath $startupError -Raw } else { "Exit code $($process.ExitCode)" }; Add-Check 'MCP startup' 'FAIL' $errorText 'Check Node.js, the pinned package, and the configured vault path.' }
            }
            catch { Add-Check 'MCP startup' 'FAIL' $_.Exception.Message 'Check Node.js, network access, and the MCP config entry.' }
            finally { if (Test-Path -LiteralPath $startupError) { Remove-Item -LiteralPath $startupError -Force } }
        }
    }
    else { Add-Check 'MCP startup' 'SKIP' 'MCP is disabled; native file tools are the default.' }
}

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCommand) { Add-Check 'Repository version' 'FAIL' 'Git is unavailable.' 'Install Git for Windows and retry.' }
else {
    $head = (& git -C $repo rev-parse --short HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { Add-Check 'Repository version' 'FAIL' 'The source folder is not a Git repository.' 'Clone hd-skill with Git or pass the repository root.' }
    else {
        $remote = $null
        try { $remote = (& git -C $repo remote get-url origin 2>$null) } catch { $remote = $null }
        if ($remote) {
            $remoteHead = (& git -C $repo ls-remote origin HEAD 2>$null)
            if ($LASTEXITCODE -eq 0 -and $remoteHead) { Add-Check 'Repository version' 'PASS' "Local $($head.Trim()); remote origin is reachable." }
            else { Add-Check 'Repository version' 'WARN' "Local $($head.Trim()); remote origin could not be queried." 'Check network access and the Git origin URL.' }
        }
        else { Add-Check 'Repository version' 'WARN' "Local $($head.Trim()); no origin remote is configured." 'Set origin to the shared hd-skill Git repository to compare remote revisions.' }
    }
}

$checks | Format-Table -Property Check, Status, Detail, Fix -Wrap -AutoSize
$failed = @($checks | Where-Object Status -eq 'FAIL')
if ($failed.Count -gt 0) { exit 1 }
exit 0
