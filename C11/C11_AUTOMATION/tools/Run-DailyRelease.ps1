param([switch]$Force)
function L([string]$m){ $ts=Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; "$ts  $m" | Add-Content -LiteralPath (Join-Path 'C:\CHECHA_CORE' 'C03\LOG\release_daily.log') -Encoding UTF8 }
L 'START Run-DailyRelease.ps1'
try{
  & (Join-Path 'C:\CHECHA_CORE\C11\C11_AUTOMATION\tools' 'New-ChechaRelease.ps1') -Root 'C:\CHECHA_CORE' -Label 'daily'
  if ($LASTEXITCODE -le 7) { $code = 0 } else { $code = $LASTEXITCODE }
  L "DONE daily release, exit=$code"
  exit $code
} catch { L ("EXC: " + $_.Exception.Message); exit 1 }
