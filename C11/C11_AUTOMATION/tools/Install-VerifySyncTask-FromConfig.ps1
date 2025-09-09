param(
  [Parameter(Mandatory=$true)][string]$ChechaRoot,
  [Parameter(Mandatory=$true)][string]$ConfigPath,
  [string]$Time="19:30",
  [ValidateSet("SUN","MON","TUE","WED","THU","FRI","SAT")][string]$Day="SUN"
)
$bat = Join-Path $ChechaRoot "C11\C11_AUTOMATION\tools\run_from_config.bat"

if (-not (Test-Path $bat))       { throw "Не знайдено BAT: $bat" }
if (-not (Test-Path $ConfigPath)){ throw "Не знайдено Config: $ConfigPath" }

$tn = "Checha-VerifySync-" + (Split-Path -LeafBase $ConfigPath)
$tr = ('"{0}" "{1}" "{2}"' -f $bat,$ChechaRoot,$ConfigPath)

function New-Task($rl){
  $cmd = 'schtasks.exe /Create /F /RL {0} /SC WEEKLY /D {1} /ST {2} /TN "{3}" /TR {4}' -f $rl,$Day,$Time,$tn,$tr
  cmd /c $cmd
  return $LASTEXITCODE
}

$rc = New-Task -rl "HIGHEST"
if ($rc -ne 0) {
  Write-Host "⚠ HIGHEST не створено (код $rc). Пробую LIMITED…" -ForegroundColor Yellow
  $rc = New-Task -rl "LIMITED"
}
if ($rc -ne 0) { throw "Створення задачі не вдалося. Код: $rc" }

schtasks.exe /Query /TN $tn /V /FO LIST
