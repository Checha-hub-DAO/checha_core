<# 
.SYNOPSIS
  DryRun/Healthcheck для Checha-Orchestrator.ps1:
  - резолв інструментів
  - список кроків по режимах
  - моделювання виходу з DryRun/FailOnMissingTools
#>

[CmdletBinding()]
param(
  [ValidateSet('Daily','Weekly','Monthly','Rolling','Init','Publish')]
  [string]$Mode = 'Daily',
  [string]$Root = 'C:\CHECHA_CORE',
  [switch]$FailOnMissingTools
)

$ErrorActionPreference = 'Stop'

function Find([string]$rel, [string[]]$alts){
  $c = @()
  $c += (Join-Path $Root $rel)
  if ($alts){ $c += $alts }
  foreach($p in $c){ if (Test-Path $p){ return (Resolve-Path $p).Path } }
  return $null
}

# Очікувані тулзи (в точності як в оркестраторі)
$Tools = [ordered]@{
  'Create-StrategicTemplate.ps1' = Find 'C11\C11_AUTOMATION\tools\Create-StrategicTemplate.ps1' $null
  'Start-Planning.ps1'           = Find 'C11\C11_AUTOMATION\tools\Start-Planning.ps1' $null
  'Checha-SessionMonthlyReport.ps1' = Find 'C11\C11_AUTOMATION\tools\Checha-SessionMonthlyReport.ps1' $null
  'Validate-Releases.ps1'        = Find 'G\G45\RELEASES\Validate-Releases.ps1' @((Join-Path $Root 'C11\C11_AUTOMATION\tools\Validate-Releases.ps1'))
  'Archive-Work.ps1'             = Find 'G\G45\RELEASES\Archive-Work.ps1' $null
  'Publish-GitBook-Submodule.ps1'= Find 'C11\C11_AUTOMATION\tools\GitBookStdPack\Publish-GitBook-Submodule.ps1' $null
}

Write-Host "== CheCha TEST =="
Write-Host "Mode: $Mode   Root: $Root   FailOnMissingTools: $FailOnMissingTools"
Write-Host ""

Write-Host "--- Tools ---"
$missing = @()
foreach($k in $Tools.Keys){
  $v = $Tools[$k]
  if ($v){ "{0,-32} FOUND   -> {1}" -f $k,$v }
  else   { "{0,-32} MISSING" -f $k; $missing += $k }
}

if ($FailOnMissingTools -and $missing.Count -gt 0){
  Write-Host ""
  Write-Host "Missing tools: $($missing -join ', ')"
  Write-Host "FailOnMissingTools: exit 10 (simulated)"
  exit 10
}

Write-Host ""
Write-Host "--- Planned steps ---"
switch ($Mode) {
  'Daily' {
    if (Get-Command -Name crun -ErrorAction SilentlyContinue){
      "- Daily:Create-StrategicTemplate(crun)"
    } elseif ($Tools['Create-StrategicTemplate.ps1']) {
      "- Daily:Create-StrategicTemplate.ps1"
    } else { "- Daily:Create-StrategicTemplate (skipped: missing)" }

    if ($Tools['Validate-Releases.ps1']) { "- Daily:Validate-Releases -Quiet -All" }
    else { "- Daily:Validate-Releases (skipped: missing)" }

    if ($Tools['Archive-Work.ps1']) { "- Daily:Archive-Work -DaysOld 0 -QuarantineKeepDays 14" }
    else { "- Daily:Archive-Work (skipped: missing)" }
  }

  'Weekly' {
    if ($Tools['Start-Planning.ps1']) { "- Weekly:Start-Planning.ps1 [-ForceRun optional]" }
    else { "- Weekly:Start-Planning (skipped: missing)" }

    if ($Tools['Validate-Releases.ps1']) { "- Weekly:Validate-Releases -All" }
    else { "- Weekly:Validate-Releases (skipped: missing)" }
  }

  'Monthly' {
    if ($Tools['Checha-SessionMonthlyReport.ps1']) { "- Monthly:Checha-SessionMonthlyReport.ps1 -Mode Calendar [-ForceRun optional]" }
    else { "- Monthly:Checha-SessionMonthlyReport (skipped: missing)" }

    if ($Tools['Validate-Releases.ps1']) { "- Monthly:Validate-Releases -All -Quiet" }
    else { "- Monthly:Validate-Releases (skipped: missing)" }
  }

  'Rolling' {
    # Daily subset:
    if (Get-Command -Name crun -ErrorAction SilentlyContinue){
      "- Rolling:Daily.Create-StrategicTemplate(crun)"
    } elseif ($Tools['Create-StrategicTemplate.ps1']) {
      "- Rolling:Daily.Create-StrategicTemplate.ps1"
    } else { "- Rolling:Daily.Create-StrategicTemplate (skipped: missing)" }

    if ($Tools['Validate-Releases.ps1']) { "- Rolling:Daily.Validate-Releases -Quiet -All" }
    else { "- Rolling:Daily.Validate-Releases (skipped: missing)" }

    if ($Tools['Archive-Work.ps1']) { "- Rolling:Daily.Archive-Work -DaysOld 0" }
    else { "- Rolling:Daily.Archive-Work (skipped: missing)" }

    # Weekly soft:
    if ($Tools['Start-Planning.ps1']) { "- Rolling:Weekly(soft) Start-Planning.ps1 -Soft" }
    else { "- Rolling:Weekly(soft) (skipped: missing)" }
  }

  'Init' {
    if ($Tools['Create-StrategicTemplate.ps1']) { "- Init:DailyTemplateSeed" }
    else { "- Init:DailyTemplateSeed (skipped: missing)" }

    if ($Tools['Validate-Releases.ps1']) { "- Init:Validate-Releases -All -Quiet" }
    else { "- Init:Validate-Releases (skipped: missing)" }
  }

  'Publish' {
    if ($Tools['Publish-GitBook-Submodule.ps1']) { "- Publish:GitBook-Submodule" }
    else { "- Publish:GitBook-Submodule (skipped: missing)" }

    if ($Tools['Validate-Releases.ps1']) { "- Publish:Validate-Releases -All -Quiet" }
    else { "- Publish:Validate-Releases (skipped: missing)" }
  }
}

Write-Host ""
Write-Host "Simulation result: 0 (DryRun OK)"
exit 0
