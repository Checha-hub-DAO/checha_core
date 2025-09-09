<#
.SYNOPSIS
  TrafficLight-Helper — логування статусу "світлофора" діалогового вікна.

.DESCRIPTION
  Визначає колір (Green/Yellow/Red) за кількістю повідомлень і:
  - пише рядок у C03\LOG\LOG.md
  - оновлює тижневу статистику у C03\LOG\trafficlight.json
  Режими: Start | Update | End

.PARAMETER Mode
  Start | Update | End — фаза сеансу.

.PARAMETER Count
  Кількість повідомлень у поточному вікні.

.PARAMETER Root
  Корінь CHECHA_CORE (за замовчуванням C:\CHECHA_CORE).

.PARAMETER Quiet
  Без консольного виводу (тільки коди виходу).

.OUTPUTS
  Exit code: 0=Green, 1=Yellow, 2=Red

.EXAMPLE
  pwsh -NoProfile -File TrafficLight-Helper.ps1 -Mode Update -Count 34
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('Start','Update','End')]
  [string]$Mode,

  [Parameter(Mandatory=$true)]
  [ValidateRange(0,10000)]
  [int]$Count,

  [string]$Root = "C:\CHECHA_CORE",
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Path {
  param([string]$Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function Get-Color {
  param([int]$Count)
  if ($Count -ge 50) { return 'Red' }
  elseif ($Count -ge 30) { return 'Yellow' }
  else { return 'Green' }
}

function Get-ExitCode {
  param([string]$Color)
  switch ($Color) {
    'Green'  { 0 }
    'Yellow' { 1 }
    'Red'    { 2 }
    default  { 2 }
  }
}

function Now-Stamp {
  # Локальний час (Europe/Kyiv у системи) у форматі YYYY-MM-DD HH:MM:SS
  (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
}

function Write-LogLine {
  param(
    [string]$LogPath,
    [string]$Mode,
    [string]$Color,
    [int]$Count
  )
  $colorIcon = switch ($Color) {
    'Green'  { '🟢' }
    'Yellow' { '🟡' }
    'Red'    { '🔴' }
    default  { '❓' }
  }
  $line = ("{0} [INFO ] TrafficLight {1}: {2} ({3} messages)" -f (Now-Stamp), $Mode, $colorIcon, $Count)
  Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Update-WeekStats {
  param(
    [string]$JsonPath,
    [string]$Mode,
    [string]$Color
  )
  $weekKey = (Get-Date).ToString("yyyy-'\W'ww")
  $data = @{
    schema = 'trafficlight.v1'
    week   = $weekKey
    counters = @{
      sessions        = 0
      ended_green     = 0
      ended_yellow    = 0
      ended_red       = 0
      updates_green   = 0
      updates_yellow  = 0
      updates_red     = 0
      starts_green    = 0
      starts_yellow   = 0
      starts_red      = 0
    }
    last_status = @{
      mode  = $Mode
      color = $Color
      time  = (Now-Stamp)
    }
  }

  if (Test-Path $JsonPath) {
    try   { $existing = Get-Content $JsonPath -Raw | ConvertFrom-Json }
    catch { $existing = $null }
    if ($existing) { $data = $existing }
    if ($data.week -ne $weekKey) {
      # новий тиждень — обнулити лічильники
      $data.week = $weekKey
      $data.counters.sessions       = 0
      $data.counters.ended_green    = 0
      $data.counters.ended_yellow   = 0
      $data.counters.ended_red      = 0
      $data.counters.updates_green  = 0
      $data.counters.updates_yellow = 0
      $data.counters.updates_red    = 0
      $data.counters.starts_green   = 0
      $data.counters.starts_yellow  = 0
      $data.counters.starts_red     = 0
    }
  }

  switch ($Mode) {
    'Start' {
      switch ($Color) {
        'Green'  { $data.counters.starts_green++ }
        'Yellow' { $data.counters.starts_yellow++ }
        'Red'    { $data.counters.starts_red++ }
      }
    }
    'Update' {
      switch ($Color) {
        'Green'  { $data.counters.updates_green++ }
        'Yellow' { $data.counters.updates_yellow++ }
        'Red'    { $data.counters.updates_red++ }
      }
    }
    'End' {
      $data.counters.sessions++
      switch ($Color) {
        'Green'  { $data.counters.ended_green++ }
        'Yellow' { $data.counters.ended_yellow++ }
        'Red'    { $data.counters.ended_red++ }
      }
    }
  }

  $data.last_status = @{ mode=$Mode; color=$Color; time=(Now-Stamp) }
  ($data | ConvertTo-Json -Depth 8) | Set-Content -Path $JsonPath -Encoding UTF8
}

# === Основна логіка ===
$logDir  = Join-Path $Root 'C03\LOG'
$logFile = Join-Path $logDir 'LOG.md'
$json    = Join-Path $logDir 'trafficlight.json'
Ensure-Path $logDir
if (-not (Test-Path $logFile)) {
  Add-Content -Path $logFile -Value "# CHECHA_CORE LOG" -Encoding UTF8
  Add-Content -Path $logFile -Value "" -Encoding UTF8
}

$color = Get-Color -Count $Count
$exit  = Get-ExitCode -Color $color

Write-LogLine -LogPath $logFile -Mode $Mode -Color $color -Count $Count
Update-WeekStats -JsonPath $json -Mode $Mode -Color $color

if (-not $Quiet) {
  Write-Host ("[{0}] Mode={1} Count={2} Color={3} ExitCode={4}" -f (Now-Stamp), $Mode, $Count, $color, $exit)
}

exit $exit
