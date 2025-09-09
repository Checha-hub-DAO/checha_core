<#{
.SYNOPSIS
  Реєструє щотижневу задачу ініціалізації модуля Checha-Orchestrator.
.DESCRIPTION
  Створює Scheduled Task із тригером Weekly (вказані дні тижня, інтервал тижнів).
  ВАЖЛИВО: використовує TaskPath '\Checha\' і чисте TaskName (без бекслешів у назві).
.PARAMETER ChechaRoot
  Корінь системи CHECHA_CORE. За замовчуванням C:\CHECHA_CORE.
.PARAMETER Module
  Ідентифікатор модуля (напр., G45.1_AOT).
.PARAMETER At
  Час запуску HH:mm (24h).
.PARAMETER WeeksInterval
  Інтервал тижнів (1 = щотижня).
.PARAMETER Days
  Дні тижня (Sunday..Saturday).
.PARAMETER RunAs
  Interactive | ServiceAccount (SYSTEM).
.PARAMETER TaskNameSuffix
  Додатковий суфікс до імені задачі для унікальності (напр., 'G45_1').
.EXAMPLE
  pwsh -NoProfile -File .\Register-InitModuleTask-Weekly.ps1 -Days Monday,Friday -At 19:00 -Module G45.1_AOT -TaskNameSuffix G45_1
.EXAMPLE
  pwsh -NoProfile -File .\Register-InitModuleTask-Weekly.ps1 -Days Tuesday,Thursday -WeeksInterval 2 -RunAs ServiceAccount -Module G43_ITETA
}#>
param(
  [string]$ChechaRoot = 'C:\CHECHA_CORE',
  [string]$Module     = 'G45.1_AOT',
  [string]$At         = '09:00',
  [int]$WeeksInterval = 1,
  [ValidateSet('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')]
  [string[]]$Days     = @('Monday','Friday'),
  [ValidateSet('Interactive','ServiceAccount')]
  [string]$RunAs      = 'Interactive',
  [string]$TaskNameSuffix
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Paths & logger
$tools = Join-Path $ChechaRoot 'C11\C11_AUTOMATION\tools'
$logFn = Join-Path $tools 'Write-OrchestratorLog.ps1'
function Log([string]$msg,[string]$lvl='INFO'){
  if (Test-Path $logFn){ & $logFn -ChechaRoot $ChechaRoot -Text $msg -Level $lvl } else { Write-Host "[$lvl] $msg" }
}

# --- Validations
if (-not (Test-Path $ChechaRoot)) { throw "ChechaRoot не існує: $ChechaRoot" }
$script = Join-Path $tools 'Checha-Orchestrator.ps1'
if (-not (Test-Path $script)) { throw "Не знайдено Checha-Orchestrator.ps1: $script" }

# sanitize for task name
function Sanitize([string]$s){ ($s -replace '[^\w\.-]','_') }

try {
  $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
} catch {
  throw "pwsh (PowerShell 7+) не знайдено в PATH."
}

# --- Task identity (TaskPath + TaskName!)
$taskPath = '\Checha\'  # Папка в Планувальнику
$auto     = Sanitize $Module
$baseName = 'Checha-Orchestrator-InitModule-Weekly'
$taskName = if ($TaskNameSuffix) { "$baseName-$(Sanitize $TaskNameSuffix)" } else { "$baseName-$auto" }

# --- Action/Trigger/Principal
# Пряма передача аргументів pwsh:
$pwshArgs = @(
  '-NoProfile','-ExecutionPolicy','Bypass',
  '-File',"`"$script`"",' -Mode','InitializeModule',' -Module',"$Module"
) -join ' '

$action  = New-ScheduledTaskAction -Execute $pwsh -Argument $pwshArgs
$trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval $WeeksInterval -DaysOfWeek $Days -At $At

# Principal
if ($RunAs -eq 'ServiceAccount') {
  $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
} else {
  # Поточний користувач у форматі DOMAIN\User
  $current = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  $principal = New-ScheduledTaskPrincipal -UserId $current -RunLevel Highest -LogonType Interactive
}

# Settings: дозволити ручний запуск, зупиняти при живленні від батареї не змінюємо (дефолт), дозволити пропуск при простої
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable -Compatibility Win8

try {
  Register-ScheduledTask `
    -TaskPath  $taskPath `
    -TaskName  $taskName `
    -Action    $action `
    -Trigger   $trigger `
    -Principal $principal `
    -Settings  $settings `
    -Force | Out-Null

  Log "Task registered: ${taskPath}${taskName} @ $At on $($Days -join ', ') every $WeeksInterval week(s) (RunAs=$RunAs; Module=$Module)"
  Write-Host "[OK] Weekly task: ${taskPath}${taskName}" -ForegroundColor Green
}
catch {
  Log ("Register-InitModuleTask-Weekly failed: {0}" -f $_) 'ERROR'
  throw
}
