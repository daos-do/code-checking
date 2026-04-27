# Copyright 2026 Hewlett Packard Enterprise Development LP
param(
    [switch]$Apply,
    [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$pythonCmd = $null

if (Get-Command py -ErrorAction SilentlyContinue) {
    $pythonCmd = @('py', '-3')
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonCmd = @('python')
}
else {
    throw 'Python 3 is required for bin/ide-workspace-setup.ps1. Run .\bin\bootstrap-windows-dev.ps1 first.'
}

$argsList = @()
if ($Apply) {
    $argsList += '--apply'
}
if ($ConfigPath) {
    $argsList += '--config'
    $argsList += $ConfigPath
}

$scriptPath = Join-Path $repoRoot 'bin/ide-workspace-setup.py'

if ($pythonCmd[0] -eq 'py') {
    & $pythonCmd[0] $pythonCmd[1] $scriptPath @argsList
}
else {
    & $pythonCmd[0] $scriptPath @argsList
}

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
