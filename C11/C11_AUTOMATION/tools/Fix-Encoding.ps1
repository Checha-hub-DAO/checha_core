<#
    Fix-Encoding.ps1 — v1.1
    ✅ Конвертує у UTF-8 з BOM
    ✅ Чистить escape-слеші (\[ \. \) …)
    ✅ Нормалізує формат часу: 0,8s → 0.8s
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path $Path)) {
    Write-Error "Файл не знайдено: $Path"
    exit 1
}

try {
    $content = Get-Content $Path -Raw -Encoding UTF8

    # --- чистка escape ---
    $content = $content -replace '\\\.', '.' `
                        -replace '\\\:', ':' `
                        -replace '\\\-', '-' `
                        -replace '\\\)', ')' `
                        -replace '\\\(', '(' `
                        -replace '\\\]', ']' `
                        -replace '\\\[', '[' `
                        -replace '\\\\', '\'

    # --- нормалізація часу ---
    $content = $content -replace '(\d+),(\d+)s', '$1.$2s'

    # --- запис у UTF-8 BOM ---
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($true))

    Write-Host "✅ $Path очищено і переведено у UTF-8 з BOM" -ForegroundColor Green
}
catch {
    Write-Error "Помилка: $_"
}
