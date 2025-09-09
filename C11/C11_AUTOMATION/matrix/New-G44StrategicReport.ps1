# C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\New-G44StrategicReport.ps1
[CmdletBinding()]
param(
  [string]$ConfigPath = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\checha_matrix_config.json",
  [string]$ReportDate = (Get-Date -Format "yyyy-MM-dd")
)

$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
if(-not (Test-Path $cfg.Feeds.G04Feed)){ throw "G04Feed missing: $($cfg.Feeds.G04Feed)" }
if(-not (Test-Path $cfg.Feeds.C12Feed)){ throw "C12Feed missing: $($cfg.Feeds.C12Feed)" }

$g04 = Get-Content $cfg.Feeds.G04Feed -Raw | ConvertFrom-Json
$c12 = Get-Content $cfg.Feeds.C12Feed -Raw | ConvertFrom-Json

$yearDir = Join-Path $cfg.C12.StrategicReportsRoot ($ReportDate.Substring(0,4))
if(-not (Test-Path $yearDir)){ New-Item -ItemType Directory -Path $yearDir | Out-Null }
$reportPath = Join-Path $yearDir ("Strateg_Report_{0}.md" -f $ReportDate)

# ---- markdown builder ----
$sb = New-Object System.Text.StringBuilder
function AddLine([string]$t){ [void]$sb.AppendLine($t) }

AddLine( '# 🧭 Strategic Report — {0}' -f $ReportDate )
AddLine( '_Автор: {0}_  ' -f $cfg.Author )
AddLine( '_Створено: {0}_' -f (Get-Date -Format 'yyyy-MM-dd HH:mm') )
AddLine( '---' )

# G04
AddLine( '## 1) Операційний стан (G04)' )
AddLine( ('- 48 год: **{0}** | 7 днів: **{1}** | 30 днів: **{2}**' -f $g04.counts.critical_48h,$g04.counts.urgent_7d,$g04.counts.planned_30d) )

function Add-TaskBlock([string]$title,$arr){
  $b = New-Object System.Text.StringBuilder
  [void]$b.AppendLine("### $title")
  if(-not $arr -or $arr.Count -eq 0){ [void]$b.AppendLine('_Порожньо_'); return $b.ToString() }
  [void]$b.AppendLine('| ID | Назва | Відп. | Дедлайн | Посилання |')
  [void]$b.AppendLine('|---|---|---|---|---|')
  foreach($t in $arr){
    $lnk = if($t.link){ "[{0}]({0})" -f $t.link } else { "" }
    [void]$b.AppendLine( ('| {0} | {1} | {2} | {3} | {4} |' -f $t.id,$t.title,$t.owner,$t.due,$lnk) )
  }
  return $b.ToString()
}

AddLine( (Add-TaskBlock '🚨 48 год'  $g04.items.critical_48h) )
AddLine( (Add-TaskBlock '⚠️ 7 днів'  $g04.items.urgent_7d) )
AddLine( (Add-TaskBlock '🟢 30 днів' $g04.items.planned_30d) )

# C12
AddLine( '## 2) Свіжі знання (C12)' )
AddLine( ('**З {0}**: стратегічні звіти — {1}, документи — {2}' -f $c12.since,$c12.counts.strategic_reports,$c12.counts.docs) )

AddLine( '### Нові стратегічні звіти' )
if( ($c12.strategic_reports | Measure-Object).Count -eq 0 ){
  AddLine('_Немає_')
}else{
  foreach($r in $c12.strategic_reports){
    $rel = ($r.rel -replace '\\','/')
    AddLine( ('- [{0}]({1})' -f $r.rel, './../' + $rel) )
  }
}

AddLine( '### Нові документи (топ 20)' )
$take = $c12.docs | Sort-Object date -Descending | Select-Object -First 20
if( ($take | Measure-Object).Count -eq 0 ){
  AddLine('_Немає_')
}else{
  foreach($d in $take){
    # використаємо одинарні лапки з форматуванням -f, щоб безпечно вставити markdown-бектики
    AddLine( ('- {0} — _{1}_  `{2}`' -f $d.rel, $d.date, $d.path) )
  }
}

# Focus
AddLine( '## 3) Фокусні висновки' )
AddLine( '- Ризики: …' )
AddLine( '- Досягнення: …' )
AddLine( '- Наступні кроки: …' )

$enc = if($cfg.Encoding -eq 'utf8BOM'){ New-Object System.Text.UTF8Encoding($true) } else { [Text.Encoding]::UTF8 }
[IO.File]::WriteAllText($reportPath, $sb.ToString(), $enc)
Write-Host "OK: report -> $reportPath"

# Update README index (optional)
if(Test-Path $cfg.Git.ReadmeStrategic){
  $date = $ReportDate; $year = $ReportDate.Substring(0,4)
  $rel  = "./$year/Strateg_Report_$date.md"
  $line = "| $date | [Strateg_Report_$date.md]($rel) |"
  $readme = Get-Content $cfg.Git.ReadmeStrategic -Raw -Encoding UTF8
  $updated = $readme -replace "(## Останні[^\r\n]*\r?\n\|.+\|\r?\n\|[-\|]+\r?\n)","`$1$line`r`n"
  if($updated -eq $readme){ $updated = $readme + "`r`n$line`r`n" }
  [IO.File]::WriteAllText($cfg.Git.ReadmeStrategic, $updated, $enc)
}

# echo path for upstream use
$reportPath
