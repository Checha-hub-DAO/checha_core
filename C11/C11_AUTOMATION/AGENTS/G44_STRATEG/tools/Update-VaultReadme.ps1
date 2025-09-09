<# Update-VaultReadme.ps1
Оновлює README.md у вітрині (Vault shelf):
- заголовок (Title) і мітка часу,
- індекс років (папки yyyy),
- таблиця останніх N файлів з дзеркалом (Vault vs Agents),
- підсумок DIFF і опційні CHECKSUMS.txt у Agents.
Сумісно з Windows PowerShell 5.x і PowerShell 7+.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]  [string]$Title,
  [Parameter(Mandatory=$true)]  [string]$VaultDir,
  [Parameter(Mandatory=$true)]  [string]$AgentsDir,
  [Parameter(Mandatory=$true)]  [string]$Pattern,
  [string]$DateRegex = '(\d{4}-\d{2}-\d{2})',
  [int]$Take = 5,
  [switch]$WriteChecksums,
  [string]$ReadmeName = "README.md",
  [string]$LogDir = "C:\CHECHA_CORE\C03\LOG"
)

# --- Безпечні налаштування ---
$ErrorActionPreference = 'Stop'
$ts = Get-Date -Format "yyyy-MM-dd_HHmmss"

# --- Логи ---
New-Item -Force -ItemType Directory -Path $LogDir | Out-Null
$logFile = Join-Path $LogDir ("update_vault_readme_{0}.log" -f $ts)
function Log([string]$msg) {
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  "$stamp $msg" | Tee-Object -FilePath $logFile -Append
}

# --- Допоміжні ---
function Get-Sha256Safe([string]$Path) {
  if (-not (Test-Path $Path -PathType Leaf)) { return $null }
  try { return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash } catch { return $null }
}

try {
  Log ("BEGIN Update; Title='{0}'; Vault='{1}'; Agents='{2}'; Pattern='{3}'; Take={4}; AutoSync=False; Checksums={5}" -f $Title,$VaultDir,$AgentsDir,$Pattern,$Take, [bool]$WriteChecksums)
  Log ("Env: PS={0}; Host={1}" -f ($PSVersionTable.PSVersion.ToString()), $Host.Name)

  if (-not (Test-Path $VaultDir -PathType Container)) { throw "VaultDir not found: $VaultDir" }
  if (-not (Test-Path $AgentsDir -PathType Container)) { Log "[i] AgentsDir not found — дзеркало буде '-'." }

  $readmePath = Join-Path $VaultDir $ReadmeName
  $vaultRoot  = (Resolve-Path $VaultDir).Path

  # Останні файли
  $files = Get-ChildItem -Path $VaultDir -Filter $Pattern -Recurse -File |
           Sort-Object LastWriteTime -Descending | Select-Object -First $Take
  if (-not $files) { throw "No files matching '$Pattern' in $VaultDir" }

  $rows = foreach($f in $files){
    $date = $null
    if ($DateRegex) {
      $m = [regex]::Match($f.Name, $DateRegex)
      if ($m.Success -and $m.Groups.Count -ge 2) { $date = $m.Groups[1].Value }
    }
    if (-not $date) {
      $m2 = [regex]::Match($f.BaseName, '(\d{4}-\d{2}-\d{2})')
      $date = if ($m2.Success) { $m2.Groups[1].Value } else { $f.LastWriteTime.ToString('yyyy-MM-dd') }
    }

    $shaV = Get-Sha256Safe $f.FullName
    $aPath = Join-Path $AgentsDir $f.Name
    $shaA = Get-Sha256Safe $aPath

    $mirror = '-'
    if ($shaV -and $shaA) { $mirror = if ($shaV -eq $shaA) { 'OK' } else { 'DIFF' } }

    $rel = ($f.FullName -replace [regex]::Escape($vaultRoot), '').TrimStart('\') -replace ' ','%20'

    [pscustomobject]@{
      Date     = $date
      Name     = $f.Name
      RelPath  = $rel
      ShaVault = $shaV
      ShaAgent = $shaA
      Mirror   = $mirror
    }
  }

  $diffCount = ($rows | Where-Object { $_.Mirror -eq 'DIFF' }).Count

  # Хедер
  $head = @(
    "# $Title",
    ("Останнє оновлення: {0}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm')),
    "---"
  )

  # Індекс років
  $yearDirs = Get-ChildItem -Path $VaultDir -Directory -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -match '^\d{4}$' } | Sort-Object Name
  $yearIndex = @()
  if ($yearDirs) {
    $yearIndex += "## Роки"
    $yearIndex += ($yearDirs | ForEach-Object { "- {0}" -f ("[{0}]({0}/)" -f $_.Name) })
    $yearIndex += ""
  }

  # Таблиця
  $tableHeader = @(
    ("## Останні звіти ({0})" -f $rows.Count),
    "| Дата | Файл | SHA-256 (Vault) | SHA-256 (Agent) | Дзеркало |",
    "|---|---|---|---|---|"
  )
  $tableRows = foreach($r in $rows){
    $link = if ($r.RelPath) { "[{0}]({1})" -f $r.Name, $r.RelPath } else { $r.Name }
    "| {0} | {1} | {2} | {3} | {4} |" -f $r.Date,$link,($r.ShaVault ?? '-'),($r.ShaAgent ?? '-'),$r.Mirror
  }

  # Футер
  $footer = @(
    "",
    "### Примітки",
    "- **Vault**: $VaultDir",
    "- **Agents mirror**: $AgentsDir",
    "- Якщо `Дзеркало=DIFF` — виконайте синхронізацію або усуньте розбіжності.",
    "",
    ("**DIFF:** {0}" -f $diffCount),
    "> Автооновлення через Update-VaultReadme.ps1"
  )

  # Запис README (UTF-8 BOM)
  $content = @($head + $yearIndex + $tableHeader + $tableRows + $footer) -join [Environment]::NewLine
  New-Item -ItemType File -Force -Path $readmePath | Out-Null
  [System.IO.File]::WriteAllText($readmePath, $content, (New-Object System.Text.UTF8Encoding($true)))

  # CHECKSUMS.txt (опційно)
  if ($WriteChecksums -and (Test-Path $AgentsDir -PathType Container)) {
    $sumLines = foreach($r in $rows){
      $h = if ($r.ShaAgent) { $r.ShaAgent } else { $r.ShaVault }
      if ($h) { "{0} *{1}" -f $h, $r.Name }
    }
    if (-not $sumLines) { $sumLines = @("# No checksums for {0}" -f (Get-Date)) }
    $sumPath = Join-Path $AgentsDir "CHECKSUMS.txt"
    [System.IO.File]::WriteAllLines($sumPath, $sumLines, (New-Object System.Text.UTF8Encoding($true)))
    Log "Checksums written: $sumPath"
  }

  Log ("OK README updated: {0}" -f $readmePath)
  Log "END"
}
catch {
  Log ("ERR: {0}" -f $_.Exception.Message)
  throw
}
