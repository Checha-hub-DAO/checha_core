Param(
  [Parameter(Mandatory=$true)][string]$NavUrl,
  [Parameter(Mandatory=$true)][string]$G23FormUrl,
  [Parameter(Mandatory=$true)][string]$G23SheetUrl,
  [string]$MainPath = "C:\CHECHA_CORE\C12\C12_MAIN.md"
)
# Update MAIN
if (Test-Path $MainPath) {
  $c = Get-Content $MainPath -Raw
  $c = $c -replace "\{\{NAV_GITBOOK_URL\}\}", $NavUrl
  $c = $c -replace "\{\{G23_FORM_URL\}\}",  $G23FormUrl
  $c = $c -replace "\{\{G23_SHEET_URL\}\}", $G23SheetUrl
  Set-Content $MainPath $c -Encoding UTF8
  Write-Host "Updated: $MainPath" -ForegroundColor Green
} else {
  Write-Warning "Not found: $MainPath"
}
