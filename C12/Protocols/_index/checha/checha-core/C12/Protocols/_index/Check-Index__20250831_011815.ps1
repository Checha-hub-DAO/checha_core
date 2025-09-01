param([string]$IndexPath = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.json")
$raw = Get-Content $IndexPath -Raw
$cntRaw = ([regex]::Matches($raw, '"id"\s*:')).Count
$j = ConvertFrom-Json -InputObject $raw
$items = @($j.protocols)
$cnt = $items.Count
Write-Host "IDs in raw JSON: $cntRaw | Parsed count: $cnt" -ForegroundColor Green
$items | Sort-Object id | Format-Table id,topic,status,updated_at -AutoSize