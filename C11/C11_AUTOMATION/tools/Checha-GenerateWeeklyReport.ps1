param(
  [string]$VaultRoot = "C:\CHECHA_CORE\C12\Vault\StrategicReports",
  [string]$YearDir   = (Get-Date -Format 'yyyy')
)

$weekEnd   = Get-Date -Hour 20 -Minute 0 -Second 0
$weekStart = $weekEnd.Date.AddDays(-6)
$yearPath  = Join-Path $VaultRoot $YearDir
New-Item -ItemType Directory -Path $yearPath -Force | Out-Null

$fname = "Strateg_Report_{0}.md" -f ($weekEnd.ToString('yyyy-MM-dd'))
$fpath = Join-Path $yearPath $fname

# якщо звіт існує — не перезаписуємо; тільки доповнюємо заголовок, інакше створюємо
if (-not (Test-Path $fpath)) {
@"
# 🧭 Щотижневий стратегічний звіт — $($weekStart.ToString('yyyy-MM-dd')) → $($weekEnd.ToString('yyyy-MM-dd'))

## 1) Результати тижня
- 

## 2) Пріоритети на наступний тиждень
- 

## 3) Ризики / блокери
- 

## 4) Примітки
- 
"@ | Set-Content -Encoding UTF8 -Path $fpath
}

# Додаємо в індекс і санітуємо
$upd = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Update-StrategicIndex.ps1"
$san = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Sanitize-StrategicIndex.ps1"

pwsh -NoProfile -File $upd -VaultRoot $VaultRoot -FilePath $fpath -Description "Щотижневий стратегічний звіт"
pwsh -NoProfile -File $san -VaultRoot $VaultRoot
