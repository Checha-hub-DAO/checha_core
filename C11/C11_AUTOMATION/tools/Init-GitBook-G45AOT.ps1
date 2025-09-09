# Init-GitBook-G45AOT.ps1
[CmdletBinding()]
param(
  [string]$Root = "C:\CHECHA_CORE\GitBook\dao-g\dao-g-mods\g45-kod-zakhystu\g45-1-aot",
  [string]$Repo = "https://github.com/Checha-hub-DAO/g45-kod-zakhystu",
  [string]$PageVersion = "1.0.0",
  [string]$TzOffset = "+03:00"  # Київ
)

$null = New-Item -ItemType Directory -Path $Root -Force

$ts = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") + $TzOffset
function FrontMatter($title){
@"
---
title: "$title"
slug: "/dao-g/dao-g-mods/g45-kod-zakhystu/g45-1-aot"
module: "G45"
submodule: "G45.1"
status: "Active (pilot)"
doc_class: "Public"
page_version: "$PageVersion"
last_updated: "$ts"
canonical_repo: "$Repo"
---
"@
}

# readme.md (головна публічна)
$readme = @"
$(FrontMatter "G45.1 — AOT (Агентство Оборонних Технологій)")

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
Підготувати **NOTES/VERSION** → зібрати **ZIP** → згенерувати **SHA-256** → оновити **лог** → тег **g45-1-aot-vX.Y**.

## Посилання
Protocols · Partners · Research · KPI
"@
Set-Content -Path (Join-Path $Root "readme.md") -Value $readme -Encoding UTF8

# manifest.md
$manifest = @"
$(FrontMatter "G45.1 — AOT — MANIFEST (Public)")

## Обсяг і межі
В обсязі: координація, етика/право, R&D-огляди (Public), партнерства, релізи й архівація.  
Поза межами: інструкції зі зброї/ПЗ, ТТХ/тактики, чутливі дані.

## Ролі
Власник контенту: С.Ч.  
Ревʼюер: (вкажи)  
Публікація: (вкажи)

## Інтерфейси
G25 (право/ризики), G04 (координація), G11 (лідерство), G43 (аналітика), C12 (Vault), C11 (Automation).

## Політики безпеки
Класи даних: Public / Internal / Restricted; PoLP, журналювання, IR-SLA.
"@
Set-Content (Join-Path $Root "manifest.md") $manifest -Encoding UTF8

# panel.md
$panel = @"
$(FrontMatter "G45.1 — AOT — PANEL")

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
Set-Content (Join-Path $Root "panel.md") $panel -Encoding UTF8

# agents.md
$agents = @"
$(FrontMatter "G45.1 — AOT — AGENTS")

Перелік публічних GPT/скриптів (узагальнено):
- AOT-Guide — навігація та правила
- AOT-Panel — робота з панеллю/статусами
(без внутрішніх інструкцій і кодів)
"@
Set-Content (Join-Path $Root "agents.md") $agents -Encoding UTF8

# forms.md
$forms = @"
$(FrontMatter "G45.1 — AOT — FORMS")

Публічні форми (посилання):
- Intake (Public)
- Partners Feedback (Public)
*Чутливі поля — поза GitBook.*
"@
Set-Content (Join-Path $Root "forms.md") $forms -Encoding UTF8

# protocols.md
$protocols = @"
$(FrontMatter "G45.1 — AOT — PROTOCOLS (Public)")

**interaction:** канали, етикет, ескалації (без чутливих маршрутів).  
**security:** принципи безпеки без технічних інструкцій.  
**ir_runbook:** ролі/сигнали/вікна SLA (без тактик і TTPs).
"@
Set-Content (Join-Path $Root "protocols.md") $protocols
