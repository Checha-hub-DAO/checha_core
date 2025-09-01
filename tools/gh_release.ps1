param(
    [Parameter(Mandatory=$true)][string]$Tag,
    [string]$Title,
    [string]$NotesFile,
    [switch]$Draft,
    [switch]$PreRelease,
    [switch]$NoUpload,
    [switch]$Clobber
)

function Fail([string]$msg) { Write-Error $msg; exit 1 }

# 0) gh presence
try {
    & gh --version | Out-Null
} catch {
    Fail "GitHub CLI (gh) не знайдено. Встанови https://cli.github.com/ і залогінься: gh auth login"
}

if (-not $Title) { $Title = "Release $Tag" }
if (-not $NotesFile) {
    $nf = "README_{0}.md" -f $Tag
    if (Test-Path $nf) { $NotesFile = $nf }
}

# 1) Існує реліз?
$exists = $false
try {
    & gh release view $Tag | Out-Null
    $exists = $true
} catch {
    $exists = $false
}

# 2) Створення або оновлення
if (-not $exists) {
    Write-Host "→ Створюю реліз $Tag…"
    $args = @("release","create",$Tag)
    $args += @("-t",$Title)
    if ($NotesFile -and (Test-Path $NotesFile)) { $args += @("-F",$NotesFile) }
    if ($Draft) { $args += @("--draft") }
    if ($PreRelease) { $args += @("--prerelease") }
    & gh @args
} else {
    Write-Host "→ Реліз $Tag вже існує — оновлюю."
    if ($NotesFile -and (Test-Path $NotesFile)) {
        # Оновити нотатки
        & gh release edit $Tag -t $Title -F $NotesFile
    } else {
        & gh release edit $Tag -t $Title
    }
}

if ($NoUpload) {
    Write-Host "ℹ️  Завантаження активів пропущено (NoUpload)."
    exit 0
}

# 3) Збір файлів для аплоаду
$upload = @()

# ZIP із тегом
$zip = Get-ChildItem -File -Filter ("*{0}*.zip" -f $Tag) | Select-Object -First 1
if ($zip) { $upload += $zip.FullName } else { Write-Warning "Не знайдено ZIP для $Tag" }

# CHECKSUMS.txt
if (Test-Path "CHECKSUMS.txt") { $upload += "CHECKSUMS.txt" } else { Write-Warning "CHECKSUMS.txt не знайдено" }

# README_Tag
$readme = "README_{0}.md" -f $Tag
if (Test-Path $readme) { $upload += $readme } else { Write-Warning "$readme не знайдено" }

# assets/*
if (Test-Path "assets") {
    $assets = Get-ChildItem -Recurse -File assets
    foreach ($a in $assets) { $upload += $a.FullName }
} else {
    Write-Warning "assets/ не знайдено"
}

if (-not $upload -or $upload.Count -eq 0) {
    Write-Warning "Нема що завантажувати."
    exit 0
}

Write-Host "→ Завантажую активи:"
$upload | ForEach-Object { Write-Host "   + $_" }

$uplArgs = @("release","upload",$Tag) + $upload
if ($Clobber) { $uplArgs += "--clobber" }
& gh @uplArgs

Write-Host "✅ Готово: файли завантажено у реліз $Tag."