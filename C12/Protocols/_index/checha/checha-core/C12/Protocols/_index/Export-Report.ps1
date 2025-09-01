param(
  [string]$IndexPath = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.json",
  [string]$OutMd = "C:\CHECHA_CORE\C12\Protocols\_index\Protocols_Report.md"
)
$j = Get-Content $IndexPath -Raw | ConvertFrom-Json
$items = @($j.protocols)
$byStatus = $items | Group-Object status | Sort-Object Name
$lines = @()
$lines += "# CheCha Protocols — Звіт"
$lines += ""
$lines += "- Оновлено: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$lines += "- Всього протоколів: $($items.Count)"
$lines += ""
$lines += "## Підсумок за статусами"
$lines += "| Статус | Кількість |"
$lines += "|---|---|"
foreach($g in $byStatus){ $lines += "| $($g.Name) | $($g.Count) |" }
$lines += ""
$lines += "## Останні оновлення"
$lines += "| ID | Тема | Статус | Оновлено |"
$lines += "|---|---|---|---|"
foreach($p in ($items | Sort-Object {[datetime]$_.updated_at} -Desc | Select-Object -First 15)){
  $lines += "| $($p.id) | $($p.topic) | $($p.status) | $([datetime]$p.updated_at).ToLocalTime().ToString('yyyy-MM-dd HH:mm') |"
}
$enc = New-Object System.Text.UTF8Encoding($true)
[IO.File]::WriteAllText($OutMd, ($lines -join "`n"), $enc)
Write-Host "✅ Звіт збережено: $OutMd" -ForegroundColor Green