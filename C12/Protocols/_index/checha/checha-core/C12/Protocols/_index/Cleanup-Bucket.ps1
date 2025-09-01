param(
  [string]$Prefix = 'checha/checha-core/C12/Protocols',
  [int]$OlderThanDays = 60,
  [switch]$DryRun = $true,
  [switch]$Confirm
)
$ErrorActionPreference='Stop'

# 0) Базова санітарія
if ($Prefix -notmatch '/C12/Protocols$') {
  throw "Refusing to operate on '$Prefix' (not a C12/Protocols prefix)."
}

# 1) Знаходимо mc
$mc = (Get-Command mc -ErrorAction SilentlyContinue)?.Source
if (-not $mc -and (Test-Path 'C:\Tools\minio\mc.exe')) { $mc = 'C:\Tools\minio\mc.exe' }
if (-not $mc) { throw "mc.exe not found in PATH or C:\Tools\minio\mc.exe" }

# 2) Локальний корінь для filesystem-аліаса (захист від видалення каталогу)
$localRoot = Join-Path $env:USERPROFILE ( ($Prefix -replace '^[^/]+/', '') -replace '/', '\' )
if (-not (Test-Path $localRoot -PathType Container)) { $localRoot = $null }  # на випадок, якщо alias інший

# 3) Кандидати від mc find
$older = "{0}d" -f $OlderThanDays
$raw = & $mc find $Prefix --older-than $older 2>$null | ForEach-Object { $_.Trim() } |
       Where-Object { $_ }  # не пусті

# 4) Фільтруємо: лише файли (Leaf), ніколи не корінь, і не сам $Prefix (для не-файлових аліасів)
$lines = foreach ($x in $raw) {
  $isLocal = $x -match '^[a-zA-Z]:\\|^\\\\'
  if ($isLocal) {
    # локальний шлях -> маємо можливість точно перевірити тип
    if ($localRoot -and ([IO.Path]::GetFullPath($x) -ieq [IO.Path]::GetFullPath($localRoot))) { continue } # корінь
    if (-not (Test-Path -LiteralPath $x -PathType Leaf)) { continue } # не файл -> пропускаємо
    $x
  } else {
    # не локальний (s3/MinIO), надійний спосіб відсікати корінь:
    if ($x -eq $Prefix -or $x -eq "$Prefix/") { continue }
    # каталог у MinIO зазвичай закінчується '/', але лишаємо додаткову перевірку:
    if ($x.TrimEnd('/') -eq $Prefix) { continue }
    $x
  }
}

# 5) Нема що видаляти — вихід
if (-not $lines -or $lines.Count -eq 0) {
  Write-Host "Nothing older than $OlderThanDays days under $Prefix"
  exit 0
}

# 6) Лог-список
$logs = Join-Path (Join-Path $PSScriptRoot 'logs') ("to_delete_{0}d.txt" -f $OlderThanDays)
New-Item -ItemType Directory -Force (Split-Path $logs) | Out-Null
$lines | Set-Content -Encoding ASCII $logs
Write-Host "Candidates: $($lines.Count)  ->  $logs"

# 7) Dry-run або реальне видалення
if ($DryRun) {
  Write-Host "DRY-RUN: showing first 20"
  $lines | Select-Object -First 20 | ForEach-Object { " - $_" } | Write-Host
  Write-Host "To actually remove: re-run with -DryRun:`$false -Confirm"
  exit 0
}

if (-not $Confirm) {
  throw "Refusing to delete without -Confirm"
}

Get-Content $logs | & $mc rm --force --stdin
Write-Host "Removal done."
