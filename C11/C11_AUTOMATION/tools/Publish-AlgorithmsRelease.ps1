<# 
.SYNOPSIS
  Публікація релізу CheCha Algorithms v1.2 у GitHub з автозбором ZIP/CHECKSUMS.

.DESCRIPTION
  Якщо ZIP або CHECKSUMS відсутні — скрипт збере їх із SourceDir.
  Вміє перевіряти SHA256, створювати або оновлювати реліз, перезаливати артефакти.

.PARAMETERS
  -Tag, -Title, -Repo, -ZipPath, -ChecksumsPath, -NotesPath, -SourceDir
  -Draft, -PreRelease, -ValidateHashes, -Overwrite
#>

[CmdletBinding()]
param(
  [string]$Tag            = "algorithms-v1.2",
  [string]$Title          = "CheCha Algorithms v1.2",
  [string]$ZipPath        = "C:\CHECHA_CORE\C05_ARCHIVE\CheCha_Algorithms_v1.2_Pack.zip",
  [string]$ChecksumsPath  = "C:\CHECHA_CORE\C05_ARCHIVE\CHECKSUMS_v1.2.txt",
  [string]$NotesPath      = "C:\CHECHA_CORE\C05_ARCHIVE\RELEASE_NOTES_v1.2.md",
  [string]$SourceDir      = "C:\CHECHA_CORE\C05_ARCHIVE\_src_v1.2",
  [string]$Repo           = "<owner>/<repo>",
  [switch]$Draft,
  [switch]$PreRelease,
  [switch]$ValidateHashes,
  [switch]$Overwrite
)

$ErrorActionPreference = "Stop"
function Write-Step($msg){ Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail($msg){ throw $msg }

# 0) gh CLI + auth
Write-Step "Перевірка наявності gh"
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Fail "gh не знайдено у PATH. Встанови GitHub CLI." }

Write-Step "Перевірка автентифікації gh"
try { gh auth status 2>$null | Out-Null } catch { Fail "gh не автентифіковано. Запусти: gh auth login" }

if ($Repo -eq "<owner>/<repo>") { Fail "Задай -Repo у форматі owner/name" }

# 1) Якщо ZIP або CHECKSUMS відсутні — автозбір з SourceDir
$needAssemble = (-not (Test-Path $ZipPath)) -or (-not (Test-Path $ChecksumsPath))
if ($needAssemble) {
  Write-Step "ZIP або CHECKSUMS відсутні — автозбір із $SourceDir"
  if (-not (Test-Path $SourceDir)) { Fail "Немає SourceDir: $SourceDir. Вкажи правильну теку з файлами v1.2." }

  $srcFiles = @(
    "CheCha_Algorithms_v1.2.md",
    "CheCha_Algorithms_v1.2.xlsx",
    "CheCha_Algorithms_v1.2.csv",
    "CheCha_Algorithms_v1.2.json",
    "CheCha_Algorithms_v1.2.png",
    "CheCha_Algorithms_v1.2.svg"
  ) | ForEach-Object { Join-Path $SourceDir $_ }

  foreach ($f in $srcFiles) {
    if (-not (Test-Path $f)) { Fail "Не знайдено файл у SourceDir: $f" }
  }

  # Notes: якщо не існує $NotesPath — шукаємо в SourceDir
  if (-not (Test-Path $NotesPath)) {
    $NotesPath = Join-Path $SourceDir "RELEASE_NOTES_v1.2.md"
    if (-not (Test-Path $NotesPath)) { Fail "Не знайдено нотатки релізу: $NotesPath" }
  }

  New-Item -ItemType Directory -Force -Path (Split-Path $ZipPath) | Out-Null

  # ZIP
  if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
  Compress-Archive -Path ($srcFiles + $NotesPath) -DestinationPath $ZipPath

  # CHECKSUMS
  "# CHECKSUMS for CheCha Algorithms v1.2" | Set-Content -Encoding UTF8 $ChecksumsPath
  foreach ($f in ($srcFiles + $NotesPath)) {
    $h = (Get-FileHash $f -Algorithm SHA256).Hash.ToLower()
    Add-Content $ChecksumsPath "$h  $(Split-Path $f -Leaf)"
  }
  $hz = (Get-FileHash $ZipPath -Algorithm SHA256).Hash.ToLower()
  Add-Content $ChecksumsPath "$hz  $(Split-Path $ZipPath -Leaf)"

  Write-Host "OK: Автозбір ZIP/CHECKSUMS завершено." -ForegroundColor Green
}

# 2) Опційна валідація SHA256 ZIP із CHECKSUMS
if ($ValidateHashes) {
  Write-Step "Валідація SHA256 ZIP із CHECKSUMS"
  $zipHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLower()
  $chkLine = (Get-Content $ChecksumsPath -Raw) -split "`r?`n" | Where-Object { $_ -match '\S' -and -not $_.StartsWith("#") } |
             Where-Object { $_ -match [Regex]::Escape([IO.Path]::GetFileName($ZipPath)) } | Select-Object -First 1
  if (-not $chkLine) { Fail "Не знайдено рядка з хешем для $(Split-Path $ZipPath -Leaf) у CHECKSUMS" }
  $m = [regex]::Match($chkLine, '([a-f0-9]{64})')
  if (-not $m.Success) { Fail "Не вдалося витягти SHA256 із CHECKSUMS" }
  $chkHash = $m.Groups[1].Value.ToLower()
  if ($zipHash -ne $chkHash) { Fail "SHA256 не збігається! ZIP=$zipHash, CHECKSUMS=$chkHash" }
  Write-Host "OK: SHA256 збігається" -ForegroundColor Green
}

# 3) Перевірка існування релізу
Write-Step "Перевірка існування релізу $Tag у $Repo"
$exists = $false
try { gh release view $Tag --repo $Repo *> $null; $exists = $true } catch { $exists = $false }

if ($exists -and $Overwrite) {
  Write-Step "Видаляю існуючий реліз $Tag (Overwrite)"
  gh release delete $Tag --repo $Repo --yes
  $exists = $false
}

# 4) Створення/оновлення релізу
if (-not $exists) {
  Write-Step "Створення релізу $Tag"
  $args = @("release","create",$Tag,"--repo",$Repo,"--title",$Title,"--notes-file",$NotesPath)
  if ($Draft)     { $args += "--draft" }
  if ($PreRelease){ $args += "--prerelease" }
  $args += @($ZipPath,$ChecksumsPath)
  gh @args
} else {
  Write-Step "Оновлення релізу $Tag (довантаження артефактів та нотаток)"
  gh release edit   $Tag --repo $Repo --title $Title --notes-file $NotesPath
  gh release upload $Tag $ZipPath $ChecksumsPath --repo $Repo --clobber
}

Write-Host "`n✔ Готово: реліз $Tag у $Repo оновлено/створено." -ForegroundColor Green
