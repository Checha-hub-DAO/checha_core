[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $Path,
  [string] $Out = 'CHECKSUMS.txt'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
  if (-not (Test-Path $Path)) { throw "Path not found: $Path" }
  $files = Get-ChildItem -File -Path $Path | Sort-Object Name
  if (-not $files) { throw "No files in: $Path" }

  $lines = foreach($f in $files){
    $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
    # формат: <hash> <filename>
    "$h $($f.Name)"
  }

  $outPath = Join-Path $Path $Out
  Set-Content -Path $outPath -Value $lines -Encoding ASCII
  Write-Host "✔ CHECKSUMS зібрано: $outPath" -ForegroundColor Green
  exit 0
}
catch {
  Write-Error $_
  exit 3
}
