Param([string]$Root="C:\CHECHA_CORE")
$ErrorActionPreference='Stop'
function Get-Field([string]$Text,[string]$Name){
  $rx = "(?m)^\s*-\s*$([regex]::Escape($Name)):\s*(.+?)\s*$"
  if($Text -match $rx){ return $Matches[1].Trim() } else { return $null }
}

$reg   = Join-Path $Root "C08_COORD\REGISTRY"
$outDir= Join-Path $Root "C08_COORD\INIT_MAP\REPORTS"
$null = New-Item -ItemType Directory -Force -Path $outDir
$out   = Join-Path $outDir "city_aggregates.csv"

$rows = @()
Get-ChildItem -Path $reg -Recurse -Filter 'CELL_PASSPORT.md' -ErrorAction SilentlyContinue | ForEach-Object {
  $t = Get-Content $_.FullName -Raw -Encoding UTF8
  $city   = Get-Field $t 'City'
  $type   = Get-Field $t 'Type'
  $status = Get-Field $t 'Status'
  if($city){ $rows += [pscustomobject]@{ city=$city; type=$type; status=$status } }
}

$grp = $rows | Group-Object city, type, status | ForEach-Object {
  [pscustomobject]@{ city=$_.Group[0].city; type=$_.Group[0].type; status=$_.Group[0].status; count=$_.Count }
}

"city,type,status,count" | Out-File -Encoding UTF8 -FilePath $out
$grp | ForEach-Object { "{0},{1},{2},{3}" -f $_.city,$_.type,$_.status,$_.count } | Add-Content -Encoding UTF8 -Path $out
Add-Content -Encoding UTF8 -Path (Join-Path $Root "C03_LOG\initmap.log") -Value ("{0} [INFO ] Anonymize-Cells: wrote {1} (rows={2})" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $out, ($grp | Measure-Object).Count)
