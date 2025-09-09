# McHelpers.tests.ps1 — прості smoke-тести
Import-Module "$PSScriptRoot\..\McHelpers.psm1" -Force

$log = Join-Path $env:TEMP "mc_test_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss")
$result = Write-McLog -LogPath $log -Message "test message" -Level INFO
if (-not (Test-Path $log)) { throw "Write-McLog не створив файл логу" }

$src = Join-Path $env:TEMP "mc_zip_src_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss")
$dst = Join-Path $env:TEMP "mc_zip_out_{0}.zip" -f (Get-Date -Format "yyyyMMdd_HHmmss")
New-Item -ItemType Directory -Path $src -Force | Out-Null
"demo" | Set-Content -Path (Join-Path $src "a.txt") -Encoding utf8
$zipInfo = Compress-McZip -SourcePath $src -ZipPath $dst -WhatIf
if (-not $zipInfo) { throw "Compress-McZip не повернув об'єкт (WhatIf)" }

"OK"
