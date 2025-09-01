param()
$ErrorActionPreference = 'Stop'

# База = C:\CHECHA_CORE\C12\Protocols
$base   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDir = Join-Path $base '_index\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Куди дзеркалимо
$Alias='checha'; $Bucket='checha-core'; $Prefix='C12/Protocols'
$TargetRoot = '{0}/{1}' -f $Alias,$Bucket
$Target     = '{0}/{1}' -f $TargetRoot,$Prefix

# Єдиний конфіг для SYSTEM/USER
$env:MC_CONFIG_DIR = 'C:\CHECHA_CORE\.mc'

function Resolve-McExe {
  $cmd = Get-Command mc -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach($p in @('C:\Tools\minio\mc.exe','C:\Program Files\MinIO\mc.exe','C:\Program Files (x86)\MinIO\mc.exe')){
    if (Test-Path $p) { return $p }
  }
  throw "mc.exe not found. Add to PATH or install MinIO client."
}

$mcExe = Resolve-McExe
$mcOut = Join-Path $logDir 'mc_stdout.txt'
$mcErr = Join-Path $logDir 'mc_stderr.txt'

# 1) bucket ensure
$p = Start-Process -FilePath $mcExe -ArgumentList @('mb','--ignore-existing', $TargetRoot) `
      -NoNewWindow -PassThru -Wait -RedirectStandardOutput $mcOut -RedirectStandardError $mcErr
if ($p.ExitCode -ne 0) { throw "mc mb exited $($p.ExitCode). See $mcOut / $mcErr" }

# 2) mirror БЕЗ --remove, з виключенням "гарячих" логів
$args = @('mirror','--overwrite')
foreach($pat in @(
  '_index/logs/*','*/_index/logs/*',  # наші журнали
  '*/logs/*',                         # будь-які інші каталоги logs
  '*.log','*.log.*',                  # будь-які .log
  '_index/mc_*.txt',                  # файли логів mc у _index
  'from-scheduler.txt'                # “хвіст” пайплайна
)){
  $args += @('--exclude', $pat)
}
$args += @($base, $Target)

$p = Start-Process -FilePath $mcExe -ArgumentList $args -NoNewWindow -PassThru -Wait `
      -RedirectStandardOutput $mcOut -RedirectStandardError $mcErr
if ($p.ExitCode -ne 0) { throw "mc mirror exited $($p.ExitCode). See $mcOut / $mcErr" }

Write-Host "Mirror OK -> $Target"
