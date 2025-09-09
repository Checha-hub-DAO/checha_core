param(
  [string]$Root = "C:\CHECHA_CORE",
  [switch]$UseMinIO = $false
)

function OK($m){ Write-Host "[ OK ] $m" -f Green }
function INF($m){ Write-Host "[INF] $m" -f Cyan }
function WRN($m){ Write-Host "[WRN] $m" -f Yellow }

# РџРѕРїРµСЂРµРґРЅС–Р№ РјС–СЃСЏС†СЊ
$now = Get-Date
$prev = $now.AddMonths(-1)
$y = $prev.ToString("yyyy")
$m = $prev.ToString("MM")

$srcDir  = Join-Path $Root "C12\Vault\StrategicReports\$y"
$archDir = Join-Path $Root "C12\Vault\StrategicReports\ARCHIVE\$y"
$logDir  = Join-Path $Root "C03\LOG"
$null = New-Item -Type Directory -Path $archDir,$logDir -Force -EA SilentlyContinue

if(!(Test-Path $srcDir)){ WRN "No source dir: $srcDir"; exit 0 }

# Р’РёР±С–СЂРєР° Р·РІС–С‚С–РІ РїРѕРїРµСЂРµРґРЅСЊРѕРіРѕ РјС–СЃСЏС†СЏ
$reports = Get-ChildItem $srcDir -Filter "Strateg_Report_*.md" -File -EA SilentlyContinue |
           Where-Object { $_.LastWriteTime.ToString("yyyyMM") -eq "$y$m" } |
           Sort-Object Name
if(!$reports){ WRN "No reports for $y-$m"; exit 0 }

$zipName = "Strategic_$y-$m.zip"
$zipPath = Join-Path $archDir $zipName
$tmpDir  = Join-Path $env:TEMP ("strategic_pack_"+[guid]::NewGuid().ToString("N"))
$null = New-Item -Type Directory -Path $tmpDir -Force -EA SilentlyContinue

# РљРѕРїС–СЏ Сѓ С‚РёРјС‡Р°СЃРѕРІРёР№ РєР°С‚Р°Р»РѕРі
$reports | ForEach-Object { Copy-Item $_.FullName $tmpDir -Force }
# CHECKSUMS.txt
$sumPath = Join-Path $tmpDir "CHECKSUMS.txt"
$reports | ForEach-Object {
  $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
  "{0}  {1}" -f $h, $_.Name | Add-Content -Encoding UTF8 $sumPath
}

# РЈРїР°РєРѕРІРєР°
if(Test-Path $zipPath){ Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $tmpDir "*") -DestinationPath $zipPath

# РџС–РґСЃСѓРјРєРѕРІРёР№ С…РµС€ Р°СЂС…С–РІСѓ
$zipHash = (Get-FileHash $zipPath -Algorithm SHA256).Hash

# Р›РѕРі
$miniLog = Join-Path $logDir ("strategic_archive_"+(Get-Date -Format "yyyyMMdd_HHmmss")+".log")
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ZIP=$zipPath HASH=$zipHash FILES=$($reports.Count)" |
  Set-Content -Encoding UTF8 $miniLog

OK "Created: $zipPath"
INF "SHA256: $zipHash"
INF "Logged:  $miniLog"

# (РћРїС†С–Р№РЅРѕ) MinIO
if($UseMinIO){
  $mc = Join-Path $Root "tools\mc.exe"
  if(Test-Path $mc){
    $bucket = "checha/checha-core/C12/Vault/StrategicReports/ARCHIVE/$y"
    & $mc cp $zipPath "checha/$bucket/" | Out-Null
    if($LASTEXITCODE -eq 0){ OK "Uploaded to MinIO: $bucket/$zipName" } else { WRN "MinIO upload failed" }
  } else { WRN "mc.exe not found; skip MinIO" }
}

# РџСЂРёР±РёСЂР°РЅРЅСЏ
Remove-Item $tmpDir -Recurse -Force -EA SilentlyContinue
# ---- Update README.md (include new archive) ----
try{
  $gen = Join-Path $PSScriptRoot "Generate-StrategicReportsReadme.ps1"
  if(Test-Path $gen){
    INF "Updating StrategicReports READMEвЂ¦"
    pwsh -NoProfile -ExecutionPolicy Bypass -File $gen -Root $Root
    OK "README updated"
  } else {
    WRN "Generate-StrategicReportsReadme.ps1 not found; skip README update"
  }
}catch{
  WRN "README update failed: $($_.Exception.Message)"
}
# Auto-update README after archive
$gen = "C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\Generate-StrategicReportsReadme.ps1"
if (Test-Path $gen) {
  pwsh -NoProfile -ExecutionPolicy Bypass -File $gen
}
