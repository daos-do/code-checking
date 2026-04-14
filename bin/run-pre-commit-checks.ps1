# Copyright 2026 Hewlett Packard Enterprise Development LP
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$libraryRoot = Split-Path -Parent $scriptDir

. (Join-Path $libraryRoot 'checks/invoke-bash.ps1')
$invokeArgs = @{
	ScriptPath = (Join-Path $scriptDir 'run-pre-commit-checks.sh')
	ScriptArgs = $args
}
Invoke-BashScript @invokeArgs
