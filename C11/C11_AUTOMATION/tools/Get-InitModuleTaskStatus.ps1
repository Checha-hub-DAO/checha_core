<# .SYNOPSIS
  Виводить статус задач InitModule у \Checha\.
.PARAMETER Type        Weekly | Once | Any (за замовч. Any)
.PARAMETER Module      Ідентифікатор модуля (для фільтру за автосанітизованим хвостом).
.PARAMETER TaskNameSuffix Суфікс імені задачі.
.EXAMPLE
  pwsh -NoProfile -File .\Get-InitModuleTaskStatus.ps1 -Type Weekly -Module G45.1_AOT
#>
param(
  [ValidateSet('Weekly','Once','Any')] [string]$Type = 'Any',
  [string]$Module,
  [string]$TaskNameSuffix
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
if (-not $all) { return }

$filtered = foreach ($p in $prefixes) {
  $c = $all | Where-Object { $_.TaskName -like "$p*" }
  if ($TaskNameSuffix) {
    $c | Where-Object { $_.TaskName -eq "$p-$(Sanitize $TaskNameSuffix)" }
  } elseif ($Module) {
    $c | Where-Object { $_.TaskName -eq "$p-$(Sanitize $Module)" }
  } else {
    $c
  }
}

$filtered = $filtered | Sort-Object -Property TaskName -Unique
if (-not $filtered) { return }

$infos = foreach ($t in $filtered) {
  $i = Get-ScheduledTaskInfo -TaskName $t.TaskName -TaskPath $taskPath
  [pscustomobject]@{
    TaskName        = $t.TaskName
    Type            = (if ($t.TaskName -like 'Checha-Orchestrator-InitModule-Weekly*') {'Weekly'} else {'Once'})
    State           = $t.State
    LastRunTime     = $i.LastRunTime
    LastTaskResult  = $i.LastTaskResult
    NextRunTime     = $i.NextRunTime
  }
}

$infos | Format-Table -AutoSize
