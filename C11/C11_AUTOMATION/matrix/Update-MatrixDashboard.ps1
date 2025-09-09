[CmdletBinding()]
param(
  [string]$ConfigPath = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\checha_matrix_config.json"
)

# --- load cfg
$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# --- load feeds
if(-not (Test-Path $cfg.Feeds.G04Feed)){ throw "G04Feed not found: $($cfg.Feeds.G04Feed)" }
if(-not (Test-Path $cfg.Feeds.C12Feed)){ throw "C12Feed not found: $($cfg.Feeds.C12Feed)" }
$g04 = Get-Content $cfg.Feeds.G04Feed -Raw | ConvertFrom-Json
$c12 = Get-Content $cfg.Feeds.C12Feed -Raw | ConvertFrom-Json

# --- latest report
$latestReport = $null
if(Test-Path $cfg.C12.StrategicReportsRoot){
  $latestReport = Get-ChildItem -Path $cfg.C12.StrategicReportsRoot -Recurse -Filter "Strateg_Report_*.md" |
                  Sort-Object LastWriteTime -Desc | Select-Object -First 1
}

# --- build Matrix.md
$matrixPath = Join-Path $cfg.C12.VaultRoot "Matrix.md"
$md = @()
$md += "# 🔄 Жива Операційна Матриця (C12 ↔ G04 ↔ G44)"
$md += "_Оновлено: $(Get-Date -Format 'yyyy-MM-dd HH:mm')_"
$md += "---"
$md += "## Стан завдань (G04)"
$md += "- 48 год: **$($g04.counts.critical_48h)** | 7 днів: **$($g04.counts.urgent_7d)** | 30 днів: **$($g04.counts.planned_30d)**"
$md += ""
$md += "## Свіжі знання (C12, за $($cfg.RecentDays) днів)"
$md += "- Нові стратегічні звіти: **$($c12.counts.strategic_reports)**"
$md += "- Нові документи: **$($c12.counts.docs)**"
if($latestReport){
  $rel = $latestReport.FullName.Replace($cfg.C12.VaultRoot,"").TrimStart("\").Replace("\","/")
  $md += ""
  $md += "## Останній стратегічний звіт (G44)"
  $md += $("[{0}]({1})" -f $latestReport.Name, "./" + $rel)
}

$enc = New-Object System.Text.UTF8Encoding($true)
[IO.File]::WriteAllLines($matrixPath, $md, $enc)
"OK: matrix -> $matrixPath"