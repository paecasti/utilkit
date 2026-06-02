$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$CommandsPath = Join-Path $Root "commands"

$Command = $null
$RemainingArgs = @()

if ($args.Count -gt 0) {
    $Command = $args[0]
}

if ($args.Count -gt 1) {
    $RemainingArgs = @($args[1..($args.Count - 1)])
}

if ($env:UTILKIT_DEBUG -eq "1") {
    Write-Host "Command=[$Command]"
    Write-Host "RemainingArgs=[$($RemainingArgs -join '],[')]"
}

function Show-UtilKitHelp {
    Write-Host "UtilKit"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  utilkit <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  replace-secrets    Replace local tokens using an unversioned JSON file"
    Write-Host "  run-iso-report     Run ISO Report with -7 or -14"
    Write-Host "  help               Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  utilkit replace-secrets --config .\.local-secrets.json"
    Write-Host "  utilkit replace-secrets --what-if"
    Write-Host "  utilkit run-iso-report -7"
    Write-Host "  utilkit run-iso-report -14"
}

function Convert-UtilKitArgs {
    param([string[]]$InputArgs)

    $converted = @()
    $passthrough = $false

    foreach ($arg in $InputArgs) {
        if ($passthrough) {
            $converted += $arg
            continue
        }

        if ($arg -eq "--") {
            $converted += $arg
            $passthrough = $true
            continue
        }

        if ($arg.StartsWith("--")) {
            $converted += "-" + $arg.Substring(2)
            continue
        }

        $converted += $arg
    }

    return $converted
}

if ([string]::IsNullOrWhiteSpace($Command) -or $Command -in @("help", "-h", "--help")) {
    Show-UtilKitHelp
    exit 0
}

switch ($Command) {
    "replace-secrets" {
        & (Join-Path $CommandsPath "replace-secrets.ps1") @RemainingArgs
    }
    "run-iso-report" {
        & (Join-Path $CommandsPath "run-iso-report.ps1") @RemainingArgs
    }
    default {
        Write-Error "Unknown command: $Command. Run 'utilkit help' to see available commands."
    }
}
