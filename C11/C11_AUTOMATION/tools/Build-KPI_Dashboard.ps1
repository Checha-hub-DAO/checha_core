[CmdletBinding(PositionalBinding=$false)]
Status = $matches[5]
ShaMatch = $matches[6]
Checksum = $matches[7]
Zip = $matches[8]
Msg = $matches[9]
}
}
return $null
}


$allRows = @()
if(Test-Path -LiteralPath $logPath){
foreach($ln in Get-Content -LiteralPath $logPath){
$row = Parse-Line $ln
if($row){ $allRows += $row }
}
}


# Останні стани модулів за вікно $Days
$rows = $allRows | Where-Object { $_.Timestamp.ToUniversalTime() -ge $since }
$latest = $rows | Sort-Object Module, Timestamp | Group-Object Module | ForEach-Object { $_.Group | Sort-Object Timestamp -Descending | Select-Object -First 1 }


function StatusIcon($st){ switch($st){ 'OK'{'🟢 OK'} 'WARN'{'🟡 WARN'} 'FAIL'{'🔴 FAIL'} Default{'⚪ N/A'} } }


$ok = ($latest | Where-Object {$_.Status -eq 'OK'}).Count
$warn = ($latest | Where-Object {$_.Status -eq 'WARN'}).Count
$fail = ($latest | Where-Object {$_.Status -eq 'FAIL'}).Count
$total = $latest.Count
$tsNow = (Get-Date).ToString('yyyy-MM-dd HH:mm')


# 7‑денні тренди
$rows7 = $allRows | Where-Object { $_.Timestamp.ToUniversalTime() -ge $since7 }
$okPct = 0
$medianPerDay = 0
if($rows7.Count -gt 0){
$ok7 = ($rows7 | Where-Object { $_.Status -eq 'OK' }).Count
$okPct = [math]::Round(100 * $ok7 / [math]::Max(1,$rows7.Count), 1)
$byDay = $rows7 | Group-Object { $_.Timestamp.Date } | ForEach-Object { $_.Count } | Sort-Object
if($byDay.Count -gt 0){
$mid = [int][math]::Floor(($byDay.Count - 1)/2)
if($byDay.Count % 2 -eq 1){ $medianPerDay = $byDay[$mid] } else { $medianPerDay = [math]::Round( ($byDay[$mid] + $byDay[$mid+1]) / 2, 1) }
}
}


$header = @(
'# 📊 KPI Dashboard — Модулі та релізи',
"Оновлено: $tsNow",
'',
'## Стан модулів',
'| Module | Version | Build | Status | SHA Match | Checksum Entry | Last Release |',
'|--------|---------|-------|--------|-----------|----------------|--------------|'
) -join "`n"


$tblLines = $latest | Sort-Object Status, Module | ForEach-Object {
"| $($_.Module) | $($_.Version) | $($_.Build) | $(StatusIcon $_.Status) | $($_.ShaMatch) | $($_.Checksum) | $($_.Zip) |"
}
$tbl = $tblLines -join "`n"


$summary = @(
'',
'## Підсумки за вікно',
"- Тривалість вікна: **$Days** дн.",
"- Загалом покрито модулів: **$total**",
"- Успішних релізів: **$ok**",
"- Попередження: **$warn**",
"- Помилок: **$fail**",
'',
'## Тренди (7 днів)',
"- Середній відсоток OK: **$okPct%**",
"- Медіана перевірок на день: **$medianPerDay**"
) -join "`n"


New-Item -ItemType Directory -Force -Path (Split-Path $outPath -Parent) | Out-Null
Set-Content -Path $outPath -Value ($header+"`n"+$tbl+$summary) -Encoding UTF8
Write-Host "✅ KPI-доповідь згенеровано → $outPath" -ForegroundColor Green