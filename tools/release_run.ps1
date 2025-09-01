<#
.SYNOPSIS
  Надійний майстер-скрипт релізу з конфігом, логами, опційною підписом CHECKSUMS, git-тегом та пушем.

.EXAMPLE
  pwsh tools/release_run.ps1 -Config release.config.json

.PARAMETER Config
  JSON-конфіг (release.config.json) з ключами:
  BlockName, Tag, SourceDir, OutZip, RequireAssets, GitTag, GitRemote, Draft, PreRelease, SignChecksums

.PARAMETER NoZip
  Пропустити пакування ZIP (перевірка і решта — виконуються).
#>
param(
    [string]$Config = "release.config.json",
    [switch]$NoZip
)

$ErrorActionPreference = "Stop"

function Log($msg) {
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[{0}] {1}" -f $ts, $msg
    $line | Tee-Object -FilePath $Global:LogPath -Append
}

# === 0) Логи і середовище ===
$logDir = Join-Path "." "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$Global:LogPath = Join-Path $logDir ("release_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
"== Release run start ==" | Out-File $Global:LogPath -Encoding UTF8

# === 1) Читання конфігу ===
if (-not (Test-Path $Config)) { throw "Config not found: $Config" }
$cfg = Get-Content $Config -Raw | ConvertFrom-Json
$BlockName     = $cfg.BlockName
$Tag           = $cfg.Tag
$SourceDir     = $cfg.SourceDir
$OutZip        = $cfg.OutZip
$RequireAssets = [bool]$cfg.RequireAssets
$GitTag        = [bool]$cfg.GitTag
$GitRemote     = if ($cfg.GitRemote) { $cfg.GitRemote } else { "origin" }
$Draft         = [bool]$cfg.Draft
$PreRelease    = [bool]$cfg.PreRelease
$SignChecksums = [bool]$cfg.SignChecksums

Log "Config loaded: $($cfg | ConvertTo-Json -Compress)"

# === 2) Перевірка середовища ===
$pwshVer = $PSVersionTable.PSVersion.ToString()
Log "PowerShell: $pwshVer"

function HasCommand($name) {
    $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

$hasGh = HasCommand "gh"
if ($hasGh) { Log "gh CLI: OK" } else { Log "gh CLI: NOT FOUND (optional)" }

# Git clean tree (optional but recommended)
if (HasCommand "git") {
    $status = git status --porcelain
    if ($status) { Log "⚠️  Git working tree not clean."; } else { Log "Git working tree clean." }
} else {
    Log "git not found (skipping clean check)."
}

# === 3) README ===
Log "Creating README_$Tag.md"
& "$PSScriptRoot/make_readme.ps1" -BlockName $BlockName -Tag $Tag -ZipName $OutZip

# === 4) ZIP ===
if (-not $NoZip) {
    if (-not (Test-Path $SourceDir)) { throw "SourceDir does not exist: $SourceDir" }
    Log "Packing '$SourceDir' -> '$OutZip'"
    & "$PSScriptRoot/pack_zip.ps1" -SourceDir $SourceDir -OutZip $OutZip
} else {
    Log "NoZip flag: skip ZIP packing."
}

# === 5) CHECKSUMS ===
Log "Generating CHECKSUMS.txt"
& "$PSScriptRoot/make_checksums.ps1" -ReleaseDir .

# === 5.1) GPG-підпис (опційно) ===
if ($SignChecksums) {
    if (HasCommand "gpg") {
        Log "Signing CHECKSUMS.txt via gpg"
        try {
            & gpg --batch --yes --armor --detach-sign --output CHECKSUMS.txt.asc CHECKSUMS.txt
            Log "CHECKSUMS.txt.asc created."
        } catch {
            Log "ERROR: gpg signing failed: $($_.Exception.Message)"
        }
    } else {
        Log "gpg not found; skip signing."
    }
}

# === 6) Перевірка комплекту ===
$checkArgs = @{ Tag = $Tag; ReleaseDir = "." }
if ($RequireAssets) { $checkArgs["RequireAssets"] = $true }
Log "Running check_release.ps1 with RequireAssets=$RequireAssets"
& "$PSScriptRoot/check_release.ps1" @checkArgs

# === 7) Git tag & push (опційно) ===
if ($GitTag) {
    if (-not (HasCommand "git")) {
        Log "git not found; cannot tag."
    } else {
        Log "Creating git tag $Tag and pushing to $GitRemote"
        try {
            git tag $Tag
        } catch {
            Log "Tag create failed (maybe exists): $($_.Exception.Message)"
        }
        try {
            git push $GitRemote $Tag
            Log "Tag pushed."
        } catch {
            Log "Tag push failed: $($_.Exception.Message)"
        }
    }
}

Log "== Release run complete =="
Write-Host "✅ Release '$Tag' completed. Logs: $Global:LogPath"