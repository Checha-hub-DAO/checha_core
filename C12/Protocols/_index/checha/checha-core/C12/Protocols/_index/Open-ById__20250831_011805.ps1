param([Parameter(Mandatory)][string]$Id)
$IndexPath = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.json"
$Root = "C:\CHECHA_CORE\C12\Protocols"
$j = Get-Content $IndexPath -Raw | ConvertFrom-Json
$p = @($j.protocols) | Where-Object { $_.id -ieq $Id }
if (-not $p) { throw "Protocol not found: $Id" }
$path = Join-Path $Root ($p.path -replace '^[\\/]+','' -replace '/','\')
if (!(Test-Path $path)) { throw "File missing: $path" }
Start-Process notepad $path