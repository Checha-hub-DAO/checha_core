$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location -LiteralPath $PSScriptRoot
$env:MC_CONFIG_DIR = 'C:\CHECHA_CORE\.mc'

# === ЛОГИ ===
$logDir = Join-Path $PSScriptRoot '_index\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log   = Join-Path $logDir ("Run-Daily_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
$trace = Join-Path $logDir 'from-scheduler.txt'
function HB([string]$msg){
  $utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + 'Z'
  Add-Content -Path $trace -Encoding ASCII -Value ("[Run-Daily] {0}  {1}" -f $utc, $msg)
}

Start-Transcript -Path $log -Append | Out-Null
HB 'ENTER'

# М’ЮТЕКС (нова мітка)
$mtx = New-Object System.Threading.Mutex($false,'Global\CHECHA_PROTOCOLS_DAILY_V5')
if (-not $mtx.WaitOne(0)) { HB 'Already running → exit 0'; Stop-Transcript; exit 0 }

# === ДІАГНОСТИКА ОТОЧЕННЯ ===
HB ("PS=" + $PSVersionTable.PSVersion)
HB ("USER=" + (whoami))
HB ("PATH=" + $env:PATH)
HB ("MC_CONFIG_DIR=" + $env:MC_CONFIG_DIR)

function Resolve-McExe {
  $cand = @()
  $cmd = Get-Command mc -ErrorAction SilentlyContinue
  if ($cmd) { $cand += $cmd.Source }
  $cand += @(
    'C:\Program Files\MinIO\mc.exe',
    'C:\Program Files (x86)\MinIO\mc.exe',
    "C:\Users\$env:USERNAME\scoop\shims\mc.exe",
    "C:\Users\$env:USERNAME\bin\mc.exe",
    "C:\Users\$env:USERNAME\mc\mc.exe"
  )
  foreach($p in $cand | Where-Object { $_ } | Select-Object -Unique){
    if (Test-Path -LiteralPath $p) { return (Resolve-Path $p).Path }
  }
  return $null
}

function Invoke-Mc([string[]]$Args){
  $mcExe = Resolve-McExe
  if (-not $mcExe) { throw "mc.exe not found (PATH/known locations). Install MinIO client or add to PATH." }

  $argsStr = ($Args | ForEach-Object { $_ -match '\s' ? '"{0}"' -f $_ : $_ }) -join ' '
  HB ("MC: `"$mcExe`" " + $argsStr)

  $mcOut = Join-Path $logDir 'mc_stdout.txt'
  $mcErr = Join-Path $logDir 'mc_stderr.txt'

  $p = Start-Process -FilePath $mcExe -ArgumentList $Args -NoNewWindow -PassThru -Wait `
        -RedirectStandardOutput $mcOut -RedirectStandardError $mcErr
  if ($p.ExitCode -ne 0) {
    HB ("MC FAILED code " + $p.ExitCode)
    throw "mc exited $($p.ExitCode). See $mcOut / $mcErr"
  }
}

try {
  if (Test-Path "$PSScriptRoot\_index\McHelpers.ps1") { . "$PSScriptRoot\_index\McHelpers.ps1"; HB 'McHelpers loaded' }

  # === ОСНОВНІ КРОКИ ===
  HB 'Reindex';        .\protocol_reindex_from_files.ps1
  HB 'Generate table'; .\generate_protocols_table.ps1
  if (Test-Path .\Check-Index.ps1)   { HB 'Check index';   .\Check-Index.ps1 }
  if (Test-Path .\Export-Report.ps1) { HB 'Export report'; .\Export-Report.ps1 }

  # === BACKUP → MinIO (мінімалістичний, як у ручному тесті) ===
  HB 'Backup to MinIO (inline wrapper)'
  & (Join-Path $PSScriptRoot '_index\Backup-MinIO-Inline.ps1')
  HB 'Backup OK'
  HB 'DONE OK'
  Write-Host '✅ DAILY OK'
}
catch {
  HB ("ERROR: " + $_.Exception.Message)
  $traceDump = ($_ | Format-List * -Force | Out-String)
  HB ("TRACE: " + $traceDump.Trim())
  Write-Error $_
  exit 1
}
finally {
  $mtx.ReleaseMutex() | Out-Null
  Stop-Transcript | Out-Null
}

