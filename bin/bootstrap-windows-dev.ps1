# Copyright 2026 Hewlett Packard Enterprise Development LP
param(
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CommandInfo {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$UsePyLauncher
    )

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return $null
    }

    try {
        if ($UsePyLauncher) {
            $out = & $Name '-3' '--version' 2>&1
        }
        else {
            $out = & $Name '--version' 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            return $null
        }
        return @{
            Name = $Name
            Path = $cmd.Source
            Version = ($out | Out-String).Trim()
        }
    }
    catch {
        return $null
    }
}

function Test-WingetAvailable {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw @'
[bootstrap-windows-dev] winget is required but was not found.

Install App Installer from Microsoft Store (winget provider), then rerun.
'@
    }
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [switch]$ValidateOnly
    )

    if ($ValidateOnly) {
        Write-Host "[bootstrap-windows-dev] validate-only: skipping install check for $DisplayName"
        return
    }

    Write-Host "[bootstrap-windows-dev] ensuring $DisplayName via winget ($PackageId)"
    & winget install -e --id $PackageId --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "[bootstrap-windows-dev] winget install failed for $DisplayName (exit $LASTEXITCODE)"
    }
}

function Install-PyYaml {
    param(
        [switch]$ValidateOnly
    )

    if ($ValidateOnly) {
        Write-Host '[bootstrap-windows-dev] validate-only: skipping PyYAML install'
        return
    }

    $pythonCmd = $null
    if (Get-Command py -ErrorAction SilentlyContinue) {
        $pythonCmd = @('py', '-3')
    }
    elseif (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonCmd = @('python')
    }

    if (-not $pythonCmd) {
        throw '[bootstrap-windows-dev] Python not available to install PyYAML'
    }

    Write-Host '[bootstrap-windows-dev] checking Python package: pyyaml'
    if ($pythonCmd[0] -eq 'py') {
        & $pythonCmd[0] $pythonCmd[1] -c "import yaml" 2>$null
    }
    else {
        & $pythonCmd[0] -c "import yaml" 2>$null
    }
    if ($LASTEXITCODE -eq 0) {
        Write-Host '[bootstrap-windows-dev] pyyaml already available'
        return
    }

    Write-Host '[bootstrap-windows-dev] installing Python package: pyyaml'
    if ($pythonCmd[0] -eq 'py') {
        & $pythonCmd[0] $pythonCmd[1] -m pip install pyyaml
    }
    else {
        & $pythonCmd[0] -m pip install pyyaml
    }
    if ($LASTEXITCODE -ne 0) {
        throw "[bootstrap-windows-dev] failed to install pyyaml (exit $LASTEXITCODE)"
    }
}

function Install-PreCommit {
    param(
        [switch]$ValidateOnly
    )

    if ($ValidateOnly) {
        Write-Host '[bootstrap-windows-dev] validate-only: skipping pre-commit install'
        return
    }

    if (Get-Command pre-commit -ErrorAction SilentlyContinue) {
        Write-Host '[bootstrap-windows-dev] pre-commit already available'
        return
    }

    $pythonCmd = $null
    if (Get-Command py -ErrorAction SilentlyContinue) {
        $pythonCmd = @('py', '-3')
    }
    elseif (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonCmd = @('python')
    }

    if (-not $pythonCmd) {
        throw '[bootstrap-windows-dev] Python not available to install pre-commit'
    }

    Write-Host '[bootstrap-windows-dev] installing Python package: pre-commit'
    if ($pythonCmd[0] -eq 'py') {
        & $pythonCmd[0] $pythonCmd[1] -m pip install pre-commit
    }
    else {
        & $pythonCmd[0] -m pip install pre-commit
    }
    if ($LASTEXITCODE -ne 0) {
        throw "[bootstrap-windows-dev] failed to install pre-commit (exit $LASTEXITCODE)"
    }
}

function Set-GitGlobalConfig {
    param(
        [switch]$ValidateOnly
    )

    $desiredConfig = @(
        @{ Key = 'core.autocrlf'; Value = 'input' },
        @{ Key = 'core.eol'; Value = 'lf' },
        @{ Key = 'core.safecrlf'; Value = 'true' },
        @{ Key = 'core.filemode'; Value = 'false' },
        @{ Key = 'core.symlinks'; Value = 'false' },
        @{ Key = 'core.longpaths'; Value = 'true' }
    )

    foreach ($entry in $desiredConfig) {
        $current = (& git config --global --get $entry.Key 2>$null | Out-String).Trim()
        $isMatch = (-not [string]::IsNullOrWhiteSpace($current)) -and ($current -eq $entry.Value)

        if ($isMatch) {
            Write-Host "[bootstrap-windows-dev] git config $($entry.Key)=$($entry.Value)"
            continue
        }

        if ($ValidateOnly) {
            Write-Host "[bootstrap-windows-dev] validate-only: git config $($entry.Key) expected '$($entry.Value)' (current '$current')"
            continue
        }

        Write-Host "[bootstrap-windows-dev] setting git config --global $($entry.Key) $($entry.Value)"
        & git config --global $entry.Key $entry.Value
        if ($LASTEXITCODE -ne 0) {
            throw "[bootstrap-windows-dev] failed to set git config $($entry.Key) (exit $LASTEXITCODE)"
        }
    }
}

Write-Host '[bootstrap-windows-dev] validating Windows developer prerequisites'

$gitInfo = Get-CommandInfo -Name 'git'
if (-not $gitInfo) {
    Test-WingetAvailable
    Install-WingetPackage -PackageId 'Git.Git' -DisplayName 'Git for Windows' -ValidateOnly:$ValidateOnly
    $gitInfo = Get-CommandInfo -Name 'git'
}
if (-not $gitInfo) {
    throw '[bootstrap-windows-dev] git was not detected after bootstrap'
}
Write-Host "[bootstrap-windows-dev] git: $($gitInfo.Version)"
Set-GitGlobalConfig -ValidateOnly:$ValidateOnly

$bashInfo = Get-CommandInfo -Name 'bash'
if (-not $bashInfo) {
    throw '[bootstrap-windows-dev] bash was not detected. Git for Windows should provide bash. Reopen terminal and rerun.'
}
Write-Host "[bootstrap-windows-dev] bash: $($bashInfo.Version)"

$pythonInfo = Get-CommandInfo -Name 'py' -UsePyLauncher
if (-not $pythonInfo) {
    $pythonInfo = Get-CommandInfo -Name 'python'
}
if (-not $pythonInfo) {
    Test-WingetAvailable
    Install-WingetPackage -PackageId 'Python.Python.3.12' -DisplayName 'Python 3' -ValidateOnly:$ValidateOnly
    $pythonInfo = Get-CommandInfo -Name 'py' -UsePyLauncher
    if (-not $pythonInfo) {
        $pythonInfo = Get-CommandInfo -Name 'python'
    }
}
if (-not $pythonInfo) {
    throw '[bootstrap-windows-dev] python was not detected after bootstrap'
}
Write-Host "[bootstrap-windows-dev] python: $($pythonInfo.Version)"

Install-PyYaml -ValidateOnly:$ValidateOnly

Install-PreCommit -ValidateOnly:$ValidateOnly

if (-not $ValidateOnly) {
    Write-Host '[bootstrap-windows-dev] install/check complete'
    Write-Host '[bootstrap-windows-dev] if tools were newly installed, reopen terminal and rerun this script once.'
}
else {
    Write-Host '[bootstrap-windows-dev] validation complete'
}
