<#
  tools/check_release.ps1
  Перевіряє, що GitHub Release має потрібні ассети,
  і (опційно) звіряє SHA256, скачуючи файли з релізу.

  Приклад:
    .\tools\check_release.ps1 -Tag symbols-2025-08-31_1200 -RequireMP4 -VerifyChecksums
#>

param(
  [Parameter(Mandatory=$true)][string]$Tag,
  [switch]$RequireMP4,
  [switch]$RequireChecksums = $true,
  [switch]$VerifyChecksums
)

function Require-Cli($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    Write-Error "CLI '$name' не знайдено у PATH."
    exit 2
  }
}

Require-Cli gh

Write-Host "ℹ️  Перевіряю реліз '$Tag'…" -ForegroundColor Cyan
try {
  $info = gh release view $Tag --json assets,tagName,isPrerelease | ConvertFrom-Json
} catch {
  Write-Error "Реліз '$Tag' не знайдено або немає доступу."
  exit 2
}

$assets = @()
if ($info -and $info.assets) { $assets = $info.assets.name }

# формуємо множину імен ассетів
$assetSet = [System.Collections.Generic.HashSet[string]]::new()
foreach ($n in $assets) { if ($null -ne $n) { [void]$assetSet.Add([string]$n) } }

# Очікуваний набір
$expected = @(
  "C01_symbol_extended_pack_v1.1.zip",
  "C02_symbol_pack_v1.0.zip"
)
if ($RequireChecksums) { $expected += "CHECKSUMS.txt" }
if ($RequireMP4) {
  $expected += @(
    "C02_radial_anim_light.mp4",
    "C02_radial_anim_dark.mp4",
    "C02_radial_vibe_light.mp4",
    "C02_radial_vibe_dark.mp4",
    "C02_wave_anim_light.mp4",
    "C02_wave_anim_dark.mp4",
    "C02_wave_vibe_light.mp4",
    "C02_wave_vibe_dark.mp4"
  )
}

# Вивід таблиці стану
$rows = foreach ($name in $expected) {
  [pscustomobject]@{ Asset = $name; Status = $(if ($assetSet.Contains($name)) { "OK" } else { "MISSING" }) }
}
$rows | Format-Table -AutoSize | Out-String | Write-Host

$missing = $rows | Where-Object { $_.Status -ne "OK" } | Select-Object -ExpandProperty Asset
$hadError = $false
if ($missing.Count -gt 0) {
  Write-Warning ("Відсутні ассети: " + ($missing -join ", "))
  $hadError = $true
} else {
  Write-Host "✅ Базовий набір присутній." -ForegroundColor Green
}

# Перевірка CHECKSUMS (скачуємо з релізу)
if ($VerifyChecksums) {
  if (-not $assetSet.Contains("CHECKSUMS.txt")) {
    Write-Warning "CHECKSUMS.txt відсутній у релізі — перевірка хешів пропущена."
    $hadError = $true
  } else {
    $tmp = Join-Path $env:TEMP ("relchk_" + $Tag + "_" + (Get-Random))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    gh release download $Tag -p "CHECKSUMS.txt" -D $tmp --clobber | Out-Null

    $checks = Get-Content (Join-Path $tmp "CHECKSUMS.txt")
    $mismatch = @()

    foreach ($line in $checks) {
      if ($line -match '^\s*SHA256\s+([A-Fa-f0-9]{64})\s+(.+?)\s*$') {
        $want  = $matches[1].ToLower()
        $fname = $matches[2]

        # скачати конкретний файл для звірки (з релізу)
        gh release download $Tag -p $fname -D $tmp --clobber | Out-Null
        $local = Join-Path $tmp $fname

        if (-not (Test-Path $local)) {
          Write-Warning "Не вдалося завантажити '$fname' для звірки."
          $hadError = $true
          continue
        }

        $got = (Get-FileHash $local -Algorithm SHA256).Hash.ToLower()
        if ($got -ne $want) {
          $mismatch += [pscustomobject]@{ File=$fname; Expected=$want; Actual=$got }
        }
      }
    }

    if ($mismatch.Count -gt 0) {
      Write-Host ""
      Write-Error "❌ Невідповідність SHA256:"
      $mismatch | Format-Table -AutoSize | Out-String | Write-Host
      $hadError = $true
    } else {
      Write-Host "✅ CHECKSUMS.txt збігається з файлами релізу." -ForegroundColor Green
    }
  }
}

if ($hadError) { exit 1 } else { exit 0 }
