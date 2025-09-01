Param(
  [string]$ModuleName = "C12.Tooling",
  [string]$FromPath = ".\C12.Tooling.psm1"
)
$target = Join-Path $env:USERPROFILE "Documents\PowerShell\Modules\$ModuleName\1.0.0"
New-Item -ItemType Directory -Path $target -Force | Out-Null
Copy-Item -Path $FromPath -Destination (Join-Path $target "$ModuleName.psm1") -Force
Write-Host "Installed to: $target" -ForegroundColor Green
Write-Host "Import with:  Import-Module $ModuleName" -ForegroundColor Yellow
