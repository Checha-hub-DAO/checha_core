[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$SourceDir,
  [string]$OutputPath = "CHECKSUMS.txt",
  [switch]$Recurse
)
if (-not (Test-Path $SourceDir)) { Write-Host "ERROR: Теку не знайдено: $SourceDir"; exit 1 }
$files = Get-ChildItem -LiteralPath $SourceDir -File -Recurse:$Recurse
if (-not $files) { Write-Host "WARN: Немає файлів у $SourceDir"; "" | Set-Content -Path $OutputPath -Encoding UTF8; exit 0 }
$lines = foreach($f in $files) {
  $h=(Get-FileHash -Algorithm SHA256 -Path $f.FullName).Hash.ToLower()
  "$h *$($f.Name)"
}
$lines | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "OK: CHECKSUMS.txt → $OutputPath (files: $($files.Count))"
exit 0
