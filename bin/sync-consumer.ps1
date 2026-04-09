Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$libraryRoot = Split-Path -Parent $scriptDir
$targetRoot = (Get-Location).Path
$defaultRef = 'origin/main'
$submodulePath = 'code_checking'
$refreshWorkflow = $true
$refreshPreCommit = $true
$updateReadme = $true

for ($index = 0; $index -lt $args.Count; $index++) {
    switch ($args[$index]) {
        '--target-root' {
            $index++
            $targetRoot = $args[$index]
        }
        '--submodule-path' {
            $index++
            $submodulePath = $args[$index]
        }
        '--default-ref' {
            $index++
            $defaultRef = $args[$index]
        }
        '--skip-workflow' {
            $refreshWorkflow = $false
        }
        '--skip-pre-commit' {
            $refreshPreCommit = $false
        }
        '--update-readme' {
            $updateReadme = $true
        }
        '--skip-readme' {
            $updateReadme = $false
        }
        '--help' {
            Write-Host 'Usage: sync-consumer.ps1 [--target-root PATH] [--submodule-path PATH] [--default-ref REF] [--skip-workflow] [--skip-pre-commit] [--skip-readme]'
            exit 0
        }
        default {
            throw "Unknown argument: $($args[$index])"
        }
    }
}

$targetRoot = (Resolve-Path -LiteralPath $targetRoot).Path
if (-not (Test-Path -LiteralPath (Join-Path $targetRoot '.git'))) {
    throw "[sync-consumer] target is not a git repository: $targetRoot"
}

if ($libraryRoot -eq $targetRoot) {
    throw '[sync-consumer] run this from a consumer repository that vendors code_checking as a submodule'
}

$targetPrefix = "$targetRoot$([System.IO.Path]::DirectorySeparatorChar)"
if (-not $libraryRoot.StartsWith($targetPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "[sync-consumer] library root is outside target root: $libraryRoot"
}

if ($libraryRoot.StartsWith($targetPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    $inferredPath = $libraryRoot.Substring($targetPrefix.Length)
    if ($inferredPath) {
        $submodulePath = $inferredPath -replace '\\', '/'
    }
}

$refFile = Join-Path $targetRoot '.code-checking-ref'
$desiredRef = $defaultRef
if (Test-Path -LiteralPath $refFile) {
    foreach ($line in Get-Content -LiteralPath $refFile) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }
        if ($trimmed.StartsWith('#')) { continue }
        $desiredRef = $trimmed
        break
    }
}

function Resolve-DesiredRef {
    param(
        [string]$LibraryRoot,
        [string]$DesiredRef
    )

    if ($DesiredRef -match '^[0-9a-fA-F]{7,40}$') {
        return @($DesiredRef, 'commit-sha')
    }

    $candidates = @()
    if ($DesiredRef.StartsWith('refs/')) {
        $candidates += $DesiredRef
    }
    elseif ($DesiredRef.StartsWith('origin/')) {
        $branch = $DesiredRef.Substring('origin/'.Length)
        $candidates += "refs/heads/$branch"
        $candidates += $branch
    }
    elseif ($DesiredRef -match '^pull/\d+/(head|merge)$') {
        $candidates += "refs/$DesiredRef"
        $candidates += $DesiredRef
    }
    else {
        $candidates += "refs/heads/$DesiredRef"
        $candidates += $DesiredRef
    }

    foreach ($candidate in $candidates) {
        $output = & git -C $LibraryRoot ls-remote --exit-code origin $candidate 2>$null
        if ($LASTEXITCODE -eq 0 -and $output) {
            $desiredSha = (($output | Select-Object -First 1) -split "`t")[0].Trim()
            if (-not $desiredSha) {
                $desiredSha = (($output | Select-Object -First 1) -split ' ')[0].Trim()
            }
            if ($desiredSha) {
                return @($desiredSha, $candidate)
            }
        }
    }

    throw "[sync-consumer] unable to resolve desired ref '$DesiredRef' from origin"
}

function Remove-TrailingBlankLines {
    param([string[]]$Lines)

    if (-not $Lines) {
        return @()
    }

    $lastNonBlank = -1
    for ($i = $Lines.Length - 1; $i -ge 0; $i--) {
        if ($Lines[$i] -notmatch '^\s*$') {
            $lastNonBlank = $i
            break
        }
    }

    if ($lastNonBlank -lt 0) {
        return @()
    }

    return $Lines[0..$lastNonBlank]
}

$resolvedInfo = Resolve-DesiredRef -LibraryRoot $libraryRoot -DesiredRef $desiredRef
$desiredSha = $resolvedInfo[0]
$resolvedFrom = $resolvedInfo[1]
$currentSha = (& git -C $libraryRoot rev-parse HEAD).Trim()

if ($currentSha -ne $desiredSha) {
    Write-Host "[sync-consumer] syncing $submodulePath to $desiredRef ($resolvedFrom)"
    if ($desiredRef -match '^[0-9a-fA-F]{7,40}$') {
        & git -C $libraryRoot fetch origin $desiredRef
        & git -C $libraryRoot checkout $desiredRef
    }
    else {
        & git -C $libraryRoot fetch origin $resolvedFrom
        & git -C $libraryRoot checkout FETCH_HEAD
    }
}
else {
    $shortSha = $currentSha
    if ($currentSha.Length -ge 12) {
        $shortSha = $currentSha.Substring(0, 12)
    }
    Write-Host "[sync-consumer] $submodulePath already matches $desiredRef ($shortSha)"
}

if ($refreshWorkflow) {
    & bash (Join-Path $libraryRoot 'bin/setup-github-workflow.sh') `
        --target-root $targetRoot `
        --submodule-path $submodulePath `
        --apply
}

if ($refreshPreCommit) {
    $preCommitConfig = Join-Path $targetRoot '.pre-commit-config.yaml'
    if (Test-Path -LiteralPath $preCommitConfig) {
        if (Get-Command pre-commit -ErrorAction SilentlyContinue) {
            Write-Host "[sync-consumer] refreshing pre-commit hooks in $targetRoot"
            Push-Location $targetRoot
            try {
                & pre-commit install --install-hooks
            }
            finally {
                Pop-Location
            }
        }
        else {
            Write-Host '[sync-consumer] pre-commit not installed; skipping hook refresh'
        }
    }
    else {
        Write-Host '[sync-consumer] no .pre-commit-config.yaml in target root; skipping hook refresh'
    }
}

if ($updateReadme) {
    $readmePath = Join-Path $targetRoot 'README.md'
    if (-not (Test-Path -LiteralPath $readmePath)) {
        Write-Host '[sync-consumer] README.md not found; skipping README update'
    }
    else {
        $beginMarker = '<!-- BEGIN code_checking submodule links -->'
        $endMarker = '<!-- END code_checking submodule links -->'
        $managedBlock = @(
            $beginMarker,
            '## Shared Checks Submodule',
            '',
            'This repository uses the shared `code_checking` submodule.',
            '',
            "- Framework documentation: [code_checking README](./$submodulePath/README.md)",
            "- Integration guide: [code_checking integration](./$submodulePath/docs/integration.md)",
            '',
            $endMarker
        )

        $existingLines = Get-Content -LiteralPath $readmePath
        $startIndex = [Array]::IndexOf($existingLines, $beginMarker)
        $endIndex = [Array]::IndexOf($existingLines, $endMarker)

        if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
            $prefix = @()
            if ($startIndex -gt 0) {
                $prefix = $existingLines[0..($startIndex - 1)]
            }
            $suffix = @()
            if ($endIndex -lt ($existingLines.Length - 1)) {
                $suffix = $existingLines[($endIndex + 1)..($existingLines.Length - 1)]
            }
            $prefix = Remove-TrailingBlankLines -Lines $prefix

            $newLines = @()
            $newLines += $prefix
            $newLines += ''
            $newLines += $managedBlock
            if ($suffix.Length -gt 0) {
                $newLines += $suffix
            }

            Set-Content -LiteralPath $readmePath -Value $newLines -NoNewline:$false
            Write-Host '[sync-consumer] refreshed README managed section'
        }
        else {
            $existingTrimmed = Remove-TrailingBlankLines -Lines $existingLines
            $newLines = @()
            $newLines += $existingTrimmed
            $newLines += ''
            $newLines += $managedBlock
            Set-Content -LiteralPath $readmePath -Value $newLines -NoNewline:$false
            Write-Host '[sync-consumer] appended README managed section'
        }
    }
}

$gitignorePath = Join-Path $targetRoot '.gitignore'
if (-not (Test-Path -LiteralPath $gitignorePath)) {
    $gitignoreBaseline = Join-Path $libraryRoot '.gitignore'
    if (Test-Path -LiteralPath $gitignoreBaseline) {
        Copy-Item -LiteralPath $gitignoreBaseline -Destination $gitignorePath
        Write-Host '[sync-consumer] created .gitignore from code_checking baseline'
    }
    else {
        Write-Host "[sync-consumer] baseline not found: $gitignoreBaseline" -ForegroundColor Yellow
    }
}

$cspellConfigPath = Join-Path $targetRoot 'cspell.config.yaml'
if (-not (Test-Path -LiteralPath $cspellConfigPath)) {
    $cspellConfigBaseline = Join-Path $libraryRoot 'cspell.config.yaml'
    if (Test-Path -LiteralPath $cspellConfigBaseline) {
        Copy-Item -LiteralPath $cspellConfigBaseline -Destination $cspellConfigPath
        Write-Host '[sync-consumer] created cspell.config.yaml from code_checking baseline'
    }
    else {
        Write-Host "[sync-consumer] baseline not found: $cspellConfigBaseline" -ForegroundColor Yellow
    }
}

$cspellWordsPath = Join-Path $targetRoot 'vscode-project-words.txt'
if (-not (Test-Path -LiteralPath $cspellWordsPath)) {
    $cspellWordsBaseline = Join-Path $libraryRoot 'vscode-project-words.txt'
    if (Test-Path -LiteralPath $cspellWordsBaseline) {
        Copy-Item -LiteralPath $cspellWordsBaseline -Destination $cspellWordsPath
        Write-Host '[sync-consumer] created vscode-project-words.txt from code_checking baseline'
    }
    else {
        Write-Host "[sync-consumer] baseline not found: $cspellWordsBaseline" -ForegroundColor Yellow
    }
}

Write-Host '[sync-consumer] complete'