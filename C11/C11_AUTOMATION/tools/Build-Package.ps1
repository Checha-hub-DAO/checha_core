[CmdletBinding()]
param(
[Parameter(Mandatory)] [string] $Path,
[string] $Out
)


Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


try {
& $PSScriptRoot\Validate-Module.ps1 -Path $Path
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }


if (-not $Out) {
$name = Split-Path $Path -Leaf
$date = (Get-Date).ToString('yyyy-MM-dd')
$Out = Join-Path (Join-Path $env:TEMP '.') ("{0}_{1}_build.zip" -f $name,$date)
}
$outDir = Split-Path $Out -Parent
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (Test-Path $Out) { Remove-Item $Out -Force }


$excludes = @('*.ps1~','*.tmp','*.log','.git','bin','obj','.DS_Store')


$tmp = Join-Path $env:TEMP ("pkg_" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$dest = Join-Path $tmp (Split-Path $Path -Leaf)
Copy-Item $Path $dest -Recurse -Force
Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $Out -CompressionLevel Optimal
Remove-Item $tmp -Recurse -Force


if (-not (Test-Path $Out)) { throw "Не вдалося створити ZIP: $Out" }
Write-Host "✔ Пакет створено: $Out" -ForegroundColor Green
exit 0
}
catch {
Write-Error $_
exit 3
}