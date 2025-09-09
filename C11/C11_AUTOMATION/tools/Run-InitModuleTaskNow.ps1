<# .SYNOPSIS
  Ручний запуск задач InitModule у \Checha\ за фільтрами.
.PARAMETER Type        Weekly | Once | Any (за замовч. Any)
.PARAMETER Module      Ідентифікатор модуля (для автосанітизованого хоста імені).
.PARAMETER TaskNameSuffix Суфікс імені задачі.
.PARAMETER All         Запустити всі, що підпадають під фільтри (Type/Any).
.EXAMPLE
  pwsh -NoProfile -File .\Run-InitModuleTaskNow.ps1 -Type Weekly -Module G45.1_AOT
.EXAMPLE
  pwsh -NoProfile -File .\Run-InitModuleTaskNow.ps1 -All -Type Any
#>
param(
  [ValidateSet('Weekly','Once','Any')] [string]$Type = 'Any',
  [string]$Module,
  [string]$TaskNameSuffix,
  [switch]$All
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Sanitize([string]$s){ ($s -replace '[^\w\.-]','_') }

$taskPath = '\Checha\'
$prefixes = switch ($Type) {
  'Weekly' { @('Checha-Orchestrator-InitModule-Weekly') }
  'Once'   { @('Checha-Orchestrator-InitModule-Once') }
  default  { @('Checha-Orchestrator-InitModule-Weekly','Checha-Orchestrator-InitModule-Once') }
}

$all = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue
if (-not $all) {
  Write-Warning "Немає задач у $taskPath"
  return
}

$targets = foreach ($p in $prefixes) {
  $c = $all | Where-Object { $_.TaskName -like "$p*" }
  if ($All) { $c }
  elseif ($TaskNameSuffix) { $c | Where-Object { $_.TaskName -eq "$p-$(Sanitize $TaskNameSuffix)" } }
  elseif ($Module) { $c | Where-Object { $_.TaskName -eq "$p-$(Sanitize $Module)" } }
}

$targets = $targets | Sort-Object -Property TaskName -Unique
if (-not $targets) {
  Write-Warning "Не знайдено задач під умови (Type=$Type; Module=$Module; Suffix=$TaskNameSuffix; All=$All)"
  return
}

foreach ($t in $targets) {
  try {
    Start-ScheduledTask -TaskName $t.TaskName -TaskPath $taskPath -ErrorAction Stop
    Write-Host "[OK] Started: ${taskPath}$($t.TaskName)" -ForegroundColor Green
  } catch {
    Write-Error ("Failed start {0}{1}: {2}" -f $taskPath,$t.TaskName,$_)
    throw
  }
}
