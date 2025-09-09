# C11\C11_AUTOMATION\Run-ChechaAlgorithms.ps1
[CmdletBinding()]
param(
  [string]$JsonPath = "C:\CHECHA_CORE\C12\Protocols\CheCha_Algorithms_v1.1.json",
  [string[]]$Only,          # фільтр: виконати лише ці алгоритми за назвою
  [switch]$DryRun,          # показати, що було б виконано
  [switch]$Force            # ігнорувати деякі перевірки (ризиковано)
)

$ErrorActionPreference = "Stop"

# --- 1) Завантаження JSON
if (-not (Test-Path $JsonPath)) {
  throw "Не знайдено JSON: $JsonPath"
}
$algos = Get-Content $JsonPath -Raw | ConvertFrom-Json

# --- 2) Мапінг «Алгоритм» -> «Обробник»
$AlgorithmHandlers = @{
  "Релізи" = {
    param($item)
    # приклад: валідація релізних ассетів + завантаження
    $tag = (Get-Date -Format "yyyy-MM-dd_HHmm")  # або з твоєї логіки
    $verify = "C:\CHECHA_CORE\tools\verify_release_assets.ps1"
    if ($DryRun) { 
      Write-Host "[DRY] Перевірив би релізні файли через $verify" -ForegroundColor Yellow
      return
    }
    if (Test-Path $verify) {
      & $verify -Tag $tag -RequireAssets -VerifyChecksums
    } else {
      Write-Warning "Скрипт валідації не знайдено: $verify"
    }
  }

  "Звіти" = {
    param($item)
    $agent = "C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\Build-StrategicReport.ps1"
    if ($DryRun) { Write-Host "[DRY] Зібрав би стратегічний звіт через $agent" -ForegroundColor Yellow; return }
    if (Test-Path $agent) { & $agent } else { Write-Warning "Нема $agent" }
  }

  "Архівація" = {
    param($item)
    $zipper = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Archive-CHECHA.ps1"
    if ($DryRun) { Write-Host "[DRY] Створив би ZIP + SHA256 через $zipper" -ForegroundColor Yellow; return }
    if (Test-Path $zipper) { & $zipper -Force:$Force } else { Write-Warning "Нема $zipper" }
  }

  "Синхронізація" = {
    param($item)
    $sync = "C:\CHECHA_CORE\tools\sync_all.ps1"
    if ($DryRun) { Write-Host "[DRY] Синхронізував би GitHub/MinIO/GitBook через $sync" -ForegroundColor Yellow; return }
    if (Test-Path $sync) { & $sync } else { Write-Warning "Нема $sync" }
  }

  "Панелі" = {
    param($item)
    $dash = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Update-VaultDashboard.ps1"
    if ($DryRun) { Write-Host "[DRY] Оновив би панелі через $dash" -ForegroundColor Yellow; return }
    if (Test-Path $dash) { & $dash } else { Write-Warning "Нема $dash" }
  }

  "Моніторинг" = {
    param($item)
    $mon = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Scan-LogsAndAlerts.ps1"
    if ($DryRun) { Write-Host "[DRY] Пробіг би логі та алерти через $mon" -ForegroundColor Yellow; return }
    if (Test-Path $mon) { & $mon } else { Write-Warning "Нема $mon" }
  }

  "Відновлення" = {
    param($item)
    $restore = "C:\CHECHA_CORE\tools\restore_drill.ps1"
    if ($DryRun) { Write-Host "[DRY] Прокрутив би restore-drill через $restore" -ForegroundColor Yellow; return }
    if (Test-Path $restore) { & $restore } else { Write-Warning "Нема $restore" }
  }

  "Ініціалізація" = {
    param($item)
    $init = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Init-NewModule.ps1"
    if ($DryRun) { Write-Host "[DRY] Запустив би ініціалізацію модуля через $init" -ForegroundColor Yellow; return }
    if (Test-Path $init) { & $init -Template "TEMPLATE_DAO-GXX.md" } else { Write-Warning "Нема $init" }
  }

  "Самокорекція" = {
    param($item)
    $auto = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Auto-TuneConfigs.ps1"
    if ($DryRun) { Write-Host "[DRY] Оцінив би метрики і підкрутив конфіги через $auto" -ForegroundColor Yellow; return }
    if (Test-Path $auto) { & $auto -Config "C:\CHECHA_CORE\C11\C11_AUTOMATION\config\checha_shelves.json" } else { Write-Warning "Нема $auto" }
  }
}

# --- 3) Виконання (з фільтром -Only)
foreach ($a in $algos) {
  $name = $a."Алгоритм"
  if ($Only -and ($Only -notcontains $name)) { continue }
  if (-not $AlgorithmHandlers.ContainsKey($name)) {
    Write-Warning "Нема обробника для '$name' — пропускаю"
    continue
  }
  Write-Host "▶ $name — $($a.'Призначення')" -ForegroundColor Cyan
  & $AlgorithmHandlers[$name] $a
}

Write-Host "DONE" -ForegroundColor Green
