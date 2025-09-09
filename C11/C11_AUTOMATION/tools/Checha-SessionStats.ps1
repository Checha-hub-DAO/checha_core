[CmdletBinding()]
param(
  [string]$Root = "C:\CHECHA_CORE",
  [int]$Days = 30
)

$csv = Join-Path $Root "C03\LOG\SESSIONS\SESSIONS_INDEX.csv"
if (-not (Test-Path $csv)) { throw "Index not found: $csv" }

$rows = Import-Csv $csv
$cut  = (Get-Date).AddDays(-$Days)

$rows = $rows | Where-Object { [datetime]::Parse($_.timestamp_iso) -ge $cut }

# Групуємо по даті + session_id, визначаємо перший Start і останній End
$grouped = $rows | Group-Object session_id
$stats = foreach($g in $grouped){
  $sid  = $g.Name
  $ts   = $g.Group | Sort-Object { [datetime]::Parse($_.timestamp_iso) }
  $start = ($ts | Where-Object { $_.mode -eq 'Start' } | Select-Object -First 1)
  $end   = ($ts | Where-Object { $_.mode -eq 'End'   } | Select-Object -Last  1)

  $startTime = if($start){ [datetime]::Parse($start.timestamp_iso) } else { $null }
  $endTime   = if($end)  { [datetime]::Parse($end.timestamp_iso)   } else { $null }
  $durMin    = if($startTime -and $endTime){ [math]::Round(($endTime-$startTime).TotalMinutes,0) } else { $null }

  [pscustomobject]@{
    session_id = $sid
    date       = if($start){ $start.date } elseif ($end){ $end.date } else { "" }
    start      = if($startTime){ $startTime.ToString("HH:mm") } else { "" }
    end        = if($endTime)  { $endTime.ToString("HH:mm")   } else { "" }
    duration_m = $durMin
  }
}

# Підсумки за датою
$daily = $stats | Group-Object date | ForEach-Object {
  $date = $_.Name
  $durs = $_.Group | Where-Object { $_.duration_m } | Select-Object -ExpandProperty duration_m
  $avgEnd = ($stats | Where-Object { $_.date -eq $date -and $_.end -ne "" } | 
             Select-Object -ExpandProperty end |
             ForEach-Object { [datetime]::ParseExact($_,"HH:mm",$null) } |
             Measure-Object Ticks -Average).Average
  [pscustomobject]@{
    date         = $date
    sessions     = $_.Count
    total_min    = ($durs | Measure-Object -Sum).Sum
    avg_end      = if($avgEnd){ (Get-Date $avgEnd).ToString("HH:mm") } else { "" }
  }
}

# Збереження
$outDir = Join-Path $Root "C03\LOG\SESSIONS"
$sum1   = Join-Path $outDir "SESSION_STATS_raw_$(Get-Date -Format yyyyMMdd_HHmm).csv"
$sum2   = Join-Path $outDir "SESSION_STATS_daily_$(Get-Date -Format yyyyMMdd_HHmm).csv"

$stats | Sort-Object date,start | Export-Csv -NoTypeInformation -Encoding UTF8 $sum1
$daily | Sort-Object date       | Export-Csv -NoTypeInformation -Encoding UTF8 $sum2

Write-Host "✅ Saved:" -ForegroundColor Green
Write-Host "  $sum1"
Write-Host "  $sum2"
