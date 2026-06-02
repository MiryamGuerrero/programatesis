param(
  [switch]$Apply,
  [int]$MaxSide = 900,
  [int]$Quality = 68,
  [string[]]$Buckets = @("receta_imagenes", "imagenes_recetas")
)

$ErrorActionPreference = "Stop"

function Read-EnvFile {
  param([string]$Path)
  $values = @{}
  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) { return }
    $parts = $line.Split("=", 2)
    $values[$parts[0].Trim()] = $parts[1].Trim().Trim('"')
  }
  return $values
}

function Join-StoragePath {
  param([string]$Prefix, [string]$Name)
  if ([string]::IsNullOrWhiteSpace($Prefix)) { return $Name }
  return "$Prefix/$Name"
}

function Get-StorageObjects {
  param([string]$Bucket, [string]$Prefix = "")

  $offset = 0
  $limit = 1000
  while ($true) {
    $body = @{
      prefix = $Prefix
      limit = $limit
      offset = $offset
      sortBy = @{ column = "name"; order = "asc" }
    } | ConvertTo-Json -Depth 5

    $items = Invoke-RestMethod `
      -Method Post `
      -Uri "$script:SupabaseUrl/storage/v1/object/list/$Bucket" `
      -Headers $script:Headers `
      -ContentType "application/json" `
      -Body $body

    if (-not $items -or $items.Count -eq 0) { break }

    foreach ($item in $items) {
      $path = Join-StoragePath -Prefix $Prefix -Name $item.name
      if ($null -eq $item.metadata) {
        Get-StorageObjects -Bucket $Bucket -Prefix $path
      } else {
        [pscustomobject]@{
          Bucket = $Bucket
          Path = $path
          Name = $item.name
          Metadata = $item.metadata
        }
      }
    }

    if ($items.Count -lt $limit) { break }
    $offset += $limit
  }
}

function Test-IsImageObject {
  param($Object)
  $name = $Object.Path.ToLowerInvariant()
  if ($name.EndsWith(".jpg") -or $name.EndsWith(".jpeg") -or $name.EndsWith(".png") -or $name.EndsWith(".webp")) {
    return $true
  }
  $mime = $Object.Metadata.mimetype
  return $mime -and $mime.ToString().StartsWith("image/")
}

function Optimize-ImageBytes {
  param([byte[]]$Bytes, [int]$MaxSide, [int]$Quality)

  Add-Type -AssemblyName System.Drawing

  $inputStream = [System.IO.MemoryStream]::new($Bytes)
  $source = [System.Drawing.Image]::FromStream($inputStream)
  try {
    $width = $source.Width
    $height = $source.Height
    $scale = [Math]::Min(1.0, $MaxSide / [double]([Math]::Max($width, $height)))
    $newWidth = [Math]::Max(1, [int][Math]::Round($width * $scale))
    $newHeight = [Math]::Max(1, [int][Math]::Round($height * $scale))

    $bitmap = [System.Drawing.Bitmap]::new($newWidth, $newHeight)
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($source, 0, 0, $newWidth, $newHeight)
      } finally {
        $graphics.Dispose()
      }

      $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq "image/jpeg" } |
        Select-Object -First 1
      $encoder = [System.Drawing.Imaging.Encoder]::Quality
      $encoderParams = [System.Drawing.Imaging.EncoderParameters]::new(1)
      $encoderParams.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new($encoder, [int64]$Quality)

      $outputStream = [System.IO.MemoryStream]::new()
      $bitmap.Save($outputStream, $jpegCodec, $encoderParams)
      return $outputStream.ToArray()
    } finally {
      $bitmap.Dispose()
    }
  } finally {
    $source.Dispose()
    $inputStream.Dispose()
  }
}

function UrlEncode-Path {
  param([string]$Path)
  return ($Path -split "/" | ForEach-Object { [uri]::EscapeDataString($_) }) -join "/"
}

$envPath = Join-Path $PSScriptRoot "..\.env"
if (-not (Test-Path -LiteralPath $envPath)) {
  throw "No se encontro .env en backend."
}

$envValues = Read-EnvFile -Path $envPath
$script:SupabaseUrl = $envValues["SUPABASE_URL"].TrimEnd("/")
$serviceKey = $envValues["SUPABASE_SERVICE_ROLE_KEY"]
if (-not $script:SupabaseUrl -or -not $serviceKey) {
  throw "Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en backend\.env."
}

$script:Headers = @{
  "apikey" = $serviceKey
  "Authorization" = "Bearer $serviceKey"
}

$backupRoot = Join-Path $PSScriptRoot ("storage_image_backups\" + (Get-Date -Format "yyyyMMdd_HHmmss"))
$tempRoot = Join-Path $env:TEMP ("reumanutri_image_opt_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$processed = 0
$optimized = 0
$skipped = 0
$failed = 0
$beforeTotal = 0L
$afterTotal = 0L

foreach ($bucket in $Buckets) {
  Write-Host "Bucket: $bucket"
  try {
    $objects = Get-StorageObjects -Bucket $bucket | Where-Object { Test-IsImageObject $_ }
  } catch {
    Write-Warning "No se pudo listar ${bucket}: $($_.Exception.Message)"
    continue
  }

  foreach ($object in $objects) {
    $processed++
    try {
      $encodedPath = UrlEncode-Path -Path $object.Path
      $downloadUrl = "$script:SupabaseUrl/storage/v1/object/$bucket/$encodedPath"
      $downloadPath = Join-Path $tempRoot ([guid]::NewGuid().ToString("N"))
      Invoke-WebRequest -Method Get -Uri $downloadUrl -Headers $script:Headers -OutFile $downloadPath
      $originalBytes = [System.IO.File]::ReadAllBytes($downloadPath)
      $newBytes = Optimize-ImageBytes -Bytes $originalBytes -MaxSide $MaxSide -Quality $Quality

      $before = $originalBytes.Length
      $after = $newBytes.Length
      $beforeTotal += $before
      $afterTotal += [Math]::Min($before, $after)

      if ($after -ge $before) {
        $skipped++
        Write-Host ("SKIP {0}/{1}: {2:N0} KB -> {3:N0} KB" -f $bucket, $object.Path, ($before / 1KB), ($after / 1KB))
        continue
      }

      if ($Apply) {
        $backupPath = Join-Path $backupRoot (Join-Path $bucket $object.Path)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupPath) | Out-Null
        [System.IO.File]::WriteAllBytes($backupPath, $originalBytes)

        $uploadUrl = "$script:SupabaseUrl/storage/v1/object/$bucket/$encodedPath"
        $uploadPath = Join-Path $tempRoot ([guid]::NewGuid().ToString("N") + ".jpg")
        [System.IO.File]::WriteAllBytes($uploadPath, $newBytes)
        Invoke-RestMethod `
          -Method Post `
          -Uri $uploadUrl `
          -Headers ($script:Headers + @{ "x-upsert" = "true" }) `
          -ContentType "image/jpeg" `
          -InFile $uploadPath | Out-Null
      }

      $optimized++
      $mode = if ($Apply) { "OK" } else { "DRY" }
      Write-Host ("{0} {1}/{2}: {3:N0} KB -> {4:N0} KB" -f $mode, $bucket, $object.Path, ($before / 1KB), ($after / 1KB))
    } catch {
      $failed++
      Write-Warning "Error con $($object.Bucket)/$($object.Path): $($_.Exception.Message)"
    }
  }
}

$saved = $beforeTotal - $afterTotal
Write-Host ""
Write-Host "Procesadas: $processed"
Write-Host "Optimizables: $optimized"
Write-Host "Omitidas: $skipped"
Write-Host "Fallidas: $failed"
Write-Host ("Estimado antes: {0:N2} MB" -f ($beforeTotal / 1MB))
Write-Host ("Estimado despues: {0:N2} MB" -f ($afterTotal / 1MB))
Write-Host ("Ahorro estimado: {0:N2} MB" -f ($saved / 1MB))
if ($Apply) {
  Write-Host "Backups locales: $backupRoot"
} else {
  Write-Host "Simulacion solamente. Ejecuta con -Apply para sobrescribir en Supabase."
}

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
