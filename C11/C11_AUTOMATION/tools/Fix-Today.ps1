[CmdletBinding()]
param(
  [switch]$RunAll,
  [switch]$RecreateTasks
)

function Write-Info([string]$m){ Write-Host ("{0} [INFO ] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -ForegroundColor Cyan }
function Write-Ok  ([string]$m){ Write-Host ("{0} [ OK  ] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -ForegroundColor Green }
function Write-Warn([string]$m){ Write-Host ("{0} [WARN ] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -ForegroundColor Yellow }
function Write-Err ([string]$m){ Write-Host ("{0} [ERR  ] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -ForegroundColor Red }

$ErrorActionPreference='Stop'

function Ensure-Path([string]$p){ if(-not (Test-Path $p)){ throw "Not found: $p"} }

function Is-Admin {
  (New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
  )).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if(-not $pwshPath){ $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe" }

function New-OrUpdateTask {
  param(
    [string]$Name,
    [ValidateSet('DAILY','WEEKLY','ONCE')][string]$Schedule,
    [string]$TimeHHmm,
    [string]$ScriptPath,
    [string]$ScriptArgs
  )
  Ensure-Path $ScriptPath
  $admin = Is-Admin
  try{
    if($RecreateTasks){ Unregister-ScheduledTask -TaskName $Name -Confirm:$false -ErrorAction SilentlyContinue | Out-Null }
    $at = if($TimeHHmm){ [DateTime]::ParseExact($TimeHHmm,'HH:mm',$null) } else { (Get-Date).Date.AddHours(9) }
    switch($Schedule){
      'DAILY'  { $trigger = New-ScheduledTaskTrigger -Daily  -At $at }
      'WEEKLY' { $trigger = New-ScheduledTaskTrigger -Weekly -At $at }
      'ONCE'   { $trigger = New-ScheduledTaskTrigger -Once   -At (Get-Date).AddMinutes(1) }
    }
    $arg = ('-NoProfile -File "{0}" {1}' -f $ScriptPath, $ScriptArgs).Trim()
    $action = New-ScheduledTaskAction -Execute $pwshPath -Argument $arg
    $args = @{ TaskName=$Name; Action=$action; Trigger=$trigger; Force=$true }
    if($admin){ $args.RunLevel='Highest' }
    Register-ScheduledTask @args | Out-Null
    Write-Ok "Task ensured: $Name"
    return
  } catch {
    Write-Warn ("Register-ScheduledTask failed for {0}: {1}. Fallback to schtasks..." -f $Name, $_.Exception.Message)
  }

  # Фолбек: schtasks (все в один рядок, аби /TR не «розсипався»)
$quotedPwsh   = '"' + $pwshPath   + '"'
$quotedScript = '"' + $ScriptPath + '"'
$tr = ($quotedPwsh + ' -NoProfile -File ' + $quotedScript + ' ' + ($ScriptArgs ?? '')).Trim()

# /SC і /ST
$st = ''
if ($Schedule -ne 'ONCE' -and $TimeHHmm) { $st = ' /ST ' + $TimeHHmm }

# RunLevel
$rl = ''
if ($admin) { $rl = ' /RL HIGHEST' }

# Один суцільний рядок аргументів
$argLine = ('/Create /F /TN "{0}" /SC {1}{2}{3} /TR "{4}"' -f $Name, $Schedule, $st, $rl, $tr)

$p = Start-Process -FilePath 'schtasks.exe' -ArgumentList $argLine -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { throw ("schtasks failed: code {0}" -f $p.ExitCode) }
Write-Ok "Task ensured: $Name"
}

function Ensure-ChechaTasks {
  Write-Info "Ensuring scheduled tasks…"
  $rootTools = 'C:\CHECHA_CORE\C11\C11_AUTOMATION\tools'
  New-OrUpdateTask -Name 'Checha-Daily-StrategicTemplate' -Schedule DAILY -TimeHHmm '09:00' `
    -ScriptPath (Join-Path $rootTools 'Create-StrategicTemplate.ps1') -ScriptArgs ''
  New-OrUpdateTask -Name 'Checha-Monthly-StrategicReport' -Schedule DAILY -TimeHHmm '21:00' `
    -ScriptPath (Join-Path $rootTools 'Checha-SessionMonthlyReport.ps1') -ScriptArgs '-Mode Calendar'
}

function Ensure-VaultYaml {
  param([string]$DefaultTitle='CheCha Vault',[string]$DefaultSlogan='Швидко. Чітко. Щодня.')
  try{
    $idx='C:\CHECHA_CORE\C12\Vault\_index.md'
    $readme='C:\CHECHA_CORE\C12\Vault\README.md'
    $dash='C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Update-VaultDashboard.ps1'
    $sts='C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Set-TitleSlogan.ps1'

    if(-not (Test-Path $readme) -and (Test-Path $dash)){
      Write-Info ("Run: {0}" -f $dash)
      & $pwshPath -NoProfile -File $dash | Out-Null
    }

    $title=$DefaultTitle; $slogan=$DefaultSlogan
    if(Test-Path $readme){
      $rm = Get-Content -Raw -LiteralPath $readme
      $m  = [regex]::Match($rm,'^\s*---\r?\n(.*?)\r?\n---\s*\r?\n',[System.Text.RegularExpressions.RegexOptions]::Singleline)
      if($m.Success){
        $yaml=$m.Groups[1].Value
        $mt=[regex]::Match($yaml,'(?im)^\s*title\s*:\s*["'']?(?<t>.+?)["'']?\s*$'); if($mt.Success){ $title=$mt.Groups['t'].Value.Trim() }
        $md=[regex]::Match($yaml,'(?im)^\s*(description|slogan)\s*:\s*["'']?(?<d>.+?)["'']?\s*$'); if($md.Success){ $slogan=$md.Groups['d'].Value.Trim() }
      }
    }
    if(Test-Path $sts){
      & $sts -Title $title -Slogan $slogan -Targets @($idx,$readme) -YamlOnly | Out-Host
    }
  } catch {
    Write-Warn ("Vault YAML step skipped: {0}" -f $_.Exception.Message)
  }
}

if($RunAll){
  Write-Info "BEGIN Fix-Today for C:\CHECHA_CORE"

  try{ Ensure-ChechaTasks } catch { Write-Err ($_.Exception.Message) }

  try{
    $names='Checha-Daily-StrategicTemplate','Checha-Monthly-StrategicReport'
    Get-ScheduledTask -TaskName $names | Select TaskName,State | Format-Table -Auto | Out-Host
  } catch {}

  $dash='C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Update-VaultDashboard.ps1'
  if(Test-Path $dash){
    Write-Info ("Run: {0}" -f $dash)
    & $pwshPath -NoProfile -File $dash | Out-Host
  }

  Ensure-VaultYaml -DefaultTitle 'CheCha Vault' -DefaultSlogan 'Швидко. Чітко. Щодня.'
  Write-Ok "DONE Fix-Today"
}