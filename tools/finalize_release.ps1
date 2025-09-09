<#
  finalize_release.ps1
  1) Guard по dist/* з пер-папковими порогами та патернами (генерує CHECKSUMS.txt)
  2) Staging-пакування ZIPів (виключає сміття), таймштамп + опційний суфікс
  3) CHECKSUMS_ZIPS.txt для ZIPів
  4) Upload у реліз (--clobber)
  5) Prune: лишити лише найсвіжіші ZIPи (можна вимкнути -SkipPrune)
  6) Показати таблицю асетів
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string[]]$DistPath,
  [Parameter(Mandatory=$true)][hashtable]$MinSizeKBPerPath,
  [Parameter(Mandatory=$true)][string]$Tag,

  # Глобальні обов'язкові патерни (якщо для шляху не вказано у -RequireFilesPerPath)
  [string[]]$RequireFiles = @('README*.md','*.*'),

  # Пер-папкові обов'язкові патерни: @{ 'full\path\to\dir' = @('*.svg','*.png') ; ... }
  [hashtable]$RequireFilesPerPath = @{},

  [string]$ChecksumsDist = 'C:\CHECHA_CORE\gallery\CHECKSUMS.txt',
  [string]$ChecksumsZips = 'C:\CHECHA_CORE\gallery\CHECKSUMS_ZIPS.txt',

  # Які dist-папки пакувати в ZIP (за префіксом у шляху)
  [string[]]$ZipPrefixes = @('SYMBOLS','ANIM','BRAND'),

  # Пропустити крок prune
  [switch]$SkipPrune,

  # Заборонені імена файлів у проді (перевіряються перед guard)
  [string[]]$ForbiddenNames = @('padding.bin','placeholder.*'),
  [switch]$SkipForbiddenCheck,

  # Виключення з ZIP (завжди ігноруються при пакуванні)
  [string[]]$ExcludeFromZip = @('padding.bin','placeholder.*'),

  # Додатковий суфікс до імен ZIPів, наприклад: -ZipNameSuffix 'prod' -> *_YYYYmmdd_HHmm_prod.zip
  [string]$ZipNameSuffix = ''
)

$ErrorActionPreference = 'Stop'
$guard = Join-Path $PSScriptRoot 'release-assets-guard.ps1'
$show  = 'C:\CHECHA_CORE\tools\Show-ReleaseAssets.ps1'

function Join-Parts {
  param([string[]]$arr)
  return ($arr -join ', ')
}

# 0) Перевірка заборонених файлів у dist/ (можна вимкнути -SkipForbiddenCheck)
if (-not $SkipForbiddenCheck -and $ForbiddenNames.Count -gt 0) {
  $bad = foreach($d in $DistPath){
    if (Test-Path -LiteralPath $d) {
      Get-ChildItem -LiteralPath $d -Recurse -File -EA SilentlyContinue |
        Where-Object {
          foreach ($pat in $ForbiddenNames) { if ($_.Name -like $pat) { return $true } }
          return $false
        }
    }
  }
  if ($bad) {
    Write-Host "Forbidden files present:`n$($bad.FullName -join "`n")" -ForegroundColor Red
    exit 2
  }
}

# 1) Guard + CHECKSUMS.txt
$guardArgs = @{
  DistPath            = $DistPath
  MinSizeKBPerPath    = $MinSizeKBPerPath
  RequireFiles        = $RequireFiles
  RequireFilesPerPath = $RequireFilesPerPath
  ChecksumOut         = $ChecksumsDist
}
& $guard @guardArgs
if ($LASTEXITCODE -ne 0) {
  Write-Host "Guard failed (exit $LASTEXITCODE)" -ForegroundColor Red
  exit $LASTEXITCODE
}

# 2) Збірка ZIPів зі staging (без сміття)
$stamp  = Get-Date -Format 'yyyyMMdd_HHmm'
$suffix = if ([string]::IsNullOrEmpty($ZipNameSuffix)) { '' } else { "_$ZipNameSuffix" }
$zipList = @()

foreach($pfx in $ZipPrefixes){
  $src = $DistPath | Where-Object { $_ -match "\\$pfx\\dist$" }
  if (-not $src) { continue }

  $zip  = "C:\CHECHA_CORE\gallery\{0}_{1}{2}.zip" -f $pfx, $stamp, $suffix
  if (Test-Path $zip) { Remove-Item $zip -Force }

  $stg = Join-Path $env:TEMP ("checha_pack_{0}_{1}" -f $pfx, $stamp)
  if (Test-Path $stg) { Remove-Item $stg -Recurse -Force }
  New-Item $stg -ItemType Directory | Out-Null

  # Копіюємо все, окрім ExcludeFromZip
  $exclude = $ExcludeFromZip
  Copy-Item -Path (Join-Path $src '*') -Destination $stg -Recurse -Force -Exclude $exclude

  Compress-Archive -Path (Join-Path $stg '*') -DestinationPath $zip -Force
  Remove-Item $stg -Recurse -Force

  $zipList += $zip
}

# 3) CHECKSUMS_ZIPS.txt
if ($zipList.Count -gt 0) {
  Get-FileHash $zipList -Algorithm SHA256 |
    ForEach-Object { "{0} *{1}" -f $_.Hash, $_.Path } |
    Set-Content $ChecksumsZips -Encoding UTF8
}

# 4) Upload у реліз
if ($zipList.Count -gt 0) {
  gh release upload $Tag $zipList $ChecksumsZips --clobber
}

# 5) Prune (якщо не вимкнено)
if (-not $SkipPrune) {
  $assets = (gh release view $Tag --json assets | ConvertFrom-Json).assets
  foreach($pfx in $ZipPrefixes){
    $grp = $assets | Where-Object { $_.name -like "$pfx`_*.zip" } | Sort-Object name
    if ($grp.Count -gt 1) {
      $keep = $grp[-1]
      $drop = $grp[0..($grp.Count-2)]
      $drop | ForEach-Object { gh release delete-asset $Tag $_.name --yes }
    }
  }
}

# 6) Підсумок
if (Test-Path $show) {
  & $show -Tag $Tag
} else {
  (gh release view $Tag --json assets | ConvertFrom-Json).assets |
    Select-Object name,size
}
Write-Host "finalize_release: DONE" -ForegroundColor Green
exit 0
