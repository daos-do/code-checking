# Copyright 2026 Hewlett Packard Enterprise Development LP
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$checksRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

. (Join-Path $checksRoot 'invoke-bash.ps1')
Invoke-BashScript -ScriptPath (Join-Path $scriptDir 'run.sh') -ScriptArgs $args
