# Copyright 2026 Hewlett Packard Enterprise Development LP
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$libraryRoot = Split-Path -Parent $scriptDir
$syncScript = Join-Path $scriptDir 'sync-consumer.sh'

if (-not (Test-Path -LiteralPath $syncScript -PathType Leaf)) {
    throw "Missing script: $syncScript"
}

. (Join-Path $libraryRoot 'checks/invoke-bash.ps1')
Invoke-BashScript -ScriptPath $syncScript -ScriptArgs $args
