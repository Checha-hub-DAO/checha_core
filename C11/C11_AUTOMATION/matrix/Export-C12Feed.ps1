[CmdletBinding()]
param(
  [string]$ConfigPath = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\checha_matrix_config.json"
)
$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$since = (Get-Date).AddDays(-1 * [int]$cfg.RecentDays)

function Get-RecentFiles($dir,$pat){
  if(-not (Test-Path $dir)){ return @() }
  Get-ChildItem -Path $dir -Recurse -File -Include $pat -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $since } |
    Select-Object FullName, Length, LastWriteTime
}

$reports = Get-RecentFiles $cfg.C12.StrategicReportsRoot @("*.md")
$docs    = Get-RecentFiles $cfg.C12.VaultRoot @("*.md","*.pdf","*.txt","*.json") |
           Where-Object { $_.FullName -notmatch [regex]::Escape($cfg.C12.StrategicReportsRoot) }

$payload = @{
  ts = (Get-Date).ToString("s")
  since = $since.ToString("s")
  counts = @{
    strategic_reports = ($reports | Measure-Object).Count
    docs = ($docs | Measure-Object).Count
  }
  strategic_reports = $reports | ForEach-Object {
    @{
      path = $_.FullName
      date = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
      rel  = $_.FullName.Replace($cfg.C12.VaultRoot, "").TrimStart("\")
    }
  }
  docs = $docs | ForEach-Object {
    @{
      path = $_.FullName
      date = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
      rel  = $_.FullName.Replace($cfg.C12.VaultRoot, "").TrimStart("\")
      size = $_.Length
    }
  }
}

if(-not (Test-Path $cfg.Feeds.Dir)){ New-Item -ItemType Directory -Path $cfg.Feeds.Dir | Out-Null }
[IO.File]::WriteAllText($cfg.Feeds.C12Feed, ($payload | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
"OK: C12 feed -> $($cfg.Feeds.C12Feed)"