# Scaffold-GitBook-Submodule.ps1
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)] [string]$RootPath,
  [Parameter(Mandatory=$true)] [string]$Slug,
  [Parameter(Mandatory=$true)] [string]$Title,
  [string]$Module      = "G45",
  [string]$SubmoduleId = "G45.?",
  [string]$RepoUrl     = "https://github.com/Checha-hub-DAO/g45-kod-zakhystu",
  [string]$PageVersion = "1.0.0",
  [string]$TzOffset    = "+03:00",
  [string]$TagPrefix   = "g45-?-?-vX.Y"
)
$ErrorActionPreference = "Stop"
$null = New-Item -ItemType Directory -Path $RootPath -Force

function FrontMatter($title){
  $ts = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") + $TzOffset
@"
---
title: "$title"
slug: $Slug
module: "$Module"
submodule: "$SubmoduleId"
status: "Active (pilot)"
doc_class: Public
page_version: "$PageVersion"
last_updated: "$ts"
canonical_repo: "$RepoUrl"
---
"@
}

$files = "manifest.md","readme.md","panel.md","agents.md","forms.md","protocols.md","partners.md","research.md","kpi.md","media.md"
foreach($f in $files){
  $p = Join-Path $RootPath $f
  if(-not (Test-Path $p)){ New-Item -ItemType File -Path $p -Force | Out-Null }
}

# readme.md
$readmeContent = @"
$(FrontMatter $Title)

## Місія
Етична координація «Коду Захисту» без публікації чутливих матеріалів.

## Швидкий старт
- Ознайомся з **MANIFEST**
- Онови **PANEL** (48h/7d/30d)
- Підготуй **реліз** (ZIP + NOTES + VERSION + CHECKSUMS)

## Ритми
- **Щодня:** короткий апдейт (≤10 рядків) у `PANEL`
- **Щотижня:** дайджест у `C12/Vault` + оновлення GitBook
- **Щомісяця:** рев’ю доступів (PoLP) + аудит релізів

## Релізний цикл
Підготувати **NOTES/VERSION** → зібрати **ZIP** → згенерувати **SHA-256** → оновити **лог** → тег **$TagPrefix**.

## Посилання
Protocols · Partners · Research · KPI
"@
Set-Content (Join-Path $RootPath "readme.md") $readmeContent -Encoding UTF8

# manifest.md
$manifestContent = @"
$(FrontMatter "$Title — MANIFEST (Public)")

## Обсяг і межі
В обсязі: координація, етика/право, R&D-огляди (Public), партнерства, релізи й архівація.
Поза межами: інструкції зі зброї/ПЗ, ТТХ/тактики, чутливі дані.

## Ролі
Власник контенту: (вкажи)
Ревʼюер: (вкажи)
Публікація: (вкажи)

## Інтерфейси
G25 (право/ризики), G04 (координація), G11 (лідерство), G43 (аналітика), C12 (Vault), C11 (Automation).

## Політики безпеки
Класи даних: Public / Internal / Restricted; PoLP, журналювання, IR-SLA.
"@
Set-Content (Join-Path $RootPath "manifest.md") $manifestContent -Encoding UTF8

# panel.md
$panelContent = @"
$(FrontMatter "$Title — PANEL")

### 48h
- [ ] Завдання 1 — опис
- [ ] Завдання 2 — опис

### 7d
- [ ] Завдання 1 — опис
- [ ] Завдання 2 — опис

### 30d
- [ ] Завдання 1 — опис
- [ ] Завдання 2 — опис
"@
Set-Content (Join-Path $RootPath "panel.md") $panelContent -Encoding UTF8

# agents.md
$agents = @"
$(FrontMatter "$Title — AGENTS")

Публічні GPT/скрипти (узагальнено):
- Guide — навігація та правила
- Panel — робота з панеллю/статусами
(без внутрішніх інструкцій і кодів)
"@
Set-Content (Join-Path $RootPath "agents.md") $agents -Encoding UTF8

# forms.md
$forms = @"
$(FrontMatter "$Title — FORMS")

Публічні форми (посилання):
- Intake (Public)
- Partners Feedback (Public)
*Чутливі поля — поза GitBook.*
"@
Set-Content (Join-Path $RootPath "forms.md") $forms -Encoding UTF8

# protocols.md
$protocols = @"
$(FrontMatter "$Title — PROTOCOLS (Public)")

**interaction:** канали, етикет, ескалації (без чутливих маршрутів).
**security:** принципи безпеки без технічних інструкцій.
**ir_runbook:** ролі/сигнали/вікна SLA (без тактик і TTPs).
"@
Set-Content (Join-Path $RootPath "protocols.md") $protocols -Encoding UTF8

# partners.md
$partners = @"
$(FrontMatter "$Title — PARTNERS")

| Партнер | Роль | Зона експертизи | Рівень доступу |
|---|---|---|---|
| (ім'я) | (опис ролі) | (сфера) | Public/Internal |

Outreach: one-pager (Public) + форма контакту (Google Form).
"@
Set-Content (Join-Path $RootPath "partners.md") $partners -Encoding UTF8

# research.md
$research = @"
$(FrontMatter "$Title — RESEARCH (Public)")

Огляди лише з відкритих джерел. Без ТТХ/схем/тактик.
Короткі висновки + посилання на джерела.
"@
Set-Content (Join-Path $RootPath "research.md") $research -Encoding UTF8

# kpi.md
$kpi = @"
$(FrontMatter "$Title — KPI")

- Security SLA (Public рівень)
- Ops оновлення (щотижневі)
- Partners активність (Public метрики)
(без чутливих величин)
"@
Set-Content (Join-Path $RootPath "kpi.md") $kpi -Encoding UTF8

# media.md
$media = @"
$(FrontMatter "$Title — MEDIA")

Публічні зображення/банери/схеми **без** чутливих деталей.
"@
Set-Content (Join-Path $RootPath "media.md") $media -Encoding UTF8

Write-Host "✔ Scaffold created at $RootPath"
Get-ChildItem $RootPath -Name | Sort-Object | ForEach-Object { " - $_" }