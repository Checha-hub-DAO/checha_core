<# РЁРІРёРґРєРёР№ self-test С–РЅСЃС‚СЂСѓРјРµРЅС‚Р°СЂС–СЋ СЂРµРїРѕ. РџР°РґР°С”, СЏРєС‰Рѕ Р·РЅР°Р№РґРµРЅРѕ РєСЂРёС‚РёС‡РЅС– РїРѕРјРёР»РєРё. #>
[CmdletBinding()]param()
$ErrorActionPreference = 'Stop'
$fail = @()

function Assert-True($cond, $msg) { if (-not $cond) { $script:fail += "вќЊ $msg" } else { Write-Host "вњ… $msg" -ForegroundColor Green } }

Write-Host "рџљ¦ SELFTEST START" -ForegroundColor Cyan

# 1) РџРµСЂРµРІС–СЂРєР° СЃРёРЅС‚Р°РєСЃРёСЃСѓ РєР»СЋС‡РѕРІРёС… .ps1
$toolScripts = @(
  ".\tools\naming.ps1",
  ".\tools\release-assets-guard.ps1"
) | Where-Object { Test-Path $_ }

foreach ($s in $toolScripts) {
  try { powershell -NoProfile -Command "[void][ScriptBlock]::Create((Get-Content '$s' -Raw))" | Out-Null; Assert-True $true "Syntax OK: $s" }
  catch { $fail += "вќЊ Syntax error: $s в†’ $($_.Exception.Message)" }
}

# 2) РњС–РЅС–РјР°Р»СЊРЅРёР№ СЂР°РЅ РґР»СЏ guard (С€С‚СѓС‡РЅРёР№ РєРµР№СЃ)
$temp = Join-Path $env:TEMP "guard_test_$(Get-Random)"
New-Item -ItemType Directory $temp | Out-Null
"readme" | Set-Content (Join-Path $temp "README_test.md") -Encoding UTF8
try {
  pwsh -NoProfile -File .\tools\release-assets-guard.ps1 -DistPath $temp -MinSizeKB 1 -RequireFiles @("README*") | Out-Null
  Assert-True $true "Guard minimal run OK"
} catch {
  $fail += "вќЊ Guard failed on minimal run: $($_.Exception.Message)"
}
Remove-Item -Recurse -Force $temp

# 3) Р РµРіСѓР»СЏСЂРєРё naming.ps1 Р·Р°РІР°РЅС‚Р°Р¶СѓСЋС‚СЊСЃСЏ?
if (Test-Path .\tools\naming.ps1) {
  try {
    . .\tools\naming.ps1
    $sample = "ETHNO_Block_v1.2_20250902_155731.zip"
    $m = $sample -match $Global:NamingRegex
    Assert-True $m "naming.ps1: regex РјР°С‚С‡Рµ Р·СЂР°Р·РѕРє"
  } catch { $fail += "вќЊ naming.ps1 load/match: $($_.Exception.Message)" }
}

if ($fail.Count) {
  $fail | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  Write-Host "в›” SELFTEST: FAIL" -ForegroundColor Red
  exit 2
}
Write-Host "рџџў SELFTEST: OK" -ForegroundColor Green
