# Requires -Version 5.1
[CmdletBinding()]
param(
  [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
  [string]$Keyword = 'Цілісність',
  [switch]$NoLog
)

$panel = @"
# 🎯 Фокус-Панель — $Date

## 🔑 Ключове слово
**$Keyword** — тримати зв’язки між модулями та архітектурою, уникати повторів.

---

## 📌 Головні тригери дня
1. **G45.1 — АОТ**
   - Перевірка цілісності релізу (ZIP, CHECKSUMS, GitBook).
   - Синхронізація з іншими G-модулями.

2. **Архітектура**
   - Утримання структури CHECHA_CORE без “петлянь”.
   - Відстеження зв’язків між блоками (C01–C12 ↔ G-модулі).

3. **Автоматизація**
   - Перевірка щоденної/щотижневої/щомісячної автоматики.
   - Логування результатів у C03_LOG.

4. **Баланс**
   - 20% — технічне занурення.
   - 80% — стратегічний огляд і закріплення.

---

## 📝 Нагадування
- Фіксуй ключові дії у `C03\LOG\LOG.md`.
- Став точку завершення — не повторюй процес “по колу”.
- Після завершення — короткий звіт: *Що зроблено / Що перевірено / Що наступне*.
"@

function Write-Block([string]$title, [ConsoleColor]$color) {
  $old = $Host.UI.RawUI.ForegroundColor
  $Host.UI.RawUI.ForegroundColor = $color
  Write-Host $title
  $Host.UI.RawUI.ForegroundColor = $old
}

Clear-Host
Write-Block "🎯 Фокус-Панель — $Date" Cyan
Write-Host
Write-Block "🔑 Ключове слово: $Keyword" Yellow
Write-Host
Write-Block "📌 Головні тригери:" Green
@(
  '1) G45.1 — АОТ → ZIP/CHECKSUMS/GitBook; синхронізація з G-модулями',
  '2) Архітектура → утримання структури CHECHA_CORE; зв’язки C01–C12↔G',
  '3) Автоматизація → щоденна/щотижнева/щомісячна; лог у C03_LOG',
  '4) Баланс → 20% техніка / 80% стратегія'
) | ForEach-Object { "   • $_" } | Write-Host
Write-Host
Write-Block "📝 Нагадування:" Magenta
@(
  '— Фіксуй ключові дії у C03\LOG\LOG.md',
  '— Не повторюй процес “по колу”',
  '— Звіт: Що зроблено / Що перевірено / Що наступне'
) | ForEach-Object { "   $_" } | Write-Host
Write-Host

# Markdown-варіант (для копіювання у звіт/панель)
Write-Block '▼ Markdown версія (скопіюй за потреби):' DarkGray
$panel | Write-Host

if (-not $NoLog) {
  try {
    $logPath = 'C:\CHECHA_CORE\C03\LOG\LOG.md'
    $stamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $line = "$stamp [INFO ] FocusPanel shown for $Date; keyword=$Keyword"
    New-Item -ItemType File -Path $logPath -Force | Out-Null
    Add-Content -Path $logPath -Value $line -Encoding UTF8
  } catch { Write-Warning "LOG append failed: $($_.Exception.Message)" }
}
