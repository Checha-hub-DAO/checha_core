# Minimal Weekly runner (stub). Replace with твої кроки, якщо потрібно.
$ErrorActionPreference = "Stop"
$root = "C:\CHECHA_CORE"
$new  = Join-Path $root "C12\Vault\StrategicReports\2025\Strateg_Report_$(Get-Date -f yyyy-MM-dd).md"
New-Item -ItemType Directory -Force -Path (Split-Path $new) | Out-Null
"## Weekly Auto-Report $(Get-Date)" | Set-Content -Path $new -Encoding UTF8
Add-Content -Path (Join-Path $root "C03\LOG\weekly.log") -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') [INFO ] Weekly stub created: $new" -Encoding UTF8
exit 0
