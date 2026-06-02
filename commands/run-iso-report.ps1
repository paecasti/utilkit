$ErrorActionPreference = "Stop"

$Config = ".\.iso-report.local.json"
$Path = $null
$Mode = $null
$DryRun = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]

    switch ($arg) {
        { $_ -in @("-7", "--7") } {
            $Mode = "-7"
        }
        { $_ -in @("-14", "--14") } {
            $Mode = "-14"
        }
        { $_ -in @("-Config", "--config", "-config") } {
            $i++
            if ($i -ge $args.Count) {
                Write-Error "Missing value for --config."
            }
            $Config = $args[$i]
        }
        { $_ -in @("-Path", "--path", "-path") } {
            $i++
            if ($i -ge $args.Count) {
                Write-Error "Missing value for --path."
            }
            $Path = $args[$i]
        }
        { $_ -in @("-DryRun", "--dry-run", "-dry-run") } {
            $DryRun = $true
        }
        default {
            Write-Error "Unknown option for run-iso-report: $arg"
        }
    }
}

function Resolve-UtilKitPath {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ([System.IO.Path]::IsPathRooted($Value)) {
        return $Value
    }

    return Join-Path (Get-Location) $Value
}

$configPath = Resolve-UtilKitPath $Config

if (Test-Path -LiteralPath $configPath) {
    $configData = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($Path) -and $configData.path) {
        $Path = [string]$configData.path
    }

    if ([string]::IsNullOrWhiteSpace($Mode) -and $configData.defaultMode) {
        $configuredMode = [string]$configData.defaultMode
        if ($configuredMode -notin @("-7", "-14")) {
            Write-Error "defaultMode must be '-7' or '-14'."
        }
        $Mode = $configuredMode
    }
}

if ([string]::IsNullOrWhiteSpace($Path)) {
    Write-Error "Missing ISO Report path. Set it in .iso-report.local.json or pass --path."
}

if ([string]::IsNullOrWhiteSpace($Mode)) {
    Write-Error "Missing ISO Report mode. Use -7 or -14."
}

$reportPath = Resolve-UtilKitPath $Path
if (-not (Test-Path -LiteralPath $reportPath -PathType Container)) {
    Write-Error "ISO Report path does not exist: $reportPath"
}

$dotnetArgs = @("run", $Mode)

Write-Host "Working directory: $reportPath"
Write-Host "dotnet $($dotnetArgs -join ' ')"

if ($DryRun) {
    exit 0
}

Push-Location $reportPath
try {
    & dotnet @dotnetArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
