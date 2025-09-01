param(
  [string]$Endpoint,                         # напр. https://minio.example.com або http://IP:9000
  [Parameter(Mandatory)][string]$BucketPath, # напр. checha-core/C12/Protocols
  [string]$Alias = "checha",                 # alias для mc
  [switch]$RemoveExtra,                      # робити повне дзеркало (видаляти зайве у бакеті)
  [switch]$DryRun,                           # сухий прогін
  [switch]$Insecure,                         # для самопідписаного TLS або IP
  [string]$AccessKey,
  [string]$SecretKey
)

$ErrorActionPreference = "Stop"
$Root = "C:\CHECHA_CORE\C12\Protocols"

function HasCmd($n){ [bool](Get-Command $n -ErrorAction SilentlyContinue) }
$mc = if (HasCmd "mc") { "mc" } elseif (Test-Path "C:\Tools\minio\mc.exe") { "C:\Tools\minio\mc.exe" } else { $null }
if (-not $mc) { throw "MinIO client (mc) не знайдено у PATH або C:\Tools\minio\mc.exe" }

# Глобальні прапори mc
$global = @()
if ($Insecure) { $global += "--insecure" }
$global += "--disable-pager"

# Якщо передано Endpoint — налаштуємо/оновимо alias
if ($Endpoint) {
  $ak = if ($AccessKey) { $AccessKey } elseif ($env:MINIO_ACCESS_KEY) { $env:MINIO_ACCESS_KEY } else { $null }
  $sk = if ($SecretKey) { $SecretKey } elseif ($env:MINIO_SECRET_KEY) { $env:MINIO_SECRET_KEY } else { $null }
  if (-not $ak -or -not $sk) {
    throw "Для -Endpoint потрібно вказати AccessKey/SecretKey (параметрами або через змінні середовища MINIO_ACCESS_KEY / MINIO_SECRET_KEY)."
  }
  & $mc @($global + @("alias","set",$Alias,$Endpoint,$ak,$sk))
  if ($LASTEXITCODE -ne 0) { throw "mc alias set failed ($LASTEXITCODE)" }
}

# Збір аргументів mirror з виключеннями службових файлів
$mirror = @("mirror", $Root, "$Alias/$BucketPath", "--overwrite",
  "--exclude", "*\_index\protocols_index.bak_*.json",
  "--exclude", "*\_index\*.tmp",
  "--exclude", "*\_index\Protocols.md",
  "--exclude", "*\_index\Protocols_Report.md"
)
if ($RemoveExtra) { $mirror += "--remove" }
if ($DryRun)      { $mirror += "--dry-run" }

# Запуск mirror
& $mc @($global + $mirror)
if ($LASTEXITCODE -ne 0) { throw "mc mirror failed ($LASTEXITCODE)" }

# Коротка перевірка кількостей (з тими самими exclude)
$localCount = (Get-ChildItem $Root -Recurse -File | Where-Object {
  $_.FullName -notmatch '\\_index\\(protocols_index\.bak_.*\.json|.*\.tmp|Protocols(_Report)?\.md)$'
} | Measure-Object | Select-Object -ExpandProperty Count)

$remoteCount = (& $mc @($global + @("ls","--recursive","$Alias/$BucketPath")) | Measure-Object).Count

Write-Host ("LOCAL:  {0}" -f $localCount)
Write-Host ("REMOTE: {0}" -f $remoteCount)
Write-Host ("✅ Резервна копія синхронізована до {0}/{1} (mc)" -f $Alias, $BucketPath) -ForegroundColor Green