[CmdletBinding()]param([string]$ChechaRoot="C:\CHECHA_CORE",[string]$Time="19:30",[ValidateSet("SUN","MON","TUE","WED","THU","FRI","SAT")][string]$Day="SUN")
$bat = Join-Path $ChechaRoot "G\G45\45.1_АОТ\tools\run_verify_sync.bat"; if(-not (Test-Path $bat)){Write-Host "❌ Не знайдено "+$bat; exit 1}
$cmd = 'schtasks.exe /Create /F /RL HIGHEST /SC WEEKLY /D {0} /ST {1} /TN "Checha-VerifySync-G45_1" /TR "{2}"' -f $Day,$Time,$bat
cmd /c $cmd | Out-Host
schtasks.exe /Query /TN "Checha-VerifySync-G45_1" /V /FO LIST | Out-Host
