# Copyright 2026 Hewlett Packard Enterprise Development LP
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$libraryRoot = Split-Path -Parent $scriptDir
$targetRoot = (Get-Location).Path
$codeCheckingPath = ''

for ($index = 0; $index -lt $args.Count; $index++) {
    switch ($args[$index]) {
        '--target-root' {
            $index++
            $targetRoot = $args[$index]
        }
        '--code-checking-path' {
            $index++
            $codeCheckingPath = $args[$index]
        }
        '--help' {
            Write-Host 'Usage: setup-dev.ps1 [--target-root PATH] [--code-checking-path PATH]'
            Write-Host 'Delegates to setup-dev.sh using WSL bash or Git Bash.'
            exit 0
        }
        default {
            throw "Unknown argument: $($args[$index])"
        }
    }
}

$targetRoot = (Resolve-Path -LiteralPath $targetRoot).Path

function Test-BashRuntime {
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        return $true
    }
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        return $true
    }
    return $false
}

if (-not (Test-BashRuntime)) {
    Write-Error '[setup-dev] no bash runtime found (WSL or Git Bash required)'
    Write-Error '[setup-dev] install one of:'
    Write-Error '  - WSL with a Linux distribution'
    Write-Error '  - Git for Windows (Git Bash)'
    Write-Error '[setup-dev] then rerun setup-dev.ps1'
    Write-Error '[setup-dev] for details, see docs/usage.md (Local setup sections)'
    exit 1
}

$setupScript = Join-Path $scriptDir 'setup-dev.sh'
if (-not (Test-Path -LiteralPath $setupScript -PathType Leaf)) {
    throw "Missing script: $setupScript"
}

Push-Location $targetRoot
try {
    . (Join-Path $libraryRoot 'checks/invoke-bash.ps1')
    $scriptArgs = @('--target-root', $targetRoot)
    if ($codeCheckingPath) {
        $scriptArgs += @('--code-checking-path', $codeCheckingPath)
    }
    Invoke-BashScript -ScriptPath $setupScript -ScriptArgs $scriptArgs
}
finally {
    Pop-Location
}
