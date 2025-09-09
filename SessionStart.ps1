# SessionStart.ps1
$ErrorActionPreference = 'Stop'

$update = "C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\Update-Strateg-README.ps1"

if (-not (Test-Path $update)) {
  Write-Host "вќЊ Not found: $update" -ForegroundColor Red
  exit 1
}

# 1) РћРЅРѕРІРёС‚Рё README СЃС‚СЂР°С‚РµРіС–С‡РЅРёС… Р·РІС–С‚С–РІ
& pwsh -NoProfile -ExecutionPolicy Bypass -File $update

# 2) (РћРїС†С–Р№РЅРѕ) С–РЅС€С– В«РЅР° СЃС‚Р°СЂС‚С–В» РґС–С—:
# & pwsh -NoProfile -ExecutionPolicy Bypass -File C:\CHECHA_CORE\tools\check_release.ps1 -Tag ethno-v1.2 -DryRun

Write-Host "вњ… Session start tasks completed."
