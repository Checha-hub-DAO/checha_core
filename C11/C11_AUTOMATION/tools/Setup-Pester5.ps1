<# -----------------------------------------------------------------------
  Setup-Pester5.ps1  v1.1
  - Ставит NuGet provider (з fallback у CurrentUser)
  - Позначає PSGallery як Trusted
  - Встановлює Pester v5 у Scope=CurrentUser (без адміна)
  - Імпортує саме Pester v5 (обминаючи 3.4.0)
  - (Опційно) запускає тести з потрібною Verbosity

  Виклик:
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\Setup-Pester5.ps1 `
      -RunPath "C:\...\tests\Badge-Stale.Tests.ps1" -Verbosity Detailed
------------------------------------------------------------------------ #>

[CmdletBinding()]
param(
  [string]$RunPath = "",                         # шлях до тестів (опц.)
  [ValidateSet('None','Normal','Detailed','Diagnostic')]
  [string]$Verbosity = 'Normal'
)

$ErrorActionPreference = 'Stop'

try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

Write-Host "→ Installing NuGet provider (if needed)..." -ForegroundColor Cyan
try {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
} catch {
    Write-Warning "Global install failed, retrying with -Scope CurrentUser..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
}

Write-Host "→ Trusting PSGallery (if needed)..." -ForegroundColor Cyan
try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop } catch {}

Write-Host "→ Installing Pester v5 (CurrentUser)..." -ForegroundColor Cyan
Install-Module Pester -Scope CurrentUser -MinimumVersion 5.5.0 -Force -AllowClobber -SkipPublisherCheck

# Переконуємось, що в сесії немає підвантаженої "старої" версії
Remove-Module Pester -ErrorAction SilentlyContinue

# Імпорт саме v5
$pesterV5 = Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [Version]'5.0.0' } |
            Sort-Object Version -Descending | Select-Object -First 1

if (-not $pesterV5) { throw "Pester v5 not found after install. Please re-run this script." }

Import-Module (Join-Path $pesterV5.ModuleBase 'Pester.psd1') -Force
$ver = (Get-Module Pester).Version
Write-Host ("✓ Pester loaded: v{0}" -f $ver) -ForegroundColor Green

if ($RunPath) {
  if (-not (Test-Path $RunPath)) { throw "RunPath not found: $RunPath" }
  Write-Host "→ Running tests: $RunPath" -ForegroundColor Cyan
  $cfg = @{
    Run    = @{ Path = $RunPath }
    Output = @{ Verbosity = $Verbosity }   # None|Normal|Detailed|Diagnostic
  }
  Invoke-Pester -Configuration $cfg
} else {
  Write-Host "ℹ️ No RunPath provided. Pester v5 is ready to use." -ForegroundColor Yellow
}
