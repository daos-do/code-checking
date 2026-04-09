Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$libraryRoot = ''
$targetRoot = ''
$defaultRef = 'origin/main'

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
        '--default-ref' {
            $index++
            $defaultRef = $args[$index]
        }
        '--help' {
            Write-Host 'Usage: ensure-code-checking-ref.ps1 --library-root PATH --target-root PATH [--default-ref REF]'
            exit 0
        }
        default {
            throw "Unknown argument: $($args[$index])"
        }
    }
}

if (-not $libraryRoot -or -not $targetRoot) {
    throw 'Both --library-root and --target-root are required.'
}

$libraryRoot = (Resolve-Path -LiteralPath $libraryRoot).Path
$targetRoot = (Resolve-Path -LiteralPath $targetRoot).Path

if ($libraryRoot -eq $targetRoot) {
    Write-Host '[code-checking-ref] library root matches target root; skip ref check'
    exit 0
}

$targetPrefix = "$targetRoot$([System.IO.Path]::DirectorySeparatorChar)"
if (-not $libraryRoot.StartsWith($targetPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host '[code-checking-ref] library root is outside target root; skip ref check'
    exit 0
}

$refFile = Join-Path $targetRoot '.code-checking-ref'
$desiredRef = $defaultRef
if (Test-Path -LiteralPath $refFile) {
    foreach ($line in Get-Content -LiteralPath $refFile) {
        $trimmed = $line.Trim()
        if (-not $trimmed) {
            continue
        }
        if ($trimmed.StartsWith('#')) {
            continue
        }
        $desiredRef = $trimmed
        break
    }
}

$currentSha = (& git -C $libraryRoot rev-parse HEAD).Trim()
$desiredSha = ''
$resolvedFrom = ''

if ($desiredRef -match '^[0-9a-fA-F]{7,40}$') {
    $desiredSha = $desiredRef
    $resolvedFrom = 'commit-sha'
} else {
    $candidates = @()
    if ($desiredRef.StartsWith('refs/')) {
        $candidates += $desiredRef
    } elseif ($desiredRef.StartsWith('origin/')) {
        $branch = $desiredRef.Substring('origin/'.Length)
        $candidates += "refs/heads/$branch"
        $candidates += $branch
    } elseif ($desiredRef -match '^pull/\d+/(head|merge)$') {
        $candidates += "refs/$desiredRef"
        $candidates += $desiredRef
    } else {
        $candidates += "refs/heads/$desiredRef"
        $candidates += $desiredRef
    }

    foreach ($candidate in $candidates) {
        $output = & git -C $libraryRoot ls-remote --exit-code origin $candidate 2>$null
        if ($LASTEXITCODE -eq 0 -and $output) {
            $desiredSha = (($output | Select-Object -First 1) -split "`t")[0].Trim()
            if (-not $desiredSha) {
                $desiredSha = (($output | Select-Object -First 1) -split ' ')[0].Trim()
            }
            if ($desiredSha) {
                $resolvedFrom = $candidate
                break
            }
        }
    }
}

if (-not $desiredSha) {
    Write-Error "[code-checking-ref] unable to resolve desired ref '$desiredRef' from origin"
    Write-Error '[code-checking-ref] set .code-checking-ref to a valid ref or ensure network access'
    exit 1
}

if ($currentSha -ne $desiredSha) {
    Write-Error '[code-checking-ref] submodule checkout mismatch'
    Write-Error "[code-checking-ref] desired ref: $desiredRef ($resolvedFrom)"
    Write-Error "[code-checking-ref] desired sha: $desiredSha"
    Write-Error "[code-checking-ref] current sha: $currentSha"
    Write-Error '[code-checking-ref] run the following commands, then rerun checks:'
    Write-Error "  git -C `"$libraryRoot`" fetch origin `"$desiredRef`""
    if (
        $desiredRef.StartsWith('origin/') -or
        $desiredRef.StartsWith('refs/') -or
        $desiredRef -match '^pull/\d+/(head|merge)$'
    ) {
        Write-Error "  git -C `"$libraryRoot`" checkout FETCH_HEAD"
    } else {
        Write-Error "  git -C `"$libraryRoot`" checkout `"$desiredRef`""
    }
    exit 1
}

Write-Host "[code-checking-ref] verified: $desiredRef ($desiredSha)"
