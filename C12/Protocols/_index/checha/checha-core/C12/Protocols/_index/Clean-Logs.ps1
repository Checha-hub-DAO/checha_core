$ErrorActionPreference = "Stop"
$logDir = "C:\CHECHA_CORE\C12\Protocols\_index\logs"
$threshold = (Get-Date).AddDays(-14)
Get-ChildItem "$logDir\*.log" -File -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -lt $threshold } |
  ForEach-Object {
    try {
      $s = [IO.File]::Open($_.FullName,'Open','ReadWrite','None'); $s.Close()
      Remove-Item $_.FullName -Force -ErrorAction Stop
      Write-Host "Removed: $($_.Name)"
    } catch { Write-Host "Skip locked: $($_.Name)" }
  }
# підрізати хвіст
$tailFile = Join-Path $logDir 'from-scheduler.txt'
if (Test-Path $tailFile) {
  $lines = Get-Content $tailFile -ErrorAction SilentlyContinue
  if ($lines.Count -gt 500) { $lines | Select-Object -Last 500 | Set-Content -Encoding ASCII $tailFile }
}
