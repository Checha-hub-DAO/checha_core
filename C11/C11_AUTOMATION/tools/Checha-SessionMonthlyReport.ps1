#requires -Version 5.1
[CmdletBinding()]
param(
  [string]$Root      = "C:\CHECHA_CORE",
  [ValidateSet("Calendar","Rolling")]
  [string]$Mode      = "Calendar",
  [int]$Days         = 30,
  [datetime]$EndDate = (Get-Date),
  [string]$OutName,
  [switch]$ForceRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --- Helpers: sum/avg без Measure-Object ---
function Sum-Property {
  param($Items, [string]$Property)
  $sum = 0.0; $hasAny = $false
  foreach($it in @($Items)){
    if ($null -eq $it) { continue }
    $v = $it.$Property
    if ($null -ne $v -and ($v -is [double] -or $v -is [int] -or $v -is [long])) {
      $sum += [double]$v
      $hasAny = $true
    }
  }
  if ($hasAny) { return [int][math]::Round($sum) } else { return 0 }
}

function Avg-Ticks {
  param([datetime[]]$Dates)
  $ticks = [decimal]0; $n = 0
  foreach($d in @($Dates)){
    if ($null -ne $d) { $ticks += [decimal]$d.Ticks; $n++ }
  }
  if ($n -gt 0) { return [long]($ticks / $n) } else { return $null }
}

function Sparkline {
  param([double[]]$Values)
  if (-not $Values -or $Values.Count -eq 0) { return "" }
  $bars = @('.',':','-','=','+','*','#','%')
  $min = ($Values | Measure-Object -Minimum).Minimum
  $max = ($Values | Measure-Object -Maximum).Maximum
  if ($max -eq $min) { return ''.PadLeft($Values.Count, ($bars[3])[0]) }
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

function HeatChar {
  param([int]$v, [int]$min, [int]$max)
  if ($v -le 0) { return "." }
  $bars = @('.',':','-','=','+','*','#','%')
  if ($max -le $min) { return $bars[4] }
  $t = ($v - $min) / [double]($max - $min)
  $idx = [math]::Floor($t * ($bars.Count - 1))
  if ($idx -lt 0) { $idx = 0 }
  if ($idx -ge $bars.Count) { $idx = $bars.Count - 1 }
  return $bars[$idx]
}

function DowIndexMonFirst {
  param([datetime]$d)
  $sunday0 = [int]$d.DayOfWeek
  return (($sunday0 + 6) % 7)  # Monday=0 ... Sunday=6
}

# Paths
$idxCsv     = Join-Path $Root "C03\LOG\SESSIONS\SESSIONS_INDEX.csv"
$reportsDir = Join-Path $Root "C12\Vault\StrategicReports"
if (-not (Test-Path $idxCsv))     { throw ("Index not found: {0}" -f $idxCsv) }
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir | Out-Null }

# Calendar guard
if ($Mode -eq "Calendar" -and -not $ForceRun) {
  $today = Get-Date
  $isLastDay = ($today.AddDays(1).Month -ne $today.Month)
  if (-not $isLastDay) {
    Write-Host "INFO: Not the last day of month. Use -ForceRun or Mode=Rolling."
    exit 0
  }
  Write-Host "OK: Last day of month - generating report..."
} elseif ($Mode -eq "Calendar" -and $ForceRun) {
  Write-Host "TEST: Forced run (Calendar) - generating outside last day."
}

# Period
if ($Mode -eq "Calendar") {
  $monthStart = Get-Date -Year $EndDate.Year -Month $EndDate.Month -Day 1
  $periodStart = $monthStart
  $periodEnd   = $EndDate.Date
} else {
  $periodStart = $EndDate.Date.AddDays(-1 * ($Days - 1))
  $periodEnd   = $EndDate.Date
}
$periodStr = "{0:yyyy-MM-dd} - {1:yyyy-MM-dd}" -f $periodStart, $periodEnd
$cutStart  = $periodStart
$cutEnd    = $periodEnd.AddDays(1).AddSeconds(-1)

# Read index + normalize to array + validate
$raw = Import-Csv $idxCsv
if ($null -eq $raw) {
  $raw = @()
} elseif ($raw -isnot [System.Array]) {
  $raw = @($raw)
}

$need = @('timestamp_iso','session_id','mode','date')
$have = if ($raw.Count -gt 0 -and $null -ne $raw[0]) { $raw[0].PSObject.Properties.Name } else { @() }
foreach($n in $need){
  if ($have -notcontains $n) { throw ("Index {0}: column '{1}' is missing." -f $idxCsv,$n) }
}

$rows = $raw | ForEach-Object {
  $ts = try { [datetime]::Parse($_.timestamp_iso, [Globalization.CultureInfo]::InvariantCulture) } catch { $_.timestamp_iso }
  $_ | Add-Member -NotePropertyName ts -NotePropertyValue $ts -PassThru
} | Where-Object { $_.ts -ge $cutStart -and $_.ts -le $cutEnd }

# Build sessions
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

# Summary
$valid      = $sessions | Where-Object { $_.dur_m -ne $null }
$totalMin   = Sum-Property -Items $valid -Property 'dur_m'
$h          = [math]::Floor($totalMin / 60)
$m          = $totalMin % 60
$sessionCnt = ($sessions | Measure-Object).Count

# Avg end time
$ends  = @($sessions | Where-Object { $_.end } | Select-Object -ExpandProperty end)
$avgEnd = $null
$avgTicks = Avg-Ticks -Dates $ends
if ($avgTicks) { $avgEnd = (Get-Date ([long]$avgTicks)).ToString("HH:mm") }

# Daily aggregation
$daily = $sessions | Group-Object date | ForEach-Object {
  $date = $_.Name
  $durMin = Sum-Property -Items ($_.Group | Where-Object { $_.dur_m -ne $null }) -Property 'dur_m'
  $endsLocal = @($_.Group | Where-Object { $_.end } | Select-Object -ExpandProperty end)
  $avgEndTicks = Avg-Ticks -Dates $endsLocal
  $avgEndDay = if($avgEndTicks){ (Get-Date ([long]$avgEndTicks)).ToString("HH:mm") } else { "-" }
  [pscustomobject]@{
    date = $date
    sum  = [int]$durMin
    avgE = $avgEndDay
  }
} | Sort-Object date

$daySum = @{}
foreach($r in $daily){ $daySum[$r.date] = [int]$r.sum }

$chronDates = 0..(($periodEnd - $periodStart).Days) | ForEach-Object { $periodStart.AddDays($_).ToString("yyyy-MM-dd") }
$vals = foreach($d in $chronDates){ if($daySum.ContainsKey($d)){ [double]$daySum[$d] } else { 0 } }
$spark = Sparkline -Values $vals

# Heatmap (weeks x weekdays, Mon..Sun)
$mmVals = foreach($d in $chronDates){ if($daySum.ContainsKey($d)){ [int]$daySum[$d] } else { 0 } }
$minV = ($mmVals | Measure-Object -Minimum).Minimum
$maxV = ($mmVals | Measure-Object -Maximum).Maximum

$heat = New-Object System.Collections.Generic.List[string]
$heat.Add("| Week | Mo | Tu | We | Th | Fr | Sa | Su |")
$heat.Add("|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|")

$cursor = $periodStart
$weekIdx = 1
$pad = DowIndexMonFirst -d $cursor
$rowCells = @("W" + $weekIdx)
for($i=0;$i -lt $pad;$i++){ $rowCells += " " }

while($cursor -le $periodEnd){
  $k = $cursor.ToString("yyyy-MM-dd")
  $v = if($daySum.ContainsKey($k)){ [int]$daySum[$k] } else { 0 }
  $rowCells += (HeatChar -v $v -min $minV -max $maxV).ToString()

  $dow = DowIndexMonFirst -d $cursor
  if ($dow -eq 6 -or $cursor -eq $periodEnd) {
    while($rowCells.Count -lt 8) { $rowCells += " " }
    $heat.Add("| " + ($rowCells -join " | ") + " |")
    $weekIdx++
    $rowCells = @("W" + $weekIdx)
  }
  $cursor = $cursor.AddDays(1)
}

# Markdown
$todayStr = (Get-Date).ToString("yyyy-MM-dd")
if (-not $OutName) {
  if ($Mode -eq "Calendar") {
    $OutName = "SESSION_STATS_MONTHLY_" + $periodEnd.ToString("yyyy-MM") + ".md"
  } else {
    $OutName = "SESSION_STATS_MONTHLY_" + $todayStr + ".md"
  }
}
$outPath = Join-Path $reportsDir $OutName

$enc = New-Object System.Text.UTF8Encoding($true) # UTF-8 BOM
$nl  = [Environment]::NewLine
$md  = New-Object System.Collections.Generic.List[string]

$md.Add("# CheCha - Monthly session analytics")
$md.Add("")
$md.Add("**Period:** " + $periodStr + "  (" + $Mode + ")")
$md.Add("")
$md.Add("**Sessions:** " + $sessionCnt)
$md.Add("**Total duration:** " + $h + " h " + $m + " min")
$md.Add("**Avg end time:** " + ($(if($avgEnd){$avgEnd}else{"-"})))
$md.Add("")
$md.Add("## Daily summary table")
$md.Add("")
$md.Add("| Date | Total (min) | Avg end |")
$md.Add("|---|---:|:---|")
foreach($r in $daily){ $md.Add("| " + $r.date + " | " + $r.sum + " | " + $r.avgE + " |") }
$md.Add("")
$md.Add("**Total minutes (sparkline):** " + $spark)
$md.Add("")
$md.Add("## Monthly heatmap")
$md.Add("")
$md.AddRange($heat)

$tempContent = ($md -join $nl)
$sha256 = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($tempContent))).Replace("-","").ToLowerInvariant()

$md.Add("")
$md.Add("---")
$md.Add("SHA-256: " + $sha256)
$final = ($md -join $nl)

[System.IO.File]::WriteAllText($outPath, $final, $enc)
Write-Host ("OK: Monthly report saved: {0}" -f $outPath)
