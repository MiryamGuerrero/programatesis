param(
  [string]$DeviceId,
  [string]$ApiBaseUrl = "http://127.0.0.1:8000/api/v1"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = if ((Split-Path -Leaf $scriptDir) -eq "debug") { Split-Path -Parent $scriptDir } else { $scriptDir }
$backendDir = Join-Path $repoRoot "backend"
$frontendDir = Join-Path $repoRoot "frontend/flutter_app"
$envPath = Join-Path $backendDir ".env"
$debugEnvPath = Join-Path $repoRoot "debug/backend/.env"
if (-not (Test-Path $envPath) -and (Test-Path $debugEnvPath)) {
  $envPath = $debugEnvPath
}
$pythonExe = Join-Path $repoRoot ".venv/Scripts/python.exe"

if (-not (Test-Path $envPath)) {
  throw "No se encontro .env en backend/.env ni debug/backend/.env"
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
  $adb = Get-Command adb -ErrorAction SilentlyContinue
  if ($adb) {
    $adbDevice = adb devices |
      Select-String -Pattern "^\S+\s+device$" |
      Select-Object -First 1

    if ($adbDevice) {
      $DeviceId = (($adbDevice.Line -split "\s+")[0]).Trim()
      Write-Host "Usando dispositivo Android detectado por adb: $DeviceId"
    }
  }

  if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    $devicesJson = flutter devices --machine | Out-String
    $devices = @()
    try {
      $devices = $devicesJson | ConvertFrom-Json
    }
    catch {
      $devices = @()
    }

    $mobileDevice = $devices |
      Where-Object { $_.targetPlatform -in @("android-arm", "android-arm64", "android-x64", "ios") } |
      Select-Object -First 1

    if ($mobileDevice) {
      $DeviceId = $mobileDevice.id
      Write-Host "Usando dispositivo movil detectado: $($mobileDevice.name) [$DeviceId]"
    }
  }

  if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    Write-Host "Dispositivos disponibles por adb:"
    if (Get-Command adb -ErrorAction SilentlyContinue) {
      adb devices
    }
    Write-Host "Dispositivos disponibles por Flutter:"
    flutter devices
    throw "No hay dispositivo movil detectado (Android/iOS). Conecta tu celular o inicia un emulador."
  }
}

if ($DeviceId -match "android|emulator|^\d+\.\d+\.\d+\.\d+:\d+$|^[A-Z0-9]+$") {
  $adb = Get-Command adb -ErrorAction SilentlyContinue
  if ($adb) {
    try {
      adb -s $DeviceId reverse tcp:8000 tcp:8000 | Out-Null
      Write-Host "ADB reverse activo: dispositivo 127.0.0.1:8000 -> host 127.0.0.1:8000"
    }
    catch {
      Write-Host "No se pudo configurar adb reverse automaticamente: $($_.Exception.Message)"
    }
  }
}


flutter run -d $DeviceId -t lib/main_tutor_mobile.dart `
  --dart-define=SUPABASE_URL=$($cfg["SUPABASE_URL"]) `
  --dart-define=SUPABASE_ANON_KEY=$($cfg["SUPABASE_ANON_KEY"]) `
  --dart-define=FASTAPI_BASE_URL=$ApiBaseUrl
