param(
  # РџРѕРІРЅРёР№ С€Р»СЏС… РґРѕ Р·РіРµРЅРµСЂРѕРІР°РЅРѕРіРѕ Р·РІС–С‚Сѓ (СЏРє Сѓ РІРёРІРѕРґС– Agent-Strateg)
  [Parameter(Mandatory=$true)]
  [string]$ReportPath,

  # РљРѕСЂС–РЅСЊ СЃРёСЃС‚РµРјРё
  [string]$Root = "C:\CHECHA_CORE",

  # РЈРІС–РјРєРЅСѓС‚Рё MinIO sync (Р·Р° РЅР°СЏРІРЅРѕСЃС‚С– mc.exe С– РїСЂРѕС„С–Р»СЋ)
  [switch]$MinIO
)

function Write-Ok($m){ Write-Host "[ OK ] $m" -ForegroundColor Green }
function Write-Info($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[ERR ] $m" -ForegroundColor Red }

if(-not (Test-Path $ReportPath)){
  Write-Err "Report not found: $ReportPath"
  exit 1
}

# --------- РЁР»СЏС…Рё Сѓ Vault ----------
$vaultDir    = Join-Path $Root "C12\Vault\StrategicReports"
$indexDir    = Join-Path $Root "C12\_index"
$indexPath   = Join-Path $indexDir "VAULT_INDEX.json"
$logDir      = Join-Path $Root "C03\LOG"
$null = New-Item -ItemType Directory -Path $vaultDir,$indexDir,$logDir -Force -ErrorAction SilentlyContinue

# Р С–Рє РґР»СЏ СЂРѕР·РєР»Р°РґР°РЅРЅСЏ
$dt   = Get-Date
$yearDir = Join-Path $vaultDir $dt.Year
$null = New-Item -ItemType Directory -Path $yearDir -Force -ErrorAction SilentlyContinue

# --------- РљРѕРїС–СЏ Сѓ Vault ----------
$destPath = Join-Path $yearDir ([IO.Path]::GetFileName($ReportPath))
Copy-Item -Path $ReportPath -Destination $destPath -Force
Write-Ok "Copied to Vault: $destPath"

# --------- SHA256 ----------
$sha = (Get-FileHash -Path $destPath -Algorithm SHA256).Hash
Write-Info "SHA256: $sha"

# --------- Р—Р°РїРёСЃ Сѓ VAULT_INDEX.json ----------
# РЎС‚СЂСѓРєС‚СѓСЂР° РµР»РµРјРµРЅС‚Р°
$item = [ordered]@{
  id          = "strategic-report::$($dt.ToString('yyyyMMdd_HHmmss'))"
  type        = "document"
  category    = "StrategicReport"
  title       = [IO.Path]::GetFileNameWithoutExtension($destPath)
  date        = $dt.ToString("yyyy-MM-dd")
  path        = $destPath
  sha256      = $sha
  tags        = @("G44","Agent-Strateg","DAO-GOGS","Р©РРў-4","CheChaUniversity")
}

# РџСЂРѕС‡РёС‚Р°С‚Рё С–СЃРЅСѓСЋС‡РёР№ С–РЅРґРµРєСЃ (Р°Р±Рѕ СЃС‚РІРѕСЂРёС‚Рё)
if(Test-Path $indexPath){
  try {
    $json = Get-Content $indexPath -Raw | ConvertFrom-Json
    if(-not ($json -is [System.Collections.IEnumerable])){ $json = @($json) }
    $json = @($json) + (New-Object PSObject -Property $item)
  } catch {
    Write-Warn "Corrupted VAULT_INDEX.json вЂ” recreating"
    $json = @(@{ note="index recreated" }, (New-Object PSObject -Property $item))
  }
} else {
  $json = @((New-Object PSObject -Property $item))
}

# Р’С–РґСЃРѕСЂС‚СѓС”РјРѕ Р·Р° РґР°С‚РѕСЋ (РЅРѕРІС– РІ РєС–РЅС†С–)
$json = $json | Sort-Object { $_.date }, { $_.title }

# Р—Р±РµСЂРµРіС‚Рё
$json | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $indexPath
Write-Ok "Index updated: $indexPath"

# --------- Р›РѕРі ----------
$miniLog = Join-Path $logDir ("vault_post_strateg_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Added=$destPath SHA256=$sha" | Set-Content -Encoding UTF8 $miniLog
Write-Ok "Logged: $miniLog"

# --------- (РћРїС†С–Р№РЅРѕ) MinIO ----------
if($MinIO){
  # РќР°Р»Р°С€С‚СѓР№ СЃРІС–Р№ alias: mc alias set checha http(s)://... access secret
  $mc = Join-Path $Root "tools\mc.exe"
  if(Test-Path $mc){
    $bucketPath = "checha/checha-core/C12/Vault/StrategicReports/$($dt.Year)"
    & $mc cp $destPath "checha/$bucketPath/" | Out-Null
    if($LASTEXITCODE -eq 0){
      Write-Ok "Uploaded to MinIO: $bucketPath"
    } else {
      Write-Warn "MinIO upload failed (mc exitcode=$LASTEXITCODE)"
    }
  } else {
    Write-Warn "mc.exe not found; skip MinIO"
  }
}
# ---- Update README.md (latest reports & archives) ----
try{
  $gen = Join-Path $PSScriptRoot "Generate-StrategicReportsReadme.ps1"
  if(Test-Path $gen){
    Write-Info "Updating StrategicReports READMEвЂ¦"
    pwsh -NoProfile -ExecutionPolicy Bypass -File $gen -Root $Root
    Write-Ok "README updated"
  } else {
    Write-Warn "Generate-StrategicReportsReadme.ps1 not found; skip README update"
  }
}catch{
  Write-Warn "README update failed: $($_.Exception.Message)"
}
# Auto-update README
$gen = "C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\Generate-StrategicReportsReadme.ps1"
if (Test-Path $gen) {
  pwsh -NoProfile -ExecutionPolicy Bypass -File $gen
}
