# Install-G43-ITETA-Pack.ps1  (v1.0, ASCII-safe)
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ChechaRoot,
  [string]$Name = "G43 — Інститут Аналізу Еволюційних Трендів (ITETA)",
  [string]$Slug = "g43-iteta",
  [string]$Tag  = "g43-iteta-v1.0"
)
function W([string]$m){ $ts=Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; Write-Host "$ts $m" }
function WriteUtf8([string]$p,[string]$t,[bool]$bom=$false){ [IO.File]::WriteAllText($p,$t,[Text.UTF8Encoding]::new($bom)) }

# Layout
$GitBookRoot  = Join-Path $ChechaRoot "GitBook"
$SubPath      = "dao-g\dao-g-mods\g43-iteta\g43-iteta"
$GbDir        = Join-Path $GitBookRoot $SubPath
$ModuleDir    = Join-Path $ChechaRoot "G\G43\ITETA"
$RelRoot      = Join-Path $ChechaRoot "G\RELEASES"
$ArchiveDir   = Join-Path $RelRoot "ARCHIVE"
$CfgPath      = Join-Path $ChechaRoot "C11\C11_AUTOMATION\configs\g43-iteta.json"
$SyncPath     = Join-Path $ModuleDir "SYNC.md"

# Ensure dirs
$null=New-Item -ItemType Directory -Force -Path $GbDir,$ModuleDir,$RelRoot,$ArchiveDir

# ---------- CONTENT (built from your doc) ----------
$readme = @"
slug: $Slug
# $Name

**Місія.** Дослідження еволюційних трендів у трьох вимірах — Всесвіт, Людина, ШІ — для виявлення ризиків, можливостей і формування стратегій співбуття.

## Опис
ITETA — стратегічний дослідницький модуль DAO-GOGS: космологія та фізика (Всесвіт), біологія/психіка/соціум (Людина), технології та етика (ШІ). Мета — цілісне бачення взаємодії сфер для прогнозів і сценаріїв.  

### Завдання
- Дослідження трендів у Всесвіті, Людині, ШІ.  
- Аналіз ризиків дисбалансу та пошук синергії.  
- Формування прогнозів і сценаріїв майбутнього.  
- Інтеграція знань у DAO-модулі та інструменти.

### Структура
- **Секція I — Всесвіт**
- **Секція II — Людина**
- **Секція III — ШІ**
- **Крос-група** (синтез трьох секцій)
- **Аналітична платформа** (БД, моделі, дашборди)
- **Публікаційний блок** (дайджести, звіти, статті)

### Зв’язки
G11 (Свідоме лідерство), G20 (DAO-Освіта), G30 (Технології DAO), G37 (Аудит порогу), G44 (R&D), G35 (Медіа-контур).

## Дорожня карта (скорочено)
**2025:** запуск секцій і крос-групи; перший “Еволюційний дайджест”.  
**2026:** інтеграція в освіту DAO; 50+ прогнозів і сценаріїв.  
**2027–2030:** глобальний аналітичний хаб DAO-GOGS.

## Навігація
- [Карта зв’язків](./map.md)
- [Агенти та ролі](./agents.md)
- [NFR — нефункціональні вимоги](./nfr.md)
- [Журнал досліджень](./research-journal.md)
- [Quarterly Report (шаблон)](./quarterly-report.md)
- [Annual Report (шаблон)](./annual-report.md)

© DAO-GOGS | $Name
"@

$manifest = @"
slug: $Slug
version: $Tag
title: $Name
"@

$map = @"
# G43 ITETA — Map

## Карта зв’язків
- **G11 — Свідоме Лідерство** → аналітика для лідерів.  
- **G17/G20 — DAO-Освіта** → інтеграція результатів у програми.  
- **G25 — Безпека і Право** → правові ризики технологій.  
- **G30 — Технології DAO** → прогноз DAO-інструментів.  
- **G35 — Медіа-Контур** → трансляція результатів.  
- **G44 — R&D** → тестування ідей / валідація прогнозів.

## Дослідницькі секції
- Еволюція **Всесвіту** | **Людини** | **ШІ**  
- **Крос-група** → синтез і сценарії.
"@

$agents = @"
# G43 ITETA — Agents & Roles

## GPT-Агенти
- **Trend-GPT** — збір/аналіз трендів.  
- **Scenario-GPT** — моделювання сценаріїв, аналіз ризиків.  
- **Synth-GPT** — інтеграція результатів трьох секцій.

## Ролі людей
- **Дослідник** — збір даних.  
- **Аналітик** — інтерпретація трендів.  
- **Стратег** — перетворення в практичні рішення.
"@

$nfr = @"
# NFR — G43 ITETA

## Призначення
Етичний, організаційний та якісний каркас дослідницької діяльності ITETA.

## Принципи
- Наукова обґрунтованість, системність, прозорість, етичність, міждисциплінарність.

## Безпека
- Захист чутливої інформації; контроль доступу; аудит джерел.

## Якість
- Стандартизовані формати звітів; peer-review; оцінка впливу.

## Соціальний вплив
- Підвищення свідомості; сценарії з фокусом на безпеку людини і гармонію з природою.

## Критерії відповідності
- Внутрішній peer-review; публікація в GitBook; синхронізація з BTD.
"@

$journal = @"
# Журнал Досліджень — G43 ITETA

## Формат запису
- **ID:** ITETA-EXP-YYYY-XX  
- **Назва:** коротко  
- **Секція:** Всесвіт / Людина / ШІ / Крос-група  
- **Гіпотеза, Методологія, Дані, Результати, Вплив, Статус, Відповідальні**

## Приклад
- **ID:** ITETA-EXP-2025-01  
- **Назва:** Взаємозв’язок між темпом розвитку ШІ та суспільними кризами  
- **Секція:** ШІ  
- **Методологія:** аналітичний огляд + моделювання; **Дані:** 2010–2025  
- **Статус:** Виконується
"@

$qtr = @"
# Quarterly Report — G43 ITETA

**Період:** QX YYYY | **Відповідальні:** Аналітики ITETA

## Огляд діяльності
- Запущено / Завершено / Основні теми

## Ключові результати
- Всесвіт / Людина / ШІ / Крос-група

## Аналіз ризиків
- Ризики, вплив, рекомендації

## Рекомендації на наступний квартал
- Пріоритети, співпраці, нові методології
"@

$annual = @"
# Annual Report — G43 ITETA

**Рік:** YYYY | **Відповідальні:** Аналітики ITETA, Етичний модератор

## Огляд року
- Загальна кількість досліджень, завершені проекти, ключові відкриття, суспільний вплив

## Ключові результати
- Всесвіт / Людина / ШІ / Крос-група

## Ризики та виклики
- Глобальні ризики, критичні виклики, заходи

## Стратегія на наступний рік
- Пріоритети, інтеграція в DAO-модулі, партнерства
"@
# ---------- /CONTENT ----------

# Write files (UTF-8 no BOM; LF by default)
W "Writing GitBook pages to $GbDir"
WriteUtf8 (Join-Path $GbDir "readme.md")           $readme
WriteUtf8 (Join-Path $GbDir "manifest.md")         $manifest
WriteUtf8 (Join-Path $GbDir "map.md")              $map
WriteUtf8 (Join-Path $GbDir "agents.md")           $agents
WriteUtf8 (Join-Path $GbDir "nfr.md")              $nfr
WriteUtf8 (Join-Path $GbDir "research-journal.md") $journal
WriteUtf8 (Join-Path $GbDir "quarterly-report.md") $qtr
WriteUtf8 (Join-Path $GbDir "annual-report.md")    $annual

# Build local release (ZIP + CHECKSUMS)
$dateTag = Get-Date -Format 'yyyy-MM-dd'
$zipName = "$Slug" + "_$dateTag" + "_build.zip"
$zipPath = Join-Path $RelRoot $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
W "Compress -> $zipPath"
Compress-Archive -Path (Join-Path $GbDir "*") -DestinationPath $zipPath
$sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToUpper()
$chk = Join-Path $RelRoot "CHECKSUMS.txt"
"$sha  $zipName" | Set-Content -LiteralPath $chk -Encoding ascii
Copy-Item $zipPath,$chk -Destination $ArchiveDir -Force

# SYNC.md (UTF-8 BOM)
$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$src = "Local Releases ($ArchiveDir)"
$bt = [char]0x60
$sync = @"
# Sync Map — $Name

Оновлено: $ts

## Артефакти релізу
- Тег: $bt$Tag$bt
- ZIP: $bt$zipName$bt
- SHA-256: $bt$sha$bt
- Джерело: $src

---
> Автоматично оновлено **Install-G43-ITETA-Pack.ps1** для $bt$Name$bt.
"@
WriteUtf8 $SyncPath $sync $true

# Runner config (LOCAL mode)
$cfg = @{
  Name             = $Name
  Repo             = "(local)"
  Tag              = $Tag
  ZipName          = $zipName
  ModuleDir        = $ModuleDir
  GitBookRepoRoot  = $GitBookRoot
  GitBookSubPath   = $SubPath
  ExpectedSlug     = $Slug
  GitCommitMessage = "$Slug: verify + sync + publish"
  LocalReleasesDir = $ArchiveDir
}
$cfg | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $CfgPath -Encoding utf8

# Optional: commit GitBook superrepo
try{
  Push-Location $GitBookRoot
  git add -A | Out-Null
  git commit -m "$Slug: pages created/normalized" | Out-Null
  git push | Out-Null
  Pop-Location
  W "GitBook commit/push OK"
}catch{ W ("WARN: GitBook commit skipped: " + $_.Exception.Message) }

W "DONE: G43 ITETA installed. Config: $CfgPath"
W "Next: run verify/publish locally with Run-VerifySync-WithConfig.ps1"
