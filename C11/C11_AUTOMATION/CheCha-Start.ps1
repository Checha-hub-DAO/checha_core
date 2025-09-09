<# ============================================================
  CheCha-Start.ps1 — ультра-ярлик старту робочого процесу
  Дії:
    1) Старт-транскрипт у C03\LOG\start_session_*.log
    2) Запуск Checha-RunAll.ps1 -UpdatePanel
    3) Відкриття CONTROL_PANEL.md у VS Code (або Notepad)
    4) Відкриття теки C06_FOCUS у Провіднику
    5) Вивід підсумку і (опц.) пауза (якщо викликано з .bat)
============================================================ #>

[CmdletBinding()]
param(
  [switch]$NoExplorer,        # не відкривати теку C06_FOCUS
  [switch]$NoLogs,            # не показувати останній лог
  [switch]$NoVSCode,          # не відкривати у VS Code (використати Notepad)
  [switch]$PauseAtEnd         # зробити паузу наприкінці (зручно для .bat)
)

$ErrorActionPreference = 'Stop'
$root     = "C:\CHECHA_CORE"
$runAll   = Join-Path $root "C11\C11_AUTOMATION\Checha-RunAll.ps1"
$panel    = Join-Path $root "C06_FOCUS\CONTROL_PANEL.md"
$logDir   = Join-Path $root "C03\LOG"
$iconsDir = Join-Path $root "C06_FOCUS\icons"

# 1) Транскрипт
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$tsPath = Join-Path $logDir ("start_session_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
try { Start-Transcript -Path $tsPath -Append | Out-Null } catch {}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$hadErr = $false

Write-Host "→ CheCha Start — ініціалізація..." -ForegroundColor Cyan

# 2) RunAll
try {
  if (-not (Test-Path $runAll)) { throw "Не знайдено Checha-RunAll.ps1: $runAll" }
  & $runAll -UpdatePanel -StatusTake 8
  if ($LASTEXITCODE -ne 0) { throw "RunAll exited code $LASTEXITCODE" }
  Write-Host "✓ RunAll: OK" -ForegroundColor Green
} catch {
  $hadErr = $true
  Write-Warning "RunAll ERR: $($_.Exception.Message)"
}

# 3) Відкрити панель
try {
  if (-not (Test-Path $panel)) {
    # якщо файла ще нема — створимо мінімальний і оновимо
    $dir = Split-Path $panel -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    @'
# 🛠 Панель Управління — v1.0
Останнє оновлення: {{DATE}}
Статус: {{STATUS_BADGE}}

## 1. 🔍 Статус Системи
- Health-check: {{AUTO:desktop_health}}
- Останній лог: {{AUTO:last_log}}
- Попередження: {{AUTO:alerts}}
- Останнє RunAll: {{AUTO:last_runall}}
'@ | Set-Content -Path $panel -Encoding UTF8
    # спробуємо оновити
    $upd = Join-Path $root "C11\C11_AUTOMATION\tools\Update-ControlPanel.ps1"
    if (Test-Path $upd) { & $upd | Out-Null }
  }

  # знайдемо VS Code
  $codeExe = $null
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
    "C:\Program Files\Microsoft VS Code\Code.exe",
    "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
  )
  foreach ($c in $candidates) { if (Test-Path $c) { $codeExe = $c; break } }
  if (-not $NoVSCode -and $codeExe) {
    Start-Process -FilePath $codeExe -ArgumentList "`"$panel`""
    Write-Host "✓ Відкрито у VS Code: $panel" -ForegroundColor Green
  } else {
    Start-Process notepad.exe "`"$panel`""
    Write-Host "ℹ️ VS Code недоступний — відкрито у Notepad" -ForegroundColor Yellow
  }
} catch {
  $hadErr = $true
  Write-Warning "OPEN PANEL ERR: $($_.Exception.Message)"
}

# 4) Провідник і лог
try {
  if (-not $NoExplorer) {
    Start-Process explorer.exe "`"$($root)\C06_FOCUS`""
  }
  if (-not $NoLogs) {
    $lastRunAll = Get-ChildItem $logDir -Filter "run_all_*.log" -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Desc | Select-Object -First 1
    if ($lastRunAll) {
      Write-Host "🧾 Останній лог: $($lastRunAll.FullName)" -ForegroundColor DarkCyan
    }
  }
} catch {
  Write-Warning "OPEN EXPLORER/LOG ERR: $($_.Exception.Message)"
}

$sw.Stop()
Write-Host ("⏱ Готово за {0:N1}s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Cyan
if ($hadErr) { Write-Host "⚠️ Є попередження/помилки — дивись лог: $tsPath" -ForegroundColor Yellow }
else { Write-Host "✅ Усе зелено" -ForegroundColor Green }

try { Stop-Transcript | Out-Null } catch {}

if ($PauseAtEnd) { Write-Host ""; Read-Host "Натисни Enter, щоб закрити" | Out-Null }
