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
    Fail "GitHub CLI (gh) РЅРµ Р·РЅР°Р№РґРµРЅРѕ. Р’СЃС‚Р°РЅРѕРІРё https://cli.github.com/ С– Р·Р°Р»РѕРіС–РЅСЊСЃСЏ: gh auth login"
}

if (-not $Title) { $Title = "Release $Tag" }
if (-not $NotesFile) {
    $nf = "README_{0}.md" -f $Tag
    if (Test-Path $nf) { $NotesFile = $nf }
}

# 1) Р†СЃРЅСѓС” СЂРµР»С–Р·?
$exists = $false
try {
    & gh release view $Tag | Out-Null
    $exists = $true
} catch {
    $exists = $false
}

# 2) РЎС‚РІРѕСЂРµРЅРЅСЏ Р°Р±Рѕ РѕРЅРѕРІР»РµРЅРЅСЏ
if (-not $exists) {
    Write-Host "в†’ РЎС‚РІРѕСЂСЋСЋ СЂРµР»С–Р· $TagвЂ¦"
    $args = @("release","create",$Tag)
    $args += @("-t",$Title)
    if ($NotesFile -and (Test-Path $NotesFile)) { $args += @("-F",$NotesFile) }
    if ($Draft) { $args += @("--draft") }
    if ($PreRelease) { $args += @("--prerelease") }
    & gh @args
} else {
    Write-Host "в†’ Р РµР»С–Р· $Tag РІР¶Рµ С–СЃРЅСѓС” вЂ” РѕРЅРѕРІР»СЋСЋ."
    if ($NotesFile -and (Test-Path $NotesFile)) {
        # РћРЅРѕРІРёС‚Рё РЅРѕС‚Р°С‚РєРё
        & gh release edit $Tag -t $Title -F $NotesFile
    } else {
        & gh release edit $Tag -t $Title
    }
}

if ($NoUpload) {
    Write-Host "в„№пёЏ  Р—Р°РІР°РЅС‚Р°Р¶РµРЅРЅСЏ Р°РєС‚РёРІС–РІ РїСЂРѕРїСѓС‰РµРЅРѕ (NoUpload)."
    exit 0
}

# 3) Р—Р±С–СЂ С„Р°Р№Р»С–РІ РґР»СЏ Р°РїР»РѕР°РґСѓ
$upload = @()

# ZIP С–Р· С‚РµРіРѕРј
$zip = Get-ChildItem -File -Filter ("*{0}*.zip" -f $Tag) | Select-Object -First 1
if ($zip) { $upload += $zip.FullName } else { Write-Warning "РќРµ Р·РЅР°Р№РґРµРЅРѕ ZIP РґР»СЏ $Tag" }

# CHECKSUMS.txt
if (Test-Path "CHECKSUMS.txt") { $upload += "CHECKSUMS.txt" } else { Write-Warning "CHECKSUMS.txt РЅРµ Р·РЅР°Р№РґРµРЅРѕ" }

# README_Tag
$readme = "README_{0}.md" -f $Tag
if (Test-Path $readme) { $upload += $readme } else { Write-Warning "$readme РЅРµ Р·РЅР°Р№РґРµРЅРѕ" }

# assets/*
if (Test-Path "assets") {
    $assets = Get-ChildItem -Recurse -File assets
    foreach ($a in $assets) { $upload += $a.FullName }
} else {
    Write-Warning "assets/ РЅРµ Р·РЅР°Р№РґРµРЅРѕ"
}

if (-not $upload -or $upload.Count -eq 0) {
    Write-Warning "РќРµРјР° С‰Рѕ Р·Р°РІР°РЅС‚Р°Р¶СѓРІР°С‚Рё."
    exit 0
}

Write-Host "в†’ Р—Р°РІР°РЅС‚Р°Р¶СѓСЋ Р°РєС‚РёРІРё:"
$upload | ForEach-Object { Write-Host "   + $_" }

$uplArgs = @("release","upload",$Tag) + $upload
if ($Clobber) { $uplArgs += "--clobber" }
& gh @uplArgs

Write-Host "вњ… Р“РѕС‚РѕРІРѕ: С„Р°Р№Р»Рё Р·Р°РІР°РЅС‚Р°Р¶РµРЅРѕ Сѓ СЂРµР»С–Р· $Tag."