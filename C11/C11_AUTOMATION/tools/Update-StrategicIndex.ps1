<#  Update-StrategicIndex.ps1
    Додає запис про стратегічний файл у C12\Vault\StrategicReports\_index.md
    Підтримує 2 макети таблиць:
      A) | Дата | Файл | SHA-256 (якщо є) |
      B) | Дата | Файл | Опис |
#>

[CmdletBinding()]
param(
  # Корінь Vault із стратегічними звітами
  [string]$VaultRoot = "C:\CHECHA_CORE\C12\Vault\StrategicReports",
  # Повний шлях до нового файлу (звіт/календар)
  [Parameter(Mandatory)]
  [string]$FilePath,
  # Необов’язково: людинозрозумілий опис (для таблиці з "Опис")
  [string]$Description = "",
  # Необов’язково: перевизначення дати (формат YYYY-MM або YYYY-MM-DD).
  # Якщо не задано — дата береться з імені файлу або з LastWriteTime.
  [string]$DateOverride
)

function Get-RelPath([string]$base, [string]$full) {
  $uriBase = New-Object System.Uri(($base.TrimEnd('\') + '\'))
  $uriFull = New-Object System.Uri($full)
  $rel = $uriBase.MakeRelativeUri($uriFull).ToString()
  return $rel -replace '%20',' '
}

function Get-StrategicDate([string]$file, [string]$override) {
  if ($override) { return $override }

  $name = [System.IO.Path]::GetFileName($file)

  # Спроба: YYYY-MM-DD
  if ($name -match '(20\d{2})[-_\.](0[1-9]|1[0-2])[-_\.]([0-3]\d)') {
    return "$($matches[1])-$($matches[2])-$($matches[3])"
  }
  # Спроба: YYYY-MM
  if ($name -match '(20\d{2})[-_\.](0[1-9]|1[0-2])') {
    return "$($matches[1])-$($matches[2])"
  }
  # Фолбек: дата змін файлу
  return (Get-Item $file).LastWriteTime.ToString('yyyy-MM-dd')
}

function Get-FileSha256([string]$path) {
  try {
    (Get-FileHash -Algorithm SHA256 -Path $path).Hash
  } catch {
    ""
  }
}

# --- Готуємо шляхи
$indexPath = Join-Path $VaultRoot "_index.md"
if (-not (Test-Path $indexPath)) {
  # Якщо індекс відсутній — створимо універсальну шапку з обома секціями
  @"
# 📚 Strategic Reports — Vault
Останнє оновлення: $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Останні звіти (SHA)
| Дата | Файл | SHA-256 (якщо є) |
|---|---|---|

## Останні матеріали
| Дата | Файл | Опис |
|---|---|---|
"@ | Set-Content -Encoding UTF8 -Path $indexPath
}

# --- Читаємо індекс
$content = Get-Content -Path $indexPath -Raw -Encoding UTF8

# Визначаємо, яку таблицю обновляти — за наявністю секцій
$hasShaTable   = $content -match '\| *Дата *\| *Файл *\| *SHA-256'
$hasDescTable  = $content -match '\| *Дата *\| *Файл *\| *Опис *\|'

# Якщо жодної — додаємо обидві
if (-not $hasShaTable -and -not $hasDescTable) {
  $content += @"

## Останні звіти (SHA)
| Дата | Файл | SHA-256 (якщо є) |
|---|---|---|

## Останні матеріали
| Дата | Файл | Опис |
|---|---|---|
"@
  $hasShaTable = $true
  $hasDescTable = $true
}

# --- Готуємо дані про файл
if (-not (Test-Path $FilePath)) {
  throw "Файл не знайдено: $FilePath"
}

$rel = Get-RelPath -base $VaultRoot -full $FilePath
$fname = [IO.Path]::GetFileName($FilePath)
$date  = Get-StrategicDate -file $FilePath -override $DateOverride
$hash  = Get-FileSha256 -path $FilePath

# Рядки для вставки
$lineSha  = "| $date | [$fname]($rel) | $hash |"
$lineDesc = "| $date | [$fname]($rel) | $Description |"

# --- Ідемпотентність: якщо запис уже є — не дублюємо
if ($content -match [regex]::Escape("[$fname]($rel)")) {
  # Оновити лише 'Останнє оновлення'
  $content = $content -replace '(Останнє оновлення:\s*)(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})', "`${1}$(Get-Date -Format 'yyyy-MM-dd HH:mm')"
  $content | Set-Content -Encoding UTF8 -Path $indexPath
  Write-Host "⚠️ В індексі вже є запис для $fname — пропущено (оновлено timestamp)."
  exit 0
}

# --- Вставка у відповідні таблиці
function Insert-IntoTable([string]$text, [string]$tableHeaderPattern, [string]$row) {
  # Вставимо рядок відразу ПІСЛЯ лінії з роздільниками |---|---|---|
  $pattern = "($tableHeaderPattern\s*\r?\n\|---\|---\|.*?\|\r?\n)"
  $regex = [regex]::new($pattern, 'Singleline')
  if ($regex.IsMatch($text)) {
    $m = $regex.Match($text)
    $insertionPoint = $m.Index + $m.Length
    return $text.Insert($insertionPoint, $row + "`r`n")
  }
  # Якщо не знайшли — додаємо секцію в кінець
  return $text + "`r`n" + $tableHeaderPattern + "`r`n|---|---|---|`r`n" + $row + "`r`n"
}

if ($hasShaTable) {
  $content = Insert-IntoTable -text $content `
    -tableHeaderPattern '## Останні звіти \(SHA\)\s*\r?\n\| Дата \| Файл \| SHA-256 \(якщо є\) \|' `
    -row $lineSha
}
if ($hasDescTable) {
  $content = Insert-IntoTable -text $content `
    -tableHeaderPattern '## Останні матеріали\s*\r?\n\| Дата \| Файл \| Опис \|' `
    -row $lineDesc
}

# Оновлюємо штамп часу
$content = $content -replace '(Останнє оновлення:\s*)(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})', "`${1}$(Get-Date -Format 'yyyy-MM-dd HH:mm')"

# Запис
$content | Set-Content -Encoding UTF8 -Path $indexPath
Write-Host "✅ Додано у _index.md: $fname"
