param(
  [string]$DeviceId,
  [string]$ApiBaseUrl = "http://10.0.2.2:8000/api/v1"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDir = Join-Path $repoRoot "backend"
$frontendDir = Join-Path $repoRoot "frontend/flutter_app"
$envPath = Join-Path $backendDir ".env"
$pythonExe = Join-Path $repoRoot ".venv/Scripts/python.exe"

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

$backendListening = Get-NetTCPConnection -State Listen -LocalPort 8000 -ErrorAction SilentlyContinue
if (-not $backendListening) {
  $backendCmd = "Set-Location '$backendDir'; & '$pythonExe' -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
  Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd | Out-Null
}

$healthy = $false
for ($i = 0; $i -lt 20; $i++) {
  try {
    $resp = Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/health -TimeoutSec 2
    if ($resp.StatusCode -eq 200) {
      $healthy = $true
      break
    }
  }
  catch {
  }
  Start-Sleep -Milliseconds 500
}

if (-not $healthy) {
  throw "Backend no responde en /health."
}

Set-Location $frontendDir
flutter pub get

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
  Write-Host "Dispositivos disponibles:"
  flutter devices
  throw "Debes indicar -DeviceId para el tutor movil."
}

flutter run -d $DeviceId -t lib/main_tutor_mobile.dart `
  --dart-define=SUPABASE_URL=$($cfg["SUPABASE_URL"]) `
  --dart-define=SUPABASE_ANON_KEY=$($cfg["SUPABASE_ANON_KEY"]) `
  --dart-define=FASTAPI_BASE_URL=$ApiBaseUrl
