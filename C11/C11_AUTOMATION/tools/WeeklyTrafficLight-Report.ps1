<#
.SYNOPSIS
  Формує Markdown-звіт за статусами "світлофора" за тиждень.

.DESCRIPTION
  Читає C03\LOG\trafficlight.json (schema=trafficlight.v1) і генерує
  стислий блок для щотижневого звіту: сесії, вчасні переходи, "червоні" входження тощо.

.PARAMETER Root
  Корінь CHECHA_CORE (default: C:\CHECHA_CORE)

.PARAMETER OutFile
  Якщо вказано — збереже Markdown у файл.

.PARAMETER Quiet
  Не друкувати у консоль (лише запис у файл/exit code).

.OUTPUTS
  Пише Markdown у stdout або у файл. Exit code: 0 ок.

.EXAMPLE
  pwsh -NoProfile -File WeeklyTrafficLight-Report.ps1
#>

[CmdletBinding()]
Param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$OutFile,
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Load-JsonSafe {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return $null }
  try { return Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch { return $null }
}

function MkLine { param([string]$s); return $s }

$logDir = Join-Path $Root 'C03\LOG'
$json   = Join-Path $logDir 'trafficlight.json'
$data   = Load-JsonSafe $json

if (-not $data) {
  $md = @()
  $md += MkLine("### Світлофор (цього тижня)")
  $md += MkLine("> Дані відсутні. Файл `trafficlight.json` не знайдено або порожній.")
  $md = $md -join "`r`n"
  if ($OutFile) { $md | Set-Content -Path $OutFile -Encoding UTF8 }
  if (-not $Quiet) { $md | Write-Output }
  exit 0
}

# Безпечні читання
$c = $data.counters
if (-not $c) {
  $data | Add-Member -NotePropertyName counters -NotePropertyValue (@{}) -Force
  $c = $data.counters
}
foreach ($k in 'sessions','ended_green','ended_yellow','ended_red','updates_green','updates_yellow','updates_red','starts_green','starts_yellow','starts_red') {
  if (-not $c.$k) { $c.$k = 0 }
}

$weekKey   = $data.week
$sessions  = [int]$c.sessions
$endedG    = [int]$c.ended_green
$endedY    = [int]$c.ended_yellow
$endedR    = [int]$c.ended_red
$warns     = [int]$c.updates_yellow
$redsUpd   = [int]$c.updates_red

# Метрики дисципліни
$onTimeSwitches   = $endedG + $endedY  # завершили <= жовтого
$lateRedEntries   = $endedR            # завершили у "червоній"
$yellowShare      = if ($sessions) { [math]::Round(100.0 * $endedY / $sessions, 1) } else { 0 }
$redShare         = if ($sessions) { [math]::Round(100.0 * $endedR / $sessions, 1) } else { 0 }

# Рекомендації
$recs = @()
if ($lateRedEntries -gt 0) {
  $recs += "• Зменшити входження у 🔴: робити перехід ще на 🟡 (30–49 повідомлень)."
}
if ($warns -gt 2) {
  $recs += "• Більше реагувати на 🟡-попередження: планувати перехід і проміжний підсумок."
}
if ($sessions -gt 0 -and $yellowShare -lt 25 -and $redShare -eq 0) {
  $recs += "• Дисципліна хороша: тримаємо більшість сесій ≤ 🟡."
}
if ($recs.Count -eq 0) {
  $recs += "• Підтримувати правило: 🟡 на 30-му, 🔴 на 50-му. Фіксувати підсумок кожної сесії."
}

# Markdown
$md = @()
$md += MkLine("### Світлофор (тиждень: $weekKey)")
$md += MkLine("")
$md += MkLine("| Показник | Значення |")
$md += MkLine("|---|---:|")
$md += MkLine("| Кількість сесій | $sessions |")
$md += MkLine("| Завершено на 🟢 | $endedG |")
$md += MkLine("| Завершено на 🟡 | $endedY |")
$md += MkLine("| Завершено на 🔴 | $endedR |")
$md += MkLine("| Частка 🟡 серед сесій | ${yellowShare}% |")
$md += MkLine("| Частка 🔴 серед сесій | ${redShare}% |")
$md += MkLine("| Попереджень 🟡 (Update) | $warns |")
$md += MkLine("| Оновлень 🔴 (Update) | $redsUpd |")
$md += MkLine("")
$md += MkLine("**Переходи вчасно** (≤ 🟡): **$onTimeSwitches** │ **Входження у 🔴**: **$lateRedEntries**")
$md += MkLine("")
$md += MkLine("**Рекомендації:**")
foreach ($r in $recs) { $md += MkLine($r) }

$mdOut = $md -join "`r`n"
if ($OutFile) { $mdOut | Set-Content -Path $OutFile -Encoding UTF8 }
if (-not $Quiet) { $mdOut | Write-Output }

exit 0
