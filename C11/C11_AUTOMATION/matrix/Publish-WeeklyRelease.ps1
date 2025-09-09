# Publish-WeeklyRelease.ps1
[CmdletBinding()]
param(
  [string]$ConfigPath = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\checha_matrix_config.json",
  [string]$ReportDate = (Get-Date -Format "yyyy-MM-dd")
)

# --- Load config
$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
if(-not $cfg.GitHub.EnableRelease){ "GitHub release disabled"; exit 0 }

# --- Resolve paths
$srRoot = $cfg.C12.StrategicReportsRoot
$year   = $ReportDate.Substring(0,4)
$report = Join-Path (Join-Path $srRoot $year) ("Strateg_Report_{0}.md" -f $ReportDate)
$checks = Join-Path $srRoot $cfg.Checksums.FileName

# --- Ensure report exists (try generate; else create minimal)
if(-not (Test-Path $report)){
  $gen = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\New-G44StrategicReport.ps1"
  if(Test-Path $gen){
    $out = & $gen -ConfigPath $ConfigPath -ReportDate $ReportDate
    if($out -and (Test-Path $out)){ $report = $out }
  }
}
if(-not (Test-Path $report)){
  $yearDir = Join-Path $srRoot $year
  if(-not (Test-Path $yearDir)){ New-Item -ItemType Directory -Path $yearDir | Out-Null }
  $minimal = "# 🧭 Strategic Report — $ReportDate`r`n_(auto-generated minimal placeholder)_"
  [IO.File]::WriteAllText($report, $minimal, [Text.Encoding]::UTF8)
  Write-Warning "Created minimal placeholder: $report"
}

# --- Ensure CHECKSUMS
if(-not (Test-Path $checks)){
  $chk = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\New-StrategicChecksums.ps1"
  if(Test-Path $chk){ & $chk -ConfigPath $ConfigPath | Out-Null }
}

# --- Notes from template (fallback to minimal)
$g04 = Get-Content $cfg.Feeds.G04Feed -Raw | ConvertFrom-Json
$c12 = Get-Content $cfg.Feeds.C12Feed -Raw | ConvertFrom-Json
$week = (Get-Culture).Calendar.GetWeekOfYear([datetime]::Parse($ReportDate),
        [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
$tpl  = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\templates\weekly_release_notes.md"
if(-not (Test-Path $tpl)){
  $notesDefault = "# Weekly Strategic Pack — {{DATE}} ({{WEEK}})`r`nHighlights: G04={{C48}}/{{C7}}/{{C30}}; C12={{DOCS}} docs, {{SR}} reports."
  [IO.File]::WriteAllText($tpl, $notesDefault, [Text.Encoding]::UTF8)
}
$notes = (Get-Content $tpl -Raw -Encoding UTF8).
  Replace("{{DATE}}",$ReportDate).
  Replace("{{WEEK}}","W$week").
  Replace("{{AUTHOR}}",$cfg.Author).
  Replace("{{C48}}",$g04.counts.critical_48h.ToString()).
  Replace("{{C7}}",$g04.counts.urgent_7d.ToString()).
  Replace("{{C30}}",$g04.counts.planned_30d.ToString()).
  Replace("{{DOCS}}",$c12.counts.docs.ToString()).
  Replace("{{SR}}",$c12.counts.strategic_reports.ToString())
$tmpNotes = Join-Path $env:TEMP ("weekly_notes_{0}.md" -f $ReportDate)
[IO.File]::WriteAllText($tmpNotes, $notes, [Text.Encoding]::UTF8)

# --- Build ZIP Weekly Pack (report + checksums + опційно Matrix.md через builder)
$zipBuilder = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\Build-WeeklyZip.ps1"
$zipPath = $null
if(Test-Path $zipBuilder){ $zipPath = & $zipBuilder -ConfigPath $ConfigPath -ReportDate $ReportDate -IncludeMatrix }

# --- Якщо ZIP зібрався — порахувати SHA256 і додати в нотатки
if($zipPath -and (Test-Path $zipPath)){
  $zipHash = (Get-FileHash $zipPath -Algorithm SHA256).Hash
  $notesWithHash = (Get-Content $tmpNotes -Raw -Encoding UTF8) + "`r`n`r`n**SHA256 (ZIP):** `"$zipHash`""
  [IO.File]::WriteAllText($tmpNotes, $notesWithHash, [Text.Encoding]::UTF8)
}

# --- Локальний архів ZIP у C05_ARCHIVE\WeeklyPacks (для підстраховки)
$archiveRoot = Join-Path $cfg.ChechaRoot "C05_ARCHIVE\WeeklyPacks"
try{
  if(-not (Test-Path $archiveRoot)){ New-Item -ItemType Directory -Path $archiveRoot | Out-Null }
  if($zipPath -and (Test-Path $zipPath)){
    $destZip = Join-Path $archiveRoot (Split-Path $zipPath -Leaf)
    Copy-Item $zipPath $destZip -Force
    Write-Host "OK: archived ZIP -> $destZip"
  }
}catch{
  Write-Warning "Archive copy failed: $($_.Exception.Message)"
}

# --- Release metadata
$tag  = "{0}-{1}-W{2}" -f $cfg.GitHub.ReleasePrefix, ($ReportDate.Substring(0,4)), $week
$name = "Weekly Strategic Pack — $ReportDate (W$week)"
$env:GH_REPO = $cfg.GitHub.RepoSlug

$flags = @()
if($cfg.GitHub.Draft){ $flags += "--draft" }
if($cfg.GitHub.Prerelease){ $flags += "--prerelease" }

# --- Idempotent create-or-update
$exists = $false
try { gh release view $tag --json tagName | Out-Null; $exists = $true } catch { $exists = $false }

if(-not $exists){
  gh release create $tag $report $checks --title $name --notes-file $tmpNotes @flags | Out-Null
  if($zipPath -and (Test-Path $zipPath)){ gh release upload $tag $zipPath --clobber | Out-Null }
  "OK: created release $tag"
}else{
  gh release edit   $tag --title $name --notes-file $tmpNotes @flags | Out-Null
  gh release upload $tag $report $checks --clobber | Out-Null
  if($zipPath -and (Test-Path $zipPath)){ gh release upload $tag $zipPath --clobber | Out-Null }
  "OK: updated release $tag (notes/assets)"
}
