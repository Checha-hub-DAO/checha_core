Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ChechaCore {
  param([string]$Start)
  if ($env:CHECHA_CORE -and (Test-Path (Join-Path $env:CHECHA_CORE 'C06'))) { return (Resolve-Path $env:CHECHA_CORE).Path }
  if ((Test-Path 'C:\CHECHA_CORE\C06')) { return 'C:\CHECHA_CORE' }
  if ((Test-Path 'D:\CHECHA_CORE\C06')) { return 'D:\CHECHA_CORE' }
  if ($Start) {
    $p = Split-Path -Parent $Start
    for ($i=0; $i -lt 6; $i++) {
      if ($p -and (Test-Path (Join-Path $p 'C06'))) { return (Resolve-Path $p).Path }
      $parent = Split-Path -Parent $p; if (-not $parent -or $parent -eq $p) { break }; $p = $parent
    }
  }
  throw "Не знайдено CHECHA_CORE. Встанови env:CHECHA_CORE або тримай структуру з текою C06."
}

function New-ChechaRelease {
  [CmdletBinding()]
  param([string]$Label,[string]$Root)
  $start = $PSCommandPath; if (-not $start) { $start = $MyInvocation.MyCommand.Path }
  $root  = if ($Root) { (Resolve-Path $Root).Path } else { Resolve-ChechaCore -Start $start }
  $tools = Join-Path $root 'C11\C11_AUTOMATION\tools'
  & (Join-Path $tools 'New-ChechaRelease.ps1') -Root $root -Label $Label
}

function Invoke-ChechaDailyRelease {
  [CmdletBinding()]
  param([switch]$Force,[string]$Root)
  $start = $PSCommandPath; if (-not $start) { $start = $MyInvocation.MyCommand.Path }
  $root  = if ($Root) { (Resolve-Path $Root).Path } else { Resolve-ChechaCore -Start $start }
  & (Join-Path $root 'C11\C11_AUTOMATION\tools\Run-DailyRelease.ps1') -Force:$Force
}

function Invoke-ChechaWeeklyRelease {
  [CmdletBinding()]
  param([switch]$Force,[string]$Root)
  $start = $PSCommandPath; if (-not $start) { $start = $MyInvocation.MyCommand.Path }
  $root  = if ($Root) { (Resolve-Path $Root).Path } else { Resolve-ChechaCore -Start $start }
  & (Join-Path $root 'C11\C11_AUTOMATION\tools\Run-WeekRelease.ps1') -Force:$Force
}

function Invoke-ChechaMonthlyRelease {
  [CmdletBinding()]
  param([switch]$Force,[string]$Root)
  $start = $PSCommandPath; if (-not $start) { $start = $MyInvocation.MyCommand.Path }
  $root  = if ($Root) { (Resolve-Path $Root).Path } else { Resolve-ChechaCore -Start $start }
  & (Join-Path $root 'C11\C11_AUTOMATION\tools\Run-MonthEndRelease.ps1') -Force:$Force
}

Export-ModuleMember -Function Resolve-ChechaCore,New-ChechaRelease,Invoke-ChechaDailyRelease,Invoke-ChechaWeeklyRelease,Invoke-ChechaMonthlyRelease
