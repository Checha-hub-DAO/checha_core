$ErrorActionPreference = 'Stop'
$base = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $base

$from = Join-Path $base '_index\logs\from-scheduler.txt'
$trns = Join-Path $base '_index\logs' ('Task-Runner_{0:yyyyMMdd_HHmmss}.log' -f (Get-Date))
Start-Transcript -Path $trns -Append | Out-Null

$env:MC_CONFIG_DIR = 'C:\CHECHA_CORE\.mc'

Add-Content -Path $from -Encoding ASCII -Value ('Start: ' + (Get-Date -Format s))
Add-Content -Path $from -Encoding ASCII -Value ('BASE=' + $base + '  PWD=' + (Get-Location).Path)
Add-Content -Path $from -Encoding ASCII -Value ('PS=' + $PSVersionTable.PSVersion + '  USER=' + [System.Security.Principal.WindowsIdentity]::GetCurrent().Name + '  MC_CONFIG_DIR=' + $env:MC_CONFIG_DIR)

$run = Join-Path $base 'Run-Daily.ps1'
Add-Content -Path $from -Encoding ASCII -Value ('Exists Run-Daily.ps1: ' + (Test-Path $run))

try {
  & $run   # ВАЖЛИВО: без Tee-Object у $from
  Add-Content -Path $from -Encoding ASCII -Value ('End: ' + (Get-Date -Format s) + ' OK')
  Stop-Transcript | Out-Null
  exit 0
}
catch {
  Add-Content -Path $from -Encoding ASCII -Value ('ERROR: ' + $_.Exception.Message)
  $_ | Out-String | Add-Content -Path $from -Encoding ASCII
  Stop-Transcript | Out-Null
  exit 1
}
