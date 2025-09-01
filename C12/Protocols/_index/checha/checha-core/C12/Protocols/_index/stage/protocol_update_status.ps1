param(
  [Parameter(Mandatory=$true)][string]$Id,
  [Parameter(Mandatory=$true)][ValidateSet("draft","active","archived","closed")] [string]$NewStatus,
  [string]$Root = "C:\CHECHA_CORE\C12\Protocols",
  [string]$IndexPath = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.json"
)
$ErrorActionPreference = "Stop"
$j = Get-Content $IndexPath -Raw | ConvertFrom-Json
$p = @($j.protocols) | Where-Object { $_.id -ieq $Id }
if(-not $p){ throw "Protocol not found: $Id" }
$src = Join-Path $Root ($p.path -replace '^[\\/]+','' -replace '/','\')
$destDir = Join-Path $Root $NewStatus
if(!(Test-Path $destDir)){ New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
$dest = Join-Path $destDir (Split-Path $src -Leaf)
if(Test-Path $src){ Move-Item $src $dest -Force }
# оновити YAML у файлі
$txt = Get-Content $dest -Raw
$nowIso = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
if($txt -match '(?s)^\s*---\s*(.*?)\s*---'){
  $fm = $matches[1]
  $fm = ($fm -replace '(?m)^\s*status\s*:\s*.*$', "status: $NewStatus")
  if($fm -notmatch '(?m)^\s*status\s*:'){ $fm = $fm.TrimEnd() + "`nstatus: $NewStatus" }
  $fm = ($fm -replace '(?m)^\s*updated_at\s*:\s*.*$', "updated_at: $nowIso")
  if($fm -notmatch '(?m)^\s*updated_at\s*:'){ $fm = $fm.TrimEnd() + "`nupdated_at: $nowIso" }
  $txt = $txt -replace '(?s)^\s*---\s*.*?\s*---', ("---`n{0}`n---" -f $fm)
} else {
  $txt = ("---`nstatus: $NewStatus`nupdated_at: $nowIso`n---`n`n") + $txt
}
$enc = New-Object System.Text.UTF8Encoding($true)
[IO.File]::WriteAllText($dest,$txt,$enc)
Write-Host ("✅ [{0}] статус → {1} | файл: {2}" -f $Id,$NewStatus,$dest) -ForegroundColor Green
# авто-реіндекс
& (Join-Path $Root "_index\protocol_reindex_from_files.ps1") | Out-Null