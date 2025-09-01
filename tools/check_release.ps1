param(
    [Parameter(Mandatory=$true)][string]$Tag,
    [string]$ReleaseDir = ".",
    [switch]$RequireAssets
)

Write-Host ("ℹ️  Перевіряю реліз '{0}' у '{1}'…" -f $Tag, (Resolve-Path $ReleaseDir))

$errors = 0
function Fail($msg) {
    Write-Error $msg
    $script:errors++
}

$readme = Join-Path $ReleaseDir ("README_{0}.md" -f $Tag)
$zip    = Get-ChildItem $ReleaseDir -Filter ("*{0}*.zip" -f $Tag) | Select-Object -First 1
$chk    = Join-Path $ReleaseDir "CHECKSUMS.txt"
$assets = Join-Path $ReleaseDir "assets"

# 1) Перевірка наявності базових файлів
if (-not (Test-Path $readme)) { Fail "❌ Нема файла: $(Split-Path -Leaf $readme)" }
if (-not $zip) { Fail "❌ Нема ZIP-файлу з тегом '$Tag'." }
if (-not (Test-Path $chk)) { Fail "❌ Нема файла: CHECKSUMS.txt" }

if ($RequireAssets -and -not (Test-Path $assets)) { Fail "❌ Нема папки assets/ (RequireAssets)" }

# 2) Верифікація хешів
if (Test-Path $chk) {
    $lines = Get-Content $chk | Where-Object { $_.Trim().Length -gt 0 }
    foreach ($line in $lines) {
        $parts = $line -split "\s+\*"
        if ($parts.Count -lt 2) { Fail "❌ Некоректний рядок у CHECKSUMS.txt: '$line'"; continue }
        $expected = $parts[0].Trim()
        $relPath  = $parts[1].Trim()
        $path     = Join-Path $ReleaseDir $relPath

        if (-not (Test-Path $path)) { Fail "❌ Відсутній файл із CHECKSUMS: $relPath"; continue }

        $actual = (Get-FileHash -Path $path -Algorithm SHA256).Hash
        if ($expected -ne $actual) { Fail "❌ Хеш не збігається: $relPath"; continue }
    }
}

if ($errors -eq 0) {
    Write-Host "✅ Реліз '$Tag' пройшов перевірку та готовий до пушу."
    exit 0
} else {
    Write-Host ("⚠️  Виявлено {0} проблем(и). Виправ і запусти перевірку повторно." -f $errors)
    exit 2
}