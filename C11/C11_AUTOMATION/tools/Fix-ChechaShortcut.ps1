Start-Sleep -Seconds 5
$ErrorActionPreference = "SilentlyContinue"

function Test-IsAdmin(){
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { $false }
}

# Paths
$ToolsDir  = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools"
$MasterLnk = Join-Path $ToolsDir "CheCha CONTROL PANEL.master.lnk"

$targets = @(
  (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\CheCha CONTROL PANEL.lnk')
)
if (Test-IsAdmin) { $targets += (Join-Path $env:Public 'Desktop\CheCha CONTROL PANEL.lnk') }

# Log
$logDir  = "C:\CHECHA_CORE\C03\LOG"
if(-not (Test-Path $logDir)){ New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "shortcut_restore.log"
"{0} START restore" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Out-File -FilePath $logFile -Append -Encoding utf8

foreach($t in $targets){
  try{
    $dir = Split-Path $t -Parent
    if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    Copy-Item $MasterLnk $t -Force
    try{ (Get-Item $t).Attributes = 'ReadOnly' }catch{}
    try{ attrib +P $t 2>$null }catch{}
    "{0} OK   {1}" -f (Get-Date -Format 'HH:mm:ss'), $t | Out-File -FilePath $logFile -Append -Encoding utf8
  }
  catch {
    # ASCII only
    "{0} ERR  {1} - {2}" -f (Get-Date -Format 'HH:mm:ss'), $t, $_.Exception.Message | Out-File -FilePath $logFile -Append -Encoding utf8
  }
}
