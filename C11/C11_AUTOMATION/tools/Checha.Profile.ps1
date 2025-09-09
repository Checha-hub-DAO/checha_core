function Format-TaskResult([int]$Code){
  switch ($Code) {
    0             { "Success" }
    0x41300       { "Ready (queued for next run)" }
    0x41301       { "Running" }
    0x41302       { "Disabled" }
    0x41303       { "Not yet run" }
    0x41304       { "No more runs" }
    0x41305       { "Schedule incomplete" }
    0x80070002    { "File not found" }
    0xC000013A    { "Terminated by user/Logoff (CTRL+C)" }
    default       { "0x{0:X8}" -f $Code }
  }
}

function Get-ChechaTaskInfo([string]$TaskName){
  $path = '\CHECHA\'
  $obj = [pscustomobject]@{
    Name        = $TaskName
    State       = '?'
    LastRunTime = $null
    NextRunTime = $null
    LastResult  = '?'
  }
  try {
    $t = Get-ScheduledTask -TaskPath $path -TaskName $TaskName -ErrorAction Stop
    $obj.State = $t.State
  } catch {}

  # Try native cmdlet first (may fail with AccessDenied on some systems)
  try {
    $info = Get-ScheduledTaskInfo -TaskPath $path -TaskName $TaskName -ErrorAction Stop
    $obj.LastRunTime = $info.LastRunTime
    $obj.NextRunTime = $info.NextRunTime
    $obj.LastResult  = ('0x{0:X8} ({1})' -f $info.LastTaskResult, (Format-TaskResult $info.LastTaskResult))
    return $obj
  } catch {}

  # Fallback to SCHTASKS /V (verbose) — may also be restricted; handle gracefully
  try {
    $txt = schtasks /Query /TN "$path$TaskName" /V /FO LIST 2>$null
    if ($LASTEXITCODE -eq 0 -and $txt) {
      $ht=@{}
      foreach($line in $txt){ if($line -match '^\s*([^:]+):\s*(.*)$'){ $ht[$matches[1].Trim()]=$matches[2].Trim() } }
      if ($ht.ContainsKey('Status'))       { $obj.State = $ht['Status'] }
      if ($ht.ContainsKey('Last Run Time')){ $obj.LastRunTime = $ht['Last Run Time'] }
      if ($ht.ContainsKey('Next Run Time')){ $obj.NextRunTime = $ht['Next Run Time'] }
      if ($ht.ContainsKey('Last Result'))  { $obj.LastResult  = $ht['Last Result'] }
      return $obj
    }
  } catch {}

  # Last fallback: non-verbose query (gives at least Status/Next)
  try {
    $txt = schtasks /Query /TN "$path$TaskName" /FO LIST 2>$null
    if ($LASTEXITCODE -eq 0 -and $txt) {
      $ht=@{}
      foreach($line in $txt){ if($line -match '^\s*([^:]+):\s*(.*)$'){ $ht[$matches[1].Trim()]=$matches[2].Trim() } }
      if ($ht.ContainsKey('Status'))       { $obj.State = $ht['Status'] }
      if ($ht.ContainsKey('Next Run Time')){ $obj.NextRunTime = $ht['Next Run Time'] }
      return $obj
    }
  } catch {}

  return $obj
}

function checha-status {
  $names = 'CreateStrategicTemplate-Daily','StrategicTemplate-HealthCheck'
  $rows = foreach($n in $names){ Get-ChechaTaskInfo $n }
  $rows | Format-Table Name, State, LastRunTime, NextRunTime, LastResult -AutoSize
}

function checha-run {
  [CmdletBinding()]
  param(
    [ValidateSet('main','health','both')]
    [string]$What='both'
  )
  $targets = @()
  if($What -in @('main','both'))   { $targets += '\CHECHA\CreateStrategicTemplate-Daily' }
  if($What -in @('health','both')) { $targets += '\CHECHA\StrategicTemplate-HealthCheck' }

  foreach($t in $targets){
    try {
      schtasks /Run /TN $t | Out-Null
      Write-Host "[RUN] $t" -ForegroundColor Green
    } catch {
      Write-Host "[RUN FAIL] $t - $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }
  Start-Sleep 2
  checha-status
}

Set-Alias cstatus checha-status -Scope Global
Set-Alias crun    checha-run    -Scope Global

function checha-grant-access {
  [CmdletBinding()]
  param(
    [string]$User = "$env:USERDOMAIN\$env:USERNAME"
  )
  # --- inner elevated worker ---
  $script = @"
`$ErrorActionPreference='Stop'
`$User = '$User'
# Resolve SID
try {
  `$acct = New-Object System.Security.Principal.NTAccount(`$User)
  `$sid  = (`$acct.Translate([System.Security.Principal.SecurityIdentifier])).Value
} catch { throw "Cannot resolve SID for user `$User. $_" }

# Connect Task Scheduler
`$svc = New-Object -ComObject "Schedule.Service"
`$svc.Connect()
try { `$folder = `$svc.GetFolder("\CHECHA") } catch { throw "Folder \CHECHA not found. Create tasks first." }

# Backup SDDL
`$backupDir = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tasks"
if (!(Test-Path `$backupDir)) { New-Item -ItemType Directory -Path `$backupDir | Out-Null }
`$stamp = Get-Date -Format yyyyMMdd_HHmmss
`$sddlFolder = `$folder.GetSecurityDescriptor(0)
Set-Content -Path (Join-Path `$backupDir "CHECHA_folder_sddl_`$stamp.txt") -Value `$sddlFolder -Encoding UTF8

`$tasks = @()
`$col = `$folder.GetTasks(0)
foreach(`$t in `$col){ `$tasks += `$t }
`$i=0
foreach(`$t in `$tasks){
  `$i++; `$s = `$t.GetSecurityDescriptor(0)
  Set-Content -Path (Join-Path `$backupDir ("CHECHA_task{0:00}_{1}_sddl_`$stamp.txt" -f `$i, `$t.Name)) -Value `$s -Encoding UTF8
}

function Add-ReadExecuteAce {
  param(`$obj, [string]`$sid)
  # prepend our ACE if not already present
  `$sddl = `$obj.GetSecurityDescriptor(0)
  if (`$sddl -notmatch [regex]::Escape(`$sid)) {
    `$sddl2 = `$sddl -replace '^D:', "D:(A;;GRGX;;;" + `$sid + ")"
    `$obj.SetSecurityDescriptor(`$sddl2, 0)
    return `$true
  }
  return `$false
}

`$changedFolder = Add-ReadExecuteAce -obj `$folder -sid `$sid
`$changedTasks = 0
foreach(`$t in `$tasks){ if (Add-ReadExecuteAce -obj `$t -sid `$sid) { `$changedTasks++ } }

Write-Host ("[ACL] Folder updated: {0}; Tasks updated: {1}" -f `$changedFolder, `$changedTasks) -ForegroundColor Cyan
"@

  # Elevate if needed
  $amIAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $amIAdmin) {
    $tmp = Join-Path $env:TEMP "checha_grant_acl.ps1"
    [IO.File]::WriteAllText($tmp, $script, [Text.UTF8Encoding]::new($false))
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$tmp`"")
  } else {
    Invoke-Expression $script
  }

  # Quick check (best effort)
  try {
    Get-ScheduledTaskInfo -TaskPath '\CHECHA\' -TaskName 'CreateStrategicTemplate-Daily' |
      Select-Object LastRunTime, @{n='LastResult';e={'0x{0:X8}' -f $_.LastTaskResult}}, NextRunTime | Out-Host
  } catch {}
  try {
    Get-ScheduledTaskInfo -TaskPath '\CHECHA\' -TaskName 'StrategicTemplate-HealthCheck' |
      Select-Object LastRunTime, @{n='LastResult';e={'0x{0:X8}' -f $_.LastTaskResult}}, NextRunTime | Out-Host
  } catch {}
}

Set-Alias cgrant checha-grant-access -Scope Global


# --- override checha-grant-access (hotfix) ---
function checha-grant-access {
  [CmdletBinding()]
  param([string]$User = "$env:USERDOMAIN\$env:USERNAME")

  $inner = @"
`$ErrorActionPreference='Stop'
`$User = '$User'

# Resolve SID
`$sid = try {
  (New-Object System.Security.Principal.NTAccount(`$User)).Translate([System.Security.Principal.SecurityIdentifier]).Value
} catch { throw "Cannot resolve SID for user `$User. `$_" }

# Helper: insert our ACE right after 'D:' (wherever it is)
function Insert-Ace([string]`$sddl, [string]`$sid) {
  if (`$sddl -match [regex]::Escape(`$sid)) { return `$sddl }
  `$ace = "(A;;GRGX;;;" + `$sid + ")"
  `$idx = `$sddl.IndexOf('D:')
  if (`$idx -ge 0) {
    return `$sddl.Substring(0, `$idx + 2) + `$ace + `$sddl.Substring(`$idx + 2)
  } else {
    return 'D:' + `$ace + `$sddl
  }
}

# Connect Task Scheduler
`$svc = New-Object -ComObject "Schedule.Service"
`$svc.Connect()
try { `$folder = `$svc.GetFolder("\CHECHA") } catch { throw "Folder \CHECHA not found. Create tasks first." }

# Backup SDDL
`$backupDir = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tasks"
if (!(Test-Path `$backupDir)) { New-Item -ItemType Directory -Path `$backupDir | Out-Null }
`$stamp = Get-Date -Format yyyyMMdd_HHmmss
Set-Content (Join-Path `$backupDir "CHECHA_folder_sddl_`$stamp.txt") `$folder.GetSecurityDescriptor(0) -Encoding UTF8

# Apply to folder
`$orig = `$folder.GetSecurityDescriptor(0)
`$want = Insert-Ace `$orig `$sid
`$changedFolder = `$false
if (`$want -ne `$orig) { `$folder.SetSecurityDescriptor(`$want,0); `$changedFolder = `$true }

# Apply to each task
`$changedTasks = 0
`$tasks = @(); `$col = `$folder.GetTasks(0); foreach(`$t in `$col){ `$tasks += `$t }
`$i=0
foreach(`$t in `$tasks){
  `$i++; `$s = `$t.GetSecurityDescriptor(0)
  Set-Content (Join-Path `$backupDir ("CHECHA_task{0:00}_{1}_sddl_`$stamp.txt" -f `$i, `$t.Name)) `$s -Encoding UTF8
  `$s2 = Insert-Ace `$s `$sid
  if (`$s2 -ne `$s) { `$t.SetSecurityDescriptor(`$s2,0); `$changedTasks++ }
}

# Also grant NTFS RX on the tasks storage folder (helps schtasks/ps cmdlets on some systems)
`$tasksFs = "$env:SystemRoot\System32\Tasks\CHECHA"
if (Test-Path `$tasksFs) {
  & icacls "`$tasksFs" /grant "`$User:(RX)" /T /Q | Out-Null
}

Write-Host ("[ACL] Folder updated: {0}; Tasks updated: {1}" -f `$changedFolder, `$changedTasks) -ForegroundColor Cyan
"@

  # Elevate if needed
  $amIAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $amIAdmin) {
    $tmp = Join-Path $env:TEMP "checha_grant_acl_fix.ps1"
    [IO.File]::WriteAllText($tmp, $inner, [Text.UTF8Encoding]::new($false))
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$tmp`"")
  } else {
    Invoke-Expression $inner
  }

  # Quick status (best effort, non-elevated context)
  try {
    Get-ScheduledTaskInfo -TaskPath '\CHECHA\' -TaskName 'CreateStrategicTemplate-Daily' |
      Select-Object LastRunTime, @{n='LastResult';e={'0x{0:X8}' -f $_.LastTaskResult}}, NextRunTime | Out-Host
  } catch { Write-Host "MAIN info: $($_.Exception.Message)" -ForegroundColor DarkYellow }
  try {
    Get-ScheduledTaskInfo -TaskPath '\CHECHA\' -TaskName 'StrategicTemplate-HealthCheck' |
      Select-Object LastRunTime, @{n='LastResult';e={'0x{0:X8}' -f $_.LastTaskResult}}, NextRunTime | Out-Host
  } catch { Write-Host "HEALTH info: $($_.Exception.Message)" -ForegroundColor DarkYellow }
}
Set-Alias cgrant checha-grant-access -Scope Global

# --- override helpers (no-admin direct-run + logs) ---
function Get-LastTimestamp {
  param([string[]]$Lines,[string]$Pattern)
  $m = $Lines | Select-String -Pattern $Pattern | Select-Object -Last 1
  if($m){ 
    $ts = $m.Line.Substring(0,[Math]::Min(19,$m.Line.Length)) # "yyyy-MM-dd HH:mm:ss"
    try { return [datetime]::ParseExact($ts,'yyyy-MM-dd HH:mm:ss',$null) } catch { return $null }
  }
  return $null
}

function Get-ChechaLogInfo {
  $logDir = "C:\CHECHA_CORE\C03\LOG"
  $mainLog = Get-ChildItem $logDir -Filter strategic_template_*.log -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Desc | Select-Object -First 1
  $hcLog   = Join-Path $logDir "strategic_template_health.log"

  $mainLines = if($mainLog){ Get-Content $mainLog.FullName -ErrorAction SilentlyContinue } else { @() }
  $hcLines   = if(Test-Path $hcLog){ Get-Content $hcLog -ErrorAction SilentlyContinue } else { @() }

  $lastBegin   = Get-LastTimestamp $mainLines 'BEGIN Create-StrategicTemplate'
  $lastSuccess = Get-LastTimestamp $mainLines '\[INFO \] SUCCESS'
  $lastHC      = Get-LastTimestamp $hcLines   ' \[HEALTH\] '

  [pscustomobject]@{
    MainLogPath    = $mainLog.FullName
    LastMainBegin  = $lastBegin
    LastMainOK     = $lastSuccess
    LastHealthPing = $lastHC
  }
}

function checha-status {
  # 1) Логовий статус (працює завжди)
  $L = Get-ChechaLogInfo

  # 2) Best-effort спроба витягти з Планувальника (може вернути AccessDenied — ігноруємо)
  $sch = @()
  foreach($name in 'CreateStrategicTemplate-Daily','StrategicTemplate-HealthCheck'){
    $row = [pscustomobject]@{ Name=$name; State='?'; LastRunTime=$null; NextRunTime=$null; LastResult='?' }
    try{
      $t = Get-ScheduledTask -TaskPath '\CHECHA\' -TaskName $name -ErrorAction Stop
      $row.State = $t.State
    } catch {}
    try{
      $i = Get-ScheduledTaskInfo -TaskPath '\CHECHA\' -TaskName $name -ErrorAction Stop
      $row.LastRunTime = $i.LastRunTime
      $row.NextRunTime = $i.NextRunTime
      $row.LastResult  = ('0x{0:X8}' -f $i.LastTaskResult)
    } catch {}
    $sch += $row
  }

  Write-Host "`n=== CheCha STATUS ===" -ForegroundColor Cyan
  if($sch.Where({ $_.LastRunTime -or $_.NextRunTime -or $_.LastResult -ne '?' -or $_.State -ne '?' }).Count -gt 0){
    $sch | Format-Table Name, State, LastRunTime, NextRunTime, LastResult -AutoSize
  } else {
    Write-Host "(Scheduler API недоступний у цій сесії — показую статус із логів)" -ForegroundColor DarkYellow
  }

  Write-Host "`n--- From logs ---" -ForegroundColor Gray
  $ok = if($L.LastMainOK){ 'OK' } else { '-' }
  [pscustomobject]@{
    Main_LastBegin   = $L.LastMainBegin
    Main_LastSuccess = $L.LastMainOK
    Health_LastPing  = $L.LastHealthPing
    Main_Status      = $ok
  } | Format-List
}

function checha-run {
  [CmdletBinding()]
  param([ValidateSet('main','health','both')][string]$What='both')
  $pwsh = "C:\Program Files\PowerShell\7\pwsh.exe"
  $main = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Create-StrategicTemplate.ps1"
  $hc   = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Checha_StrategicTemplate_Health.ps1"

  Write-Host "[CheCha] DIRECT RUN (без Scheduler)" -ForegroundColor Green
  if($What -in @('main','both')){
    try{
      & $pwsh -NoProfile -ExecutionPolicy Bypass -File $main -OpenWith none
    } catch { Write-Host "[RUN FAIL] MAIN: $($_.Exception.Message)" -ForegroundColor Yellow }
  }
  if($What -in @('health','both')){
    try{
      & $pwsh -NoProfile -ExecutionPolicy Bypass -File $hc
    } catch { Write-Host "[RUN FAIL] HEALTH: $($_.Exception.Message)" -ForegroundColor Yellow }
  }

  # Best-effort: якщо Scheduler дозволяє — тригернемо й там (ігноруємо AccessDenied)
  foreach($tn in '\CHECHA\CreateStrategicTemplate-Daily','\CHECHA\StrategicTemplate-HealthCheck'){
    try { schtasks /Run /TN $tn | Out-Null; Write-Host "[Scheduler] Triggered $tn" -ForegroundColor DarkCyan } catch {}
  }

  Start-Sleep -Seconds 2
  checha-status
}

Set-Alias cstatus checha-status -Scope Global
Set-Alias crun    checha-run    -Scope Global

# quiet scheduler messages
Set-Item -Path function:checha-run -Value {
  [CmdletBinding()]
  param([ValidateSet('main','health','both')][string]$What='both')
  $pwsh = "C:\Program Files\PowerShell\7\pwsh.exe"
  $main = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Create-StrategicTemplate.ps1"
  $hc   = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Checha_StrategicTemplate_Health.ps1"

  Write-Host "[CheCha] DIRECT RUN (без Scheduler)" -ForegroundColor Green
  if($What -in @('main','both')){ try{ & $pwsh -NoProfile -ExecutionPolicy Bypass -File $main -OpenWith none } catch { Write-Host "[RUN FAIL] MAIN: $($_.Exception.Message)" -ForegroundColor Yellow } }
  if($What -in @('health','both')){ try{ & $pwsh -NoProfile -ExecutionPolicy Bypass -File $hc } catch { Write-Host "[RUN FAIL] HEALTH: $($_.Exception.Message)" -ForegroundColor Yellow } }

  foreach($tn in '\CHECHA\CreateStrategicTemplate-Daily','\CHECHA\StrategicTemplate-HealthCheck'){
    schtasks /Run /TN $tn 2>$null 1>$null
    if($LASTEXITCODE -eq 0){ Write-Host "[Scheduler] Triggered $tn" -ForegroundColor DarkCyan }
  }
  Start-Sleep 2
  checha-status
}
