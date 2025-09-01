param(
  [Parameter(Mandatory)][string]$Endpoint,
  [Parameter(Mandatory)][string]$BucketPath,  # напр. checha-core/C12/Protocols
  [string]$Alias = "checha",
  [switch]$Direct
)
$Root = "C:\CHECHA_CORE\C12\Protocols"
if (-not (Get-Command mc -ErrorAction SilentlyContinue)) { throw "MinIO client (mc) не знайдено у PATH" }
mc alias set $Alias $Endpoint $env:MINIO_ACCESS_KEY $env:MINIO_SECRET_KEY | Out-Null
if ($Direct) {
  mc mirror "$Alias/$BucketPath" $Root --overwrite --remove
} else {
  $tmp = "C:\CHECHA_RESTORE\$(Get-Date -Format yyyyMMdd_HHmmss)"; New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  mc mirror "$Alias/$BucketPath" $tmp --overwrite
  $backup = "C:\CHECHA_BACKUP\Protocols_$(Get-Date -Format yyyyMMdd_HHmmss)"; robocopy $Root $backup /MIR | Out-Null
  robocopy $tmp  $Root  /MIR | Out-Null
}
pwsh "$Root\_index\protocol_reindex_from_files.ps1"
pwsh "$Root\_index\protocol_validate.ps1"
pwsh "$Root\_index\Check-Index.ps1"