[CmdletBinding()]
param(
  [string]$ZipPath = "$env:USERPROFILE\Downloads\McHelpers_StarterPack_v0.3.3.zip",
  [string]$CoreRoot = $(
    @('C:\CHECHA_CORE','D:\CHECHA_CORE') | Where-Object { Test-Path $_ } | Select-Object -First 1
  )
)

if (-not $CoreRoot) {
  $CoreRoot = 'C:\CHECHA_CORE'
  New-Item -ItemType Directory -Path $CoreRoot -Force | Out-Null
}

Write-Host "→ Корінь CHECHA_CORE: $CoreRoot"

if (-not (Test-Path $ZipPath)) {
  Write-Warning "ZIP не знайдено за шляхом: $ZipPath"
  Write-Host  "Поклади McHelpers_StarterPack_v0.3.3.zip у Downloads або вкажи -ZipPath"
  throw "Нема ZIP"
}

# 1) Розпакувати у корінь
Expand-Archive -LiteralPath $ZipPath -DestinationPath $CoreRoot -Force

# 2) Розблокувати файли
$McPath = Join-Path $CoreRoot 'C12\Protocols\_index\McHelpers'
Get-ChildItem $McPath -Recurse -File | Unblock-File

# 3) Додати _index у PSModulePath
$Parent = Split-Path $McPath -Parent
if (-not ($env:PSModulePath -split ';' | Where-Object { $_ -eq $Parent })) {
  $env:PSModulePath = "$Parent;$env:PSModulePath"
}

# 4) Імпорт модуля
try {
  Import-Module McHelpers -Force -Verbose
} catch {
  Import-Module (Join-Path $McPath 'McHelpers.psd1') -Force -Verbose
}

# 5) Smoke-тест
$log = Join-Path $CoreRoot 'C03\LOG\mchelpers_install_demo.log'
Write-McLog -LogPath $log -Message "McHelpers installed" -Level INFO
Get-Module McHelpers | Format-List Name,Version,Path
Write-Host "✅ Інсталяцію завершено."
