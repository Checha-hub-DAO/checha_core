#requires -Version 5.1
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Repo,         # напр. Checha-hub-DAO/g45-kod-zakhystu
  [string]$Tag,                                      # напр. g45-1-aot-v1.1 (якщо пусто — з Prefix+Version)
  [string]$TagPrefix = "g45-1-aot",
  [string]$Version   = "v1.1",
  [string]$ArchiveDir = "C:\CHECHA_CORE\G\G45\45.1_АОТ\RELEASES\ARCHIVE",
  [string]$ChecksName = "CHECKSUMS.txt"
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

if (-not $Tag) { $Tag = "$TagPrefix-$Version" }
$checks = Join-Path $ArchiveDir $ChecksName
if (-not (Test-Path $checks)) { throw "Not found: $checks" }

Write-Host "== Verify $ChecksName format (ASCII + LF) ==" -ForegroundColor Cyan
$bytes = [IO.File]::ReadAllBytes($checks)
if ($bytes.Length -eq 0) { throw "Empty $ChecksName" }
if ($bytes | Where-Object { $_ -gt 127 }) { throw "$ChecksName must be ASCII only" }
if ($bytes.Contains(13)) { throw "$ChecksName must use LF only (no CRLF)" }
Write-Host "OK: ASCII + LF"

Write-Host "== Verify SHA256 lines vs local files ==" -ForegroundColor Cyan
$lines = Get-Content -Path $checks -Encoding Ascii
if ($lines.Count -eq 0) { throw "No checksum lines" }
$expectNames = @()
foreach($line in $lines){
  if ($line -notmatch '^[0-9a-f]{64}\s+\*(.+)$'){ throw "Bad line: $line" }
  $name = $Matches[1]
  $file = Join-Path $ArchiveDir $name
  if (-not (Test-Path $file)) { throw "Missing file listed in checksums: $name" }
  $got = (Get-FileHash $file -Algorithm SHA256).Hash.ToLower()
  $exp = $line.Substring(0,64)
  if ($got -ne $exp){ throw "Checksum mismatch: $name" }
  $expectNames += $name
}
Write-Host "OK: local hashes match"

Write-Host "== Verify GitHub Release assets list ==" -ForegroundColor Cyan
if (-not (Get-Command gh -ErrorAction SilentlyContinue)){ throw "GitHub CLI (gh) not found" }

$json = gh release view $Tag -R $Repo --json assets | ConvertFrom-Json
if (-not $json -or -not $json.assets){ throw "Cannot read release assets from GH" }
$assetNames = @($json.assets | ForEach-Object { $_.name })

foreach($n in $expectNames){
  if ($assetNames -notcontains $n){ throw "Remote asset missing: $n" }
}
if ($assetNames -notcontains $ChecksName){ throw "Remote asset missing: $ChecksName" }

Write-Host "OK: GH Release has expected assets" -ForegroundColor Green
Write-Host "✓ Verify done"
