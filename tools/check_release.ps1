<#
  tools/check_release.ps1
  Перевіряє, що GitHub Release має всі потрібні ассети,
  і (опційно) звіряє SHA256 з локальними файлами.

  Використання:
    .\tools\check_release.ps1 -Tag symbols-2025-08-31_1200 -RequireMP4 -VerifyChecksums

  Параметри:
    -Tag               тег релізу (напр. symbols-YYYY-MM-DD_HHMM, або symbols_next)
    -RequireMP4        вимагати 8 MP4 (C02 radial/wave × light/dark)
    -RequireChecksums  вимагати CHECKSUMS.txt (за замовчуванням УВІМКНЕНО)
    -VerifyChecksums   завантажити CHECKSUMS.txt і звірити з локальними файлами
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
  $json = gh release view $Tag --json assets,tagName,isPrerelease --jq .
} catch {
  Write-Error "Реліз '$Tag' не знайдено або немає доступу."
  exit 2
}

$assets = (gh release view $Tag --json assets --jq ".assets[].name") -split "`r?`n" | Where-Object { $_ }
$assetSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$assets)

# Очікуваний базовий набір
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

$missing = @()
foreach ($name in $expected) {
  if (-not $assetSet.Contains($name)) { $missing += $name }
}

# Вивід таблиці
$rows = @()
foreach ($name in $expected) {
  $rows += [pscustomobject]@{
    Asset  = $name
    Status = $(if ($assetSet.Contains($name)) { "OK" } else { "MISSING" })
  }
}
$rows | Format-Table -AutoSize | Out-String | Write-Host

$hadError = $false
if ($missing.Count -gt 0) {
  Write-Warning ("Відсутні ассети: " + ($missing -join ", "))
  $hadError = $true
} else {
  Write-Host "✅ Базовий набір присутній." -ForegroundColor Green
}

# Перевірка чекcум (опційно)
if ($VerifyChecksums) {
  if (-not $assetSet.Contains("CHECKSUMS.txt")) {
    Write-Warning "CHECKSUMS.txt відсутній у релізі — перевірка хешів пропущена."
    $hadError = $true
  } else {
    $tmp = Join-Path $env:TEMP ("relchk_" + $Tag + "_" + (Get-Random))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    gh release download $Tag -p "CHECKSUMS.txt" -D $tmp --clobber | Out-Null
    $checks = Get-Content (Join-Path $tmp "CHECKSUMS.txt")

    # Спроба знайти локальні файли у релізній теці або в пак-фолдерах
    $baseRel = Join-Path (Get-Location) ("release\release_{0}" -f $Tag)
    $candidates = @($tmp) "c01_pack"),
      (Join-Path (Get-Location) "c02_pack")
    )

    $mismatch = @()
    foreach ($line in $checks) {
      if ($line -match '^\s*SHA256\s+([A-Fa-f0-9]{64})\s+(.+?)\s*$') {
        $want = $matches[1].ToLower()
        $fname = $matches[2]

        # Пошук локального файлу
        $local = $null
        foreach ($dir in $candidates) {
          $p = Join-Path $dir $fname
          if (Test-Path $p) { $local = $p; break }
        }

        if (-not $local) {
          Write-Warning "Локальний файл для '$fname' не знайдено — пропускаю звірку."
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
      Write-Host "✅ CHECKSUMS.txt збігається з локальними файлами." -ForegroundColor Green
    }
  }
}

if ($hadError) { exit 1 } else { exit 0 }

