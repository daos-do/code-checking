Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$libraryRoot = Split-Path -Parent $scriptDir
$targetRoot = (Get-Location).Path
$mode = 'changed'
$baseRef = if ($env:GITHUB_BASE_REF) { $env:GITHUB_BASE_REF } else { '' }

for ($index = 0; $index -lt $args.Count; $index++) {
    switch ($args[$index]) {
        '--target-root' {
            $index++
            $targetRoot = $args[$index]
        }
        '--mode' {
            $index++
            $mode = $args[$index]
        }
        '--base-ref' {
            $index++
            $baseRef = $args[$index]
        }
        '--help' {
            Write-Host 'Usage: run-linters.ps1 [--target-root PATH] [--mode changed|full] [--base-ref REF]'
            exit 0
        }
        default {
            throw "Unknown argument: $($args[$index])"
        }
    }
}

$targetRoot = (Resolve-Path -LiteralPath $targetRoot).Path

Write-Host "[linters] library root: $libraryRoot"
Write-Host "[linters] target root: $targetRoot"
Write-Host "[linters] mode: $mode"

& (Join-Path $libraryRoot 'checks/ensure-code-checking-ref.ps1') `
    --library-root $libraryRoot `
    --target-root $targetRoot

$detectArgs = @(
    '--library-root', $libraryRoot,
    '--target-root', $targetRoot,
    '--mode', $mode
)
if ($baseRef) {
    $detectArgs += @('--base-ref', $baseRef)
}

$requiredLinters = & (Join-Path $libraryRoot 'checks/detect-linters.ps1') @detectArgs
if (-not $requiredLinters) {
    Write-Host '[linters] no applicable linters for selected files'
    exit 0
}

Write-Host "[linters] selected linters: $($requiredLinters -join ', ')"

foreach ($linter in $requiredLinters) {
    switch ($linter) {
        'shellcheck' {
            $runArgs = @(
                '--library-root', $libraryRoot,
                '--target-root', $targetRoot,
                '--mode', $mode
            )
            if ($baseRef) {
                $runArgs += @('--base-ref', $baseRef)
            }
            & (Join-Path $libraryRoot 'checks/linters/shellcheck/run.ps1') @runArgs
        }
        default {
            throw "Unknown linter selected: $linter"
        }
    }
}

Write-Host '[linters] complete'