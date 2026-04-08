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
    'ide/vscode/settings-baseline.json',
    'ide/vscode/extensions-baseline.json'
)

foreach ($path in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required path: $path"
    }
}

Write-Host "[check] validating JSON syntax"
Get-ChildItem -Path 'ide/vscode' -Filter '*.json' -Recurse | ForEach-Object {
    $null = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
}

Write-Host "All checks passed."
