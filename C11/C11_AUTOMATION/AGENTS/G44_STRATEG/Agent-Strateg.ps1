<#
  G44 вЂ” Agent-Strateg.ps1
  РђРІС‚РѕСЂ: РЎ.Р§. / CheCha Assistant
  РџСЂРёР·РЅР°С‡РµРЅРЅСЏ: Р·С–Р±СЂР°С‚Рё РєРѕСЂРѕС‚РєРёР№ СЃС‚СЂР°С‚РµРіС–С‡РЅРёР№ Р·РІС–С‚ (DAO-GOGS, Р©РРўвЂ‘4 РћРґРµСЃР°, CheCha University)
  Р¤РѕСЂРјР°С‚ РІРёС…РѕРґСѓ: Markdown-С„Р°Р№Р» Сѓ C11\C11_AUTOMATION\AGENTS\G44_STRATEG\reports\

  РњРµС…Р°РЅС–РєР°:
  вЂў РџС–РґС‚СЏРіСѓС” Р±Р°Р·РѕРІС– СЃРёРіРЅР°Р»Рё Р· C03\LOG (РѕСЃС‚Р°РЅРЅС– С„Р°Р№Р»Рё) С‚Р° RHYTHM_DASHBOARD.md.
  вЂў РћР±С‡РёСЃР»СЋС” РїСЂРёР±Р»РёР·РЅРёР№ Р±Р°Р»Р°РЅСЃ С„РѕРєСѓСЃС–РІ (С‚РµС…РЅС–С‡РЅРёР№ / РїСѓР±Р»С–С‡РЅРёР№ / С„С–Р»РѕСЃРѕС„СЃСЊРєРёР№) РµРІСЂРёСЃС‚РёС‡РЅРѕ Р·Р° РєР»СЋС‡РѕРІРёРјРё СЃР»РѕРІР°РјРё.
  вЂў Р“РµРЅРµСЂСѓС” Р·РІС–С‚ С–Р· С€Р°Р±Р»РѕРЅСѓ. РЇРєС‰Рѕ TEMPLATE_STRATEG_REPORT.md РІС–РґСЃСѓС‚РЅС–Р№ вЂ” СЃС‚РІРѕСЂСЋС” РґРµС„РѕР»С‚РЅРёР№.

  Р—Р°РїСѓСЃРє (РїСЂРёРєР»Р°Рґ):
  pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\Agent-Strateg.ps1"

  РџР»Р°РЅСѓРІР°Р»СЊРЅРёРє (РїСЂРёРєР»Р°Рґ СЂР°Р· РЅР° С‚РёР¶РґРµРЅСЊ, РЅРµРґС–Р»СЏ 09:00):
  schtasks /Create /TN Checha-Agent-Strateg-Weekly /TR "pwsh -NoProfile -ExecutionPolicy Bypass -File C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\Agent-Strateg.ps1" /SC WEEKLY /D SUN /ST 09:00
#>
param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$AgentDirRel = "C11\C11_AUTOMATION\AGENTS\G44_STRATEG",
  [string]$ReportsRel = "reports",
  [string]$TemplateName = "TEMPLATE_STRATEG_REPORT.md",
  [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
  [int]$LogTail = 400,
  [switch]$Quiet
)

function Write-Info($msg){ if(-not $Quiet){ Write-Host "[INFO] $msg" -ForegroundColor Cyan } }
function Write-Ok($msg){ if(-not $Quiet){ Write-Host "[ OK ] $msg" -ForegroundColor Green } }
function Write-Warn($msg){ if(-not $Quiet){ Write-Host "[WARN] $msg" -ForegroundColor Yellow } }
function Write-Err($msg){ Write-Host "[ERR ] $msg" -ForegroundColor Red }

# РЁР»СЏС…Рё
$AgentDir = Join-Path $Root $AgentDirRel
$ReportsDir = Join-Path $AgentDir $ReportsRel
$TemplatePath = Join-Path $AgentDir $TemplateName
$LogDir = Join-Path $Root "C03\LOG"
$RhythmPath = Join-Path $Root "RHYTHM_DASHBOARD.md"

# РџРµСЂРµРєРѕРЅР°С‚РёСЃСЏ, С‰Рѕ РєР°С‚Р°Р»РѕРіРё С–СЃРЅСѓСЋС‚СЊ
$null = New-Item -ItemType Directory -Path $AgentDir -Force -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path $ReportsDir -Force -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction SilentlyContinue

# --- Р”РµС„РѕР»С‚РЅРёР№ С€Р°Р±Р»РѕРЅ, СЏРєС‰Рѕ РІС–РґСЃСѓС‚РЅС–Р№ ---
$defaultTemplate = @'
# рџ“‘ РЎС‚СЂР°С‚РµРіС–С‡РЅРёР№ Р·РІС–С‚ РђРіРµРЅС‚Р°-РЎС‚СЂР°С‚РµРіР°
**Р”Р°С‚Р°:** {{DATE}}

---

## 1. Р—Р°РіР°Р»СЊРЅРёР№ СЃС‚Р°РЅ
- **DAO-GOGS**: {{DAO_STATE}}
- **Р©РРў-4 РћРґРµСЃР°**: {{SHIELD_STATE}}
- **CheCha University**: {{CCU_STATE}}

---

## 2. РЎРёР»СЊРЅС– СЃС‚РѕСЂРѕРЅРё (С†СЊРѕРіРѕ РїРµСЂС–РѕРґСѓ)
{{STRENGTHS}}

---

## 3. Р РёР·РёРєРё С‚Р° РІС–РґС…РёР»РµРЅРЅСЏ
{{RISKS}}

---

## 4. РќР°СЃС‚СѓРїРЅС– РєСЂРѕРєРё (2вЂ“3 С‚РёР¶РЅС–)
- DAO-GOGS в†’ {{NEXT_DAO}}
- Р©РРў-4 РћРґРµСЃР° в†’ {{NEXT_SHIELD}}
- CheCha University в†’ {{NEXT_CCU}}

---

## 5. Р¤С–Р»РѕСЃРѕС„СЃСЊРєРёР№ РІРµРєС‚РѕСЂ
*"{{PHILOS}}"*

---

## 6. Р С–РІРµРЅСЊ РіР°СЂРјРѕРЅС–С—
- вљ™пёЏ РўРµС…РЅС–С‡РЅРёР№ С„РѕРєСѓСЃ: **{{TECH_PCT}}%**
- рџЋ¤ РџСѓР±Р»С–С‡РЅРёР№ С„РѕРєСѓСЃ: **{{PUB_PCT}}%**
- рџЊЊ Р¤С–Р»РѕСЃРѕС„СЃСЊРєРёР№ С„РѕРєСѓСЃ: **{{PHIL_PCT}}%**
'@

if(-not (Test-Path $TemplatePath)){
  Write-Warn "РЁР°Р±Р»РѕРЅ РЅРµ Р·РЅР°Р№РґРµРЅРѕ вЂ” СЃС‚РІРѕСЂСЋСЋ РґРµС„РѕР»С‚РЅРёР№: $TemplatePath"
  $defaultTemplate | Set-Content -Path $TemplatePath -Encoding UTF8
  Write-Ok "РЎС‚РІРѕСЂРµРЅРѕ TEMPLATE_STRATEG_REPORT.md"
}

# --- Р—Р±С–СЂ СЃРёРіРЅР°Р»С–РІ С–Р· Р»РѕРіС–РІ ---
$latestLogs = @()
if(Test-Path $LogDir){
  $latestLogs = Get-ChildItem $LogDir -File -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 6
}

# РўРµРєСЃС‚ РґР»СЏ Р°РЅР°Р»С–Р·Сѓ
$sampleText = ""
foreach($f in $latestLogs){
  try{ $sampleText += (Get-Content -Path $f.FullName -Tail $LogTail -ErrorAction Stop) -join "`n" + "`n" }
  catch{ Write-Warn "РќРµ РІРґР°Р»РѕСЃСЏ РїСЂРѕС‡РёС‚Р°С‚Рё $($f.Name): $($_.Exception.Message)" }
}
if(Test-Path $RhythmPath){
  try{ $sampleText += (Get-Content $RhythmPath -Tail 200) -join "`n" } catch{}
}

# --- Р•РІСЂРёСЃС‚РёРєР° Р±Р°Р»Р°РЅСЃСѓ С„РѕРєСѓСЃС–РІ ---
# РљР»СЋС‡РѕРІС– СЃР»РѕРІР° РјРѕР¶РЅР° РґРѕРїРѕРІРЅСЋРІР°С‚Рё РїС–Рґ СЃРёСЃС‚РµРјСѓ
$techKeys = @('git','release','zip','checksum','CI/CD','powershell','script','docker','MinIO','rebase','push','branch','tag','ps1','verify','archive')
$pubKeys  = @('РћРґРµСЃР°','Р·СѓСЃС‚СЂС–С‡','РєСЂСѓРіР»РёР№ СЃС‚С–Р»','РїСѓР±Р»С–РєР°С†С–СЏ','Telegram','Facebook','GitBook','РјРѕР»РѕРґСЊ','С‡РёС‚Р°Р»СЊРЅР°','РІС–РґРєСЂРёС‚РёР№ Р·Р°С…С–Рґ','РІРёСЃС‚СѓРї','РїСЂРµР·РµРЅС‚Р°С†С–СЏ')
$phiKeys  = @('С„С–Р»РѕСЃРѕС„','СЃРµРЅСЃ','РјС–С„РѕР»РѕРі','РјРѕСЂР°Р»СЊРЅРёР№ РєРѕРјРїР°СЃ','РґСѓС…РѕРІРЅ','СЃРІС–РґРѕРјС–СЃС‚СЊ','РЅР°СЂР°С‚РёРІ','СЃРёРјРІРѕР»','РєСѓР»СЊС‚СѓСЂР°','Р°СЂС…РµС‚РёРї')

function Count-Matches($text, $patterns){
  $c = 0
  foreach($p in $patterns){
    $c += ([regex]::Matches($text, [regex]::Escape($p), 'IgnoreCase')).Count
  }
  return $c
}

$techCount = Count-Matches $sampleText $techKeys
$pubCount  = Count-Matches $sampleText $pubKeys
$phiCount  = Count-Matches $sampleText $phiKeys
$total = [Math]::Max(1, ($techCount + $pubCount + $phiCount))
$techPct = [Math]::Round(($techCount / $total) * 100)
$pubPct  = [Math]::Round(($pubCount  / $total) * 100)
$phiPct  = 100 - $techPct - $pubPct

Write-Info "Р•РІСЂРёСЃС‚РёРєР° С„РѕРєСѓСЃС–РІ в†’ TECH=$techPct% PUB=$pubPct% PHIL=$phiPct%"

# --- Р—Р°РіРѕС‚РѕРІРєРё Р·РјС–СЃС‚Сѓ (РјРѕР¶РЅР° Р·Р°РјС–РЅСЏС‚Рё СЂСѓС‡РЅРёРј РІРІРµРґРµРЅРЅСЏРј Р°Р±Рѕ РѕРєСЂРµРјРёРјРё С„Р°Р№Р»Р°РјРё-РґР¶РµСЂРµР»Р°РјРё) ---
$daoState     = "РЇРґСЂРѕ (G01вЂ“G44) СЃС‚Р°Р±С–Р»С–Р·РѕРІР°РЅРѕ; Starter Kit РіРѕС‚РѕРІРёР№ РґРѕ РїСѓР±Р»С–С‡РЅРѕРіРѕ РїРѕРєР°Р·Сѓ; РІР°Р¶Р»РёРІРѕ РІРёР№С‚Рё Р· С‚РµС…РЅС–С‡РЅРѕС— РјРѕРІРё РґРѕ РіСЂРѕРјР°РґСЃСЊРєРѕС—."
$shieldState  = "Р©РРўвЂ‘4 РћРґРµСЃР° РІРёР·РЅР°С‡РµРЅРѕ СЏРє РІСѓР·РѕР» СЃРёР»Рё; СЃС‚Р°СЂС‚РѕРІРёР№ РєСЂРѕРє вЂ” РїСѓР±Р»С–С‡РЅРёР№ РєСЂСѓРіР»РёР№ СЃС‚С–Р» / С‡РёС‚Р°Р»СЊРЅР° Р·СѓСЃС‚СЂС–С‡; РїРѕС‚СЂС–Р±РЅС– РїР°СЂС‚РЅРµСЂРёвЂ‘РјР°Р№РґР°РЅС‡РёРєРё."
$ccuState     = "Р‘Р°Р·Р° CheCha University СЃС„РѕСЂРјРѕРІР°РЅР° (РєРЅРёРіРё, РєРѕРјРїР°СЃ, РЅР°РїСЂСЏРјРё); РїРµСЂС€Р° РґС–СЏ вЂ” РїС–Р»РѕС‚РЅР° Р»РµРєС†С–СЏ РґР»СЏ РјРѕР»РѕРґС– РћРґРµСЃРё."
$strengths    = "- РЎС‚Р°Р±С–Р»СЊРЅР° С–РЅС„СЂР°СЃС‚СЂСѓРєС‚СѓСЂР° (Р»РѕРіРё, СЂРµР»С–Р·Рё, Р°СЂС…С–РІРё).`n- РЇРґСЂРѕ DAO-GOGS РѕС„РѕСЂРјР»РµРЅРµ СЃРёСЃС‚РµРјРЅРѕ.`n- РћРґРµСЃР° СЏРє РїРѕР»С–РіРѕРЅ РїСѓР±Р»С–С‡РЅРѕС— РґС–С—." 
$risks        = "- Р РёР·РёРє Р·Р°СЃС‚СЂСЏРіС‚Рё РІ С‚РµС…РЅС–С‡РЅРёС… РґРµС‚Р°Р»СЏС….`n- РќРёР·СЊРєР° РєС–Р»СЊРєС–СЃС‚СЊ РїСѓР±Р»С–С‡РЅРёС… РјРµСЃРµРґР¶С–РІ Сѓ РјС–СЃС‚С–.`n- CCU РјРѕР¶Рµ Р·Р°РІРёСЃРЅСѓС‚Рё Р±РµР· РїС–Р»РѕС‚РЅРѕС— Р·СѓСЃС‚СЂС–С‡С–."
$nextDAO      = "РџСѓР±Р»С–С‡РЅРёР№ Starter Kit + РєРѕСЂРѕС‚РєРёР№ РјР°РЅС–С„РµСЃС‚ РЅР° GitBook/СЃРѕС†РјРµСЂРµР¶С–."
$nextSHIELD   = "РћСЂРіР°РЅС–Р·СѓРІР°С‚Рё РєСЂСѓРіР»РёР№ СЃС‚С–Р»/С‡РёС‚Р°РЅРЅСЏ (РјС–СЃС†Рµ, С‡Р°СЃ, 3 СЃРїС–РєРµСЂРё, 1 РјРѕРґРµСЂР°С‚РѕСЂ)."
$nextCCU      = "РџСЂРѕРІРµСЃС‚Рё 45вЂ‘С…РІ РїС–Р»РѕС‚РЅСѓ Р»РµРєС†С–СЋ: 'РЎРІС–РґРѕРјС–СЃС‚СЊ С– РіСЂРѕРјР°РґР° РјР°Р№Р±СѓС‚РЅСЊРѕРіРѕ'."
$philos       = "Р’С–Рґ С‚РµС…РЅС–РєРё вЂ” РґРѕ СЃРµРЅСЃС–РІ С– СЃРїС–Р»СЊРЅРѕС— РґС–С—: СЃРёСЃС‚РµРјР° С–СЃРЅСѓС” Р·Р°СЂР°РґРё Р»СЋРґРёРЅРё, РіСЂРѕРјР°РґРё Р№ РєСѓР»СЊС‚СѓСЂРё."

# --- Р—Р°РІР°РЅС‚Р°Р¶РёС‚Рё С€Р°Р±Р»РѕРЅ С‚Р° СЃС„РѕСЂРјСѓРІР°С‚Рё С‚РµРєСЃС‚ ---
$template = Get-Content -Path $TemplatePath -Raw
$body = $template
$body = $body.Replace("{{DATE}}", $Date)
$body = $body.Replace("{{DAO_STATE}}", $daoState)
$body = $body.Replace("{{SHIELD_STATE}}", $shieldState)
$body = $body.Replace("{{CCU_STATE}}", $ccuState)
$body = $body.Replace("{{STRENGTHS}}", $strengths)
$body = $body.Replace("{{RISKS}}", $risks)
$body = $body.Replace("{{NEXT_DAO}}", $nextDAO)
$body = $body.Replace("{{NEXT_SHIELD}}", $nextSHIELD)
$body = $body.Replace("{{NEXT_CCU}}", $nextCCU)
$body = $body.Replace("{{PHILOS}}", $philos)
$body = $body.Replace("{{TECH_PCT}}", "$techPct")
$body = $body.Replace("{{PUB_PCT}}", "$pubPct")
$body = $body.Replace("{{PHIL_PCT}}", "$phiPct")

# --- Р†Рј'СЏ С„Р°Р№Р»Сѓ Р·РІС–С‚Сѓ ---
$fname = "Strateg_Report_" + $Date + ".md"
$outPath = Join-Path $ReportsDir $fname
$body | Set-Content -Path $outPath -Encoding UTF8
Write-Ok "Р—РІС–С‚ СЃС‚РІРѕСЂРµРЅРѕ: $outPath"

# РљРѕСЂРѕС‚РєРёР№ Р·Р°РїРёСЃ Сѓ LOG
try{
  $miniLog = Join-Path $Root "C03\LOG\agent_strateg_$(Get-Date -Format yyyyMMdd_HHmmss).log"
  "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Report=$fname TECH=$techPct PUB=$pubPct PHIL=$phiPct" | Set-Content $miniLog -Encoding UTF8
  Write-Ok "Р›РѕРіРѕРІР°РЅРѕ: $miniLog"
}catch{ Write-Warn "РќРµ РІРґР°Р»РѕСЃСЏ СЃС‚РІРѕСЂРёС‚Рё РјС–РЅС–-Р»РѕРі: $($_.Exception.Message)" }

# Р—Р°РІРµСЂС€РµРЅРЅСЏ
if(-not $Quiet){
  Write-Host "вЂ”" -ForegroundColor DarkGray
  Write-Host $body
}
# --- Auto-post to C12 Vault (optional) ---
if ($PostToVault) {
  try {
    $postScript = Join-Path $AgentDir "Post-StrategicReport.ps1"
    if (Test-Path $postScript) {
      Write-Host "[INFO] Posting report to C12 VaultвЂ¦" -ForegroundColor Cyan
      pwsh -NoProfile -ExecutionPolicy Bypass -File $postScript -ReportPath $outPath -MinIO:$UseMinIO
      Write-Host "[ OK ] Post to Vault finished" -ForegroundColor Green
    } else {
      Write-Host "[WARN] Post-StrategicReport.ps1 not found; using inline fallbackвЂ¦" -ForegroundColor Yellow

      # ----- Inline fallback (one-shot): РєРѕРїС–СЏ Сѓ Vault + SHA256 + VAULT_INDEX.json + Р»РѕРі -----
      $vaultBase = Join-Path $Root "C12\Vault\StrategicReports"
      $indexDir  = Join-Path $Root "C12\_index"
      $indexPath = Join-Path $indexDir "VAULT_INDEX.json"
      $logDir    = Join-Path $Root "C03\LOG"
      $yearDir   = Join-Path $vaultBase ((Get-Date).Year.ToString())

      New-Item -ItemType Directory -Force -Path $yearDir,$indexDir,$logDir | Out-Null

      $dest = Join-Path $yearDir ([IO.Path]::GetFileName($outPath))
      Copy-Item $outPath $dest -Force
      $sha  = (Get-FileHash -Path $dest -Algorithm SHA256).Hash

      try {
        $json = Get-Content $indexPath -Raw | ConvertFrom-Json
        if(-not ($json -is [System.Collections.IEnumerable])){ $json=@($json) }
      } catch { $json=@() }

      $item = [pscustomobject]@{
        id       = "strategic-report::" + (Get-Date -Format "yyyyMMdd_HHmmss")
        type     = "document"
        category = "StrategicReport"
        title    = [IO.Path]::GetFileNameWithoutExtension($dest)
        date     = (Get-Date -Format "yyyy-MM-dd")
        path     = $dest
        sha256   = $sha
        tags     = @("G44","Agent-Strateg","DAO-GOGS","Р©РРў-4","CheChaUniversity")
      }

      $json = @($json) + $item | Sort-Object date,title
      $json | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $indexPath

      $mini = Join-Path $logDir ("vault_post_strateg_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
      "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Added=$dest SHA256=$sha" | Set-Content -Encoding UTF8 $mini

      Write-Host "[ OK ] Fallback posted to Vault: $dest" -ForegroundColor Green

      if ($UseMinIO) {
        $mc = Join-Path $Root "tools\mc.exe"
        if (Test-Path $mc) {
          $bucketPath = "checha/checha-core/C12/Vault/StrategicReports/$((Get-Date).Year)"
          & $mc cp $dest "checha/$bucketPath/" | Out-Null
          if($LASTEXITCODE -eq 0){
            Write-Host "[ OK ] Fallback uploaded to MinIO: $bucketPath" -ForegroundColor Green
          } else {
            Write-Host "[WARN] Fallback MinIO upload failed (exit=$LASTEXITCODE)" -ForegroundColor Yellow
          }
        } else {
          Write-Host "[WARN] mc.exe not found; skip MinIO" -ForegroundColor Yellow
        }
      }
      # ----- /fallback -----
    }
  } catch {
    Write-Host "[ERR ] Post to Vault failed: $($_.Exception.Message)" -ForegroundColor Red
  }
}
