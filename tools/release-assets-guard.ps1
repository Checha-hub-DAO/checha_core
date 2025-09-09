<#
  release-assets-guard.ps1
  Validates that release asset directories are non-empty, meet minimal size
  (globally or per-path), contain required files (globally or per-path),
  and (optionally) generates CHECKSUMS.txt.
  Exit codes: 0=OK, 2=FAIL
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string[]]$DistPath,

  [int]$MinSizeKB = 16,

  # Per-path minimal size override (key = full directory path)
  [hashtable]$MinSizeKBPerPath = @{},

  # Global required file name patterns (applied if no per-path override)
  [string[]]$RequireFiles = @(),

  # Per-path required file patterns (key = full directory path, value = string[] of patterns)
  [hashtable]$RequireFilesPerPath = @{},

  # Output file for checksums (generated only if validation passes)
  [string]$ChecksumOut = '',

  # Sizes-only mode: print sizes and (optionally) top-N largest files, then exit 0
  [switch]$ShowSizesOnly,
  [int]$TopFiles = 0
)

$ErrorActionPreference = 'Stop'
$fail = @()

function Get-FolderSizeKB {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue |
          Measure-Object Length -Sum).Sum
  if (-not $sum) { $sum = 0 }
  return [int]([Math]::Round($sum / 1KB))
}

function Test-Dist {
  param(
    [string]$Path,
    [int]$MinKB,
    [string[]]$RequireFilesLocal
  )
  if (-not (Test-Path -LiteralPath $Path)) { return "Missing directory: $Path" }

  $files = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction Stop
  if (-not $files) { return "Empty directory: $Path" }

  $sumKB = [int]([Math]::Round( ($files | Measure-Object Length -Sum).Sum / 1KB ))
  if ($sumKB -lt $MinKB) { return "Too small ($sumKB KB < $MinKB KB): $Path" }

  foreach ($pattern in $RequireFilesLocal) {
    $match = $files | Where-Object { $_.Name -like $pattern }
    if (-not $match) { return "Required file not found ($pattern) in: $Path" }
  }
  return $null
}

# Sizes-only mode
if ($ShowSizesOnly) {
  Write-Host "Sizes-only mode"
  foreach ($p in $DistPath) {
    $kb = Get-FolderSizeKB -Path $p
    if ($kb -eq $null) { Write-Host "[MISSING] $p" -ForegroundColor Red; continue }
    $mb = [math]::Round($kb/1024,2)
    Write-Host ("{0}  ->  {1} KB  ({2} MB)" -f $p, $kb, $mb)
    if ($TopFiles -gt 0 -and (Test-Path -LiteralPath $p)) {
      $top = Get-ChildItem -LiteralPath $p -Recurse -File |
             Sort-Object Length -Descending |
             Select-Object -First $TopFiles
      if ($top) {
        Write-Host "Top files:"
        foreach ($f in $top) {
          $fk = [int]([math]::Round($f.Length/1KB))
          Write-Host ("  {0}  [{1} KB]" -f $f.FullName, $fk)
        }
      }
    }
  }
  exit 0
}

Write-Host ("release-assets-guard: Global MinSizeKB={0}; RequireFiles={1}" -f $MinSizeKB, ($RequireFiles -join ', '))

# Validate each path with its effective thresholds/patterns
foreach ($p in $DistPath) {
  $effectiveKB = $MinSizeKB
  if ($MinSizeKBPerPath.ContainsKey($p)) {
    try { $effectiveKB = [int]$MinSizeKBPerPath[$p] } catch {}
  }

  $effectiveReq = $RequireFiles
  if ($RequireFilesPerPath.ContainsKey($p)) {
    $v = $RequireFilesPerPath[$p]
    if ($v -is [System.Array]) { $effectiveReq = @($v) }
    elseif ($v -is [string])   { $effectiveReq = @($v) }
  }

  $r = Test-Dist -Path $p -MinKB $effectiveKB -RequireFilesLocal $effectiveReq
  if ($r) { $fail += $r; Write-Host $r -ForegroundColor Red }
  else    { Write-Host ("OK: {0} (>= {1} KB)" -f $p, $effectiveKB) -ForegroundColor Green }
}

# Only generate checksums if validation passed
if (($fail.Count -eq 0) -and ($ChecksumOut)) {
  Write-Host "Generating CHECKSUMS.txt -> $ChecksumOut"
  $outDir = Split-Path -Parent $ChecksumOut
  if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
  }
  $lines = @()
  foreach ($p in $DistPath) {
    Get-ChildItem -LiteralPath $p -Recurse -File | ForEach-Object {
      $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256
      $rel  = Resolve-Path $_.FullName | Split-Path -NoQualifier
      $lines += ("{0} *{1}" -f $hash.Hash, $rel.TrimStart('\'))
    }
  }
  $lines | Sort-Object | Set-Content -Path $ChecksumOut -Encoding UTF8
  Write-Host "CHECKSUMS.txt generated." -ForegroundColor Green
}

if ($fail.Count) {
  Write-Host "Guard: FAIL" -ForegroundColor Red
  exit 2
}

Write-Host "Guard: OK" -ForegroundColor Green
exit 0
