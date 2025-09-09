<#
.SYNOPSIS
  Отримує/оновлює кількість повідомлень у поточному діалоговому вікні.

.DESCRIPTION
  Джерела (у режимі -Source Auto):
    1) ENV: CHECHA_DIALOG_COUNT (якщо є і валідне число)
    2) Файл: C03\LOG\dialog_count.txt (за замовчуванням або вказаний -FilePath)
    3) -DefaultValue (як запасний варіант)

  Підтримує:
    -Increment         : збільшити знайдене значення на 1 і зберегти (у файл і ENV).
    -Set <int>         : примусово встановити значення (перезапис файлу і ENV).
    -Source Env|File|Auto
    -Root              : корінь CHECHA_CORE (default: C:\CHECHA_CORE)

.EXAMPLES
  pwsh -NoProfile -File Get-DialogCount.ps1               # авто-визначення
  pwsh -NoProfile -File Get-DialogCount.ps1 -Increment    # +1 і збереження
  pwsh -NoProfile -File Get-DialogCount.ps1 -Set 35       # примусово 35
  pwsh -NoProfile -File Get-DialogCount.ps1 -Source Env
  pwsh -NoProfile -File Get-DialogCount.ps1 -FilePath "D:\...\dialog_count.txt"

.OUTPUTS
  Пише число у stdout. ExitCode=0 у разі успіху.
#>

[CmdletBinding()]
Param(
  [ValidateSet('Env','File','Auto')]
  [string]$Source = 'Auto',

  [string]$Root = 'C:\CHECHA_CORE',

  [string]$FilePath,

  [int]$DefaultValue = 0,

  [switch]$Increment,

  [int]$Set
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

# --- Обчислити шлях до файлика лічильника (за замовчуванням)
if (-not $FilePath) {
  $logDir  = Join-Path $Root 'C03\LOG'
  Ensure-Dir $logDir
  $FilePath = Join-Path $logDir 'dialog_count.txt'
}

# --- Якщо вказано -Set — записати та вийти
if ($PSBoundParameters.ContainsKey('Set')) {
  $val = [Math]::Max(0, [int]$Set)
  # Запис у файл
  Set-Content -Path $FilePath -Value $val -Encoding ASCII
  # Оновити ENV для поточної сесії
  $env:CHECHA_DIALOG_COUNT = "$val"
  Write-Output $val
  exit 0
}

function TryGet-Env {
  $s = $env:CHECHA_DIALOG_COUNT
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  if ([int]::TryParse($s, [ref]([int]$null))) { return [int]$s }
  return $null
}

function TryGet-File([string]$Path) {
  if (-not (Test-Path $Path)) { return $null }
  try {
    $raw = (Get-Content -Path $Path -Raw -Encoding ASCII).Trim()
    if ([int]::TryParse($raw, [ref]([int]$null))) { return [int]$raw }
    return $null
  } catch { return $null }
}

# --- Вибір джерела
[int]$count = $null
switch ($Source) {
  'Env'  { $count = TryGet-Env }
  'File' { $count = TryGet-File -Path $FilePath }
  'Auto' {
    $count = TryGet-Env
    if ($null -eq $count) { $count = TryGet-File -Path $FilePath }
  }
}

if ($null -eq $count) { $count = [Math]::Max(0, [int]$DefaultValue) }

# --- Режим інкремента
if ($Increment) {
  $count++
  # Пишемо в файл та ENV
  Set-Content -Path $FilePath -Value $count -Encoding ASCII
  $env:CHECHA_DIALOG_COUNT = "$count"
}

# --- Завжди синхронізуємо ENV та файл (щоб інші скрипти бачили однаково)
#     (не перезаписуємо файл зайвий раз, лише якщо відрізняється)
try {
  $fileVal = TryGet-File -Path $FilePath
  if ($fileVal -ne $count) {
    Set-Content -Path $FilePath -Value $count -Encoding ASCII
  }
} catch { }

$env:CHECHA_DIALOG_COUNT = "$count"

Write-Output $count
exit 0
