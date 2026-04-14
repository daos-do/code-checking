# Copyright 2026 Hewlett Packard Enterprise Development LP
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-BashScript {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$ScriptArgs = @()
    )

    $resolvedScriptPath = (Resolve-Path -LiteralPath $ScriptPath).Path
    $currentDir = (Get-Location).Path

    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        $wslCurrentDirInput = $currentDir -replace '\\', '/'
        $wslCurrentDir = (& wsl wslpath -a $wslCurrentDirInput).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $wslCurrentDir) {
            throw 'Unable to convert current directory to a WSL path.'
        }

        $wslScriptPathInput = $resolvedScriptPath -replace '\\', '/'
        $wslScriptPath = (& wsl wslpath -a $wslScriptPathInput).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $wslScriptPath) {
            throw "Unable to convert script path to a WSL path: $resolvedScriptPath"
        }

        $wslArgs = @('--cd', $wslCurrentDir, 'bash', $wslScriptPath) + $ScriptArgs
        & wsl @wslArgs
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        return
    }

    if (Get-Command bash -ErrorAction SilentlyContinue) {
        & bash $resolvedScriptPath @ScriptArgs
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        return
    }

    throw 'Unable to find bash. Install WSL or Git Bash.'
}
