
param(
  [string]$Root = "C:\CHECHA_CORE"
)

function Show-Header($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }

Show-Header "ScheduledTasks status"
$names = @("Checha-Planning-Day","Checha-Planning-Week")
foreach($n in $names){
  try{
    Get-ScheduledTask -TaskName $n | Get-ScheduledTaskInfo | Select-Object LastRunTime,LastTaskResult,NextRunTime,TaskName
  } catch {
    Write-Host "$n : NOT FOUND" -ForegroundColor Yellow
  }
}

Show-Header "Test run"
foreach($n in $names){
  try{ schtasks /Run /TN $n | Out-Null; Write-Host "$n : RUN signal sent" } catch { Write-Host "$n : RUN failed" -ForegroundColor Red }
}

Start-Sleep -Seconds 2

Show-Header "LOG tail"
$log = Join-Path $Root "C03\LOG\LOG.md"
if(Test-Path $log){ Get-Content $log -Tail 20 } else { Write-Host "LOG not found: $log" -ForegroundColor Yellow }

Show-Header "Files existence"
$today   = (Get-Date).ToString('yyyy-MM-dd')
$monday  = (Get-Date).Date.AddDays( - (([int](Get-Date).DayOfWeek + 6) % 7) ).ToString('yyyy-MM-dd')
$daily   = Join-Path $Root "C03\LOG\daily\$today.md"
$weekly  = Join-Path $Root ("C12\Vault\StrategicReports\{0}\Strateg_Report_{1}.md" -f (Get-Date).ToString('yyyy'), $monday)
"{0} : {1}" -f $daily,  (Test-Path $daily)
"{0} : {1}" -f $weekly, (Test-Path $weekly)
