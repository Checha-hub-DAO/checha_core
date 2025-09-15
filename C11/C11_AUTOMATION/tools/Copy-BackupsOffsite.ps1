[CmdletBinding()]
Param(
  [string]$SourceDir = "$env:USERPROFILE\CHECHA_BACKUPS",
  [string]$OffsiteDir = "AUTO",   # "AUTO" → обрати найкращий носій; або вкажи явний шлях (X:\..., \\server\share\...)
  [int]$Keep = 12
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-OffsiteDir([string]$Desired) {
  if ([string]::IsNullOrWhiteSpace($Desired) -or $Desired -eq "AUTO") {
    # кандидати: знімні (2) та локальні (3) диски з вільним місцем > 5GB
    $cands = Get-CimInstance Win32_LogicalDisk |
      Where-Object { $_.DriveType -in 2,3 -and $_.FreeSpace -gt 5GB }

    # пріоритет: спочатку знімні, далі локальні; усередині — за вільним місцем
    $cand = $cands | Sort-Object @{Expression = { $_.DriveType -eq 2 }; Descending = $true}, FreeSpace -Descending | Select-Object -First 1

    if ($cand) {
      return (Join-Path ($cand.DeviceID + '\') 'CHECHA_OFFSITE')
    }

    if (Get-PSDrive -Name D -ErrorAction SilentlyContinue) { return 'D:\CHECHA_OFFSITE' }
    throw "Не знайдено придатного off-site носія (removable/local з >5GB). Вкажи -OffsiteDir явно (напр., 'F:\CHECHA_OFFSITE' або '\\NAS\Backups\CHECHA_OFFSITE')."
  }
  return $Desired
}

if (-not (Test-Path $SourceDir)) { throw "SourceDir not found: $SourceDir" }
$OffsiteDir = Resolve-OffsiteDir $OffsiteDir

# Якщо шлях типу X:\..., перевіримо, що літера диска існує
if ($OffsiteDir -match '^[A-Za-z]:\\') {
  $drive = $OffsiteDir.Substring(0,1)
  if (-not (Get-PSDrive -Name $drive -ErrorAction SilentlyContinue)) {
    throw ("Диск '{0}:' недоступний. Підключи носій або задай інший -OffsiteDir." -f $drive)
  }
}

# Створимо цільову теку
New-Item -ItemType Directory -Force -Path $OffsiteDir | Out-Null

# Шляхи checksums
$srcChecks = Join-Path $SourceDir 'CHECKSUMS.txt'
$ofsChecks = Join-Path $OffsiteDir 'CHECKSUMS.txt'
if (-not (Test-Path $srcChecks)) { throw "Source checksums not found: $srcChecks" }
if (-not (Test-Path $ofsChecks)) { New-Item -ItemType File -Force -Path $ofsChecks | Out-Null }

# Останні $Keep архівів з джерела
$latest = Get-ChildItem -LiteralPath $SourceDir -Filter 'CHECHA_CORE_PUSH_*.zip' |
  Sort-Object LastWriteTime -Descending | Select-Object -First $Keep

foreach ($z in $latest) {
  $name = $z.Name
  $dst  = Join-Path $OffsiteDir $name

  if (-not (Test-Path $dst)) {
    Copy-Item -LiteralPath $z.FullName -Destination $dst -Force
  }

  # SHA з джерела (із CHECKSUMS, або перерахуємо)
  $m = Select-String -Path $srcChecks -Pattern ("^{0}\s+([0-9A-Fa-f]{{64}})\s*$" -f [regex]::Escape($name)) -ErrorAction SilentlyContinue
  $shaSrc = if ($m) { $m.Matches[0].Groups[1].Value } else { (Get-FileHash $z.FullName -Algorithm SHA256).Hash }

  # Перевірка копії
  $shaDst = (Get-FileHash $dst -Algorithm SHA256).Hash
  if ($shaDst -ne $shaSrc) {
    Remove-Item $dst -Force -ErrorAction SilentlyContinue
    throw ("SHA mismatch for {0} at Offsite ({1} != {2})." -f $name, $shaDst, $shaSrc)
  }

  # Оновити/додати запис у offsite CHECKSUMS
  $escaped = [regex]::Escape($name)
  $pat = ("^{0}\s+[0-9A-Fa-f]{{64}}\s*$" -f $escaped)
  if (Select-String -Path $ofsChecks -Pattern $pat -Quiet -ErrorAction SilentlyContinue) {
    (Get-Content $ofsChecks) | ForEach-Object {
      if ($_ -match $pat) { "{0}  {1}" -f $name, $shaSrc } else { $_ }
    } | Set-Content -Path $ofsChecks -Encoding utf8
  } else {
    Add-Content -Path $ofsChecks -Value ("{0}  {1}" -f $name, $shaSrc) -Encoding utf8
  }
}

# Ротація на off-site
if ($Keep -gt 0) {
  $all = Get-ChildItem -LiteralPath $OffsiteDir -Filter 'CHECHA_CORE_PUSH_*.zip' |
    Sort-Object LastWriteTime -Descending
  if ($all.Count -gt $Keep) {
    $all | Select-Object -Skip $Keep | Remove-Item -Force
    $now = Get-ChildItem -LiteralPath $OffsiteDir -Filter 'CHECHA_CORE_PUSH_*.zip' |
      Sort-Object LastWriteTime
    $tmp = New-TemporaryFile
    foreach ($f in $now) {
      "{0}  {1}" -f $f.Name, (Get-FileHash $f.FullName -Algorithm SHA256).Hash |
        Add-Content -Path $tmp -Encoding utf8
    }
    Get-Content $tmp | Set-Content -Path $ofsChecks -Encoding utf8
    Remove-Item $tmp -Force
  }
}

Write-Host ("[OFFSITE] OK → {0}" -f $OffsiteDir)
exit 0
