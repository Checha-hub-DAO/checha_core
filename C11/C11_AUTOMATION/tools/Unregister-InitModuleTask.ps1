<# .SYNOPSIS
  Видаляє задачі ініціалізації модуля (Weekly/Once) у \Checha\.
.DESCRIPTION
  Працює за префіксами:
    Checha-Orchestrator-InitModule-Weekly-*
    Checha-Orchestrator-InitModule-Once-*
.PARAMETER ChechaRoot  Корінь CHECHA_CORE (для логів).
.PARAMETER Module      Ідентифікатор модуля (G45.1_AOT тощо).
.PARAMETER TaskNameSuffix Додатковий суфікс до імені задачі.
.PARAMETER Type        Weekly | Once | Any (за замовч. Any).
.PARAMETER All         Видалити всі задачі указаного типу (ігнорує Module/Suffix).
.EXAMPLE
  pwsh -NoProfile -File .\Unregister-InitModuleTask.ps1 -Module G45.1_AOT -Type Weekly
.EXAMPLE
  pwsh -NoProfile -File .\Unregister-InitModuleTask.ps1 -All -Type Any
#>
param(
  [string]$ChechaRoot = 'C:\CHECHA_CORE',
  [string]$Module,
  [string]$TaskNameSuffix,
  [ValidateSet('Weekly','Once','Any')] [string]$Type = 'Any',
  [switch]$All
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Logger
$tools = Join-Path $ChechaRoot 'C11\C11_AUTOMATION\tools'
$logFn = Join-Path $tools 'Write-OrchestratorLog.ps1'
function Log([string]$msg,[string]$lvl='INFO'){
  if (Test-Path $logFn){ & $logFn -ChechaRoot $ChechaRoot -Text $msg -Level $lvl } else { Write-Host "[$lvl] $msg" }
}
function Sanitize([string]$s){ ($s -replace '[^\w\.-]','_') }

$taskPath = '\Checha\'
$prefixes = switch ($Type) {
  'Weekly' { @('Checha-Orchestrator-InitModule-Weekly') }
  'Once'   { @('Checha-Orchestrator-InitModule-Once') }
  default  { @('Checha-Orchestrator-InitModule-Weekly','Checha-Orchestrator-InitModule-Once') }
}

# Отримати всі задачі в \Checha\
$all = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue

if (-not $all) {
  Log "Немає задач у $taskPath — нічого видаляти" 'WARN'
  return
}

# Фільтрація
$targets = @()
foreach ($p in $prefixes) {
  $candidates = $all | Where-Object { $_.TaskName -like "$p*" }
  if ($All) {
    $targets += $candidates
  } else {
    if ($TaskNameSuffix) {
      $suffix = Sanitize $TaskNameSuffix
      $targets += $candidates | Where-Object { $_.TaskName -eq "$p-$suffix" }
    } elseif ($Module) {
      $mod = Sanitize $Module
      # або з модульним автосанітом:
      $targets += $candidates | Where-Object { $_.TaskName -eq "$p-$mod" }
    }
  }
}

$targets = $targets | Sort-Object -Property TaskName -Unique
if (-not $targets) {
  Log "Не знайдено задач під умови (Type=$Type; Module=$Module; Suffix=$TaskNameSuffix; All=$All)" 'WARN'
  return
}

foreach ($t in $targets) {
  try {
    Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $taskPath -Confirm:$false -ErrorAction Stop
    Log "Removed: ${taskPath}$($t.TaskName)"
    Write-Host "[OK] Removed: ${taskPath}$($t.TaskName)" -ForegroundColor Green
  } catch {
    Log ("Failed remove {0}{1}: {2}" -f $taskPath,$t.TaskName,$_ ) 'ERROR'
    throw
  }
}
