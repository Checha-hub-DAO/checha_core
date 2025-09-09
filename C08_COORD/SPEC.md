# C08_COORD — Специфікація та міграція (v2.1)
**Дата:** 2025‑09‑09 · **Власник:** С.Ч. · **Консультант:** GPT‑5 Thinking  
**Статус:** затверджено як заміна C08_INIT_MAP. INIT_MAP стає підсистемою всередині C08_COORD.

---

## 1) Призначення C08_COORD
C08 — це **координація осередків/ініціатив** на мета‑рівні ядра: реєстр без PII, політики доступу, агрегації, карти (k‑анонімні), публічні снапшоти. Увесь виконуваний код — у **C11_AUTOMATION**.

---

## 2) Еталонна структура
```
C08_COORD\
│  README.md
│  MANIFEST.yaml                         ← версія, власник, політики
├─POLICY\                                 ← політики доступу та публікації
│  ├─ACCESS_POLICY.md
│  ├─MAP_POLICY.md
│  └─PUBLISH_DELAY.md
├─TEMPLATES\
│  ├─CELL_PASSPORT.md
│  ├─REGION_TEMPLATE.md
│  ├─CITY_TEMPLATE.md
│  └─OPS_PLAYBOOK.md
├─REGISTRY\                                ← реєстр осередків (без PII)
│  └─regions\<region>\cities\<city>\cells\<CELL-ID>\CELL_PASSPORT.md
├─OPS\
│  └─PLAYBOOKS\
├─RISK\
│  └─indicators.md
└─INIT_MAP\                                 ← підсистема карт/агрегатів
   ├─REPORTS\                               ← .csv/.json агрегати/heatmap
   ├─PILOT\ODESA\
   └─manifests\INITMAP-RELEASE.yaml
```
> **REGISTRY** містить лише не‑чутливі дані; жодних імен, контактів, адрес або точних координат.

---

## 3) Контракти між блоками
- **C08_COORD → C07_ANALYTICS:** `INIT_MAP/REPORTS/*` підхоплюються у звіти/дашборди.
- **C08_COORD → C05_ARCHIVE:** релізи `RELEASES/INITMAP/vX.Y/*.zip + CHECKSUMS.txt`.
- **C08_COORD ↔ C02_GLOSSARY:** терміни `CELL-ID`, `k‑анонімність`, ролі `Owner/Editor/Viewer`.
- **C11_AUTOMATION:** усі скрипти з запуску валід/агрегацій/релізів зберігаються у `tools/initmap`.

---

## 4) Міграція з C08_INIT_MAP → C08_COORD
### 4.1 Команди (PowerShell 7+)
```powershell
$root = 'C:\\CHECHA_CORE'
$old  = Join-Path $root 'C08_INIT_MAP'
$new  = Join-Path $root 'C08_COORD'

# 1) Перейменування каталогу
if (Test-Path $old) { Rename-Item -Path $old -NewName 'C08_COORD' }

# 2) Створити підкаталоги, якщо відсутні
$dirs = @('POLICY','TEMPLATES','REGISTRY','OPS/PLAYBOOKS','RISK','INIT_MAP/REPORTS','INIT_MAP/PILOT/ODESA','INIT_MAP/manifests')
foreach($d in $dirs){ $p = Join-Path $new $d; if(-not (Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

# 3) Оновити посилання у файлах (обережно)
Get-ChildItem -Path $root -Recurse -File -Include *.md,*.ps1,*.yaml,*.yml |
  ForEach-Object {
    $t = Get-Content $_.FullName -Raw -Encoding UTF8
    $u = $t -replace 'C08_INIT_MAP','C08_COORD'
    if ($u -ne $t) {
      [System.IO.File]::WriteAllText($_.FullName, $u, [System.Text.UTF8Encoding]::new($false))
      Write-Host "upd  $($_.FullName)"
    }
  }
```

### 4.2 Патч до `Initialize-Core-Tree.ps1`
```diff
- 'C08_INIT_MAP',
- 'C08_INIT_MAP/REGISTRY',
- 'C08_INIT_MAP/TEMPLATES',
- 'C08_INIT_MAP/POLICY',
- 'C08_INIT_MAP/OPS/PLAYBOOKS',
- 'C08_INIT_MAP/PILOT/ODESA',
- 'C08_INIT_MAP/REPORTS',
- 'C08_INIT_MAP/manifests',
- 'C08_INIT_MAP/tools',
+ 'C08_COORD',
+ 'C08_COORD/REGISTRY',
+ 'C08_COORD/TEMPLATES',
+ 'C08_COORD/POLICY',
+ 'C08_COORD/OPS/PLAYBOOKS',
+ 'C08_COORD/RISK',
+ 'C08_COORD/INIT_MAP/PILOT/ODESA',
+ 'C08_COORD/INIT_MAP/REPORTS',
+ 'C08_COORD/INIT_MAP/manifests',
```
А також замінити створення `C08_*README*` → `C08_COORD/README.md` з коротким описом.

---

## 5) Скрипти та планувальник (у C11_AUTOMATION)
### 5.1 Розміщення скриптів
```
C11_AUTOMATION\tools\initmap\
  Validate-InitMap.ps1
  Anonymize-Cells.ps1
  Build-Heatmap.ps1
  Publish-InitMapSnapshot.ps1
  Run-CoordWeekly.ps1          ← обгортка-ланцюжок
```
**Run-CoordWeekly.ps1 (еталон):**
```powershell
Param([string]$Root='C:\\CHECHA_CORE',[int]$K=5,[string]$Version='v2.1')
$tools = Join-Path $Root 'C11_AUTOMATION/tools/initmap'
$log = Join-Path $Root 'C03_LOG/initmap.log'
$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Add-Content -Path $log -Encoding UTF8 -Value "$ts [INFO ] Run-CoordWeekly begin"
& pwsh -NoProfile -File (Join-Path $tools 'Validate-InitMap.ps1') -Root $Root
& pwsh -NoProfile -File (Join-Path $tools 'Anonymize-Cells.ps1') -Root $Root
& pwsh -NoProfile -File (Join-Path $tools 'Build-Heatmap.ps1') -Root $Root -K $K
& pwsh -NoProfile -File (Join-Path $tools 'Publish-InitMapSnapshot.ps1') -Root $Root -Version $Version
Add-Content -Path $log -Encoding UTF8 -Value ("{0} [INFO ] Run-CoordWeekly done" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
```

### 5.2 Канонічні назви задач (Task Scheduler)
```
\Checha\Coord-Weekly     → нд 18:05: Run-CoordWeekly.ps1
\Checha\Coord-DailyAudit → щодня 02:15: Validate-InitMap.ps1 (тільки перевірка)
```
**Реєстрація (приклад):**
```powershell
$ps = 'C:\\Program Files\\PowerShell\\7\\pwsh.exe'
$root='C:\\CHECHA_CORE'
$act = "-NoProfile -ExecutionPolicy Bypass -File `"$root\\C11\\C11_AUTOMATION\\tools\\initmap\\Run-CoordWeekly.ps1`" -Root `"$root`" -K 5 -Version v2.1"
SCHTASKS /Create /TN "\Checha\Coord-Weekly" /TR "`"$ps`" $act" /SC WEEKLY /D SUN /ST 18:05 /RL HIGHEST /F
```

---

## 6) README для `C08_COORD/README.md` (шаблон)
```md
# C08_COORD — Координація осередків (мета‑рівень)
Містить REGISTRY (без PII), POLICY, TEMPLATES, OPS/PLAYBOOKS, RISK та підсистему INIT_MAP із агрегованими звітами/тепловими картами.
Виконувані скрипти — у C11_AUTOMATION/tools/initmap.

## Швидкий запуск (через C11)
1) Validate → 2) Anonymize → 3) Heatmap (k≥5) → 4) Publish
```

---

## 7) Definition of Done
- [ ] Папка `C08_COORD` існує з повною структурою, `REGISTRY` без PII.
- [ ] Усі згадки `C08_INIT_MAP` у репо замінено на `C08_COORD`.
- [ ] Скрипти перенесені у `C11_AUTOMATION/tools/initmap`, працює `Run-CoordWeekly.ps1`.
- [ ] Планувальник містить `\Checha\Coord-Weekly` (нд 18:05) і, за потреби, `Coord-DailyAudit`.
- [ ] Снапшоти INIT_MAP у `C05_ARCHIVE/RELEASES/INITMAP/<version>` із `CHECKSUMS.txt`.
```

