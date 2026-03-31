$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDir = Join-Path $repoRoot "backend"
$frontendDir = Join-Path $repoRoot "frontend/flutter_app"
$envPath = Join-Path $backendDir ".env"
$pythonExe = Join-Path $repoRoot ".venv-1/Scripts/python.exe"

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
flutter run -d chrome --web-port $webPort -t lib/main_web.dart `
  --dart-define=SUPABASE_URL=$($cfg["SUPABASE_URL"]) `
  --dart-define=SUPABASE_ANON_KEY=$($cfg["SUPABASE_ANON_KEY"]) `
  --dart-define=FASTAPI_BASE_URL=http://127.0.0.1:8000/api/v1
