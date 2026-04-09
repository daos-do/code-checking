Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PythonCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [switch]$UsePyLauncher
    )

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return $null
    }

    try {
        if ($UsePyLauncher) {
            $versionOut = & $Command '-3' '--version' 2>&1
        }
        else {
            $versionOut = & $Command '--version' 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            return $null
        }
        return @{
            Command = $Command
            Path = $cmd.Source
            Version = ($versionOut | Out-String).Trim()
        }
    }
    catch {
        return $null
    }
}

Write-Host '[bootstrap-python] checking for Python 3 runtime'

$detected = Test-PythonCommand -Command 'py' -UsePyLauncher
if (-not $detected) {
    $detected = Test-PythonCommand -Command 'python'
}

if ($detected) {
    Write-Host "[bootstrap-python] found: $($detected.Command)"
    Write-Host "[bootstrap-python] path: $($detected.Path)"
    Write-Host "[bootstrap-python] version: $($detected.Version)"
    Write-Host '[bootstrap-python] Python bootstrap check passed'
    exit 0
}

Write-Host '[bootstrap-python] Python 3 not found; attempting install via winget'

$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Write-Error @'
[bootstrap-python] Python 3 not found and winget is not available.

Install Python 3 manually, then rerun this script.
Recommended command:
winget install -e --id Python.Python.3.12
'@
    exit 1
}

& winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -ne 0) {
    Write-Error "[bootstrap-python] winget install failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host '[bootstrap-python] rechecking Python runtime after install'
$detected = Test-PythonCommand -Command 'py' -UsePyLauncher
if (-not $detected) {
    $detected = Test-PythonCommand -Command 'python'
}

if (-not $detected) {
    Write-Error @'
[bootstrap-python] Python install appears complete, but python is not yet on PATH.

Open a new terminal and rerun bootstrap-python.ps1.

Future enhancement:
- add a separate script for controlled Python runtime updates.
'@
    exit 1
}

Write-Host "[bootstrap-python] found: $($detected.Command)"
Write-Host "[bootstrap-python] path: $($detected.Path)"
Write-Host "[bootstrap-python] version: $($detected.Version)"
Write-Host '[bootstrap-python] Python bootstrap install/check passed'
exit 0
