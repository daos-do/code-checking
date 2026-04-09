Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$libraryRoot = ''
$targetRoot = ''
$mode = 'changed'
$baseRef = if ($env:GITHUB_BASE_REF) { $env:GITHUB_BASE_REF } else { '' }

for ($index = 0; $index -lt $args.Count; $index++) {
    switch ($args[$index]) {
        '--library-root' {
            $index++
            $libraryRoot = $args[$index]
        }
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
        default {
            throw "Unknown argument: $($args[$index])"
        }
    }
}

if (-not $libraryRoot -or -not $targetRoot) {
    throw '--library-root and --target-root are required'
}

if (-not (Get-Command shellcheck -ErrorAction SilentlyContinue)) {
    throw 'shellcheck is required but was not found in PATH'
}

$libraryRoot = (Resolve-Path -LiteralPath $libraryRoot).Path
$targetRoot = (Resolve-Path -LiteralPath $targetRoot).Path
$libraryRelativePath = ''
if ($libraryRoot.StartsWith($targetRoot + [System.IO.Path]::DirectorySeparatorChar) -or
    $libraryRoot.StartsWith($targetRoot + '/')) {
    $libraryRelativePath = $libraryRoot.Substring($targetRoot.Length).TrimStart('\', '/')
}

function Get-CandidateFiles {
    Push-Location $targetRoot
    try {
        if ($mode -eq 'full') {
            Get-ChildItem -File -Recurse -Filter '*.sh' | ForEach-Object {
                $relativePath = Resolve-Path -LiteralPath $_.FullName -Relative
                $relativePath -replace '^[.][\\/]', ''
            }
            return
        }

        if ($baseRef) {
            git diff --name-only --diff-filter=ACMR "origin/$baseRef...HEAD"
            return
        }

        $stagedFiles = @(git diff --name-only --cached --diff-filter=ACMR)
        if ($stagedFiles.Count -gt 0) {
            $stagedFiles
            return
        }

        @(git diff --name-only --diff-filter=ACMR) + @(git ls-files --others --exclude-standard) |
            Where-Object { $_ } |
            Select-Object -Unique
    }
    finally {
        Pop-Location
    }
}

$filesToCheck = @()
foreach ($filePath in @(Get-CandidateFiles)) {
    if (-not $filePath) {
        continue
    }

    if ($libraryRelativePath) {
        $normalizedRelativePath = $libraryRelativePath -replace '\\', '/'
        if ($filePath -like "$normalizedRelativePath/*") {
            continue
        }
    }

    if ($filePath -like '*.sh') {
        $absolutePath = Join-Path $targetRoot $filePath
        if (Test-Path -LiteralPath $absolutePath) {
            $filesToCheck += $absolutePath
        }
    }
}

if ($filesToCheck.Count -eq 0) {
    Write-Host '[shellcheck] no shell files to lint'
    exit 0
}

Write-Host "[shellcheck] linting $($filesToCheck.Count) file(s)"
& shellcheck '--external-sources' @filesToCheck