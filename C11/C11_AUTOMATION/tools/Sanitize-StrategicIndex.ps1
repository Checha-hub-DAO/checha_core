param(
  [string]$VaultRoot = "C:\CHECHA_CORE\C12\Vault\StrategicReports"
)

$idx   = Join-Path $VaultRoot "_index.md"
$bak   = "$idx.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $idx $bak -Force

$raw = Get-Content $idx -Raw -Encoding UTF8

# Прибрати артефактні рядки
$raw = $raw -replace '(?m)^## Останні матеріали\\s.*$', ''
$raw = $raw -replace '(?m)^## Останні матеріали\\s*\\r\?\\n\\\|{1,4}.*$', ''

# Гарантувати правильний заголовок
$headerRegex = '## Останні матеріали\s*\r?\n\| Дата \| Файл \| Опис \|\s*\r?\n\|---\|---\|---\|\s*'
if ($raw -notmatch $headerRegex) {
  $normHeader = "## Останні матеріали`r`n| Дата | Файл | Опис |`r`n|---|---|---|`r`n"
  $raw += "`r`n" + $normHeader
}

# Прибрати дубльовані розділювачі
$raw = $raw -replace '(?m)(\|---\|---\|---\|\s*){2,}','|---|---|---|`r`n'

Set-Content $idx -Value $raw -Encoding UTF8
Write-Host "✅ _index.md санітайз завершено. Бекап: $bak"
