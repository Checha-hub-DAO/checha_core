[CmdletBinding()]
param(
  [string]$Root = "C:\CHECHA_CORE",
  [int]$Days = 7,
  [datetime]$EndDate = (Get-Date),
  [string]$OutName
)

$ErrorActionPreference = 'Stop'

# ---------- Helpers ----------
function Escape-ForPlain {
  param([string]$s)
  if ($null -eq $s) { return "" }
  return $s.Trim()
}

function Sparkline {
  param([double[]]$Values)
  if (-not $Values -or $Values.Count -eq 0) { return "" }
  $bars = @([char]0x2581,[char]0x2582,[char]0x2583,[char]0x2584,[char]0x2585,[char]0x2586,[char]0x2587,[char]0x2588)
  $min = ($Values | Measure-Object -Minimum).Minimum
  $max = ($Values | Measure-Object -Maximum).Maximum
  if ($max -eq $min) { return ($bars[3].ToString() * $Values.Count) }
  $out = New-Object System.Text.StringBuilder
  foreach($v in $Values){
    $t = ($v - $min) / ($max - $min)
    $idx = [math]::Floor($t * ($bars.Count - 1))
    if ($idx -lt 0) { $idx = 0 }
    if ($idx -ge $bars.Count) { $idx = $bars.Count - 1 }
    [void]$out.Append($bars[$idx])
  }
  $out.ToString()
}

# ---------- Paths ----------
$idxCsv     = Join-Path $Root "C03\LOG\SESSIONS\SESSIONS_INDEX.csv"
$logDir     = Join-Path $Root "C03\LOG"
$reportsDir = Join-Path $Root "C12\Vault\StrategicReports"

if (-not (Test-Path $idxCsv)) { throw "Index not found: $idxCsv" }
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir | Out-Null }

# ---------- Period ----------
$periodStart = $EndDate.Date.AddDays(-1 * ($Days - 1))
$periodEnd   = $EndDate.Date
$periodStr   = $periodStart.ToString("yyyy-MM-dd") + " — " + $periodEnd.ToString("yyyy-MM-dd")

# ---------- Read index ----------
$rows = Import-Csv $idxCsv | ForEach-Object {
  $_ | Add-Member -NotePropertyName ts -NotePropertyValue ([datetime]::Parse($_.timestamp_iso)) -PassThru
} | Where-Object { $_.ts -ge $periodStart -and $_.ts -le ($periodEnd.AddDays(1).AddSeconds(-1)) }

# ---------- Build sessions ----------
$grouped = $rows | Group-Object session_id
$sessions = foreach($g in $grouped){
  $sid = $g.Name
  $sorted = $g.Group | Sort-Object ts
  $st = ($sorted | Where-Object { $_.mode -eq 'Start' } | Select-Object -First 1)
  $en = ($sorted | Where-Object { $_.mode -eq 'End' }   | Select-Object -Last 1)
  $stTs = if($st){$st.ts}else{$null}
  $enTs = if($en){$en.ts}else{$null}
  $dur  = if($stTs -and $enTs){ [math]::Round(($enTs - $stTs).TotalMinutes) } else { $null }
  [pscustomobject]@{
    date   = if($st){ $st.date } elseif ($en){ $en.date } else { "" }
    start  = $stTs
    end    = $enTs
    end_hm = if($enTs){ $enTs.ToString("HH:mm") } else { $null }
    dur_m  = $dur
    sid    = $sid
  }
}

# ---------- Summary ----------
$valid      = $sessions | Where-Object { $_.dur_m -ne $null }
$totalMin   = ($valid | Measure-Object dur_m -Sum).Sum
$totalMin   = if($totalMin){ [int]$totalMin } else { 0 }
$h          = [math]::Floor($totalMin / 60)
$m          = $totalMin % 60
$sessionCnt = ($sessions | Measure-Object).Count

# Avg end time
$ends = $sessions | Where-Object { $_.end } | Select-Object -ExpandProperty end
$avgEnd = $null
if ($ends.Count -gt 0) {
  $avgTicks = ($ends | Measure-Object Ticks -Average).Average
  if ($avgTicks) { $avgEnd = (Get-Date ([long]$avgTicks)).ToString("HH:mm") }
}

# ---------- Extract top-3 focuses & blockers ----------
$focusBuckets   = @{}
$blockerBuckets = @{}
$rxFocusStart   = [regex]'(?mi)^🎯\s*\*\*Головні фокуси на завтра\*\*'
$rxSectionStop  = [regex]'(?m)^(💡|🌿|🔏|##\s|\-\-\-|🏆|📊|##\s🔴|##\s🟢)'

$datesRange = 0..($Days-1) | ForEach-Object { $periodStart.AddDays($_).ToString("yyyy-MM-dd") }
foreach($d in $datesRange){
  $file = Join-Path $logDir ("CheCha_Journal_" + $d + ".md")
  if (-not (Test-Path $file)) { continue }
  $text = Get-Content $file -Raw

  # ---- Focuses
  $m = $rxFocusStart.Matches($text)
  foreach($hit in $m){
    $startIdx = $hit.Index + $hit.Length
    $tail = $text.Substring($startIdx)
    $stop = $rxSectionStop.Match($tail)
    $block = if ($stop.Success) { $tail.Substring(0, $stop.Index) } else { $tail }
    $lines = $block -split "(`r`n|`n)"
    foreach($ln in $lines){
      $t = $ln.Trim()
      if ($t -match '^\-\s+(?<f>.+)$') {
        $focus = Escape-ForPlain $Matches['f']
        if ($focus -and $focus -ne '...') {
          if (-not $focusBuckets.ContainsKey($focus)) { $focusBuckets[$focus] = 0 }
          $focusBuckets[$focus]++
        }
      }
    }
  }

  # ---- Blockers (у блоці "📊 **Аналіз**" -> "- Що гальмувало:")
  $idxAnal = [regex]::Match($text,'(?mi)^📊\s*\*\*Аналіз\*\*')
  if ($idxAnal.Success) {
    $tail = $text.Substring($idxAnal.Index + $idxAnal.Length)
    $stop = $rxSectionStop.Match($tail)
    $block = if ($stop.Success) { $tail.Substring(0, $stop.Index) } else { $tail }
    $lines = $block -split "(`r`n|`n)"
    $inBlockers = $false
    foreach($ln in $lines){
      $t = $ln.Trim()
      if ($t -match '^\-\s*Що гальмувало:\s*$') { $inBlockers = $true; continue }
      if ($inBlockers) {
        if ($t -match '^\- ') {
          $bl = ($t -replace '^\-\s*','').Trim()
          if ($bl -and $bl -ne '...') {
            if (-not $blockerBuckets.ContainsKey($bl)) { $blockerBuckets[$bl] = 0 }
            $blockerBuckets[$bl]++
          }
        } elseif ($t -match '^\-\s*\S') { break }
      }
    }
  }
}

$topFocus    = $focusBuckets.GetEnumerator()   | Sort-Object Value -Descending | Select-Object -First 3
$topBlockers = $blockerBuckets.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 3

# ---------- Daily aggregation + sparkline ----------
$daily = $sessions | Group-Object date | ForEach-Object {
  $date = $_.Name
  $durMin = ($_.Group | Where-Object { $_.dur_m } | Measure-Object dur_m -Sum).Sum
  $avgEndTicks = ($_.Group | Where-Object { $_.end } | Select-Object -ExpandProperty end |
                  Measure-Object Ticks -Average).Average
  $avgEndDay = if($avgEndTicks){ (Get-Date ([long]$avgEndTicks)).ToString("HH:mm") } else { "—" }
  [pscustomobject]@{
    date = $date
    sum  = if($durMin){ [int]$durMin } else { 0 }
    avgE = $avgEndDay
  }
} | Sort-Object date

# Вектор для спарклайну по всіх днях періоду (включно з порожніми)
$chronDates = 0..($Days-1) | ForEach-Object { $periodStart.AddDays($_).ToString("yyyy-MM-dd") }
$vals = @()
foreach($d in $chronDates){
  $found = $daily | Where-Object { $_.date -eq $d } | Select-Object -First 1
  $vals += $(if($found){ [double]$found.sum } else { 0 })
}
$spark = Sparkline -Values $vals

# ---------- Markdown ----------
$todayStr = (Get-Date).ToString("yyyy-MM-dd")
if (-not $OutName) { $OutName = "SESSION_STATS_WEEKLY_" + $todayStr + ".md" }
$outPath = Join-Path $reportsDir $OutName

$enc = New-Object System.Text.UTF8Encoding($true) # UTF-8 BOM
$nl  = [Environment]::NewLine
$md  = New-Object System.Collections.Generic.List[string]

$md.Add("# 📈 CheCha — Щотижнева аналітика сесій")
$md.Add("")
$md.Add("**Період:** " + $periodStr)
$md.Add("")
$md.Add("**Сесій:** " + $sessionCnt)
$md.Add("**Загальна тривалість:** " + $h + " год " + $m + " хв")
$md.Add("**Середній час завершення:** " + ($(if($avgEnd){$avgEnd}else{"—"})))
$md.Add("")
$md.Add("## 🔝 Топ-3 фокуси тижня")
if ($topFocus.Count -gt 0) {
  foreach($kv in $topFocus){
    $md.Add("- " + $kv.Key + "  _(випадків: " + $kv.Value + ")_")
  }
} else { $md.Add("- Дані відсутні") }
$md.Add("")
$md.Add("## ⛔ Топ-3 блокери тижня")
if ($topBlockers.Count -gt 0) {
  foreach($kv in $topBlockers){
    $md.Add("- " + $kv.Key + "  _(випадків: " + $kv.Value + ")_")
  }
} else { $md.Add("- Дані відсутні") }
$md.Add("")
$md.Add("## 📅 Щоденна агрегована таблиця")
$md.Add("")
$md.Add("| Дата | Сумарно (хв) | Середній час завершення |")
$md.Add("|---|---:|:---|")
foreach($r in $daily){
  $md.Add("| " + $r.date + " | " + $r.sum + " | " + $r.avgE + " |")
}
$md.Add("")
$md.Add("**Сумарні хвилини (спарклайн):** " + $spark)
$md.Add("")

# Тимчасово збережемо без підпису, щоб порахувати SHA-256
$tempContent = ($md -join $nl)
$sha256 = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($tempContent))).Replace("-","").ToLowerInvariant()

$md.Add("")
$md.Add("---")
$md.Add("SHA-256: " + $sha256)
$final = ($md -join $nl)

[System.IO.File]::WriteAllText($outPath, $final, $enc)

Write-Host "✅ Weekly report saved:"
Write-Host "  " $outPath

# ---------- Update Strategic Reports index ----------
$indexPath = Join-Path $reportsDir "_index.md"
$rel = Split-Path $outPath -Leaf
$line = "* [" + $rel + "](" + $rel + ") — згенеровано " + $todayStr
if (-not (Test-Path $indexPath)) {
  $head = @(
    "# 📚 CheCha Strategic Reports Index",
    "",
    "Останні звіти:",
    "",
    $line
  ) -join $nl
  [System.IO.File]::WriteAllText($indexPath, $head, $enc)
} else {
  Add-Content -Path $indexPath -Value $line
}
