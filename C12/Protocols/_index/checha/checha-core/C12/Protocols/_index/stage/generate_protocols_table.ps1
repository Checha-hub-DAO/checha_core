param([Parameter(ValueFromRemainingArguments=$true)] $Args)
$ErrorActionPreference = 'Stop'

$base     = $PSScriptRoot                         # C:\CHECHA_CORE\C12\Protocols
$target   = Join-Path $base '_index\generate_protocols_table.ps1'
$outDir   = Join-Path $base '_index\out'
$outCsv   = Join-Path $outDir 'protocols_table.csv'

function Write-FallbackTable {
  param([string]$Root, [string]$CsvPath)
  $exclude = '\.git(\\|$)|\.github(\\|$)|\.vscode(\\|$)|\\_index\\|\\checha\\|\\checha-core\\'
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $CsvPath) | Out-Null

  $files = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
           Where-Object { $_.FullName -notmatch $exclude }

  $rows = $files | ForEach-Object {
    [PSCustomObject]@{
      RelativePath  = $_.FullName.Substring($Root.Length + 1)
      Name          = $_.Name
      SizeBytes     = $_.Length
      LastWriteTime = $_.LastWriteTime
    }
  }

  $rows | Sort-Object RelativePath | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
  Write-Host "Fallback table -> $CsvPath  (rows: $($rows.Count))"
}

try {
  if (Test-Path -LiteralPath $target) {
    Write-Host "Shim(generate_table) -> $target"
    Unblock-File $target
    & $target @Args
  } else {
    Write-Warning "No native generator at $target; running fallback."
    Write-FallbackTable -Root $base -CsvPath $outCsv
  }
}
catch {
  Write-Warning ("Native generator failed: " + $_.Exception.Message + "  -> running fallback.")
  Write-FallbackTable -Root $base -CsvPath $outCsv
}
