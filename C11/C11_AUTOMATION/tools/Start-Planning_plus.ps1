
[CmdletBinding()]
param(
  [ValidateSet('Day','Week')]
  [string]$Mode = 'Day',
  [string]$ChechaRoot = 'C:\CHECHA_CORE',
  [switch]$OpenOnlyIfNew,              # відкривати файл лише коли він новий
  [ValidateSet('notepad','code','none')]
  [string]$Editor = 'notepad',

  # --- Нові опції ---
  [switch]$Archive,                    # створювати ZIP і SHA256 для тижневого файлу
  [string]$ArchiveRoot = 'C:\CHECHA_CORE\C05_ARCHIVE\Weekly',  # корінь архівів
  [switch]$RotateLogMonthly            # ротація LOG.md раз на місяць
)

# ---- UTF-8 консоль/дефолти ----
try {
  [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
  $PSDefaultParameterValues['*:Encoding'] = 'utf8'
} catch {}

function Open-File {
  param([string]$Path)
  if ($Editor -eq 'none') { return }
  if ($Editor -eq 'code') {
    $code = (Get-Command code -ErrorAction SilentlyContinue)
    if ($code) { & $code $Path; return }
  }
  notepad.exe $Path | Out-Null
}

function Ensure-Dir { param([string]$Path) if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null } }

function Get-TemplatePath { param([string]$Root) return (Join-Path $Root 'C06_FOCUS\templates\Planning.md') }

function Get-TemplateContent {
  param([string]$TemplatePath)
  if (Test-Path $TemplatePath) {
    return Get-Content -Raw -LiteralPath $TemplatePath -Encoding UTF8
  } else {
@'
# 📘 П’ятикутник планування — Інтегрований режим

---

## 🔹 Щоденний чек-лист
- **Намір:** …
- **Рівень циклу:** День
- **1–2 критичні вектори:** …
- **Стан (ресурс/дух):** 🟢 | 🟡 | 🔴
- **Слід у системі:** LOG | архів | реліз

---

## 🔹 Тижневий протокол
### 1. Головний намір
…

### 2. Рівень циклу
Тиждень (узгодження блоків, синхронізація з модулями).

### 3. 1–2 критичні вектори
- Вектор 1: …
- Вектор 2: …

### 4. Баланс стану (ресурсність / дух)
Оцінка: 🟢 | 🟡 | 🔴  
Коментар: …

### 5. Слід у системі
- Запис у LOG.md: …
- Архів (ZIP + SHA256): …
- Реліз у GitBook/GitHub: …

---

### 📌 Підсумок тижня
- Досягнення: …
- Відхилення: …
- Висновки: …
'@
  }
}

function Get-Section {
  param([string]$FullMd, [ValidateSet('Day','Week')][string]$Mode)
  if ($Mode -eq 'Day') { $pattern = '(?s)##\s*🔹\s*Щоденний чек-лист\s*(.+?)\R---' }
  else { $pattern = '(?s)##\s*🔹\s*Тижневий протокол\s*(.+)$' }
  $m = [regex]::Match($FullMd, $pattern)
  if ($m.Success) { return $m.Groups[1].Value.Trim() }
  if ($Mode -eq 'Day') {
@'
- **Намір:** …
- **Рівень циклу:** День
- **1–2 критичні вектори:** …
- **Стан (ресурс/дух):** 🟢 | 🟡 | 🔴
- **Слід у системі:** LOG | архів | реліз
'@.Trim()
  } else {
@'
### 1. Головний намір
…

### 2. Рівень циклу
Тиждень (узгодження блоків, синхронізація з модулями).

### 3. 1–2 критичні вектори
- Вектор 1: …
- Вектор 2: …

### 4. Баланс стану (ресурсність / дух)
Оцінка: 🟢 | 🟡 | 🔴  
Коментар: …

### 5. Слід у системі
- Запис у LOG.md: …
- Архів (ZIP + SHA256): …
- Реліз у GitBook/GitHub: …

### 📌 Підсумок тижня
- Досягнення: …
- Відхилення: …
- Висновки: …
'@.Trim()
  }
}

function Ensure-Utf8Log { param([string]$Path)
  if (-not (Test-Path $Path)) {
    Set-Content -LiteralPath $Path -Value "" -Encoding UTF8   # PS5.1 → з BOM
  }
}

function Write-LogLine { param([string]$ChechaRoot, [string]$Text)
  $logPath = Join-Path $ChechaRoot 'C03\LOG\LOG.md'
  Ensure-Utf8Log $logPath
  Add-Content -LiteralPath $logPath -Value $Text -Encoding UTF8
}

function Rotate-LogMonthlyIfNeeded {
  param([string]$ChechaRoot)
  if (-not $RotateLogMonthly) { return }
  $logPath = Join-Path $ChechaRoot 'C03\LOG\LOG.md'
  Ensure-Utf8Log $logPath
  $archDir = Join-Path $ChechaRoot 'C03\LOG\archive'
  Ensure-Dir $archDir
  $stamp = (Get-Date).ToString('yyyy-MM')
  $archPath = Join-Path $archDir ("LOG_{0}.md" -f $stamp)
  if (-not (Test-Path $archPath)) {
    try {
      Copy-Item -LiteralPath $logPath -Destination $archPath -Force
      Set-Content -LiteralPath $logPath -Value "" -Encoding UTF8
      Write-Host "LOG rotated -> $archPath" -ForegroundColor Yellow
    } catch {
      Write-Host "LOG rotation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
  }
}

function Get-Monday { param([datetime]$Ref)
  $delta = ($Ref.DayOfWeek.value__ + 6) % 7 # Monday=0
  return $Ref.Date.AddDays(-$delta)
}

function Zip-Weekly {
  param([string]$ChechaRoot, [string]$WeekMdPath, [datetime]$Monday)
  if (-not $Archive) { return $null }

  $yyyy = $Monday.ToString('yyyy')
  $outDir = Join-Path $ArchiveRoot $yyyy
  Ensure-Dir $outDir
  $zipName = "Strateg_Report_{0}.zip" -f $Monday.ToString('yyyy-MM-dd')
  $zipPath = Join-Path $outDir $zipName

  try {
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -LiteralPath $WeekMdPath -DestinationPath $zipPath
    $sha = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    Write-LogLine -ChechaRoot $ChechaRoot -Text ("{0} [INFO ] Week archive -> {1}; sha256={2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $zipPath, $sha)
    return $zipPath
  } catch {
    Write-LogLine -ChechaRoot $ChechaRoot -Text ("{0} [ERROR] Week archive failed: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $_.Exception.Message)
    return $null
  }
}

# ---- MAIN ----
$now   = Get-Date
$yyyy  = $now.ToString('yyyy')
$ymd   = $now.ToString('yyyy-MM-dd')
$templatePath = Get-TemplatePath -Root $ChechaRoot
$tpl = Get-TemplateContent -TemplatePath $templatePath
$section = Get-Section -FullMd $tpl -Mode $Mode

Rotate-LogMonthlyIfNeeded -ChechaRoot $ChechaRoot

if ($Mode -eq 'Day') {
  $dailyDir  = Join-Path $ChechaRoot 'C03\LOG\daily'
  Ensure-Dir $dailyDir
  $dailyPath = Join-Path $dailyDir "$ymd.md"

  $header = "# 🔑 П’ятикутник планування — День ($ymd)`r`n"
  $content = $header + $section + "`r`n"

  if (-not (Test-Path $dailyPath)) {
    Set-Content -LiteralPath $dailyPath -Value $content -Encoding UTF8
    Write-LogLine -ChechaRoot $ChechaRoot -Text ("{0} [INFO ] Start planning (Day) -> daily/{1}.md" -f ($now.ToString('yyyy-MM-dd HH:mm:ss')), $ymd)
    Open-File $dailyPath
    Write-Host "Day planning file created: $dailyPath"
  } else {
    if (-not $OpenOnlyIfNew) { Open-File $dailyPath }
    Write-Host "Day planning file already exists: $dailyPath"
  }

} else {
  $weekRoot = Join-Path $ChechaRoot "C12\Vault\StrategicReports\$yyyy"
  Ensure-Dir $weekRoot

  $monday = Get-Monday -Ref $now
  $fname  = "Strateg_Report_{0}.md" -f ($monday.ToString('yyyy-MM-dd'))
  $weekPath = Join-Path $weekRoot $fname

  $header = "# 📑 П’ятикутник планування — Тиждень (старт {0})`r`n" -f ($monday.ToString('yyyy-MM-dd'))
  $content = $header + $section + "`r`n"

  if (-not (Test-Path $weekPath)) {
    Set-Content -LiteralPath $weekPath -Value $content -Encoding UTF8
    Write-LogLine -ChechaRoot $ChechaRoot -Text ("{0} [INFO ] Start planning (Week) -> {1}" -f ($now.ToString('yyyy-MM-dd HH:mm:ss')), $weekPath)

    $zip = Zip-Weekly -ChechaRoot $ChechaRoot -WeekMdPath $weekPath -Monday $monday

    if ($Editor -ne 'none') { Open-File $weekPath }
    Write-Host "Weekly planning file created: $weekPath"
    if ($zip) { Write-Host "Weekly archive created: $zip" -ForegroundColor Green }
  } else {
    if (-not $OpenOnlyIfNew -and $Editor -ne 'none') { Open-File $weekPath }
    Write-Host "Weekly planning file already exists: $weekPath"
  }
}

Write-Host "✔ Done." -ForegroundColor Green
