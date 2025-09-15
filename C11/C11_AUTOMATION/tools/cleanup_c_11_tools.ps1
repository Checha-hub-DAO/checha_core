<#
.SYNOPSIS
  Автоматизована чистка каталогу C11\tools (інвентаризація, архівація варіантів, опційна нормалізація назв, індекс).
.DESCRIPTION
  Скрипт проходить по *.ps1 у C11\tools, групує варіанти одного інструмента (v2, fixed2, final, bak, test, copy, draft),
  залишає один «основний» варіант (без суфіксів, або найновіший), решту переносить у архів і пакує у ZIP з SHA256.
  Також генерує TOOLS_INDEX.md з коротким описом та лог дій у C03\LOG\cleanup_tools.log.
.NOTES
  PowerShell 7+. Підтримує -WhatIf / -Confirm. Запуск від імені користувача з правами на Root.
.PARAMETER Root
  Корінь CHECHA_CORE (за замовчуванням C:\CHECHA_CORE).
.PARAMETER ToolsRel
  Відносний шлях до каталогу інструментів (за замовчуванням C11\tools).
.PARAMETER ArchiveRel
  Відносний шлях до каталогу архівів (за замовчуванням C05\ARCHIVE).
.PARAMETER DryRun
  Лише показати, що буде зроблено, без переміщень та змін.
.PARAMETER NormalizeNames
  Перейменувати «основні» скрипти до стандартизованого вигляду (обережно, опціонально).
.EXAMPLE
  pwsh -NoProfile -File .\Cleanup-C11-Tools.ps1 -Root 'D:\CHECHA_CORE' -WhatIf
.EXAMPLE
  pwsh -NoProfile -File .\Cleanup-C11-Tools.ps1 -Root 'D:\CHECHA_CORE' -NormalizeNames -Confirm:$false
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
Param(
  [string]$Root = 'C:\CHECHA_CORE',
  [string]$ToolsRel = 'C11\tools',
  [string]$ArchiveRel = 'C05\ARCHIVE',
  [switch]$DryRun,
  [switch]$NormalizeNames
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-DirIfMissing([string]$Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Path $Path | Out-Null } }
function Write-Log([string]$Path,[string]$Level,[string]$Msg){
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  Add-Content -Path $Path -Value "$ts [$Level] $Msg"
}

# --- Підготовка шляхів ---
$tools = Join-Path $Root $ToolsRel
$archiveRoot = Join-Path $Root $ArchiveRel
$logDir = Join-Path $Root 'C03\LOG'
New-DirIfMissing $tools
New-DirIfMissing $archiveRoot
New-DirIfMissing $logDir
$logPath = Join-Path $logDir 'cleanup_tools.log'

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sessionDir = Join-Path $archiveRoot ("scripts_cleanup_" + $stamp)
$sessionMoveDir = Join-Path $sessionDir 'old_variants'
$zipPath = Join-Path $sessionDir ("scripts_" + $stamp + '.zip')
$checksumsPath = Join-Path $sessionDir 'CHECKSUMS.txt'

# --- Правила нормалізації базових імен ---
# Видаляємо службові суфікси та маркери копій/чернеток
$SuffixPatterns = @(
  '(?i)[-_\. ]?(?:v\d+(?:\.\d+)*)',
  '(?i)[-_\. ]?fixed\d*',
  '(?i)[-_\. ]?final',
  '(?i)[-_\. ]?backup|bak',
  '(?i)[-_\. ]?copy( \(\d+\))?',
  '(?i)[-_\. ]?draft',
  '(?i)[-_\. ]?test',
  '(?i)\s*-\s*копия( \(\d+\))?'
)

function Get-BaseStem([string]$FileName){
  $stem = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
  foreach($re in $SuffixPatterns){ $stem = [regex]::Replace($stem, $re, '') }
  $stem = $stem -replace '[ _]+','-'
  $stem = $stem.Trim('-_ .')
  if([string]::IsNullOrWhiteSpace($stem)){ $stem = [System.IO.Path]::GetFileNameWithoutExtension($FileName) }
  return $stem
}

function Propose-NormalName([System.IO.FileInfo]$File){
  $stem = Get-BaseStem $File.Name
  $ext = $File.Extension
  return "$stem$ext"
}

# --- Інвентаризація ---
$all = Get-ChildItem -Path $tools -Filter '*.ps1' -File -ErrorAction Stop
if(-not $all){ Write-Log $logPath 'INFO' "Немає *.ps1 у $tools"; return }

# Групуємо за базовим стовбуром (після очищення суфіксів)
$groups = $all | Group-Object { Get-BaseStem $_.Name } | Sort-Object Name

Write-Log $logPath 'INFO' "Початок чистки C11\\tools ($($all.Count) файлів, груп: $($groups.Count))"

$toArchive = New-Object System.Collections.Generic.List[System.IO.FileInfo]
$keepers = New-Object System.Collections.Generic.List[System.IO.FileInfo]

foreach($g in $groups){
  $files = $g.Group | Sort-Object LastWriteTime -Descending
  # Вибір «основного»: 1) Без суфіксів > 2) Найсвіжіший
  $preferred = $files | Where-Object {
    $proposed = Propose-NormalName $_
    # Якщо вже у нормальному вигляді — вважаємо «без суфіксів»
    $proposed -eq $_.Name
  } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if(-not $preferred){ $preferred = $files | Select-Object -First 1 }

  $keepers.Add($preferred)
  foreach($f in $files){ if($f.FullName -ne $preferred.FullName){ $toArchive.Add($f) } }
}

# --- Показ плану дій ---
Write-Host "Буде збережено як основні:" -ForegroundColor Cyan
$keepers | ForEach-Object { Write-Host "  + $($_.Name)" }
Write-Host "\nБудуть перенесені в архів (варіанти):" -ForegroundColor Yellow
$toArchive | ForEach-Object { Write-Host "  - $($_.Name)" }

if($DryRun){ Write-Log $logPath 'INFO' "DryRun: завершено без змін"; return }

# --- Переміщення варіантів у архів ---
New-DirIfMissing $sessionMoveDir
if($toArchive.Count -gt 0){
  foreach($f in $toArchive){
    $dest = Join-Path $sessionMoveDir $f.Name
    if($PSCmdlet.ShouldProcess($f.FullName, "Move -> $dest")){
      Move-Item -Path $f.FullName -Destination $dest -Force
      Write-Log $logPath 'INFO' "MOVE $($f.Name) -> $dest"
    }
  }
}

# --- Нормалізація назв основних (опційно) ---
if($NormalizeNames){
  foreach($k in $keepers){
    $proposed = Propose-NormalName $k
    if($proposed -ne $k.Name){
      $target = Join-Path $k.DirectoryName $proposed
      if(Test-Path $target){
        # уникнути конфлікту: додати тайм-мітку
        $target = Join-Path $k.DirectoryName ("{0}_{1}{2}" -f [System.IO.Path]::GetFileNameWithoutExtension($proposed), $stamp, [System.IO.Path]::GetExtension($proposed))
      }
      if($PSCmdlet.ShouldProcess($k.FullName, "Rename -> $target")){
        Rename-Item -Path $k.FullName -NewName ([System.IO.Path]::GetFileName($target)) -Force
        Write-Log $logPath 'INFO' "RENAME $($k.Name) -> $(Split-Path $target -Leaf)"
      }
    }
  }
}

# --- Пакування архіву + SHA256 ---
if( (Get-ChildItem -Path $sessionMoveDir -File | Measure-Object).Count -gt 0 ){
  if($PSCmdlet.ShouldProcess($sessionMoveDir, "Compress -> $zipPath")){
    Compress-Archive -Path (Join-Path $sessionMoveDir '*') -DestinationPath $zipPath -Force
    $hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
    Set-Content -Path $checksumsPath -Value ("SHA256  {0}  {1}" -f $hash, (Split-Path $zipPath -Leaf)) -Encoding UTF8
    Write-Log $logPath 'INFO' "ZIP $zipPath; SHA256=$hash"
  }
}

# --- Генерація TOOLS_INDEX.md ---
$indexPath = Join-Path $tools 'TOOLS_INDEX.md'
$indexLines = @()
$indexLines += "# C11/tools — індекс робочих скриптів ($stamp)"
$indexLines += ""
foreach($k in (Get-ChildItem -Path $tools -Filter '*.ps1' -File | Sort-Object Name)){
  $syn = (Select-String -Path $k.FullName -Pattern '^\s*\.SYNOPSIS\s*$' -SimpleMatch -Context 0,3 -ErrorAction SilentlyContinue | ForEach-Object {
    # Беремо наступний рядок після .SYNOPSIS як короткий опис
    if($_.Context.PostContext){ $_.Context.PostContext[0].Trim() } else { $null }
  }) | Select-Object -First 1
  if(-not $syn){ $syn = '(опис відсутній)' }
  $indexLines += "- `$(Split-Path $k.Name -Leaf)`: $syn"
}
Set-Content -Path $indexPath -Value ($indexLines -join [Environment]::NewLine) -Encoding UTF8
Write-Log $logPath 'INFO' "INDEX $indexPath оновлено"

Write-Host "\n✅ Готово. Дивись лог: $logPath" -ForegroundColor Green
Write-Host "📦 Архів: $sessionDir"
