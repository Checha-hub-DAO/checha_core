[CmdletBinding()]
param(
[Parameter(Mandatory)] [string] $Path
)


Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


$required = @('README.md','VERSION.txt','docs\_index.md','manifest.md')
try {
foreach ($f in $required) {
$p = Join-Path $Path $f
if (-not (Test-Path $p)) { Write-Error "Відсутній файл: $f"; exit 2 }
if ((Get-Item $p).Length -eq 0) { Write-Error "Порожній файл: $f"; exit 2 }
}


$ver = (Get-Content (Join-Path $Path 'VERSION.txt') -Raw).Trim()
if ($ver -notmatch '^(v\d+\.\d+(?:\.\d+)?|\d{4}-\d{2}-\d{2})$') {
Write-Error "Невірний формат VERSION.txt: '$ver'"; exit 2
}


Get-ChildItem -File -Path $Path | Where-Object { $_.Length -gt 25MB } | ForEach-Object {
Write-Error "Зайвий великий файл: $($_.Name)"; exit 1
}


if (-not (Test-Path (Join-Path $Path 'export.yaml'))) {
Write-Error 'Відсутній export.yaml'; exit 2
}


Write-Host '✓ Валідація пройдена' -ForegroundColor Green
exit 0
}
catch {
Write-Error $_
exit 1
}