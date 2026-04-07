param(
  [string]$AccessToken = $env:SUPABASE_ACCESS_TOKEN,
  [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$envPath = Join-Path $repoRoot "backend/.env"

if (-not (Test-Path $envPath)) {
  throw "No se encontro backend/.env en: $envPath"
}

function Read-EnvFile {
  param([string]$Path)

  $cfg = @{}
  foreach ($line in Get-Content $Path) {
    if ($line -match '^\s*#' -or $line -notmatch '=') {
      continue
    }

    $k, $v = $line -split '=', 2
    $cfg[$k.Trim()] = $v.Trim().Trim('"').Trim("'")
  }

  return $cfg
}

function Ensure-NodeTooling {
  param([switch]$SkipInstall)

  $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
  if (-not $nodeCmd) {
    if ($SkipInstall) {
      throw "Node.js no esta instalado y se solicito -SkipInstall."
    }

    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCmd) {
      throw "Node.js no esta instalado y winget no esta disponible para instalarlo automaticamente."
    }

    Write-Host "Instalando Node.js LTS via winget..." -ForegroundColor Yellow
    winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements --silent

    $nodeInstallPath = Join-Path $env:ProgramFiles "nodejs"
    if ((Test-Path $nodeInstallPath) -and ($env:Path -notlike "*$nodeInstallPath*")) {
      $env:Path = "$nodeInstallPath;$env:Path"
    }
  }

  $nodeVersion = node -v
  Write-Host "Node detectado: $nodeVersion" -ForegroundColor Green

  $npxCmd = Get-Command npx -ErrorAction SilentlyContinue
  if (-not $npxCmd) {
    throw "npx no esta disponible aun despues de instalar Node.js. Abre una nueva terminal y reintenta."
  }

  $sbVersion = (& npx --yes supabase@latest --version | Out-String).Trim()
  Write-Host "Supabase CLI (npx): $sbVersion" -ForegroundColor Green
}

function Get-FunctionStatusCode {
  param(
    [string]$Url,
    [string]$Body
  )

  try {
    $response = Invoke-WebRequest -Method Post -Uri $Url -ContentType "application/json" -Body $Body -TimeoutSec 30 -ErrorAction Stop
    return [int]$response.StatusCode
  }
  catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      return [int]$_.Exception.Response.StatusCode.value__
    }

    throw
  }
}

$cfg = Read-EnvFile -Path $envPath

if (-not $cfg.ContainsKey("SUPABASE_URL") -or [string]::IsNullOrWhiteSpace($cfg["SUPABASE_URL"])) {
  throw "Falta SUPABASE_URL en backend/.env"
}

$supabaseUrl = $cfg["SUPABASE_URL"]
if ($supabaseUrl -notmatch '^https://([a-z0-9-]+)\.supabase\.co/?$') {
  throw "SUPABASE_URL no tiene el formato esperado: $supabaseUrl"
}

$projectRef = $Matches[1]
$functions = @(
  "plan-inteligente",
  "recomendacion-puntual",
  "reemplazo-equivalente"
)

Ensure-NodeTooling -SkipInstall:$SkipInstall

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
  throw "No se encontro SUPABASE_ACCESS_TOKEN. Define la variable de entorno o pasa -AccessToken."
}

$env:SUPABASE_ACCESS_TOKEN = $AccessToken
Set-Location $repoRoot

Write-Host "Desplegando Edge Functions en proyecto $projectRef ..." -ForegroundColor Cyan
foreach ($fn in $functions) {
  Write-Host " - Deploy: $fn"
  & npx --yes supabase@latest functions deploy $fn --project-ref $projectRef
}

Write-Host "Verificando reachability de funciones..." -ForegroundColor Cyan
$verification = @()
foreach ($fn in $functions) {
  $url = "https://$projectRef.functions.supabase.co/$fn"
  $statusCode = Get-FunctionStatusCode -Url $url -Body "{}"
  $verification += [PSCustomObject]@{
    function = $fn
    status_code = $statusCode
    ok = ($statusCode -ne 404)
  }
}

$verification | Format-Table -AutoSize

$notFound = $verification | Where-Object { -not $_.ok }
if ($notFound) {
  throw "Hay funciones aun sin desplegar (status 404)."
}

Write-Host "EDGE_FUNCTIONS_DEPLOY_OK" -ForegroundColor Green
