param(
  [switch]$Backup,
  [string]$Endpoint = "",
  [string]$BucketPath = "",
  [switch]$RemoveExtra
)
$ErrorActionPreference = "Stop"
$Root = "C:\CHECHA_CORE\C12\Protocols"
$Idx  = Join-Path $Root "_index"

function Step($name, [scriptblock]$act){ Write-Host "→ $name..." -ForegroundColor Cyan; & $act; Write-Host "✓ $name" -ForegroundColor Green }

Step "Реіндекс"           { pwsh (Join-Path $Idx "protocol_reindex_from_files.ps1") }
Step "Валідація"          { pwsh (Join-Path $Idx "protocol_validate.ps1") }
Step "Генерація таблиці"  { pwsh (Join-Path $Idx "generate_protocols_table.ps1") }
Step "Експорт звіту"      { pwsh (Join-Path $Idx "Export-Report.ps1") }

if ($Backup -or ($Endpoint -and $BucketPath)) {
  if (-not $Endpoint -or -not $BucketPath) { throw "Для бекапу вкажи -Endpoint і -BucketPath." }
  Step "Бекап у MinIO" {
    $args = @("-Endpoint",$Endpoint,"-BucketPath",$BucketPath)
    if ($RemoveExtra) { $args += "-RemoveExtra" }
    pwsh (Join-Path $Idx "Backup-To-MinIO.ps1") @args
  }
}
Write-Host "`n✅ DONE: Run-Daily завершено" -ForegroundColor Green