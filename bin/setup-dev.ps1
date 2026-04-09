Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$libraryRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir '..')).Path
$targetRoot = (Get-Location).Path

for ($index = 0; $index -lt $args.Count; $index++) {
    switch ($args[$index]) {
        '--target-root' {
            $index++
            $targetRoot = $args[$index]
        }
        '--help' {
            Write-Host 'Usage: setup-dev.ps1 [--target-root PATH]'
            exit 0
        }
        default {
            throw "Unknown argument: $($args[$index])"
        }
    }
}

$targetRoot = (Resolve-Path -LiteralPath $targetRoot).Path

function Get-CodeCheckingPath {
        if ($libraryRoot -eq $targetRoot) {
                return '.'
        }

        if ($libraryRoot.StartsWith($targetRoot + [IO.Path]::DirectorySeparatorChar)) {
                return $libraryRoot.Substring($targetRoot.Length + 1) -replace '\\', '/'
        }

        $defaultPath = Join-Path $targetRoot 'code_checking'
        if (Test-Path -LiteralPath $defaultPath) {
                return 'code_checking'
        }

        throw "[setup-dev] no .pre-commit-config.yaml found and unable to locate code_checking path from $targetRoot"
}

function Ensure-PreCommitConfig {
        $configPath = Join-Path $targetRoot '.pre-commit-config.yaml'
        if (Test-Path -LiteralPath $configPath) {
                return
        }

        $codeCheckingPath = Get-CodeCheckingPath
        $hookPrefix = if ($codeCheckingPath -eq '.') { '.' } else { "./$codeCheckingPath" }
        $content = @"
repos:
    - repo: local
        hooks:
            - id: forbid-code-checking-ref
                name: forbid tracked .code-checking-ref
                entry: $hookPrefix/checks/guard-code-checking-ref.sh --target-root .
                language: script
                pass_filenames: false
                always_run: true
                stages: [commit]
                require_serial: true
            - id: verify-executable-modes
                name: verify executable modes
                entry: $hookPrefix/checks/verify-executable-modes.sh --target-root .
                language: script
                pass_filenames: false
                always_run: true
                stages: [commit]
                require_serial: true
            - id: shellcheck
                name: shellcheck
                entry: $hookPrefix/bin/run-linters.sh --mode changed --target-root .
                language: script
                pass_filenames: false
                types: [shell]
                stages: [commit]
                require_serial: false
"@
        Set-Content -LiteralPath $configPath -Value $content -Encoding ascii
        Write-Host "[setup-dev] created .pre-commit-config.yaml using $hookPrefix hooks"
}

function Test-CommandExists {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction SilentlyContinue | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

Write-Host "[setup-dev] checking pre-commit hooks prerequisites"

# Check for pre-commit
if (-not (Test-CommandExists pre-commit)) {
    Write-Host "[setup-dev] pre-commit not found"
    Write-Host "[setup-dev] run bootstrap-windows-dev.ps1 first to install pre-commit"
    exit 1
}
Write-Host "[setup-dev] ✓ pre-commit found"

# Check for shellcheck
if (-not (Test-CommandExists shellcheck)) {
    Write-Host "[setup-dev] ⚠ shellcheck not found"
    Write-Host "[setup-dev] note: shellcheck is required for pre-commit shell linting"
    Write-Host "[setup-dev] install it manually or via winget: winget install shellcheck"
}
else {
    Write-Host "[setup-dev] ✓ shellcheck found"
}

Ensure-PreCommitConfig

# Initialize pre-commit hooks only when target repo is configured for pre-commit
if (-not (Test-Path -LiteralPath (Join-Path $targetRoot '.git'))) {
    Write-Host "[setup-dev] not a git repository; skipping pre-commit hook initialization"
}
elseif (-not (Test-Path -LiteralPath (Join-Path $targetRoot '.pre-commit-config.yaml'))) {
    Write-Host "[setup-dev] no .pre-commit-config.yaml in target root; skipping hook initialization"
}
else {
    Write-Host "[setup-dev] initializing pre-commit hooks..."
    Push-Location $targetRoot
    try {
        & pre-commit install --install-hooks
        Write-Host "[setup-dev] pre-commit hooks initialized"
    }
    finally {
        Pop-Location
    }
}

Write-Host "[setup-dev] setup complete"
