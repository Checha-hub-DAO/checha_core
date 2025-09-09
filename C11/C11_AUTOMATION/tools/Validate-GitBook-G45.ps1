# Validate-GitBook-G45.ps1
[CmdletBinding()]
param(
  [string]$Root = "C:\CHECHA_CORE\GitBook\dao-g\dao-g-mods\g45-kod-zakhystu\g45-1-aot",
  [switch]$Strict
)

$ErrorActionPreference = "Stop"
$expected = @(
  "manifest.md","readme.md","panel.md","agents.md",
  "forms.md","protocols.md","partners.md","research.md","kpi.md","media.md"
)

$exit = 0
$log  = Join-Path $env:TEMP ("gitbook_g45-1-aot_validate_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
"▶ Validate $Root" | Tee-Object -File $log

function Fail($msg){ "✖ $msg"  | Tee-Object -File $log -Append; $script:exit = 2 }
function Warn($msg){ "⚠ $msg"  | Tee-Object -File $log -Append }
function Ok  ($msg){ "✔ $msg"  | Tee-Object -File $log -Append }

# 1) Наявність файлів
$missing = @()
foreach($f in $expected){
  if(!(Test-Path (Join-Path $Root $f))){ $missing += $f }
}
if($missing){ Fail "Відсутні файли: $($missing -join ', ')"} else { Ok "Усі обов'язкові файли на місці." }

# 2) Термінологічна «зачистка»: в AOT не повинно бути АОП/AOP
$badTerms = @("AOP","АОП","Автомобільний Оборонний Пост")
$hits = Get-ChildItem $Root -File -Recurse | ForEach-Object {
  $t = Select-String -Path $_.FullName -Pattern $badTerms -SimpleMatch -List
  if($t){[pscustomobject]@{File=$_.FullName; Match=$t.Line.Trim()}}
}
if($hits){
  Fail "Знайдено недопустимі згадки AOP/АОП у G45.1 AOT:"
  $hits | ForEach-Object { "   - $($_.File): $($_.Match)" | Tee-Object -File $log -Append }
}else{ Ok "Термінологія ОК: відсутні згадки AOP/АОП у AOT." }

# 3) Перевірка front-matter у readme.md та manifest.md
function Test-FrontMatter($path){
  $txt = Get-Content $path -Raw
  if($txt -match '(?s)^---\s*(.+?)\s*---'){
    $fm = $matches[1]
    $need = @("title:","slug:","module:","submodule:","doc_class:","page_version:","last_updated:")
    $miss = $need | Where-Object { $fm -notmatch [regex]::Escape($_) }
    if($miss){ Fail "Неповний front-matter у $(Split-Path $path -Leaf): відсутнє(і) $($miss -join ', ')" }
    if($fm -notmatch 'doc_class:\s*Public'){ Fail "$(Split-Path $path -Leaf): doc_class має бути Public" }
    if($fm -notmatch 'slug:\s*/dao-g/dao-g-mods/g45-kod-zakhystu/g45-1-aot'){ Fail "$(Split-Path $path -Leaf): slug має вказувати на /dao-g/dao-g-mods/g45-kod-zakhystu/g45-1-aot" }
  } else {
    Fail "Немає YAML front-matter у $(Split-Path $path -Leaf)"
  }
}
Test-FrontMatter (Join-Path $Root "readme.md")
Test-FrontMatter (Join-Path $Root "manifest.md")

# 4) Обов'язкові секції у readme.md
$readme = Get-Content (Join-Path $Root "readme.md") -Raw
$must = @("## Місія","## Швидкий старт","## Ритми","## Релізний цикл")
$miss = $must | Where-Object { $readme -notmatch [regex]::Escape($_) }
if($miss){ Fail "readme.md: відсутні секції -> $($miss -join ', ')" } else { Ok "readme.md: секції в порядку." }

# 5) Релізи в readme.md (лише валідні згадки)
if($readme -match 'g45-1-aot-v\d+\.\d+'){ Ok "readme.md: знайдено теги релізів." }

# 6) Підсумок
if($exit -eq 0){ Ok "Валідація пройдена. Лог: $log" } else { "ВАЛІДАЦІЯ НЕ ПРОЙДЕНА. Лог: $log"; exit $exit }
