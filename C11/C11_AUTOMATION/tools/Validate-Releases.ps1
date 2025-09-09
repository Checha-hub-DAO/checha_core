[CmdletBinding()]
param(
  [switch]$All,
  [switch]$Quiet
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
  if (-not $Quiet) {
    Write-Host "Validate-Releases: OK (stub). All=$All"
  }
  exit 0
}
catch {
  if (-not $Quiet) { Write-Error $_ }
  exit 2
}
