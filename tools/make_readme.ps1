param(
    [Parameter(Mandatory=$true)][string]$BlockName,
    [Parameter(Mandatory=$true)][string]$Tag,
    [string]$ZipName
)

$today = Get-Date -Format 'yyyy-MM-dd'
if (-not $ZipName) {
    $ZipName = "{0}_{1}.zip" -f $BlockName, $Tag
}

$readmePath = "README_{0}.md" -f $Tag
$tpl = @"
# Р РµР»С–Р· $BlockName $Tag

## рџ“Њ Р—Р°РіР°Р»СЊРЅРµ
- РќР°Р·РІР°: $BlockName
- Р’РµСЂСЃС–СЏ: $Tag
- Р”Р°С‚Р° СЂРµР»С–Р·Сѓ: $today
- ZIP: $ZipName

## рџ“‚ Р’РјС–СЃС‚
1. РћСЃРЅРѕРІРЅРёР№ РїР°РєРµС‚ (`$ZipName`)
2. CHECKSUMS.txt
3. РђСЃРµС‚Рё (Р·РѕР±СЂР°Р¶РµРЅРЅСЏ, РІС–РґРµРѕ, РґРѕРґР°С‚РєРѕРІС– РјР°С‚РµСЂС–Р°Р»Рё)

## вњ… Р§РµРє-Р»РёСЃС‚ РїРµСЂРµРґ РїСѓС€РµРј
- [ ] ZIP РїСЂРёСЃСѓС‚РЅС–Р№
- [ ] CHECKSUMS.txt Р·РіРµРЅРµСЂРѕРІР°РЅРёР№ С‡РµСЂРµР· `tools/make_checksums.ps1`
- [ ] РђСЃРµС‚Рё РґРѕРґР°РЅС– (`assets/`)
- [ ] РҐРµС€С– Р·Р±С–РіР°СЋС‚СЊСЃСЏ Р· CHECKSUMS.txt (`tools/check_release.ps1`)
- [ ] README_$Tag.md Р·Р°РїРѕРІРЅРµРЅРѕ (С†РµР№ С„Р°Р№Р»)

---

**РЎ.Р§.**
"@

$tpl | Set-Content -Path $readmePath -Encoding UTF8 -NoNewline:$false
Write-Host "вњ… Р—РіРµРЅРµСЂРѕРІР°РЅРѕ $readmePath"