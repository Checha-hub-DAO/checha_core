param()
$ErrorActionPreference = 'Stop'

# База = C:\CHECHA_CORE\C12\Protocols
$base   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDir = Join-Path $base '_index\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# 0) Готуємо staging-каталог (з чистим снапшотом без службових)
$stage  = Join-Path $env:TEMP ("protocols_stage_{0:yyyyMMddHHmmss}" -f (Get-Date))
New-Item -ItemType Directory -Force -Path $stage | Out-Null

# ВИКЛЮЧЕННЯ
$xd = @('_index','.git','.github','.vscode','checha','checha-core') # цілі каталоги
$xf = @('*.log','*.log.*','*.tmp','*.bak','desktop.ini','Thumbs.db') # окремі файли/маски

# 1) Копія в staging (без «гарячих» і службових)
$rcArgs = @($base, $stage, '/E',
  '/NFL','/NDL','/NJH','/NJS','/NC','/NS','/NP',  # тихий вивід
  '/R:1','/W:1'                                   # мінімальні ретраї
)
if ($xd.Count) { $rcArgs += @('/XD') + ($xd | ForEach-Object { Join-Path $base $_ }) }
if ($xf.Count) { $rcArgs += @('/XF') + $xf }

$rc = Start-Process -FilePath 'robocopy.exe' -ArgumentList $rcArgs -NoNewWindow -PassThru -Wait
# Robocopy: 0/1/2/3/5/6/7 — «успіх», 8+ — помилка
if ($rc.ExitCode -ge 8) { throw "robocopy failed with code $($rc.ExitCode)" }

# 2) Дзеркалимо зі staging у MinIO
$Alias='checha'; $Bucket='checha-core'; $Prefix='C12/Protocols'
$TargetRoot = '{0}/{1}' -f $Alias,$Bucket
$Target     = '{0}/{1}' -f $TargetRoot,$Prefix

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

# 2.1) Створюємо бакет, якщо треба
$p = Start-Process -FilePath $mcExe -ArgumentList @('mb','--ignore-existing', $TargetRoot) `
      -NoNewWindow -PassThru -Wait -RedirectStandardOutput $mcOut -RedirectStandardError $mcErr
if ($p.ExitCode -ne 0) { throw "mc mb exited $($p.ExitCode). See $mcOut / $mcErr" }

# 2.2) Дзеркало БЕЗ --remove (як у тебе вручну)
$p = Start-Process -FilePath $mcExe -ArgumentList @('mirror','--overwrite', $stage, $Target) `
      -NoNewWindow -PassThru -Wait -RedirectStandardOutput $mcOut -RedirectStandardError $mcErr
if ($p.ExitCode -ne 0) { throw "mc mirror exited $($p.ExitCode). See $mcOut / $mcErr" }

# 3) Прибирання staging
Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Mirror OK -> $Target"
