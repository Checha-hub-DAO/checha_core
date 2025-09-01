param(
  [Parameter(Mandatory)][string]$Query,
  [string]$IndexPath = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.json"
)
$q = $Query.ToLower()
$j = Get-Content $IndexPath -Raw | ConvertFrom-Json
@($j.protocols) |
  ? { $_.id -like "*$Query*" -or $_.topic.ToLower().Contains($q) -or (($_.tags -join ",").ToLower().Contains($q)) } |
  Sort-Object updated_at -Descending |
  Format-Table id,topic,status,updated_at -AutoSize