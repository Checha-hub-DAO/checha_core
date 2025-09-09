<# 
  Start-Planning.ps1 (v2.0)
  Створює/оновлює щоденний файл планування й гарантує наявність секції "Щоденний чек-лист".
  Безпечний для запуску з Планувальника та з оркестратора (Weekly).
#>

[CmdletBinding()]
param(
  [switch]$ForceRun,         # якщо файл існує: перезаписати/оновити замість "нічого не робити"
  [switch]$Soft,             # зарезервовано (не використовується)
  [switch]$Quiet,            # мінімум виводу
  [datetime]$Date = (Get-Date).Date,

  # Базовий Root; якщо не задано — намагаємось вивести з шляху скрипта або fallback до C:\CHECHA_CORE
  [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Легкий логер (не залежимо від зовнішніх профілів/модулів) ----------------
function Write-Log {
  param(
    [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO',
    [Parameter(Mandatory)][string]$Message
  )
  if ($Quiet -and $Level -eq 'INFO') { return }
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  Write-Host ("{0} [{1,-5}] {2}" -f $ts, $Level.ToUpper(), $Message)
}

# --- Визначення Root ----------------------------------------------------------
try {
  if (-not $Root -or -not (Test-Path $Root)) {
    $here = Split-Path -Parent $PSCommandPath
    # ..\..\.. від tools → C:\CHECHA_CORE
    $probe = Resolve-Path (Join-Path $here '..\..\..') -ErrorAction Stop
    $Root = $probe.Path
  }
} catch {
  if (-not $Root) { $Root = 'C:\CHECHA_CORE' }
}
if (-not (Test-Path $Root)) {
  Write-Log ERROR ("Root не знайдено: {0}" -f $Root)
  exit 1
}

# --- Шляхи/імена --------------------------------------------------------------
$DailyDir = Join-Path $Root 'C03\LOG\daily'
$DayName  = $Date.ToString('yyyy-MM-dd') + '.md'
$DayFile  = Join-Path $DailyDir $DayName

# --- Забезпечити теку ---------------------------------------------------------
if (-not (Test-Path $DailyDir)) {
  New-Item -ItemType Directory -Force -Path $DailyDir | Out-Null
}

# --- Базовий шаблон (включно з чек-листом і розділювачем ---) -----------------
$template = @"
# Планування на $($Date.ToString('yyyy-MM-dd'))

## Щоденний чек-лист
- [ ] Розминка / план на день
- [ ] Топ-3 пріоритети
- [ ] Комунікації / відповіді
- [ ] Підсумок дня

---

## Нотатки
...
"@.Trim()

# --- Прочитати поточний вміст (якщо є) ---------------------------------------
$FullMd = if (Test-Path $DayFile) { Get-Content -Raw -Encoding UTF8 $DayFile } else { '' }

# --- Якщо файл існує й не форсимо — просто OK і вихід -------------------------
if ((Test-Path $DayFile) -and -not $ForceRun) {
  Write-Log INFO ("Day planning file already exists: {0}`n? Done." -f $DayFile)
  exit 0
}

# --- Гарантувати секцію "Щоденний чек-лист" -----------------------------------
# Безпечний regex: без \R та без «подвійних» ??; шукаємо тіло до розділювача ---
$pattern = '(?ms)^##\s*Щоденний\s+чек-лист\s*(?:\r?\n)+(?<Body>.*?)(?:\r?\n)---'

$hasChecklist = $false
try {
  $m = [regex]::Match($FullMd, $pattern)
  $hasChecklist = $m.Success
} catch {
  # На випадок модифікацій, але тут патерн і так сумісний з .NET Regex
  $hasChecklist = $false
}

# --- Зібрати новий вміст ------------------------------------------------------
if (-not (Test-Path $DayFile)) {
  # Файла немає → створюємо з шаблону
  $newContent = $template
  Write-Log INFO ("Створено новий файл планування: {0}" -f $DayFile)
} else {
  # Файл є → оновлюємо акуратно
  if ($hasChecklist) {
    # Уже все є → можна лише легкий дотик або залишити як є
    $newContent = $FullMd
    Write-Log INFO ("Checklist уже присутній → оновлення не потрібне ({0})" -f $DayFile)
  } else {
    # Додамо секцію чек-листа в кінець файлу
    $newContent = ($FullMd.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + ($template -split '\r?\n',2)[1])
    Write-Log INFO ("Додано відсутню секцію 'Щоденний чек-лист' → {0}" -f $DayFile)
  }
}

# --- Записати файл (UTF8) -----------------------------------------------------
Set-Content -Path $DayFile -Value $newContent -Encoding UTF8

Write-Log INFO ("OK: Start-Planning → {0}" -f $DayFile)
exit 0
