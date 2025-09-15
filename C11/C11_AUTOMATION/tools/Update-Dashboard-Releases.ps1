$root = "C:\CHECHA_CORE"
$arc  = Join-Path $root "C05\ARCHIVE"
$dash = Join-Path $root "C06\FOCUS\Dashboard.md"

function Get-LastDate([string]$pattern){
  $f = Get-ChildItem -Path $arc -Filter $pattern -File -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($f) { $f.LastWriteTime.ToString("yyyy-MM-dd") } else { "—" }
}

$daily   = Get-LastDate 'CHECHA_CORE_PUSH_*_daily.zip'
$weekly  = Get-LastDate 'CHECHA_CORE_PUSH_*_weekly.zip'
$monthly = Get-LastDate 'CHECHA_CORE_PUSH_*_monthly.zip'
$newLine = "- Релізи: daily — $daily | weekly — $weekly | monthly — $monthly"

# Прочитати (як масив рядків навіть якщо файл з 1 рядка)
[string[]]$lines = @()
if (Test-Path $dash) { $lines = Get-Content -LiteralPath $dash -Encoding UTF8 }

# Прибрати всі попередні рядки "Релізи:"
$lines = $lines | Where-Object { $_ -notmatch '^\s*-\s*Релізи:' }

# Додати свіжий рядок на початок
$lines = ,$newLine + $lines

Set-Content -LiteralPath $dash -Value $lines -Encoding UTF8
Write-Host "✅ Оновлено рядок 'Релізи' у $dash"
