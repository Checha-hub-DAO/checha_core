<#
.SYNOPSIS
  Єдиний wrapper для лічильника діалогу та світлофора.

.DESCRIPTION
  Викликає Get-DialogCount.ps1 і TrafficLight-Helper.ps1:
    - Start   : встановити 1 і зафіксувати 🟢/🟡/🔴 (Mode=Start)
    - PlusOne : інкрементувати на 1 і зробити проміжний апдейт (Mode=Update)
    - End     : зафіксувати фінальний стан (Mode=End)
    - Status  : показати поточний Count і колір без змін

.PARAMETER Action
  Start | PlusOne | End | Status

.PARAMETER Root
  Корінь CHECHA_CORE (default: C:\CHECHA_CORE)

.PARAMETER Quiet
  Приховати консольний вивід (але ExitCode залишиться інформативним).

.OUTPUTS
  Stdout (за потреби) + ExitCode:
    - Start/PlusOne/Status: 0=OK
    - End/Update (всередині): 0=Green, 1=Yellow, 2=Red
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('Start','PlusOne','End','Status')]
  [string]$Action,

  [string]$Root = "C:\CHECHA_CORE",
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Path-Tool([string]$rel) { return (Join-Path $Root "C11\C11_AUTOMATION\tools\$rel") }
function Ensure-File([string]$path,[string]$name) {
  if (-not (Test-Path $path)) {
    throw "Не знайдено $name: $path"
  }
}

# Локації інструментів
$getDlg = Path-Tool "Get-DialogCount.ps1"
$traf   = Path-Tool "TrafficLight-Helper.ps1"
Ensure-File $getDlg "Get-DialogCount.ps1"
Ensure-File $traf   "TrafficLight-Helper.ps1"

# Допоміжні
function OutI($msg) { if (-not $Quiet) { Write-Host $msg } }

# === Маршрутизація дій ===
switch ($Action) {
  'Start' {
    $cnt = pwsh -NoProfile -File $getDlg -Root $Root -Set 1
    OutI "[Start] Count=$cnt"
    # Фіксуємо початок сесії
    $exit = (pwsh -NoProfile -File $traf -Mode Start -Count $cnt -Root $Root; $LASTEXITCODE)
    exit $exit
  }

  'PlusOne' {
    $cnt = pwsh -NoProfile -File $getDlg -Root $Root -Increment
    OutI "[PlusOne] Count=$cnt"
    # Проміжний апдейт світлофора
    $exit = (pwsh -NoProfile -File $traf -Mode Update -Count $cnt -Root $Root; $LASTEXITCODE)
    exit $exit
  }

  'End' {
    $cnt = pwsh -NoProfile -File $getDlg -Root $Root
    OutI "[End] Count=$cnt"
    $exit = (pwsh -NoProfile -File $traf -Mode End -Count $cnt -Root $Root; $LASTEXITCODE)
    exit $exit
  }

  'Status' {
    $cnt = pwsh -NoProfile -File $getDlg -Root $Root
    # Визначимо колір локально (дзеркально до Helper)
    [int]$n = $cnt
    $color = if ($n -ge 50) { 'Red' } elseif ($n -ge 30) { 'Yellow' } else { 'Green' }
    $icon  = if ($color -eq 'Red') {'🔴'} elseif ($color -eq 'Yellow') {'🟡'} else {'🟢'}
    OutI ("[Status] Count={0} Color={1} {2}" -f $n, $color, $icon)
    exit 0
  }
}
