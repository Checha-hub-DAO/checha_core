param(
    [Parameter(Mandatory=$true)][string]$BlockName,
    [Parameter(Mandatory=$true)][string]$Tag,
    [string]$ZipName
)

$today = Get-Date -Format 'yyyy-MM-dd'
if (-not $ZipName) {
    $ZipName = "{0}_{1}.zip" -f $BlockName, $Tag
}

$readmePath = "README_{0}.md" -f $Tag
$tpl = @"
# Реліз $BlockName $Tag

## 📌 Загальне
- Назва: $BlockName
- Версія: $Tag
- Дата релізу: $today
- ZIP: $ZipName

## 📂 Вміст
1. Основний пакет (`$ZipName`)
2. CHECKSUMS.txt
3. Асети (зображення, відео, додаткові матеріали)

## ✅ Чек-лист перед пушем
- [ ] ZIP присутній
- [ ] CHECKSUMS.txt згенерований через `tools/make_checksums.ps1`
- [ ] Асети додані (`assets/`)
- [ ] Хеші збігаються з CHECKSUMS.txt (`tools/check_release.ps1`)
- [ ] README_$Tag.md заповнено (цей файл)

---

**С.Ч.**
"@

$tpl | Set-Content -Path $readmePath -Encoding UTF8 -NoNewline:$false
Write-Host "✅ Згенеровано $readmePath"