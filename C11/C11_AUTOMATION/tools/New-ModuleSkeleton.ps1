<#
[CmdletBinding()]
param(
[Parameter(Mandatory)] [string] $Module,
[string] $Root = 'C:\CHECHA_CORE'
)


Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


try {
# Нормалізація шляху модуля
if ($Module -match '^(G\d{2})(?:[\\/]|$)') {
$modulePath = Join-Path $Root $Module
} else {
if ($Module -notmatch '^G(?<g>\d{2})(?<rest>.*)$') { throw "Невірний формат модуля: $Module" }
$g = [int]$Matches['g']
$rest = $Matches['rest'].TrimStart('.')
$modulePath = Join-Path (Join-Path $Root 'G') (Join-Path ("G{0:D2}" -f $g) $rest)
}


New-Item -ItemType Directory -Force -Path $modulePath | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $modulePath 'docs') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $modulePath 'scripts') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $modulePath 'assets') | Out-Null


$readme = @"# $(Split-Path $modulePath -Leaf)
Короткий опис призначення (2–3 рядки).


## Структура
- docs/ — публічні матеріали
- scripts/ — автоматизація
- assets/ — візуали


## Стан
- Версія: v0.1.0
- Мінімальний пакет: VERSION.txt + README.md + docs/_index.md
"@
Set-Content -Path (Join-Path $modulePath 'README.md') -Value $readme -Encoding UTF8
Set-Content -Path (Join-Path $modulePath 'VERSION.txt') -Value 'v0.1.0' -Encoding ASCII


$idx = "# $(Split-Path $modulePath -Leaf)\n\nОпис публічної сторінки модуля."
Set-Content -Path (Join-Path $modulePath 'docs\_index.md') -Value $idx -Encoding UTF8


$manifest = @"id: $(Split-Path $modulePath -Leaf)
name: ""Назва модуля""
version: ""v0.1.0""
maintainer: ""С.Ч.""
"@
Set-Content -Path (Join-Path $modulePath 'manifest.md') -Value $manifest -Encoding UTF8


$export = @"module: $(Split-Path $modulePath -Leaf)
exports:
- id: main-doc
title: ""Головна сторінка""
source: ./docs/_index.md
targets: [dao-guides]
"@
Set-Content -Path (Join-Path $modulePath 'export.yaml') -Value $export -Encoding UTF8


Write-Host "✔ Створено скелет: $modulePath" -ForegroundColor Green
exit 0
}
catch {
Write-Error $_
exit 5
}