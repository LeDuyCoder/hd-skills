[CmdletBinding()]
param(
    [Parameter()]
    [string] $RootPath = (Join-Path $PSScriptRoot '..\skills')
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = [IO.Path]::GetFullPath($RootPath)
if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
    Write-Host "[ERROR] Skill root does not exist: $resolvedRoot"
    exit 1
}

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$seenNames = @{}
$utf8Strict = [Text.UTF8Encoding]::new($false, $true)
$skillFiles = @(Get-ChildItem -LiteralPath $resolvedRoot -Filter 'SKILL.md' -File -Recurse | Sort-Object FullName)

foreach ($file in $skillFiles) {
    $relativePath = $file.FullName.Substring($resolvedRoot.TrimEnd('\').Length).TrimStart('\')
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $errors.Add("${relativePath}: UTF-8 BOM is not allowed")
        continue
    }

    try {
        $content = $utf8Strict.GetString($bytes)
    }
    catch [Text.DecoderFallbackException] {
        $errors.Add("${relativePath}: file is not valid UTF-8")
        continue
    }

    $lines = [regex]::Split($content, "`r`n|`n|`r")
    if ($lines.Count -lt 3 -or $lines[0] -ne '---') {
        $errors.Add("${relativePath}: frontmatter must start on line 1 with ---")
        continue
    }

    $closingIndex = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq '---') { $closingIndex = $i; break }
    }
    if ($closingIndex -lt 0) {
        $errors.Add("${relativePath}: frontmatter closing --- is missing")
        continue
    }

    $fields = @{}
    $frontmatterValid = $true
    for ($i = 1; $i -lt $closingIndex; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch '^([A-Za-z][A-Za-z0-9_-]*):(?:\s+(.*))?$') {
            $errors.Add("${relativePath}: invalid frontmatter syntax on line $($i + 1)")
            $frontmatterValid = $false
            continue
        }
        $key = $Matches[1]
        $value = if ($null -eq $Matches[2]) { '' } else { $Matches[2].Trim() }
        if ($key -notin @('name', 'description')) {
            $errors.Add("${relativePath}: unsupported frontmatter field '$key'; portable skills use only name and description")
            $frontmatterValid = $false
            continue
        }
        if ($fields.ContainsKey($key)) {
            $errors.Add("${relativePath}: duplicate frontmatter key '$key'")
            $frontmatterValid = $false
            continue
        }
        if (($value.StartsWith('"') -and -not $value.EndsWith('"')) -or ($value.StartsWith("'") -and -not $value.EndsWith("'"))) {
            $errors.Add("${relativePath}: unclosed quoted scalar for frontmatter field '$key'")
            $frontmatterValid = $false
            continue
        }
        if ($value.StartsWith('[') -or $value.StartsWith('{') -or $value -in @('|', '>', '|-', '>-')) {
            $errors.Add("${relativePath}: frontmatter field '$key' must use a plain or quoted scalar")
            $frontmatterValid = $false
            continue
        }
        if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $fields[$key] = $value
    }
    if (-not $frontmatterValid) { continue }

    foreach ($required in @('name', 'description')) {
        if (-not $fields.ContainsKey($required) -or [string]::IsNullOrWhiteSpace([string]$fields[$required])) {
            $errors.Add("${relativePath}: required frontmatter field '$required' is missing or empty")
        }
    }
    if (-not $fields.ContainsKey('name') -or [string]::IsNullOrWhiteSpace([string]$fields['name'])) { continue }

    $skillName = [string]$fields['name']
    $folderName = Split-Path -Leaf $file.DirectoryName
    if ($skillName -cne $folderName) {
        $errors.Add("${relativePath}: name '$skillName' must match skill folder '$folderName'")
    }
    if ($seenNames.ContainsKey($skillName)) {
        $errors.Add("${relativePath}: duplicate skill name '$skillName' (also in $($seenNames[$skillName]))")
    }
    else {
        $seenNames[$skillName] = $relativePath
    }

    if ($fields.ContainsKey('description')) {
        $descriptionLength = ([string]$fields['description']).Length
        if ($descriptionLength -gt 300) {
            $warnings.Add("${relativePath}: description is $descriptionLength characters; internal target is at most 300")
        }
    }

    $bodyLineCount = [Math]::Max(0, $lines.Count - $closingIndex - 1)
    if (($content.EndsWith("`n") -or $content.EndsWith("`r")) -and $bodyLineCount -gt 0 -and $lines[-1] -eq '') {
        $bodyLineCount--
    }
    if ($bodyLineCount -gt 300) {
        $errors.Add("${relativePath}: skill body has $bodyLineCount lines; maximum is 300")
    }
}

function Test-JsonValueAgainstSchema {
    param(
        [Parameter(Mandatory)] [AllowNull()] [object] $Value,
        [Parameter(Mandatory)] [object] $Schema,
        [Parameter(Mandatory)] [string] $Location,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[string]] $ValidationErrors
    )

    $expectedTypes = @($Schema.type)
    $actualType = if ($null -eq $Value) { 'null' }
        elseif ($Value -is [string]) { 'string' }
        elseif ($Value -is [bool]) { 'boolean' }
        elseif ($Value -is [System.Collections.IDictionary] -or $Value -is [pscustomobject]) { 'object' }
        elseif ($Value -is [System.Array]) { 'array' }
        elseif ($Value -is [int] -or $Value -is [long]) { 'integer' }
        elseif ($Value -is [ValueType]) { 'number' }
        else { 'unknown' }

    if ($expectedTypes.Count -gt 0 -and $actualType -notin $expectedTypes) {
        $ValidationErrors.Add("${Location}: expected type $($expectedTypes -join ' or '), received $actualType")
        return
    }
    if ($Schema.PSObject.Properties.Name -contains 'const' -and $Value -cne $Schema.const) {
        $ValidationErrors.Add("${Location}: value must equal '$($Schema.const)'")
    }
    if ($Schema.PSObject.Properties.Name -contains 'enum' -and $Value -notin @($Schema.enum)) {
        $ValidationErrors.Add("${Location}: value must be one of [$(@($Schema.enum) -join ', ')]")
    }
    if ($actualType -eq 'string') {
        if ($Schema.minLength -and $Value.Length -lt $Schema.minLength) {
            $ValidationErrors.Add("${Location}: string is shorter than minLength $($Schema.minLength)")
        }
        if ($Schema.pattern -and $Value -notmatch $Schema.pattern) {
            $ValidationErrors.Add("${Location}: string does not match pattern '$($Schema.pattern)'")
        }
        return
    }
    if ($actualType -ne 'object') { return }

    $valueProperties = @{}
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) { $valueProperties[[string]$key] = $Value[$key] }
    }
    else {
        foreach ($property in $Value.PSObject.Properties) { $valueProperties[$property.Name] = $property.Value }
    }

    $requiredNames = @()
    if ($Schema.PSObject.Properties.Name -contains 'required') { $requiredNames = @($Schema.required) }
    foreach ($requiredName in $requiredNames) {
        if (-not $valueProperties.ContainsKey([string]$requiredName)) {
            $ValidationErrors.Add("${Location}: required property '$requiredName' is missing")
        }
    }
    $knownProperties = @{}
    if ($Schema.properties) {
        foreach ($property in $Schema.properties.PSObject.Properties) {
            $knownProperties[$property.Name] = $property.Value
            if ($valueProperties.ContainsKey($property.Name)) {
                Test-JsonValueAgainstSchema -Value $valueProperties[$property.Name] -Schema $property.Value -Location "$Location.$($property.Name)" -ValidationErrors $ValidationErrors
            }
        }
    }
    foreach ($key in $valueProperties.Keys) {
        if ($knownProperties.ContainsKey($key)) { continue }
        if ($Schema.additionalProperties -is [bool] -and -not $Schema.additionalProperties) {
            $ValidationErrors.Add("${Location}: additional property '$key' is not allowed")
        }
        elseif ($Schema.additionalProperties -is [pscustomobject]) {
            Test-JsonValueAgainstSchema -Value $valueProperties[$key] -Schema $Schema.additionalProperties -Location "$Location.$key" -ValidationErrors $ValidationErrors
        }
    }
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$schemaPath = Join-Path $repositoryRoot 'config.schema.json'
$defaultsPath = Join-Path $repositoryRoot 'config.defaults.json'
foreach ($requiredConfigFile in @($schemaPath, $defaultsPath)) {
    if (-not (Test-Path -LiteralPath $requiredConfigFile -PathType Leaf)) {
        $errors.Add("$(Split-Path -Leaf $requiredConfigFile): required configuration file is missing")
    }
}
if ((Test-Path -LiteralPath $schemaPath -PathType Leaf) -and (Test-Path -LiteralPath $defaultsPath -PathType Leaf)) {
    try {
        $schemaBytes = [IO.File]::ReadAllBytes($schemaPath)
        $defaultsBytes = [IO.File]::ReadAllBytes($defaultsPath)
        foreach ($item in @(@{ Name = 'config.schema.json'; Bytes = $schemaBytes }, @{ Name = 'config.defaults.json'; Bytes = $defaultsBytes })) {
            if ($item.Bytes.Length -ge 3 -and $item.Bytes[0] -eq 0xEF -and $item.Bytes[1] -eq 0xBB -and $item.Bytes[2] -eq 0xBF) {
                $errors.Add("$($item.Name): UTF-8 BOM is not allowed")
            }
            [void]$utf8Strict.GetString($item.Bytes)
        }
        $schema = [Text.Encoding]::UTF8.GetString($schemaBytes) | ConvertFrom-Json -ErrorAction Stop
        $defaults = [Text.Encoding]::UTF8.GetString($defaultsBytes) | ConvertFrom-Json -ErrorAction Stop
        if ($schema.'$schema' -ne 'https://json-schema.org/draft/2020-12/schema' -or $schema.type -ne 'object' -or -not $schema.properties) {
            $errors.Add('config.schema.json: expected a JSON Schema object with a supported draft and properties')
        }
        Test-JsonValueAgainstSchema -Value $defaults -Schema $schema -Location 'config.defaults.json' -ValidationErrors $errors
    }
    catch {
        $errors.Add("Configuration JSON validation failed: $($_.Exception.Message)")
    }
}

foreach ($warning in $warnings) { Write-Host "[WARN] $warning" }
foreach ($errorMessage in $errors) { Write-Host "[ERROR] $errorMessage" }
if ($errors.Count -gt 0) {
    Write-Host "Validation failed: $($errors.Count) error(s), $($warnings.Count) warning(s)."
    exit 1
}
Write-Host "Validation passed: $($skillFiles.Count) skill(s), config schema/defaults valid, $($warnings.Count) warning(s)."
exit 0
