param(
  [string]$VaultRoot = "C:\CHECHA_CORE\C12\Vault\StrategicReports",
  [string]$YearDir   = (Get-Date -Format 'yyyy')
)

$now     = Get-Date
$yearPath= Join-Path $VaultRoot $YearDir
New-Item -ItemType Directory -Path $yearPath -Force | Out-Null

$fname = "Strateg_Report_{0}.md" -f ($now.ToString('yyyy-MM'))
$fpath = Join-Path $yearPath $fname

if (-not (Test-Path $fpath)) {
@"
# 🗓️ Щомісячний стратегічний підсумок — $($now.ToString('yyyy-MM'))

## 1) Ключові досягнення
- 

## 2) Показники / KPI
- 

## 3) Ризики / уроки
- 

## 4) План на наступний місяць
- 
"@ | Set-Content -Encoding UTF8 -Path $fpath
}

# Додаємо в індекс і санітуємо
$upd = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Update-StrategicIndex.ps1"
$san = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Sanitize-StrategicIndex.ps1"

pwsh -NoProfile -File $upd -VaultRoot $VaultRoot -FilePath $fpath -Description "Щомісячний стратегічний підсумок"
pwsh -NoProfile -File $san -VaultRoot $VaultRoot
