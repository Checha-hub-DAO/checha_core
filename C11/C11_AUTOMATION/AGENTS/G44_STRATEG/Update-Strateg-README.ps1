<#
Update-Strateg-README.ps1
РћРЅРѕРІР»СЋС” README.md Сѓ Vault\StrategicReports:
- РїРѕРєР°Р·СѓС” РѕСЃС‚Р°РЅРЅС– N Р·РІС–С‚С–РІ (РґР°С‚Р°, С„Р°Р№Р», SHA-256 Vault/Agent, СЃС‚Р°С‚СѓСЃ РґР·РµСЂРєР°Р»Р°),
- С„РѕСЂРјСѓС” "Р†РЅРґРµРєСЃ СЂРѕРєС–РІ" (РїС–РґРїР°РїРєРё 2024/, 2025/, ...),
- СЂР°С…СѓС” РєС–Р»СЊРєС–СЃС‚СЊ DIFF Сѓ РІРёР±С–СЂС†С–,
- РїРёС€Рµ Р»РѕРіРё РІ C03\LOG,
- Р±РµР·РїРµС‡РЅРёР№ РґРµС„РѕР»С‚: Р°РІС‚Рѕ-СЃРёРЅС…СЂРѕРЅС–Р·Р°С†С–СЏ РІРёРјРєРЅРµРЅР°.
РЎСѓРјС–СЃРЅРѕ Р· Windows PowerShell 5.x С– PowerShell 7+.
#>

[CmdletBinding()]
param(
  [string]$VaultDir       = "C:\CHECHA_CORE\C12\Vault\StrategicReports",
  [string]$AgentsDir      = "C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\reports",
  [int]   $Take           = 3,
  [string]$ReadmeName     = "README.md",
  [string]$LogDir         = "C:\CHECHA_CORE\C03\LOG",
  [bool]  $EnableAutoSync = $false   # Р±РµР·РїРµС‡РЅРёР№ РґРµС„РѕР»С‚ (СЂСѓС‡РЅРёР№ РєРѕРЅС‚СЂРѕР»СЊ СЂРѕР·Р±С–Р¶РЅРѕСЃС‚РµР№)
)

# --- Р‘РµР·РїРµС‡РЅС– РЅР°Р»Р°С€С‚СѓРІР°РЅРЅСЏ ---
$ErrorActionPreference = 'Stop'
$ts = Get-Date -Format "yyyy-MM-dd_HHmmss"

# --- РџС–РґРіРѕС‚РѕРІРєР° Р»РѕРіС–РІ ---
New-Item -Force -ItemType Directory -Path $LogDir | Out-Null
$logFile = Join-Path $LogDir "update_strateg_readme_$ts.log"
function Log([string]$msg) {
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  "$stamp $msg" | Tee-Object -FilePath $logFile -Append
}

# --- Р”РѕРїРѕРјС–Р¶РЅС– ---
function Get-Sha256Safe([string]$Path) {
  if (-not (Test-Path $Path -PathType Leaf)) { return $null }
  try { return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash } catch { return $null }
}

try {
  Log "BEGIN Update-Strateg-README; VaultDir='$VaultDir'; AgentsDir='$AgentsDir'; Take=$Take; AutoSync=$EnableAutoSync"

  # Р’Р°Р»С–РґР°С†С–С—
  if ([string]::IsNullOrWhiteSpace($VaultDir) -or -not (Test-Path $VaultDir -PathType Container)) {
    throw "VaultDir not found or invalid: $VaultDir"
  }
  if ([string]::IsNullOrWhiteSpace($AgentsDir)) {
    Log "[i] AgentsDir not provided (empty). Mirror/Agent SHA will be '-'"
  } elseif (-not (Test-Path $AgentsDir -PathType Container)) {
    Log "[i] AgentsDir not found: $AgentsDir (mirror may be '-')"
  }

  $ReadmeName = ($ReadmeName ?? '').Trim()
  if ([string]::IsNullOrWhiteSpace($ReadmeName)) {
    throw "ReadmeName is empty. Expected something like 'README.md'."
  }
  $readmePath = Join-Path $VaultDir $ReadmeName

  # Р—РЅР°Р№С‚Рё РѕСЃС‚Р°РЅРЅС– Р·РІС–С‚Рё Сѓ Vault (СЂРµРєСѓСЂСЃРёРІРЅРѕ РІСЃРµСЂРµРґРёРЅС– СЂРѕРєС–РІ)
  $reports = Get-ChildItem -Path $VaultDir -Filter "Strateg_Report_*.md" -Recurse -File |
             Sort-Object LastWriteTime -Descending | Select-Object -First $Take
  if (-not $reports) { throw "No reports found in Vault: $VaultDir" }

  # РљРѕСЂС–РЅСЊ Vault РґР»СЏ РїРѕР±СѓРґРѕРІРё РІС–РґРЅРѕСЃРЅРёС… РїРѕСЃРёР»Р°РЅСЊ
  $vaultRoot = (Resolve-Path $VaultDir).Path

  # (1) РћРїС†С–Р№РЅРѕ: Р°РІС‚Рѕ-СЃРёРЅС…СЂРѕРЅС–Р·Р°С†С–СЏ Vault -> Agents Р”Рћ СЂРѕР·СЂР°С…СѓРЅРєС–РІ SHA
  if ($EnableAutoSync -and (Test-Path $AgentsDir -PathType Container)) {
    foreach ($r in $reports) {
      $dest = Join-Path $AgentsDir $r.Name
      Copy-Item $r.FullName -Destination $dest -Force
    }
    Log "AutoSync completed for last $Take reports."
  }

  # (2) РџРѕР±СѓРґРѕРІР° СЂСЏРґРєС–РІ С‚Р°Р±Р»РёС†С– (РїС–СЃР»СЏ РјРѕР¶Р»РёРІРѕРіРѕ Р°РІС‚Рѕ-СЃРёРЅС…Сѓ)
  $rows = foreach ($r in $reports) {
    $dateGuess = ($r.BaseName -replace '^Strateg_Report_', '')
    $shaVault  = Get-Sha256Safe $r.FullName

    $shaAgent = $null
    if (Test-Path $AgentsDir -PathType Container) {
      $agentCopy = Join-Path $AgentsDir $r.Name
      $shaAgent  = Get-Sha256Safe $agentCopy
    }

    $mirror = '-'  # СЃС‚Р°С‚СѓСЃ РґР·РµСЂРєР°Р»Р°
    if ($shaVault -and $shaAgent) {
      if ($shaVault -eq $shaAgent) { $mirror = 'OK' } else { $mirror = 'DIFF' }
    }

    $relPath = ($r.FullName -replace [regex]::Escape($vaultRoot), '').TrimStart('\')  # markdown Р»С–РЅРє

    [pscustomobject]@{
      Date     = $dateGuess
      Name     = $r.Name
      RelPath  = $relPath
      ShaVault = $shaVault
      ShaAgent = $shaAgent
      Mirror   = $mirror
    }
  }

  # (3) Р›С–С‡РёР»СЊРЅРёРє DIFF
  $diffCount = ($rows | Where-Object { $_.Mirror -eq 'DIFF' }).Count

  # (4) РҐРµРґРµСЂ
  $now = Get-Date
  $head = @(
    "# рџ“љ Strategic Reports вЂ” Vault",
    "РћСЃС‚Р°РЅРЅС” РѕРЅРѕРІР»РµРЅРЅСЏ: $($now.ToString('yyyy-MM-dd HH:mm'))",
    "---"
  )

  # (5) Р†РЅРґРµРєСЃ СЂРѕРєС–РІ
  $yearDirs = Get-ChildItem -Path $VaultDir -Directory -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -match '^\d{4}$' } | Sort-Object Name
  $yearIndex = @()
  if ($yearDirs) {
    $yearIndex += "## Р РѕРєРё"
    $yearIndex += ($yearDirs | ForEach-Object { "- [{0}]({0}/)" -f $_.Name })
    $yearIndex += ""
  }

  # (6) РўР°Р±Р»РёС†СЏ
  $tableHeader = @(
    "## РћСЃС‚Р°РЅРЅС– Р·РІС–С‚Рё ($($rows.Count))",
    "| Р”Р°С‚Р° | Р¤Р°Р№Р» | SHA-256 (Vault) | SHA-256 (Agent) | Р”Р·РµСЂРєР°Р»Рѕ |",
    "|---|---|---|---|---|"
  )
  $tableRows = foreach ($row in $rows) {
    $link = if ($row.RelPath) { "[{0}]({1})" -f $row.Name, ($row.RelPath -replace ' ','%20') } else { $row.Name }
    "| {0} | {1} | {2} | {3} | {4} |" -f $row.Date, $link, ($row.ShaVault ?? '-'), ($row.ShaAgent ?? '-'), $row.Mirror
  }

  # (7) Р¤СѓС‚РµСЂ
  $footer = @(
    "",
    "### РџСЂРёРјС–С‚РєРё",
    "- **Vault**: $VaultDir",
    "- **Agents mirror**: $AgentsDir",
    "- РЇРєС‰Рѕ `Р”Р·РµСЂРєР°Р»Рѕ=DIFF` вЂ” РІРёРєРѕРЅР°Р№С‚Рµ СЃРёРЅС…СЂРѕРЅС–Р·Р°С†С–СЋ Р°Р±Рѕ СѓСЃСѓРЅСЊС‚Рµ СЂРѕР·Р±С–Р¶РЅРѕСЃС‚С–.",
    "",
    "**DIFF:** $diffCount",
    "> РђРІС‚РѕРѕРЅРѕРІР»РµРЅРЅСЏ С‡РµСЂРµР· Update-Strateg-README.ps1"
  )

  # (7.1) CHECKSUMS_STRATEG.txt Сѓ AgentsDir (UTF-8 Р· BOM)
  try {
    if (Test-Path $AgentsDir -PathType Container) {
      $sumLines = foreach ($row in $rows) {
        $h = if ($row.ShaAgent) { $row.ShaAgent } else { $row.ShaVault }
        if ($h) { "{0} *{1}" -f $h, $row.Name }
      }
      if (-not $sumLines -or $sumLines.Count -eq 0) {
        $sumLines = @("# No checksums available for last $($rows.Count) reports at $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
      }
      $sumPath = Join-Path $AgentsDir "CHECKSUMS_STRATEG.txt"
      [System.IO.File]::WriteAllLines($sumPath, $sumLines, (New-Object System.Text.UTF8Encoding($true)))
      Log "Checksums written: $sumPath"
    } else {
      Log "[i] Skip checksums: AgentsDir not found."
    }
  } catch {
    Log "ERR while writing checksums: $($_.Exception.Message)"
  }

  # (8) Р—Р±С–СЂ С– Р·Р°РїРёСЃ README Сѓ UTF-8 Р· BOM
  $content = @($head + $yearIndex + $tableHeader + $tableRows + $footer) -join [Environment]::NewLine
  New-Item -Path $readmePath -ItemType File -Force | Out-Null
  [System.IO.File]::WriteAllText($readmePath, $content, (New-Object System.Text.UTF8Encoding($true)))

  Log "OK README updated: $readmePath"
  Log "END"
}
catch {
  Log "ERR: $($_.Exception.Message)"
  throw
}
