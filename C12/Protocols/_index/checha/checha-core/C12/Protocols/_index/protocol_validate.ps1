param(
  [string]$Root = "C:\CHECHA_CORE\C12\Protocols",
  [string]$IndexPath = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.json"
)
$ErrorActionPreference = "Stop"
$allowed = @("active","draft","archived","closed")
$j = Get-Content $IndexPath -Raw | ConvertFrom-Json
$items = @($j.protocols)
$ok=$true
# унікальні ID
$dups = $items | Group-Object id | Where-Object Count -gt 1
if ($dups){ $ok=$false; Write-Warning ("Дублікати ID: " + ($dups | ForEach-Object {$_.Name}) -join ", ") }
# статуси
$bad = $items | Where-Object { $_.status -notin $allowed }
if ($bad){ $ok=$false; $bad | ForEach-Object { Write-Warning "Некоректний статус: $($_.id) → $($_.status)" } }
# шляхи
foreach($p in $items){
  $path = Join-Path $Root ($p.path -replace '^[\\/]+','' -replace '/','\')
  if (!(Test-Path $path)){ $ok=$false; Write-Warning "Відсутній файл: $($p.id) → $path" }
}
if($ok){ Write-Host "✅ Валідація пройдена." -ForegroundColor Green } else { throw "❌ Помилки валідації. Виправ і запусти знову." }