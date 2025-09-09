<#{
.SYNOPSIS
  Пише рядок у C03\LOG\LOG.md з єдиним форматом.
.DESCRIPTION
  Створює теку логу за потреби. Формат: yyyy-MM-dd HH:mm:ss [LEVEL] message
.PARAMETER ChechaRoot
  Корінь системи CHECHA_CORE.
.PARAMETER Text
  Текст повідомлення.
.PARAMETER Level
  INFO | WARN | ERROR (за замовч. INFO).
.EXAMPLE
  pwsh -NoProfile -File .\Write-OrchestratorLog.ps1 -Text 'InitModule scheduled (Mon/Fri @ 19:00)'
.EXAMPLE
  pwsh -NoProfile -File .\Write-OrchestratorLog.ps1 -Text 'SYSTEM registration failed' -Level ERROR
}#>
param(
  [string]$ChechaRoot = 'C:\CHECHA_CORE',
  [Parameter(Mandatory)] [string]$Text,
  [ValidateSet('INFO','WARN','ERROR')] [string]$Level = 'INFO'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$log = Join-Path $ChechaRoot 'C03\LOG\LOG.md'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Add-Content -Path $log -Value ("{0} [{1,-5}] {2}" -f $ts,$Level,$Text) -Encoding UTF8
Write-Host "[OK] Logged: $Level — $Text" -ForegroundColor Green
