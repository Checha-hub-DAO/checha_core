# C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\Build-WeeklyZip.ps1
[CmdletBinding()]
param(
  [string]$ConfigPath = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\checha_matrix_config.json",
  [string]$ReportDate = (Get-Date -Format "yyyy-MM-dd"),
  [switch]$IncludeMatrix   # опційно додати Matrix.md у ZIP
)

$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$year   = $ReportDate.Substring(0,4)
$report = Join-Path (Join-Path $cfg.C12.StrategicReportsRoot $year) ("Strateg_Report_{0}.md" -f $ReportDate)
$checks = Join-Path $cfg.C12.StrategicReportsRoot $cfg.Checksums.FileName
$matrix = Join-Path $cfg.C12.VaultRoot "Matrix.md"

# ensure report exists (generate if missing)
if(-not (Test-Path $report)){
  $gen = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\New-G44StrategicReport.ps1"
  if(Test-Path $gen){ & $gen -ConfigPath $ConfigPath -ReportDate $ReportDate | Out-Null }
}

$week   = (Get-Culture).Calendar.GetWeekOfYear([datetime]::Parse($ReportDate),
          [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
$zipOut = Join-Path $env:TEMP ("Strategic_Pack_{0}-W{1}.zip" -f $year,$week)

if(Test-Path $zipOut){ Remove-Item $zipOut -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipOut,'Create')

$added = 0
try{
  if(Test-Path $report){
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$report,(Split-Path $report -Leaf)) | Out-Null
    $added++
  }
  if(Test-Path $checks){
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$checks,(Split-Path $checks -Leaf)) | Out-Null
    $added++
  }
  if($IncludeMatrix -and (Test-Path $matrix)){
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$matrix,(Split-Path $matrix -Leaf)) | Out-Null
    $added++
  }
}
finally { $zip.Dispose() }

if($added -eq 0){
  throw "ZIP is empty: nothing to add (report/checksums missing)."
}

Write-Host ("OK: zip -> {0} (files: {1})" -f $zipOut,$added)
$zipOut
