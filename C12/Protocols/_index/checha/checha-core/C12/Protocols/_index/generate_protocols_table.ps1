param(
  [string]$IndexPath = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.json",
  [string]$OutputPath = "C:\CHECHA_CORE\C12\Protocols\_index\Protocols.md"
)
$ErrorActionPreference = "Stop"
$j = Get-Content $IndexPath -Raw | ConvertFrom-Json
$rows = @($j.protocols) | Sort-Object { [datetime]$_.updated_at } -Descending
$lines = @()
$lines += "# DAO Protocols  Індекс"
$lines += ""
$lines += "| ID | Тема | Статус | Відповідальний | Оновлено | Теги |"
$lines += "|---|---|---|---|---|---|"
foreach($p in $rows){
  $rel = "../" + $p.path  # з _index до файлу
  $upd = ([datetime]$p.updated_at).ToLocalTime().ToString("yyyy-MM-dd HH:mm")
  $tags = if ($p.tags) { ($p.tags -join ", ") } else { "" }
  $idLink = "[{0}]({1})" -f $p.id, $rel
  $topic = $p.topic
  $lines += "| {0} | {1} | {2} | {3} | {4} | {5} |" -f $idLink,$topic,$p.status,$p.owner,$upd,$tags
}
$lines += ""
$lines += "---"
$lines += ""
$lines += " **Примітка:**"
$lines += "- Джерело істини для автоматизації: `protocols_index.json`."
$lines += "- Ця таблиця генерується автоматично цим скриптом."
$md = ($lines -join "`n")
$enc = New-Object System.Text.UTF8Encoding($true) # BOM
[IO.File]::WriteAllText($OutputPath,$md,$enc)
Write-Host " Згенеровано: $OutputPath"