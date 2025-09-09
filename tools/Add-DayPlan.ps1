<#
.SYNOPSIS
  Generate a Markdown daily plan with a "Main Focus" section into CHECHA_CORE\C03\LOG.

.DESCRIPTION
  Creates a file named DayPlan_YYYY-MM-DD_FOCUS.md (UTF-8 BOM) under <Root>\C03\LOG
  with a predefined template. Supports backfilling by date, custom focus text, and
  optional Windows Scheduled Task creation for daily automation.

.PARAMETER Root
  Root folder of CHECHA_CORE. Default: C:\CHECHA_CORE

.PARAMETER Date
  Date for the plan (default: today). Accepts strings parseable by [datetime].

.PARAMETER Focus
  Main focus line to prefill into the plan.

.PARAMETER Tasks
  Additional checklist items to add to the "Technical tasks" section.

.PARAMETER Open
  Open the created file with the system default app (Windows: Invoke-Item).

.PARAMETER Force
  Overwrite existing file if present (by default, script will not overwrite).

.PARAMETER CreateTask
  Create a Windows Scheduled Task to auto-run this script daily at -Time.

.PARAMETER Time
  Daily time (HH:mm) for the Scheduled Task. Default: 08:30

.EXAMPLE
  pwsh -File .\Add-DayPlan.ps1 -Root 'C:\CHECHA_CORE' -Focus 'Normalize encodings' -Open

.EXAMPLE
  pwsh -File .\Add-DayPlan.ps1 -CreateTask -Time '09:00'

.NOTES
  Author: CHECHA Assistant
  Encoding: UTF-8 with BOM
#>

[CmdletBinding()]
param(
  [string]$Root = 'C:\CHECHA_CORE',
  [datetime]$Date = (Get-Date),
  [string]$Focus = '',
  [string[]]$Tasks = @(),
  [switch]$Open,
  [switch]$Force,
  [switch]$CreateTask,
  [ValidatePattern('^\d{2}:\d{2}$')][string]$Time = '08:30'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-Utf8BomWriter {
  param([string]$Path)
  $enc = New-Object System.Text.UTF8Encoding($true)
  $sw = New-Object System.IO.StreamWriter($Path, $false, $enc)
  return $sw
}

# Resolve paths
$logDir = Join-Path $Root 'C03\LOG'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$day = $Date.ToString('yyyy-MM-dd')
$file = Join-Path $logDir ("DayPlan_{0}_FOCUS.md" -f $day)

if ((Test-Path $file) -and -not $Force) {
  Write-Host "ℹ️ File already exists: $file (use -Force to overwrite)"
  if ($Open) { Invoke-Item -Path $file }
  return $file
}

# Default tasks (technical/system/balance)
$defaultTech = @(
  "Прогнати нормалізацію кодувань (dry-run → apply) по всьому `CHECHA_CORE`",
  "Замінити дублікати функцій у скриптах: ControlPanel.ps1, RunAll.ps1, Release-check.ps1",
  "Оновити документацію: додати блок про McHelpers у `C12/Protocols/README.md`"
)
$defaultSys = @(
  "Закріпити CI (branch protection) для `PS Module Check` і `PS Release SmokeTest`",
  "Перевірити запуск workflow на PR та тегах"
)
$defaultBalance = @(
  "15–20 хв читання / відпочинку",
  "Перевірка емоційного стану (коротка нотатка у щоденнику)",
  "1 творчий крок (ескіз для DAO-галереї чи нотатка для “Свідомого Суспільства”)"
)

# Merge additional tasks into technical section (if any)
$techAll = @($defaultTech + $Tasks)

# Build Markdown content
$focusLine = if ([string]::IsNullOrWhiteSpace($Focus)) { "(вкажи тут головне завдання, яке треба зробити першим)" } else { $Focus }

$md = @"
# 📅 Денний план — $day

## 🔥 Головний фокус дня
- [ ] $focusLine

## 🔹 Технічні завдання
$( ($techAll | ForEach-Object { "- [ ] $_" }) -join "`n" )

## 🔹 Системна інтеграція
$( ($defaultSys | ForEach-Object { "- [ ] $_" }) -join "`n" )

## 🔹 Легкі / балансуючі кроки
$( ($defaultBalance | ForEach-Object { "- [ ] $_" }) -join "`n" )

---
✍️ Лог автоматично сформовано для `C03/LOG` (формат Markdown, з секцією головного фокусу).
"@

# Write UTF-8 BOM
$sw = New-Utf8BomWriter -Path $file
$sw.Write($md)
$sw.Close()

Write-Host "✅ Created: $file"
if ($Open) { Invoke-Item -Path $file }

# Optional scheduled task
if ($CreateTask) {
  try {
    if ($IsWindows) {
      $taskName = 'CHECHA_AddDayPlan'
      $pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
      $scriptPath = $MyInvocation.MyCommand.Path

      # Build argument line (escape quotes)
      $arg = "-NoProfile -File `"$scriptPath`" -Root `"$Root`""

      $timeParts = $Time.Split(':')
      $hour = [int]$timeParts[0]
      $min  = [int]$timeParts[1]

      $trigger = New-ScheduledTaskTrigger -Daily -At ([datetime]::Today.AddHours($hour).AddMinutes($min).TimeOfDay)
      $action  = New-ScheduledTaskAction -Execute $pwsh -Argument $arg
      $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType InteractiveToken -RunLevel Highest

      try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
      } catch {}

      Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal | Out-Null
      Write-Host "🗓️ Scheduled Task '$taskName' created at $Time"
    } else {
      Write-Warning "CreateTask is only supported on Windows (Scheduled Tasks)."
    }
  } catch {
    Write-Warning "Failed to create scheduled task: $($_.Exception.Message)"
  }
}

return $file
