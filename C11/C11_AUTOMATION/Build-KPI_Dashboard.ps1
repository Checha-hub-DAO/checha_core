Param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$OutPath,
  [int]$WindowDays = 1,
  [switch]$Quiet
)

Set-StrictMode -Version Latest

function ColorSay([string]$Text,[string]$Level){
  if($Quiet){ return }
  switch($Level){
    "OK"   { Write-Host $Text -ForegroundColor Green }
    "WARN" { Write-Host $Text -ForegroundColor Yellow }
    "FAIL" { Write-Host $Text -ForegroundColor Red }
    default{ Write-Host $Text }
  }
}

$log = Join-Path $Root "C03\LOG\releases_validate.log"
if(-not (Test-Path $log)){
  ColorSay "⚠️ Лог не знайдено: $log" "WARN"
  exit 1
}

$since = (Get-Date).ToUniversalTime().AddDays(-1 * [math]::Max(1,$WindowDays))
$out = if([string]::IsNullOrWhiteSpace($OutPath)){ Join-Path $Root "C06\FOCUS\kpi_dashboard.md" } else { $OutPath }

# Parse lines like:
# [timestamp=2025-09-09T13:32:45Z] module=G28 version=v1.0.0 build=20250909_1330 status=OK sha_match=true checksum_entry=true zip=G28_v1.0.0_20250909_1330.zip msg="validated successfully"
$rows = @()
$regex = 'timestamp=([^\]]+)\]\s+module=([^ ]+)\s+version=([^ ]+)\s+build=([^ ]+)\s+status=([^ ]+)\s+sha_match=([^ ]+)\s+checksum_entry=([^ ]+)\s+zip=([^ ]+)\s+msg="([^"]*)"'
foreach($ln in Get-Content -LiteralPath $log){
  if($ln -match $regex){
    try{
      $ts = [datetime]::Parse($matches[1])
    } catch {
      continue
    }
    if($ts -ge $since){
      $rows += [pscustomobject]@{
        Timestamp=$ts
        Module=$matches[2]
        Version=$matches[3]
        Build=$matches[4]
        Status=$matches[5]
        ShaMatch=$matches[6]
        Checksum=$matches[7]
        Zip=$matches[8]
        Msg=$matches[9]
      }
    }
  }
}

if($rows.Count -eq 0){
  ColorSay "⚪ Немає подій у логах за останні $WindowDays дн." "INFO"
  # все одно генеруємо пустий дашборд
}

function S([string]$st){
  switch($st){
    "OK"   { "🟢 OK" }
    "WARN" { "🟡 WARN" }
    "FAIL" { "🔴 FAIL" }
    default{ "⚪ N/A" }
  }
}

# Latest entry per module
$latest = $rows | Sort-Object Module, Timestamp | Group-Object Module | ForEach-Object { $_.Group | Sort-Object Timestamp -Descending | Select-Object -First 1 }

$ok   = ($latest | Where-Object {$_.Status -eq 'OK'}).Count
$warn = ($latest | Where-Object {$_.Status -eq 'WARN'}).Count
$fail = ($latest | Where-Object {$_.Status -eq 'FAIL'}).Count
$total = $latest.Count
$tsNow = (Get-Date).ToString('yyyy-MM-dd HH:mm')
$buildId = (Get-Date).ToString('yyyyMMdd_HHmm')

$header = @"
# 📊 KPI Dashboard — Модулі та релізи
Оновлено: $tsNow

## Стан модулів
| Module | Version | Build | Status | SHA Match | Checksum Entry | Last Release |
|--------|---------|-------|--------|-----------|----------------|--------------|
"@

$tbl = if($latest){
  ($latest | ForEach-Object { "| $($_.Module) | $($_.Version) | $($_.Build) | $(S $_.Status) | $($_.ShaMatch) | $($_.Checksum) | $($_.Zip) |" }) -join "`n"
} else { "| — | — | — | ⚪ N/A | — | — | — |" }

$summary = @"

## Підсумки за $WindowDays дн.
- Загалом модулів у вибірці: **$total**
- Успішних релізів: **$ok**
- Попередження: **$warn**
- Помилок: **$fail**

## Тренди (7 днів)
- Середній відсоток OK: **{{OK_PCT}}%**
- Медіана релізів на день: **{{MEDIAN_RELEASES}}**
"@

$dir = Split-Path $out -Parent
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Set-Content -LiteralPath $out -Value ($header + $tbl + $summary) -Encoding UTF8

ColorSay "✅ KPI-доповідь сформовано → $out" "OK"
exit 0
