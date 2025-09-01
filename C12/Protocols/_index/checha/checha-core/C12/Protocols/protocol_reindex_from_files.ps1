param([Parameter(ValueFromRemainingArguments=$true)] $Args)
$ErrorActionPreference = 'Stop'

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootC12 = (Resolve-Path (Join-Path $here '..')).Path
$rootCore= (Resolve-Path (Join-Path $here '..\..')).Path
$roots   = @($here, $rootC12, $rootCore) | Select-Object -Unique
$patterns= @('protocol_reindex_from_files.ps1','protocol-reindex-from-files.ps1','*reindex*files*.ps1','*reindex*.ps1')
$exclude = '\\_index\\|\\.git(\\|$)|\\.github(\\|$)|\\.vscode(\\|$)'

$me     = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$found  = $null
foreach ($r in $roots) {
  $found = Get-ChildItem -Path $r -Recurse -File -Include $patterns -ErrorAction SilentlyContinue |
           Where-Object { $_.FullName -notmatch $exclude -and ([IO.Path]::GetFullPath($_.FullName) -ne $me) } |
           Select-Object -First 1
  if ($found) { break }
}

if ($found) {
  Write-Host "Shim -> $($found.FullName)"
  Unblock-File $found.FullName
  & $found.FullName @Args
} else {
  Write-Warning "No real reindex script found; skipping reindex step."
}
