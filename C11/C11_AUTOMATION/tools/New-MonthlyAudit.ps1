<#
.SYNOPSIS
  Генерує Matrix Audit Report + будує матрицю архітектури (CSV і Markdown)
  з MODULE_INDEX.md та manifest.md модулів/підмодулів. Підтримує OWNERS.csv і
  виділяє модулі без Owner у звіті.

.DESCRIPTION
  1) Парсить C12\KNOWLEDGE_VAULT\MODULE_INDEX.md (таблиці модулів і підмодулів).
  2) Для кожного GXX / GXX.YY читає manifest.md (якщо є) і витягує:
     Код, Статус, Версія, Останнє оновлення, Прив’язки/Links, Підмодулі.
  3) Порівнює з MODULE_INDEX.md (Status/Version) → формує Audit Report.
  4) Створює матрицю архітектури:
     - CSV (для фільтрів / табличної обробки)
     - Markdown (для оглядових звітів і Git-рев’ю)
  5) Підтягує Owner з C12\KNOWLEDGE_VAULT\OWNERS.csv (якщо існує).
  6) Додає у звіт секцію “❗ Модулі без Owner”.

.PARAMETER Root
  Корінь CHECHA_CORE (default: C:\CHECHA_CORE)

.PARAMETER OutFile
  Куди зберегти Audit Report (Markdown). Якщо не вказано — друк у stdout.

.PARAMETER CsvOut
  Куди зберегти матрицю архітектури (CSV). Якщо не вказано — не створюється.

.PARAMETER MdMatrixOut
  Куди зберегти матрицю архітектури (Markdown). Якщо не вказано — не створюється.

.PARAMETER OwnersCsv
  Кастомний шлях до OWNERS.csv. Якщо не задано — використовується:
  $Root\C12\KNOWLEDGE_VAULT\OWNERS.csv

.OUTPUTS
  - Audit Report: Markdown (stdout або файл)
  - Матриця: CSV / Markdown (за параметрами)
  ExitCode: 1 — якщо знайдено критичні розбіжності (версія/статус/відсутній manifest), інакше 0.
#>

[CmdletBinding()]
Param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$OutFile,
  [string]$CsvOut,
  [string]$MdMatrixOut,
  [string]$OwnersCsv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------- helpers ----------
function Read-AllTextUtf8([string]$path) {
  if (-not (Test-Path $path)) { return $null }
  return Get-Content -Raw -Encoding UTF8 -Path $path
}

function Parse-TableMarkdown {
  # Примітивний парсер Markdown-таблиць
  param([string]$md)
  $lines = $md -split "`r?`n"
  $tables = @()
  $curr = @()
  foreach ($ln in $lines) {
    if ($ln.Trim().StartsWith('|')) { $curr += ,$ln }
    elseif ($curr.Count -gt 0) { $tables += ,@($curr); $curr=@() }
  }
  if ($curr.Count -gt 0) { $tables += ,@($curr) }

  $rows = @()
  foreach ($tbl in $tables) {
    if ($tbl.Count -lt 3) { continue }
    $hdr = ($tbl[0].Trim('|') -split '\|').ForEach({ $_.Trim() })
    for ($i=2; $i -lt $tbl.Count; $i++) {
      $cols = ($tbl[$i].Trim('|') -split '\|').ForEach({ $_.Trim() })
      if ($cols.Count -ne $hdr.Count) { continue }
      $obj = @{}
      for ($c=0; $c -lt $hdr.Count; $c++) { $obj[$hdr[$c]] = $cols[$c] }
      $rows += ,[pscustomobject]$obj
    }
  }
  return ,$rows
}

function Parse-Manifest {
  param([string]$text, [string]$code)
  if (-not $text) { return $null }
  $get = {
    param($pattern,$text)
    $m = [regex]::Match($text, $pattern, 'IgnoreCase, Multiline')
    if ($m.Success) { return ($m.Groups[1].Value ?? $m.Groups[2].Value).Trim() } else { return $null }
  }
  $status = & $get '^\*\*Статус:\*\*\s*([^\r\n]+)' $text
  $ver    = & $get '^\*\*Версія:\*\*\s*([^\r\n]+)' $text
  $upd    = & $get '^\*\*Останн(є|е)\s+оновлення:\*\*\s*([^\r\n]+)' $text
  $links  = & $get '^\*\*(Прив[’'']?язки|Зв[’'']?язки|Links):\*\*\s*([^\r\n]+)' $text
  $subs   = & $get '^\*\*Підмодулі:\*\*\s*([^\r\n]+)' $text

  [pscustomobject]@{
    Code=$code; Status=$status; Version=$ver; LastUpdate=$upd; Links=$links; Submodules=$subs
  }
}

function Normalize-Status([string]$s) {
  switch -Regex ($s) {
    '^\s*core\s*$'     { 'Core'; break }
    '^\s*active\s*$'   { 'Active'; break }
    '^\s*draft\s*$'    { 'Draft'; break }
    '^\s*archived?\s*$'{ 'Archived'; break }
    default { $s }
  }
}
function Status-ToMaturity([string]$s) {
  switch (Normalize-Status $s) {
    'Core'     { 3 }
    'Active'   { 2 }
    'Draft'    { 1 }
    'Archived' { 0 }
    default    { 0 }
  }
}

# ---------- OWNERS ----------
if (-not $OwnersCsv) {
  $OwnersCsv = Join-Path $Root "C12\KNOWLEDGE_VAULT\OWNERS.csv"
}
$ownersMap=@{}
if (Test-Path $OwnersCsv) {
  foreach ($o in (Import-Csv -Path $OwnersCsv)) {
    if ($o.Code) { $ownersMap[$o.Code] = $o.Owner }
  }
}

# ---------- load MODULE_INDEX ----------
$moduleIndexPath = Join-Path $Root "C12\KNOWLEDGE_VAULT\MODULE_INDEX.md"
$indexText = Read-AllTextUtf8 $moduleIndexPath
if (-not $indexText) { throw "Не знайдено MODULE_INDEX.md: $moduleIndexPath" }

$rows = Parse-TableMarkdown -md $indexText

# Спробуємо виявити таблицю модулів (рядки, де Код схожий на GNN)
$modules = $rows | Where-Object {
  $_.PSObject.Properties.Name -contains 'Код' -and
  $_.PSObject.Properties.Name -contains 'Назва' -and
  $_.PSObject.Properties.Name -contains 'Статус' -and
  $_.Код -match '^G\d{2}$'
}

# Таблиця підмодулів (Код як GNN.MM)
$submods = $rows | Where-Object {
  $_.PSObject.Properties.Name -contains 'Код' -and
  $_.PSObject.Properties.Name -contains 'Батьківський' -and
  $_.Код -match '^G\d{2}\.\d+'
}

# Додаткові можливі колонки (Layer/Priority/Зв’язки/Версія)
$hasLayerCol    = $modules | Where-Object { $_.PSObject.Properties.Name -contains 'Layer' } | Select-Object -First 1
$hasPriorityCol = $modules | Where-Object { $_.PSObject.Properties.Name -contains 'Priority' } | Select-Object -First 1
$hasLinksCol    = $modules | Where-Object { $_.PSObject.Properties.Name -contains 'Зв’язки' -or $_.PSObject.Properties.Name -contains 'Зв'\''язки' } | Select-Object -First 1

# ---------- scan manifests ----------
$manifestData = @{}
foreach ($m in $modules) {
  $code = $m.Код
  $dir = Join-Path $Root ("G\" + $code)
  $mf  = Join-Path $dir "manifest.md"
  $txt = Read-AllTextUtf8 $mf
  $manifestData[$code] = Parse-Manifest -text $txt -code $code
}
foreach ($s in $submods) {
  $code = $s.Код
  $mod  = ($code -split '\.')[0]
  $parentDir = Join-Path $Root ("G\" + $mod)
  $cand = Get-ChildItem -Path $parentDir -Recurse -Depth 3 -Filter "manifest.md" -ErrorAction SilentlyContinue | Where-Object {
    $_.FullName -match [regex]::Escape(($code -split '\.')[1])
  } | Select-Object -First 1
  $txt = $null; if ($cand) { $txt = Read-AllTextUtf8 $cand.FullName }
  $manifestData[$code] = Parse-Manifest -text $txt -code $code
}

# ---------- compare for audit ----------
$diffs = @()
function Add-Diff($code,$field,$indexVal,$mfVal) {
  $diffs += [pscustomobject]@{ Code=$code; Field=$field; Index=$indexVal; Manifest=$mfVal }
}

foreach ($m in $modules) {
  $code = $m.Код
  $idxStatus = Normalize-Status $m.Статус
  $idxVer    = $m.Версія
  $mf = $manifestData[$code]
  if (-not $mf) { Add-Diff $code 'Manifest' '—' 'відсутній'; continue }
  if ($mf.Status) { if ((Normalize-Status $mf.Status) -ne $idxStatus) { Add-Diff $code 'Статус' $idxStatus $mf.Status } }
  else { Add-Diff $code 'Статус' $idxStatus '—' }
  if ($mf.Version) { if ($mf.Version -ne $idxVer) { Add-Diff $code 'Версія' $idxVer $mf.Version } }
  else { Add-Diff $code 'Версія' $idxVer '—' }
  if (-not $mf.LastUpdate) { Add-Diff $code 'Останнє оновлення' '—' '—' }
}
foreach ($s in $submods) {
  $code = $s.Код
  $idxStatus = Normalize-Status $s.Статус
  $idxVer    = $s.Версія
  $mf = $manifestData[$code]
  if (-not $mf) { Add-Diff $code 'Manifest' '—' 'відсутній'; continue }
  if ($mf.Status) { if ((Normalize-Status $mf.Status) -ne $idxStatus) { Add-Diff $code 'Статус' $idxStatus $mf.Status } }
  else { Add-Diff $code 'Статус' $idxStatus '—' }
  if ($mf.Version) { if ($mf.Version -ne $idxVer) { Add-Diff $code 'Версія' $idxVer $mf.Version } }
  else { Add-Diff $code 'Версія' $idxVer '—' }
  if (-not $mf.LastUpdate) { Add-Diff $code 'Останнє оновлення' '—' '—' }
}

# ---------- score ----------
$score = @{ Core=0; Active=0; Draft=0; Archived=0; Missing=0 }
foreach ($m in $modules) {
  $st = Normalize-Status $m.Статус
  if ($st -match 'Core|Active|Draft|Archived') { $score[$st]++ } else { $score.Missing++ }
}
foreach ($s in $submods) {
  $st = Normalize-Status $s.Статус
  if ($st -match 'Core|Active|Draft|Archived') { $score[$st]++ } else { $score.Missing++ }
}

# ---------- build architecture matrix rows ----------
$matrix = @()

# МАП колонки з INDEX для зручності
$modules | ForEach-Object {
  $code = $_.Код
  $name = $_.Назва
  $statusIdx = Normalize-Status $_.Статус
  $versionIdx= $_.Версія
  $layer  = if ($_.PSObject.Properties.Name -contains 'Layer') { $_.Layer } else { '' }
  $prio   = if ($_.PSObject.Properties.Name -contains 'Priority') { $_.Priority } else { '' }
  $linksIdx = if ($_.PSObject.Properties.Name -contains 'Зв’язки') { $_.'Зв’язки' } elseif ($_.PSObject.Properties.Name -contains 'Зв''язки') { $_."Зв'язки" } else { '' }

  $mf = $manifestData[$code]
  $status = if ($mf.Status) { Normalize-Status $mf.Status } else { $statusIdx }
  $version= if ($mf.Version) { $mf.Version } else { $versionIdx }
  $last   = if ($mf.LastUpdate) { $mf.LastUpdate } else { '' }
  $links  = if ($mf.Links) { $mf.Links } elseif ($linksIdx) { $linksIdx } else { '' }
  $owner  = if ($ownersMap.ContainsKey($code)) { $ownersMap[$code] } else { '' }

  $matrix += [pscustomobject]@{
    Code=$code
    Name=$name
    Layer=$layer
    Status=$status
    Version=$version
    Parent='—'
    Links=$links
    Owner=$owner
    Priority=$prio
    'Maturity(0-3)'=(Status-ToMaturity $status)
    LastUpdate=$last
  }
}

$submods | ForEach-Object {
  $code = $_.Код
  $name = $_.Назва
  $parent = $_.Батьківський
  $statusIdx = Normalize-Status $_.Статус
  $versionIdx= $_.Версія

  $mf = $manifestData[$code]
  $status = if ($mf.Status) { Normalize-Status $mf.Status } else { $statusIdx }
  $version= if ($mf.Version) { $mf.Version } else { $versionIdx }
  $last   = if ($mf.LastUpdate) { $mf.LastUpdate } else { '' }
  $links  = if ($mf.Links) { $mf.Links } else { '' }
  $owner  = if ($ownersMap.ContainsKey($code)) { $ownersMap[$code] } else { '' }

  $matrix += [pscustomobject]@{
    Code=$code
    Name=$name
    Layer=''
    Status=$status
    Version=$version
    Parent=$parent
    Links=$links
    Owner=$owner
    Priority=''
    'Maturity(0-3)'=(Status-ToMaturity $status)
    LastUpdate=$last
  }
}

# --- MISSING OWNERS CHECK ---
$missingOwners = $matrix | Where-Object { -not $_.Owner -or [string]::IsNullOrWhiteSpace($_.Owner) }
$missingOwnersCount = $missingOwners.Count

# ---------- render audit markdown ----------
$today = (Get-Date).ToString('yyyy-MM-dd')
$md = @()
$md += "# 📑 Matrix Audit Report — $today"
$md += ""
$md += "> Автоматичний аудит архітектури DAO-GOGS на основі MODULE_INDEX.md + manifest.md."
$md += ""
$md += "## 🧭 Підсумки станів"
$md += ""
$md += "| Статус | К-сть |"
$md += "|---|---:|"
$md += "| Core | {0} |" -f $score.Core
$md += "| Active | {0} |" -f $score.Active
$md += "| Draft | {0} |" -f $score.Draft
$md += "| Archived | {0} |" -f $score.Archived
if ($score.Missing -gt 0) { $md += "| Невідомо | {0} |" -f $score.Missing }
$md += ""
$md += "## ⚠️ Розбіжності MODULE_INDEX ↔ manifest"
if ($diffs.Count -eq 0) {
  $md += ""
  $md += "Розбіжностей не виявлено."
} else {
  $md += ""
  $md += "| Код | Поле | MODULE_INDEX | manifest.md |"
  $md += "|---|---|---|---|"
  foreach ($d in $diffs) {
    $md += "| {0} | {1} | {2} | {3} |" -f $d.Code, $d.Field, ($d.Index ?? '—'), ($d.Manifest ?? '—')
  }
}

# --- Missing Owners section ---
$md += ""
$md += "## ❗ Модулі без Owner"
if ($missingOwnersCount -eq 0) {
  $md += "Немає."
} else {
  $md += ""
  $md += "<span style='color:#b00020'><strong>Відсутній Owner у $missingOwnersCount модул(і/ях):</strong></span>"
  $md += ""
  $md += "| Code | Name | Status | Priority | Last Update |"
  $md += "|---|---|---|---|---|"
  foreach ($row in $missingOwners | Sort-Object Code) {
    $md += ("| {0} | {1} | {2} | {3} | {4} |" -f `
      $row.Code, $row.Name, $row.Status, ($row.Priority ?? ''), ($row.LastUpdate ?? ''))
  }
}

$md += ""
$md += "## 🎯 Рекомендації"
$recs = @()

# Пріоритетним — питання Owner, якщо є відсутні
if ($missingOwnersCount -gt 0) {
  $recs += "<span style='color:#b00020'>• Призначити <strong>власників</strong> для модулів без Owner (див. секцію вище).</span>"
}

if ($diffs | Where-Object { $_.Field -eq 'Версія' })       { $recs += "• Вирівняти **Версії** (джерело істини — manifest.md)." }
if ($diffs | Where-Object { $_.Field -eq 'Статус' })       { $recs += "• Синхронізувати **Статуси** Draft/Active/Core/Archived." }
if ($diffs | Where-Object { $_.Field -eq 'Manifest' -or $_.Field -eq 'Останнє оновлення' }) { $recs += "• Створити відсутні manifest.md та додати **Останнє оновлення**." }
if ($recs.Count -eq 0) { $recs += "• Узгоджено. Переходимо до глибокого наповнення (зв’язки, агенти, сценарії)." }

foreach ($r in $recs) { $md += $r }

$mdOut = ($md -join "`r`n")

if ($OutFile) {
  New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null
  $mdOut | Set-Content -Path $OutFile -Encoding UTF8
} else {
  $mdOut | Write-Output
}

# ---------- write CSV matrix ----------
if ($CsvOut) {
  New-Item -ItemType Directory -Force -Path (Split-Path $CsvOut) | Out-Null
  $matrix | Export-Csv -Path $CsvOut -Encoding UTF8 -NoTypeInformation
}

# ---------- write Markdown matrix ----------
if ($MdMatrixOut) {
  New-Item -ItemType Directory -Force -Path (Split-Path $MdMatrixOut) | Out-Null
  $m = @()
  $m += "# 🧭 Матриця архітектури DAO-GOGS"
  $m += ""
  $m += "| Code | Name | Layer | Status | Version | Parent | Links | Owner | Priority | Maturity | Last Update |"
  $m += "|---|---|---|---|---|---|---|---|---|---:|---|"
  foreach ($row in $matrix | Sort-Object Code) {
    $m += ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} |" -f `
      $row.Code, $row.Name, ($row.Layer ?? ''), $row.Status, $row.Version, `
      ($row.Parent ?? '—'), ($row.Links ?? ''), ($row.Owner ?? ''), ($row.Priority ?? ''), `
      $row.'Maturity(0-3)', ($row.LastUpdate ?? ''))
  }
  ($m -join "`r`n") | Set-Content -Path $MdMatrixOut -Encoding UTF8
}

# Exit code
$crit = $diffs | Where-Object { $_.Field -in @('Версія','Статус','Manifest') }
if ($crit.Count -gt 0) { exit 1 } else { exit 0 }
