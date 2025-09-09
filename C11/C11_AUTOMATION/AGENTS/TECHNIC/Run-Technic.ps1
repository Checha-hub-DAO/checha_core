param([ValidateSet("Health","Repair","Maintenance")][string]$Mode="Repair")
$root = "C:\CHECHA_CORE"
New-Item -ItemType Directory -Force -Path "$root\C11\Backups","$root\C03\LOG" | Out-Null
switch ($Mode) {
  "Health"      { Add-Content "$root\C03\LOG\technic.health.log"      "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') [INFO ] HEALTH ping" -Encoding UTF8 }
  "Maintenance" { Add-Content "$root\C03\LOG\technic.maint.log"       "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') [INFO ] MAINT start" -Encoding UTF8 }
  "Repair"      {
    if (-not (Get-ScheduledTask -TaskName "Checha-Strateg-Weekly" -ErrorAction SilentlyContinue)) {
      $sp="C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\Run-StrategWeekly.ps1"
      $ac=New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$sp`""
      $tr=New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 20:00
      $st=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable -MultipleInstances Parallel
      $pr=New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
      Register-ScheduledTask -TaskName "Checha-Strateg-Weekly" -Action $ac -Trigger $tr -Settings $st -Principal $pr -Description "Weekly strategic report" -Force | Out-Null
    }
    $all = (schtasks /Query /FO LIST | Select-String -Pattern '^TaskName:\s+\\(.+)$').Matches.Value |
           ForEach-Object { ($_ -split '\\')[-1] } |
           Where-Object { $_ -like 'Checha-*' } | Sort-Object -Unique
    foreach ($t in $all) { schtasks /Query /TN $t /XML > "$root\C11\Backups\$t.xml" 2>$null }
    Add-Content "$root\C03\LOG\technic.repair.log" "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') [INFO ] REPAIR ok; tasks=$($all.Count)" -Encoding UTF8
  }
}
exit 0
