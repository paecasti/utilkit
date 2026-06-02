$ErrorActionPreference = "Stop"

$Config = ".\.local-secrets.json"
$WhatIf = $false
$Root = "."
$DefaultPatterns = @("appsettings*.json", "web.config", "web.*.config")
$ExcludedDirectories = @(".git", ".vs", "bin", "obj", "node_modules", "packages")

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        { $_ -in @("-Config", "--config", "-config") } {
            $i++
            if ($i -ge $args.Count) {
                Write-Error "Missing value for --config."
            }
            $Config = $args[$i]
        }
        { $_ -in @("-WhatIf", "--what-if", "-what-if") } {
            $WhatIf = $true
        }
        { $_ -in @("-Root", "--root", "-root") } {
            $i++
            if ($i -ge $args.Count) {
                Write-Error "Missing value for --root."
            }
            $Root = $args[$i]
        }
        default {
            Write-Error "Unknown option for replace-secrets: $($args[$i])"
        }
    }
}

function Resolve-UtilKitPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path (Get-Location) $Path
}

function Get-UtilKitReplacementMap {
    param(
        [hashtable]$GlobalReplacements,
        [object]$FileEntry
    )

    $replacements = @{}
    foreach ($key in $GlobalReplacements.Keys) {
        $replacements[$key] = $GlobalReplacements[$key]
    }

    if ($FileEntry -and $FileEntry.replacements) {
        $FileEntry.replacements.PSObject.Properties | ForEach-Object {
            $replacements[$_.Name] = [string]$_.Value
        }
    }

    return $replacements
}

function Add-UtilKitSecretReplacements {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Target,
        [object]$Secrets
    )

    if (-not $Secrets) {
        return
    }

    if ($Secrets -is [array]) {
        foreach ($secret in $Secrets) {
            if (-not $secret.value) {
                Write-Error "Each secret in 'secrets' must include 'value'."
            }

            $token = $secret.token
            if ([string]::IsNullOrWhiteSpace($token)) {
                if ([string]::IsNullOrWhiteSpace($secret.name)) {
                    Write-Error "Each secret in 'secrets' must include 'name' or 'token'."
                }

                $token = "{{" + $secret.name + "}}"
            }

            $Target[$token] = [string]$secret.value
        }

        return
    }

    $Secrets.PSObject.Properties | ForEach-Object {
        $token = $_.Name
        if (-not ($token.StartsWith("{{") -and $token.EndsWith("}}"))) {
            $token = "{{" + $token + "}}"
        }

        $Target[$token] = [string]$_.Value
    }
}

function Test-UtilKitExcludedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string[]]$ExcludedNames
    )

    $separatorPattern = "[\\/]"
    foreach ($name in $ExcludedNames) {
        if ($Path -match "(^|$separatorPattern)$([regex]::Escape($name))($separatorPattern|$)") {
            return $true
        }
    }

    return $false
}

function Find-UtilKitDefaultFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [string[]]$Patterns,
        [string[]]$ExcludedNames
    )

    $found = @()
    foreach ($pattern in $Patterns) {
        $found += Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-UtilKitExcludedPath -Path $_.FullName -ExcludedNames $ExcludedNames) }
    }

    return $found |
        Sort-Object FullName -Unique |
        ForEach-Object {
            [pscustomobject]@{
                path = $_.FullName
            }
        }
}

$configPath = Resolve-UtilKitPath $Config
$rootPath = Resolve-UtilKitPath $Root

if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Error "Configuration file does not exist: $configPath"
}

if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
    Write-Error "Root directory does not exist: $rootPath"
}

$configJson = Get-Content -LiteralPath $configPath -Raw
$configData = $configJson | ConvertFrom-Json

$globalReplacements = @{}
if ($configData.replacements) {
    $configData.replacements.PSObject.Properties | ForEach-Object {
        $globalReplacements[$_.Name] = [string]$_.Value
    }
}
Add-UtilKitSecretReplacements -Target $globalReplacements -Secrets $configData.secrets

if ($globalReplacements.Count -eq 0) {
    Write-Error "The configuration file must include secrets in 'secrets' or replacements in 'replacements'."
}

$files = @()
if ($configData.files) {
    $files = @($configData.files)
} else {
    $files = @(Find-UtilKitDefaultFiles -RootPath $rootPath -Patterns $DefaultPatterns -ExcludedNames $ExcludedDirectories)
}

if ($files.Count -eq 0) {
    Write-Warning "No appsettings*.json, web.config, or web.*.config files were found under $rootPath"
}

$changedFiles = 0

foreach ($fileEntry in $files) {
    if (-not $fileEntry.path) {
        Write-Error "Each entry in 'files' must include 'path'."
    }

    $targetPath = Resolve-UtilKitPath $fileEntry.path
    if (-not (Test-Path -LiteralPath $targetPath)) {
        Write-Error "Target file does not exist: $targetPath"
    }

    $replacements = Get-UtilKitReplacementMap -GlobalReplacements $globalReplacements -FileEntry $fileEntry

    if ($replacements.Count -eq 0) {
        Write-Warning "No replacements for $targetPath"
        continue
    }

    $originalContent = [System.IO.File]::ReadAllText($targetPath)
    $newContent = $originalContent

    foreach ($token in $replacements.Keys) {
        $newContent = $newContent.Replace($token, $replacements[$token])
    }

    if ($newContent -eq $originalContent) {
        Write-Host "No changes: $targetPath"
        continue
    }

    $changedFiles++
    if ($WhatIf) {
        Write-Host "Pending changes: $targetPath"
        continue
    }

    [System.IO.File]::WriteAllText($targetPath, $newContent)
    Write-Host "Updated: $targetPath"
}

if ($WhatIf) {
    Write-Host "Files that would change: $changedFiles"
} else {
    Write-Host "Updated files: $changedFiles"
}
