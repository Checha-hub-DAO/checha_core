<#
  prep_release.ps1
  1) Optional: clean padding.bin
  2) Copy src -> dist
  3) Run guard with per-path thresholds
  4) Generate CHECKSUMS.txt
  5) Optional: upload to GitHub Release if -Tag is provided
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string[]]$DistPath,
  [Parameter(Mandatory=$true)][hashtable]$MinSizeKBPerPath,
  [hashtable]$SrcPath = @{},
  [string]$ChecksumOut = '',
  [switch]$CleanPadding = $true,
  [switch]$DoCopy = $true,
  [string]$Tag = ''
)

$ErrorActionPreference='Stop'

function Get-KB($p){
  $sum=(Get-ChildItem -LiteralPath $p -Recurse -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum
  if(-not $sum){return 0}
  [int]([math]::Round($sum/1KB))
}

foreach($d in $DistPath){ if(-not (Test-Path -LiteralPath $d)){ New-Item -ItemType Directory -Force $d | Out-Null } }

if($CleanPadding){
  foreach($d in $DistPath){
    Get-ChildItem -LiteralPath $d -Recurse -Filter 'padding.bin' -File -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
  }
}

if($DoCopy -and $SrcPath.Count -gt 0){
  foreach($key in $SrcPath.Keys){
    $src = $SrcPath[$key]
    $dst = $DistPath | Where-Object { $_ -match "\\$key\\dist$" }
    if($src -and (Test-Path -LiteralPath $src) -and $dst){
      Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force -EA SilentlyContinue
    }
  }
}

$guard = Join-Path $PSScriptRoot 'release-assets-guard.ps1'
& $guard -DistPath $DistPath -MinSizeKBPerPath $MinSizeKBPerPath -RequireFiles @('README*.md','*.*') -ChecksumOut $ChecksumOut
$code = $LASTEXITCODE
if($code -ne 0){ Write-Host "Guard failed (exit $code)"; exit $code }

foreach($d in $DistPath){ "{0}  ->  {1} KB" -f $d, (Get-KB $d) }

if($Tag){
  gh release create $Tag -t $Tag -n "Gallery update" 2>$null
  gh release upload $Tag ($DistPath | ForEach-Object { Join-Path $_ '**' }) $ChecksumOut --clobber
}
Write-Host "prep_release: DONE"
exit 0
