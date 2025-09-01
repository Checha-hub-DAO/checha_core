param(
    [Parameter(Mandatory=$true)][string]$Tag,
    [switch]$RequireAssets
)

function Fail([string]$msg) { Write-Error $msg; $script:errors++; }

$errors = 0

try {
    $json = & gh release view $Tag --json assets
} catch {
    Fail "Не вдалося отримати дані релізу через gh. Переконайся, що залогінений: gh auth login"
    exit 2
}

# Parse assets names via ConvertFrom-Json
$assets = ($json | ConvertFrom-Json).assets
$names = @()
if ($assets) {
    $names = $assets | ForEach-Object { $_.name }
}

if (-not $names -or $names.Count -eq 0) {
    Fail "У релізі $Tag немає жодного активу."
}

# Очікувані файли
$expected = @()

# CHECKSUMS.txt
$expected += "CHECKSUMS.txt"

# README
$readme = "README_{0}.md" -f $Tag
$expected += $readme

# ZIP
$zipLocal = Get-ChildItem -File -Filter ("*{0}*.zip" -f $Tag) | Select-Object -First 1
if ($zipLocal) {
    $expected += $zipLocal.Name
} else {
    Write-Warning "Локальний ZIP не знайдено — перевірю лише наявність будь-якого *.zip у релізі."
    if (-not ($names | Where-Object { $_ -like "*.zip" })) {
        Fail "У релізі немає жодного ZIP-файлу."
    }
}

# Перевірка очікуваного
foreach ($e in $expected | Sort-Object -Unique) {
    if (-not ($names -contains $e)) {
        Fail "Відсутній актив у релізі: $e"
    }
}

# Перевірка assets (зображення/відео)
if ($RequireAssets) {
    $hasMedia = ($names | Where-Object { $_ -match "\.(png|jpg|jpeg|gif|mp4|webm)$" }) -ne $null
    if (-not $hasMedia) { Fail "RequireAssets: у релізі немає жодного медіа-файлу (png/jpg/mp4 тощо)." }
}

if ($errors -eq 0) {
    Write-Host "✅ Реліз $Tag має необхідні активи."
    exit 0
} else {
    Write-Host "⚠️  Проблем: $errors"
    exit 2
}