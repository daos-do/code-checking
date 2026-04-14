# Copyright 2026 Hewlett Packard Enterprise Development LP
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "[check] verifying required paths"
$requiredPaths = @(
    'README.md',
    'LICENSE',
    'bin/run-checks.sh',
    'checks/pre-commit_d',
    'ide/reference/recommended_settings.yml'
)

foreach ($path in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required path: $path"
    }
}

Write-Host "All checks passed."
