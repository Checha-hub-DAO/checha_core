<#{
.SYNOPSIS
  Реєструє одноразову задачу ініціалізації модуля через X хвилин.
.DESCRIPTION
  Створює Scheduled Task із тригером Once на конкретну дату/час (через OffsetMinutes від now()).
  ВАЖЛИВО: використовує TaskPath '\Checha\' і чисте TaskName (без бекслешів у назві).
.PARAMETER ChechaRoot
  Корінь системи CHECHA_CORE. За замовчуванням C:\CHECHA_CORE.
.PARAMETER Module
  Ідентифікатор модуля (напр., G45.1_AOT).
.PARAMETER OffsetMinutes
  Зсув у хвилинах від поточного часу (мін. 1).
.PARAMETER RunAs
  Interactive | ServiceAccount (SYSTEM).
.PARAMETER TaskNameSuffix
  Додатковий суфікс до імені задачі для унікальності.
.EXAMPLE
  pwsh -NoProfile -File .\Register-InitModuleTask-Once.ps1 -OffsetMinutes 5 -Module G45.1_AOT -TaskNameSuffix smoke
.EXAMPLE
  pwsh -NoProfile -File .\Register-InitModuleTask-Once.ps1 -OffsetMinutes 15 -RunAs ServiceAccount -Module G43_ITETA
}#>
param(
  [string]$ChechaRoot    = 'C:\CHECHA_CORE',
  [string]$Module        = 'G45.1_AOT',
  [int]$OffsetMinutes    = 10,
  [ValidateSet('Interactive','ServiceAccount')]
  [string]$RunAs         = 'Interactive',
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
if ($OffsetMinutes -lt 1) { $OffsetMinutes = 1 }

function Sanitize([string]$s){ ($s -replace '[^\w\.-]','_') }

try {
  $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
} catch {
  throw "pwsh (PowerShell 7+) не знайдено в PATH."
}

# --- Task identity
$taskPath = '\Checha\'
$auto     = Sanitize $Module
$baseName = 'Checha-Orchestrator-InitModule-Once'
$taskName = if ($TaskNameSuffix) { "$baseName-$(Sanitize $TaskNameSuffix)" } else { "$baseName-$auto" }

# --- Start time
$start = (Get-Date).AddMinutes([math]::Max(1,$OffsetMinutes))

# --- Action/Trigger/Principal
$pwshArgs = @(
  '-NoProfile','-ExecutionPolicy','Bypass',
  '-File',"`"$script`"",' -Mode','InitializeModule',' -Module',"$Module"
) -join ' '

$action  = New-ScheduledTaskAction -Execute $pwsh -Argument $pwshArgs
$trigger = New-ScheduledTaskTrigger -Once -At $start

if ($RunAs -eq 'ServiceAccount') {
  $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
} else {
  $current = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  $principal = New-ScheduledTaskPrincipal -UserId $current -RunLevel Highest -LogonType Interactive
}

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable -Compatibility Win8

try {
  Register-ScheduledTask `
    -TaskPath  $taskPath `
    -TaskName  $taskName `
    -Action    $action `
    -Trigger   $trigger `
    -Principal $principal `
    -Settings  $settings `
    -Description ("One-time InitModule ({0}) @ {1:yyyy-MM-dd HH:mm}" -f $Module,$start) `
    -Force | Out-Null

  Log ("One-time task registered: {0}{1} @ {2:yyyy-MM-dd HH:mm} (RunAs={3}; Module={4})" -f $taskPath,$taskName,$start,$RunAs,$Module)
  Write-Host "[OK] One-time task: ${taskPath}${taskName}" -ForegroundColor Green
}
catch {
  Log ("Register-InitModuleTask-Once failed: {0}" -f $_) 'ERROR'
  throw
}
