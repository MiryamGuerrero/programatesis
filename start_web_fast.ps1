$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot "start_web.ps1") -Fast
