
param(
  [switch]$Fast
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDir = Join-Path $repoRoot "backend"
$frontendDir = Join-Path $repoRoot "frontend/flutter_app"
$envPath = Join-Path $backendDir ".env"
$pythonExe = Join-Path $repoRoot ".venv/Scripts/python.exe"
$backendFingerprintPath = Join-Path $backendDir ".backend_fingerprint_web.txt"

function Get-StringSha256([string]$value) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($value)
    $hash = $sha.ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
  }
  finally {
    $sha.Dispose()
  }
}

function Get-BackendFingerprint([string]$rootBackendDir, [string]$dotenvPath) {
  $trackedFiles = @()
  $trackedFiles += Get-ChildItem (Join-Path $rootBackendDir "app") -Recurse -File -Filter "*.py"
  $trackedFiles += Get-ChildItem (Join-Path $rootBackendDir "requirements.txt") -ErrorAction SilentlyContinue
  $trackedFiles += Get-ChildItem $dotenvPath -ErrorAction SilentlyContinue

  $signature = ($trackedFiles |
      Sort-Object FullName -Unique |
      ForEach-Object { "{0}|{1}|{2}" -f $_.FullName, $_.Length, $_.LastWriteTimeUtc.Ticks }) -join "`n"

  if ([string]::IsNullOrWhiteSpace($signature)) {
    return ""
  }

  return Get-StringSha256 $signature
}

function Get-ListeningPids([int]$port) {
  return @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty OwningProcess -Unique)
}

function Start-Backend([string]$targetBackendDir, [string]$targetPythonExe) {
  $backendCmd = "Set-Location '$targetBackendDir'; & '$targetPythonExe' -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
  Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd | Out-Null
}

function Wait-BackendHealthy([int]$maxAttempts = 20) {
  for ($i = 0; $i -lt $maxAttempts; $i++) {
    try {
      $resp = Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/health -TimeoutSec 2
      if ($resp.StatusCode -eq 200) {
        return $true
      }
    }
    catch {
    }
    Start-Sleep -Milliseconds 500
  }

  return $false
}

if (-not (Test-Path $envPath)) {
  throw "No se encontro backend/.env en: $envPath"
}

if (-not (Test-Path $pythonExe)) {
  $pythonExe = "python"
}

$cfg = @{}
foreach ($line in Get-Content $envPath) {
  if ($line -match '^\s*#' -or $line -notmatch '=') {
    continue
  }

  $k, $v = $line -split '=', 2
  $cfg[$k.Trim()] = $v.Trim()
}

foreach ($required in @("SUPABASE_URL", "SUPABASE_ANON_KEY")) {
  if (-not $cfg.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($cfg[$required])) {
    throw "Falta la variable $required en backend/.env"
  }
}


$currentBackendFingerprint = Get-BackendFingerprint -rootBackendDir $backendDir -dotenvPath $envPath
$previousBackendFingerprint = ""
if (Test-Path $backendFingerprintPath) {
  $previousBackendFingerprint = (Get-Content $backendFingerprintPath -Raw).Trim()
}

$backendPids = Get-ListeningPids -port 8000
$backendListening = $backendPids.Count -gt 0
$healthy = $false

if ($backendListening) {
  $healthy = Wait-BackendHealthy
}

$backendFingerprintChanged =
  -not [string]::IsNullOrWhiteSpace($currentBackendFingerprint) -and
  $currentBackendFingerprint -ne $previousBackendFingerprint

$mustRestartBackend = ($backendListening -and -not $healthy) -or ($backendListening -and $backendFingerprintChanged)

if ($mustRestartBackend) {
  foreach ($backendPid in $backendPids) {
    try {
      Stop-Process -Id $backendPid -Force -ErrorAction Stop
      Write-Output "Se reinicio backend: proceso detenido PID=$backendPid"
    }
    catch {
      Write-Output "No se pudo detener PID=$backendPid en puerto 8000: $($_.Exception.Message)"
    }
  }

  $backendListening = $false
  $healthy = $false
}

if (-not $backendListening) {
  Start-Backend -targetBackendDir $backendDir -targetPythonExe $pythonExe
  $healthy = Wait-BackendHealthy
}

if (-not $healthy) {
  throw "Backend no responde en /health."
}

if (-not [string]::IsNullOrWhiteSpace($currentBackendFingerprint)) {
  Set-Content -Path $backendFingerprintPath -Value $currentBackendFingerprint -NoNewline
}

$webPort = 3000
$webListening = Get-NetTCPConnection -State Listen -LocalPort $webPort -ErrorAction SilentlyContinue
if ($webListening) {
  try {
    $webResp = Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$webPort" -TimeoutSec 2
    if ($webResp.StatusCode -ge 200 -and $webResp.StatusCode -lt 500) {
      Write-Output "La web ya esta activa en http://localhost:$webPort"
      return
    }
  }
  catch {
  }

  $foundFree = $false
  for ($p = 3001; $p -le 3010; $p++) {
    $busy = Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue
    if (-not $busy) {
      $webPort = $p
      $foundFree = $true
      break
    }
  }

  if (-not $foundFree) {
    throw "Puertos 3000-3010 ocupados. Libera uno y vuelve a ejecutar start_web.ps1"
  }
}

Set-Location $frontendDir
flutter pub get

$flutterArgs = @(
  "run",
  "-d", "chrome",
  "--web-port", "$webPort",
  "-t", "lib/main_web.dart",
  "--no-web-resources-cdn"
)

if ($Fast) {
  Write-Output "Iniciando web en modo rapido (profile, sin hot reload)..."
  $flutterArgs += "--profile"
}
else {
  $flutterArgs += "--debug"
}

$flutterArgs += "--dart-define=SUPABASE_URL=$($cfg["SUPABASE_URL"])"
$flutterArgs += "--dart-define=SUPABASE_ANON_KEY=$($cfg["SUPABASE_ANON_KEY"])"
$flutterArgs += "--dart-define=FASTAPI_BASE_URL=http://127.0.0.1:8000/api/v1"

flutter @flutterArgs
