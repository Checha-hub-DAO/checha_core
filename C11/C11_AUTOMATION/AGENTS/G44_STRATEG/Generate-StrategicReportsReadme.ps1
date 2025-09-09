# рџ“љ Р“РµРЅРµСЂР°С‚РѕСЂ README.md РґР»СЏ StrategicReports
# Р—Р°РІР¶РґРё Р·Р±РµСЂС–РіР°С” Сѓ UTF-8 Р· BOM (С‰РѕР± СѓРЅРёРєРЅСѓС‚Рё "РєСЂСЏРєРѕР·СЏР±СЂ")

# РќР°Р»Р°С€С‚СѓРІР°РЅРЅСЏ
$Root = 'C:\CHECHA_CORE'
$LatestReports  = 10
$LatestArchives = 6

$vaultBase = Join-Path $Root 'C12\Vault\StrategicReports'
if (-not (Test-Path $vaultBase)) {
  New-Item -ItemType Directory -Force -Path $vaultBase | Out-Null
}
$readme    = Join-Path $vaultBase 'README.md'
$indexPath = Join-Path $Root 'C12\_index\VAULT_INDEX.json'

# Р—РІС–С‚Рё (РѕСЃС‚Р°РЅРЅС– N)
$reports = Get-ChildItem $vaultBase -Directory -EA SilentlyContinue |
  Sort-Object Name -Desc |
  ForEach-Object { Get-ChildItem $_.FullName -Filter 'Strateg_Report_*.md' -File -EA SilentlyContinue } |
  Sort-Object LastWriteTime -Desc | Select-Object -First $LatestReports

# РђСЂС…С–РІРё (РѕСЃС‚Р°РЅРЅС– M)
$archives = Get-ChildItem (Join-Path $vaultBase 'ARCHIVE') -Directory -EA SilentlyContinue |
  Sort-Object Name -Desc |
  ForEach-Object { Get-ChildItem $_.FullName -Filter 'Strategic_*.zip' -File -EA SilentlyContinue } |
  Sort-Object LastWriteTime -Desc | Select-Object -First $LatestArchives

# РҐРµС€С– Р· VAULT_INDEX.json (СЏРєС‰Рѕ С”)
$shaMap = @{}
if (Test-Path $indexPath) {
  try { $json = Get-Content $indexPath -Raw | ConvertFrom-Json } catch { $json = $null }
  if ($json) {
    foreach ($item in $json) {
      if ($item.path -and $item.sha256) { $shaMap[$item.path] = $item.sha256 }
    }
  }
}

# РџРѕР±СѓРґРѕРІР° README
$nl = "`r`n"
$md = @()
$md += "# рџ“љ Strategic Reports вЂ” Vault$nl"
$md += "РћСЃС‚Р°РЅРЅС” РѕРЅРѕРІР»РµРЅРЅСЏ: $(Get-Date -Format 'yyyy-MM-dd HH:mm')$nl"
$md += "---$nl"

# РўР°Р±Р»РёС†СЏ Р·РІС–С‚С–РІ
$md += "## РћСЃС‚Р°РЅРЅС– Р·РІС–С‚Рё ($($reports.Count))$nl"
if ($reports -and $reports.Count -gt 0) {
  $md += "| Р”Р°С‚Р° | Р¤Р°Р№Р» | SHA-256 (СЏРєС‰Рѕ С”) |$nl|---|---|---|$nl"
  foreach ($r in $reports) {
    $rel  = $r.FullName.Substring($vaultBase.Length).TrimStart('\')
    $date = $r.LastWriteTime.ToString('yyyy-MM-dd')
    $sha  = if ($shaMap.ContainsKey($r.FullName)) { $shaMap[$r.FullName] } else { '' }
    $md  += "| $date | [$($r.Name)]($rel) | $sha |$nl"
  }
} else {
  $md += "РќРµРјР°С” Р·РІС–С‚С–РІ.$nl"
}

$md += "$nl---$nl"

# РЎРїРёСЃРѕРє Р°СЂС…С–РІС–РІ
$md += "## РћСЃС‚Р°РЅРЅС– Р°СЂС…С–РІРё ($($archives.Count))$nl"
if ($archives -and $archives.Count -gt 0) {
  foreach ($z in $archives) {
    $rel = $z.FullName.Substring($vaultBase.Length).TrimStart('\')
    $sha = if ($shaMap.ContainsKey($z.FullName)) { $shaMap[$z.FullName] } else { (Get-FileHash $z.FullName -Algorithm SHA256).Hash }
    $md += "- [$($z.Name)]($rel) вЂ” SHA-256: $sha$nl"
  }
} else {
  $md += "РќРµРјР°С” Р°СЂС…С–РІС–РІ.$nl"
}

$md += "$nl> РђРІС‚РѕРіРµРЅРµСЂР°С†С–СЏ: Agent-Strateg в†’ Post-StrategicReport в†’ README; Р°СЂС…С–РІР°С†С–СЏ РґРѕРґР°С” ZIP Сѓ СЃРїРёСЃРѕРє.$nl"

# Р—Р°РїРёСЃ Р· BOM
$utf8BOM = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($readme, ($md -join ''), $utf8BOM)

Write-Host "[ OK ] Updated README: $readme" -ForegroundColor Green
dColor Green
