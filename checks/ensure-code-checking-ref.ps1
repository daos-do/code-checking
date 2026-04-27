# Copyright 2026 Hewlett Packard Enterprise Development LP
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath

. (Join-Path $scriptDir 'invoke-bash.ps1')
Invoke-BashScript -ScriptPath (Join-Path $scriptDir 'ensure-code-checking-ref.sh') -ScriptArgs $args
