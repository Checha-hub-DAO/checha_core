# C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Update-VaultDashboard.ps1
# Compatible with Windows PowerShell 5.x and PowerShell 7+

[CmdletBinding()]
param(
  [string] $DashboardTitle = "🧭 CHECHA Vault — Dashboard",
  [string] $ConfigPath     = "C:\CHECHA_CORE\C11\C11_AUTOMATION\config\checha_shelves.json",
  [string] $OutputPath     = "C:\CHECHA_CORE\C12\Vault\README.md",
  [switch] $IncludeLatest
)

$ErrorActionPreference = 'Stop'
$enc = New-Object System.Text.UTF8Encoding($true)  # UTF-8 with BOM

# Default true for IncludeLatest if not provided explicitly
if (-not $PSBoundParameters.ContainsKey('IncludeLatest')) { $IncludeLatest = $true }

function Get-DefaultShelves {
  @(
    @{ name="StrategicReports"; title="📚 Strategic Reports — Vault";  vault="C:\CHECHA_CORE\C12\Vault\StrategicReports";  agents="C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\reports";  pattern="Strateg_Report_*.md"; take=3 },
    @{ name="DecisionsJournal"; title="🗒️ Decisions Journal — Vault"; vault="C:\CHECHA_CORE\C12\Vault\DecisionsJournal"; agents="C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G43_DECISIONS\reports"; pattern="Decision_*.md";       take=5 },
    @{ name="Releases";         title="🚀 Releases — Vault";          vault="C:\CHECHA_CORE\C12\Vault\Releases";          agents="C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G42_RELEASES\reports"; pattern="Release_*.md";        take=5 }
  )
}

# Load shelves from config or fallback
if (Test-Path $ConfigPath -PathType Leaf) {
  try {
    $shelves = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    $shelves = Get-DefaultShelves
  }
} else {
  $shelves = Get-DefaultShelves
}

# Top summary rows (read "Updated" and "DIFF" from each shelf README)
$summary = foreach ($s in $shelves) {
  $rowTitle = if ($s.PSObject.Properties['title']) { [string]$s.title } else { [string]$s.name }
  $vdir     = [string]$s.vault
  $readme   = Join-Path $vdir "README.md"

  $updated = "-"
  $diffRaw = $null

  if (Test-Path $readme -PathType Leaf) {
    $text = Get-Content $readme -Raw
    $m1 = [regex]::Match($text, '(?m)^Останнє оновлення:\s+(.+)$')
    if ($m1.Success) { $updated = $m1.Groups[1].Value.Trim() }
    $m2 = [regex]::Match($text, '(?m)^\*\*DIFF:\*\*\s*(\d+)\s*$')
    if ($m2.Success) { $diffRaw = [int]$m2.Groups[1].Value }
  }

  $relShelf = Split-Path $vdir -Leaf
  $diffBadge = "-"
  if ($diffRaw -is [int]) {
    if ($diffRaw -gt 0) { $diffBadge = "⚠️ $diffRaw" } else { $diffBadge = "✅ $diffRaw" }
  }

  $obj = New-Object psobject
  $obj | Add-Member NoteProperty Title   ($rowTitle.Trim())
  $obj | Add-Member NoteProperty Updated ($updated)
  $obj | Add-Member NoteProperty Diff    ($diffBadge)
  $obj | Add-Member NoteProperty Link    ("$relShelf/")
  $obj | Add-Member NoteProperty _cfg    ($s)
  $obj
}

# Build markdown
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$lines = @()
$lines += "# $DashboardTitle"
$lines += "Останнє оновлення: $now"
$lines += "---"
$lines += "## Полиці"
$lines += "| Полиця | Оновлено | DIFF | Посилання |"
$lines += "|---|---|---|---|"
foreach ($r in $summary) {
  $lines += ("| {0} | {1} | {2} | [{3}]({3}) |" -f $r.Title, $r.Updated, $r.Diff, $r.Link)
}

# Optional: "Latest N" sections
if ($IncludeLatest) {
  foreach ($sum in $summary) {
    $s = $sum._cfg
    $rowTitle = $sum.Title
    $vdir     = [string]$s.vault

    # Safe-read agents/pattern/take without ternary
    $adir = $null
    if ($s.PSObject.Properties['agents']) { $adir = [string]$s.agents }

    $pattern = "*.*"
    if ($s.PSObject.Properties['pattern']) { $pattern = [string]$s.pattern }

    $take = 3
    if ($s.PSObject.Properties['take']) {
      try { $take = [int]$s.take } catch { $take = 3 }
    }

    if (-not (Test-Path $vdir -PathType Container)) { continue }

    $files = Get-ChildItem -Path $vdir -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First $take

    $lines += ""
    $lines += ("### Останні {0} — {1}" -f $take, $rowTitle)
    $lines += "| Дата | Файл | Дзеркало |"
    $lines += "|---|---|---|"

    foreach ($f in $files) {
      # Date (from filename or LastWriteTime)
      $date = ($f.BaseName -replace '.*(\d{4}-\d{2}-\d{2}).*','$1')
      if ($date -eq $f.BaseName -or [string]::IsNullOrWhiteSpace($date)) {
        $date = $f.LastWriteTime.ToString('yyyy-MM-dd')
      }

      # Mirror status via hashes
      $shaV = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
      $shaA = $null
      if ($adir) {
        $aPath = Join-Path $adir $f.Name
        if (Test-Path $aPath -PathType Leaf) {
          $shaA = (Get-FileHash $aPath -Algorithm SHA256).Hash
        }
      }
      $mirror = '-'
      if ($shaV -and $shaA) {
        if ($shaV -eq $shaA) { $mirror = 'OK' } else { $mirror = 'DIFF' }
      }

      # Relative link within Vault
      $relShelf = Split-Path $vdir -Leaf
      $relInShelf = ($f.FullName -replace [regex]::Escape($vdir), '').TrimStart('\') -replace '\\','/'
      $href = ("{0}/{1}" -f $relShelf, $relInShelf) -replace ' ', '%20'

      $lines += ("| {0} | [{1}]({2}) | {3} |" -f $date, $f.Name, $href, $mirror)
    }
  }
}

$lines += ""
$lines += "> Автооновлення дашборда: Update-VaultDashboard.ps1"

New-Item -ItemType Directory -Path (Split-Path $OutputPath) -Force | Out-Null
[System.IO.File]::WriteAllText($OutputPath, ($lines -join [Environment]::NewLine), $enc)
Write-Host "OK Dashboard updated: $OutputPath"
