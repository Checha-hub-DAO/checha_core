Param([string]$Root="C:\CHECHA_CORE",[int]$K=5)
$ErrorActionPreference='Stop'
$in  = Join-Path $Root "C08_COORD\INIT_MAP\REPORTS\city_aggregates.csv"
$out = Join-Path $Root "C08_COORD\INIT_MAP\REPORTS\heatmap_k.json"
if(-not (Test-Path $in)){ throw "Not found: $in. Run Anonymize-Cells first." }
$lines = Import-Csv -Path $in
$pub = $lines | Where-Object { [int]$_.count -ge $K } | Select-Object city,type,status,count
$pub | ConvertTo-Json -Depth 3 | Set-Content -Path $out -Encoding UTF8
Add-Content -Encoding UTF8 -Path (Join-Path $Root "C03_LOG\initmap.log") -Value ("{0} [INFO ] Build-Heatmap: k={1} → {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $K, $out)
