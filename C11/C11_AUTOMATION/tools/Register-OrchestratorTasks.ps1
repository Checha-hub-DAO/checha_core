<# 
  Register-OrchestratorTasks.ps1 (v3.4)
  Створює/перевстановлює/видаляє та запускає задачі Планувальника для Checha-Orchestrator.
  Папка задач: \Checha\

  Дії:
    -Action Install     : створити/оновити три задачі (Daily/Weekly/Monthly)
    -Action Reinstall   : видалити (з бекапом XML) і знову створити
    -Action Status      : показати стан трьох задач
    -Action RunDaily    : примусовий запуск Daily
    -Action RunWeekly   : примусовий запуск Weekly
    -Action RunMonthly  : примусовий запуск Monthly
    -Action Uninstall   : видалити задачі (з бекапом XML)

  Приклади:
    pwsh -NoProfile -File .\Register-OrchestratorTasks.ps1 -Action Install
    pwsh -NoProfile -File .\Register-OrchestratorTasks.ps1 -Action Status
#>

param(
  [ValidateSet('Install','Reinstall','Status','RunDaily','RunWeekly','RunMonthly','Uninstall')]
  [string]$Action = 'Status',

  # Де зберігається сам оркестратор
  [string]$OrchestratorPath = 'C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Checha-Orchestrator.ps1',

  # Папка задач у Планувальнику
  [string]$TaskPath = '\Checha\',

  # Часи запуску
  [string]$DailyTime   = '09:00',
  [string]$WeeklyTime  = '20:00',
  [string]$MonthlyTime = '21:00',

  # Чи форсити скрипти у відповідних режимах (додає -ForceRun у /TR)
  [switch]$ForceWeekly,
  [switch]$ForceMonthly = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Легкий shim для логування (якщо Write-Log відсутній) --------------------
if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
  function Write-Log {
    param(
      [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO',
      [Parameter(Mandatory)][string]$Message
    )
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "{0} [{1,-5}] {2}" -f $ts, $Level.ToUpper(), $Message
    Write-Host $line
  }
}

# --- Основні імена ------------------------------------------------------------
$TN_D = 'Checha-Orchestrator-Daily'
$TN_W = 'Checha-Orchestrator-Weekly'
$TN_M = 'Checha-Orchestrator-Monthly'
$AllNames = @($TN_D,$TN_W,$TN_M)

# --- Довідкові шляхи ----------------------------------------------------------
$Pwsh = (Get-Command pwsh -ErrorAction Stop).Source
# Де зберігати бекапи XML задач
$BackupsDir = 'C:\CHECHA_CORE\C11\Backups'
if (-not (Test-Path $BackupsDir)) { New-Item -ItemType Directory -Force -Path $BackupsDir | Out-Null }

# --- Утиліти ------------------------------------------------------------------
function Build-TR {
  param(
    [Parameter(Mandatory)][ValidateSet('Daily','Weekly','Monthly')][string]$Mode,
    [switch]$Force
  )
  # Правильний /TR з усіма лапками
  $tr = "`"$Pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$OrchestratorPath`" -Mode $Mode"
  if ($Force) { $tr += ' -ForceRun' }
  return $tr
}

function Ensure-Create {
  param([Parameter(Mandatory)][string]$CmdLine)
  Write-Log INFO ("schtasks: {0}" -f $CmdLine)
  $out = & cmd.exe /c $CmdLine 2>&1
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    $msg = "Помилка schtasks (exit={0}) під час: {1}`n{2}" -f $code, $CmdLine, ($out -join [Environment]::NewLine)
    throw $msg
  }
  return $out
}

function Export-TaskXml {
  param([Parameter(Mandatory)][string]$TaskName)
  $tnFull = if ($TaskName -like '\*') { $TaskName } else { "$TaskPath$TaskName" }
  try {
    $xml = & schtasks /Query /TN "$tnFull" /XML 2>$null
    if ($LASTEXITCODE -eq 0 -and $xml) {
      $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
      $safe  = ($TaskName -replace '[\\/:*?"<>|]','_')
      $file  = Join-Path $BackupsDir ("{0}_{1}.xml" -f $safe,$stamp)
      Set-Content -Path $file -Value $xml -Encoding UTF8
      Write-Log INFO ("Експортовано {0} → {1}" -f $tnFull,$file)
    }
  } catch {
    Write-Log WARN ("Не вдалося експортувати {0}: {1}" -f $tnFull, $_.Exception.Message)
  }
}

function Register-Orch-Task {
  param(
    [Parameter(Mandatory)][string]$TaskName,
    [Parameter(Mandatory)][string]$TR,
    [Parameter(Mandatory)][ValidateSet('DAILY','WEEKLY','MONTHLY')][string]$Schedule,
    [Parameter(Mandatory)][string]$StartTime,
    [string]$Extra = ''
  )
  $tnFull = "$TaskPath$TaskName"
  # Створюємо/оновлюємо (RL HIGHEST для надійного доступу)
  $cmd = "schtasks /Create /TN `"$tnFull`" /TR `"$TR`" /SC $Schedule /ST $StartTime /F /RL HIGHEST"
  if ($Extra) { $cmd += " $Extra" }
  Ensure-Create $cmd | Out-Null
}

function Show-Status {
  param([string[]]$Names)
  $map = @{
    0         = '0x0    - Success'
    1         = '0x1    - General failure'
    10        = '0xA    - Missing tools (strict)'
    99        = '0x63   - Step exception'
    267008    = '0x41300 - Queued'
    267009    = '0x41301 - Running'
    267010    = '0x41302 - Disabled'
    267011    = '0x41303 - Ready'
    267012    = '0x41304 - Not Scheduled'
    267014    = '0x41306 - Terminated'
  }
  foreach ($n in $Names) {
    Write-Host ""
    Write-Host ("=== {0}{1} ===" -f $TaskPath,$n)
    $t = Get-ScheduledTask -TaskPath $TaskPath -TaskName $n -ErrorAction SilentlyContinue
    if ($null -ne $t) {
      $i = ($t | Get-ScheduledTaskInfo)
      $desc = $map[[int]$i.LastTaskResult]; if (-not $desc) { $desc = ("0x{0:X}" -f [int]$i.LastTaskResult) }
      "Task To Run : {0} {1}" -f $Pwsh, $((($t.Actions)[0]).Arguments)
      "Next Run    : {0}" -f $i.NextRunTime
      "Last Run    : {0}" -f $i.LastRunTime
      "Last Result : {0} ({1})" -f $i.LastTaskResult, $desc
      "State       : {0}" -f $t.State
    } else {
      "   (не знайдено)"
    }
  }
}

# --- ДІЇ ---------------------------------------------------------------------
switch ($Action) {

  'Install' {
    Write-Log INFO "Встановлення завдань (створення/оновлення)…"

    Register-Orch-Task -TaskName $TN_D -TR (Build-TR -Mode 'Daily')                 -Schedule 'DAILY'   -StartTime $DailyTime
    Register-Orch-Task -TaskName $TN_W -TR (Build-TR -Mode 'Weekly'  -Force:$ForceWeekly)  -Schedule 'WEEKLY'  -StartTime $WeeklyTime  -Extra '/D SUN'
    Register-Orch-Task -TaskName $TN_M -TR (Build-TR -Mode 'Monthly' -Force:$ForceMonthly) -Schedule 'MONTHLY' -StartTime $MonthlyTime -Extra '/D 1'

    Show-Status $AllNames
    Write-Log INFO "Готово."
  }

  'Reinstall' {
    Write-Log INFO "Перевстановлення (бекап + видалення + встановлення)…"
    foreach ($n in $AllNames) {
      $tnFull = "$TaskPath$n"
      try { Export-TaskXml $tnFull } catch {}
      try { schtasks /Delete /TN "$tnFull" /F 1>$null 2>$null } catch {}
    }
    $PSBoundParameters['Action'] = 'Install'
    & $PSCommandPath @PSBoundParameters
    break
  }

  'Status' {
    Show-Status $AllNames
  }

  'RunDaily' {
    Ensure-Create ("schtasks /Run /TN `"{0}{1}`"" -f $TaskPath,$TN_D) | Out-Null
    Write-Log INFO ("Запуск ініційовано: {0}{1}" -f $TaskPath,$TN_D)
  }

  'RunWeekly' {
    Ensure-Create ("schtasks /Run /TN `"{0}{1}`"" -f $TaskPath,$TN_W) | Out-Null
    Write-Log INFO ("Запуск ініційовано: {0}{1}" -f $TaskPath,$TN_W)
  }

  'RunMonthly' {
    Ensure-Create ("schtasks /Run /TN `"{0}{1}`"" -f $TaskPath,$TN_M) | Out-Null
    Write-Log INFO ("Запуск ініційовано: {0}{1}" -f $TaskPath,$TN_M)
  }

  'Uninstall' {
    Write-Log INFO "Видалення завдань…"
    foreach ($n in $AllNames) {
      $tnFull = "$TaskPath$n"
      try {
        Export-TaskXml $tnFull
        Ensure-Create ("schtasks /Delete /TN `"{0}`" /F" -f $tnFull) | Out-Null
        Write-Log INFO ("{0}: видалено" -f $tnFull)
      } catch {
        Write-Log INFO ("{0}: вже відсутнє" -f $tnFull)
      }
    }
    Write-Log INFO "Видалено."
  }
}
