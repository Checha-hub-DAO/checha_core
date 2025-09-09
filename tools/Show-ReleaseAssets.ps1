param(
  [Parameter(Mandatory=$true)]
  [string]$Tag
)

$assets = gh release view $Tag --json assets | ConvertFrom-Json | Select-Object -ExpandProperty assets

if (-not $assets) {
  Write-Host "No assets found for release $Tag" -ForegroundColor Yellow
  exit 1
}

$assets | Select-Object `
  @{n="Name";e={$_.name}},
  @{n="Size (KB)";e={[math]::Round($_.size/1KB,2)}},
  @{n="Download URL";e={$_.url}} |
  Format-Table -AutoSize
