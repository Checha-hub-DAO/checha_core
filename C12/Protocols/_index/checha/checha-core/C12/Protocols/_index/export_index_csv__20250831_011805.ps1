param(
  [string]$IndexPath = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.json",
  [string]$OutCsv = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.csv"
)
$j = Get-Content $IndexPath -Raw | ConvertFrom-Json
$rows = @($j.protocols) | Select-Object id,topic,status,owner,version,created_at,updated_at, @{n='tags';e={$_.tags -join ';'}}, path
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $OutCsv
Write-Host "✅ CSV збережено: $OutCsv" -ForegroundColor Green