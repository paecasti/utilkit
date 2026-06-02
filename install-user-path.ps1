param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$binPath = Join-Path $repoRoot "bin"

if (-not (Test-Path -LiteralPath (Join-Path $binPath "utilkit.cmd"))) {
    Write-Error "Could not find bin\utilkit.cmd under $repoRoot"
}

$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathItems = @()

if (-not [string]::IsNullOrWhiteSpace($currentUserPath)) {
    $pathItems = $currentUserPath -split ";" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$alreadyInstalled = $pathItems | Where-Object { $_.TrimEnd("\") -ieq $binPath.TrimEnd("\") }

if ($alreadyInstalled -and -not $Force) {
    Write-Host "UtilKit is already in the user PATH:"
    Write-Host "  $binPath"
    exit 0
}

if (-not $alreadyInstalled) {
    $pathItems += $binPath
    $newUserPath = ($pathItems -join ";")
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
}

Write-Host "UtilKit installed in the user PATH:"
Write-Host "  $binPath"
Write-Host ""
Write-Host "Open a new terminal and run:"
Write-Host "  utilkit help"
