param([switch]$Force)
function L([string]$m){ $ts=Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; "$ts  $m" | Add-Content -LiteralPath (Join-Path 'C:\CHECHA_CORE' 'C03\LOG\release_monthly.log') -Encoding UTF8 }
L 'START Run-MonthEndRelease.ps1'
try{
  & (Join-Path 'C:\CHECHA_CORE\C11\C11_AUTOMATION\tools' 'New-ChechaReleaseMonthly.ps1') -Root 'C:\CHECHA_CORE'
  if ($LASTEXITCODE -le 7) { $code = 0 } else { $code = $LASTEXITCODE }
  L "DONE monthly release, exit=$code"
  exit $code
} catch { L ("EXC: " + $_.Exception.Message); exit 1 }
