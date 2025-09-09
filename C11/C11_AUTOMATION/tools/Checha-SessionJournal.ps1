<# 
Checha-SessionJournal.ps1 — формує записи Start/End у CheCha-Session Journal.

.PARAMS
  -Root       : корінь CHECHA_CORE (default: C:\CHECHA_CORE)
  -Mode       : Start | End
  -SessionId  : CHECHA_SESSION_yyyy-MM-dd_HHmm (необов'язковий)
  -DataJson   : JSON з полями:
                Start: summaryPrevDay, techScheme, symbolicScheme, blocks[], substeps[], emotion, notes[]
                End  : achievements[], analysisOk[], analysisBlockers[], focusTomorrow[], recommendations[], innerState
#>
[CmdletBinding()]
param(
  [string]$Root = "C:\CHECHA_CORE",
  [Parameter(Mandatory = $true)]
  [ValidateSet("Start","End")]
  [string]$Mode,
  [string]$SessionId,
  [string]$DataJson
)

# ---------- Helpers ----------
function New-Utf8BomWriter {
  param([string]$Path)
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  if (-not (Test-Path $Path)) {
    $enc = New-Object System.Text.UTF8Encoding($true)  # emit BOM
    [System.IO.File]::WriteAllText($Path, "", $enc)
  }
  return $Path
}

function Get-TodayJournalPath {
  param([string]$Root)
  $logDir = Join-Path $Root "C03\LOG"
  if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
  $name = "CheCha_Journal_{0}.md" -f (Get-Date -Format "yyyy-MM-dd")
  Join-Path $logDir $name
}

function Get-SessionsIndexPath {
  param([string]$Root)
  $idxDir = Join-Path $Root "C03\LOG\SESSIONS"
  if (-not (Test-Path $idxDir)) { New-Item -ItemType Directory -Path $idxDir | Out-Null }
  Join-Path $idxDir "SESSIONS_INDEX.csv"
}

function Ensure-SessionsIndex {
  param([string]$CsvPath)
  if (-not (Test-Path $CsvPath)) {
    "date,mode,session_id,timestamp_iso" | Out-File -FilePath $CsvPath -Encoding utf8
  }
}

function Add-IndexRow {
  param([string]$CsvPath,[string]$Mode,[string]$SessionId,[datetime]$Ts)
  $row = "{0},{1},{2},{3}" -f ($Ts.ToString("yyyy-MM-dd")), $Mode, $SessionId, ($Ts.ToString("s"))
  Add-Content -Path $CsvPath -Value $row
}

function New-SessionId {
  $now = Get-Date
  "CHECHA_SESSION_{0}_{1}" -f $now.ToString("yyyy-MM-dd"), $now.ToString("HHmm")
}

function Get-LastSessionIdFromJournal {
  param([string]$JournalPath)
  if (-not (Test-Path $JournalPath)) { return $null }
  $text = Get-Content $JournalPath -Raw
  $m = [regex]::Matches($text, 'CHECHA_SESSION_\d{4}-\d{2}-\d{2}_\d{4}')
  if ($m.Count -gt 0) { return $m[$m.Count-1].Value }
  return $null
}

function Parse-JsonSafe {
  param([string]$Json)
  if ([string]::IsNullOrWhiteSpace($Json)) { return $null }
  try { return $Json | ConvertFrom-Json -ErrorAction Stop } catch { return $null }
}

# ---------- Main ----------
$nl = [Environment]::NewLine
$now = Get-Date
$journalPath = Get-TodayJournalPath -Root $Root | New-Utf8BomWriter
$sessionsCsv = Get-SessionsIndexPath -Root $Root
Ensure-SessionsIndex -CsvPath $sessionsCsv

$data = Parse-JsonSafe -Json $DataJson

if (-not $SessionId) {
  if ($Mode -eq "Start") {
    $SessionId = New-SessionId
  } else {
    $SessionId = Get-LastSessionIdFromJournal -JournalPath $journalPath
    if (-not $SessionId) { $SessionId = New-SessionId }
  }
}

$stampStart = ("🕒 Дата й час старту: {0}{2}🆔 Ідентифікатор сеансу: {1}{2}" -f ($now.ToString("yyyy-MM-dd HH:mm")), $SessionId, $nl)
$stampEnd   = ("🕒 Дата й час завершення: {0}{2}🆔 Ідентифікатор сеансу: {1}{2}" -f ($now.ToString("yyyy-MM-dd HH:mm")), $SessionId, $nl)

if ($Mode -eq "Start") {
  $summaryPrev = $data?.summaryPrevDay
  $tech        = $data?.techScheme
  $symb        = $data?.symbolicScheme
  $blocks      = @($data?.blocks)   | Where-Object { $_ }
  $steps       = @($data?.substeps) | Where-Object { $_ }
  $emotion     = $data?.emotion
  $notes       = @($data?.notes)    | Where-Object { $_ }

  $md = @()
  $md += ""
  $md += "---"
  $md += "## 🟢 Start Report"
  $md += $stampStart
  $md += "📝 **Підсумок попереднього дня**"
  if ($summaryPrev) { $md += ("- {0}" -f $summaryPrev) } else { $md += "- ..." }
  $md += ""
  $md += "🗺 **Схеми-синтези**"
  $md += ("- **Технічна:** {0}" -f ($(if($tech){$tech}else{"..."})))
  $md += ("- **Символічна:** {0}" -f ($(if($symb){$symb}else{"..."})))
  $md += ""
  $md += "🛡 **Панель CheCha**"
  if ($blocks.Count -gt 0) {
    $md += "- 🔑 Головні блоки:"
    $blocks | ForEach-Object { $md += ("  - {0}" -f $_) }
  } else { $md += "- 🔑 Головні блоки: ..." }
  if ($steps.Count -gt 0) {
    $md += "- 🛠 Підкроки:"
    $steps | ForEach-Object { $md += ("  - {0}" -f $_) }
  } else { $md += "- 🛠 Підкроки: ..." }
  $md += ""
  $md += ("🌈 **Емоційний індикатор:** {0}" -f ($(if($emotion){$emotion}else{"..."})))
  $md += ""
  $md += "🗒 **Нотатки дня з тригерами**"
  if ($notes.Count -gt 0) { $notes | ForEach-Object { $md += ("- {0}" -f $_) } } else { $md += "- ..." }
  $md += ""
  $md += ("🔏 **Печатка:** {0}" -f $SessionId)
  $md += ""

  Add-Content -Path $journalPath -Value ($md -join $nl)
  Add-IndexRow -CsvPath $sessionsCsv -Mode "Start" -SessionId $SessionId -Ts $now
  Write-Host "✅ Додано Start до $journalPath" -ForegroundColor Green
  Write-Host ("ID: {0}" -f $SessionId)
  exit 0
}

if ($Mode -eq "End") {
  $ach      = @($data?.achievements)     | Where-Object { $_ }
  $ok       = @($data?.analysisOk)       | Where-Object { $_ }
  $blockers = @($data?.analysisBlockers) | Where-Object { $_ }
  $focus    = @($data?.focusTomorrow)    | Where-Object { $_ }
  $reco     = @($data?.recommendations)  | Where-Object { $_ }
  $inner    = $data?.innerState

  $md = @()
  $md += ""
  $md += "---"
  $md += "## 🔴 End Report"
  $md += $stampEnd
  $md += "🏆 **Головні досягнення дня**"
  if ($ach.Count -gt 0) { $ach | ForEach-Object { $md += ("- {0}" -f $_) } } else { $md += "- ..." }
  $md += ""
  $md += "📊 **Аналіз**"
  if ($ok.Count -gt 0) {
    $md += "- Що вдалося:"
    $ok | ForEach-Object { $md += ("  - {0}" -f $_) }
  } else { $md += "- Що вдалося: ..." }
  if ($blockers.Count -gt 0) {
    $md += "- Що гальмувало:"
    $blockers | ForEach-Object { $md += ("  - {0}" -f $_) }
  } else { $md += "- Що гальмувало: ..." }
  $md += ""
  $md += "🎯 **Головні фокуси на завтра**"
  if ($focus.Count -gt 0) { $md | ForEach-Object { } ; $focus | ForEach-Object { $md += ("- {0}" -f $_) } } else { $md += "- ..." }
  $md += ""
  $md += "💡 **Рекомендації**"
  if ($reco.Count -gt 0) { $reco | ForEach-Object { $md += ("- {0}" -f $_) } } else { $md += "- ..." }
  $md += ""
  $md += ("🌿 **Оцінка внутрішнього стану:** {0}" -f ($(if($inner){$inner}else{"..."})))
  $md += ""
  $md += ("🔏 **Печатка:** {0}" -f $SessionId)
  $md += ""

  Add-Content -Path $journalPath -Value ($md -join $nl)
  Add-IndexRow -CsvPath $sessionsCsv -Mode "End" -SessionId $SessionId -Ts $now
  Write-Host "✅ Додано End до $journalPath" -ForegroundColor Green
  Write-Host ("ID: {0}" -f $SessionId)
  exit 0
}
