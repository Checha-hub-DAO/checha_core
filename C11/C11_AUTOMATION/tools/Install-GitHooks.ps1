[CmdletBinding()]param([string]$RepoRoot="C:\CHECHA_CORE")
$hooksDir = Join-Path $RepoRoot ".git\hooks"; if(-not (Test-Path $hooksDir)){Write-Host "❌ Не знайдено .git\hooks у $RepoRoot"; exit 1}
$pc_ps1 = @'
# pre-commit.ps1 — блокує U+FFFD та CRLF
$files = git diff --cached --name-only --diff-filter=ACM
$bad=@(); foreach($f in $files){ if(-not (Test-Path $f)){continue}; $raw=Get-Content -Raw -LiteralPath $f -ErrorAction SilentlyContinue; if($null -ne $raw){ if($raw -match "`uFFFD"){ $bad+="$f  [U+FFFD]" } if($raw -match "`r`n"){ $bad+="$f  [CRLF]" } } }
if($bad.Count -gt 0){ Write-Host "❌ Коміт заблоковано:" -ForegroundColor Red; $bad | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }; exit 1 } exit 0
'@
$pc_sh='#!/usr/bin/env bash
pwsh -NoProfile -File ".git/hooks/pre-commit.ps1"
'
Set-Content -Path (Join-Path $hooksDir "pre-commit.ps1") -Value $pc_ps1 -Encoding UTF8
Set-Content -Path (Join-Path $hooksDir "pre-commit") -Value $pc_sh -Encoding Ascii
Write-Host "✅ Встановлено pre-commit хуки у $hooksDir" -ForegroundColor Green
