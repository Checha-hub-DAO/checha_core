[CmdletBinding()]
param(
  [string]$ConfigPath = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\checha_matrix_config.json"
)
$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# Ensure tasks.json exists (seed if needed)
$tasksJson = $cfg.G04.TasksJson
$tasksDir  = Split-Path $tasksJson
if(-not (Test-Path $tasksDir)){ New-Item -ItemType Directory -Path $tasksDir | Out-Null }
if(-not (Test-Path $tasksJson)){
  $seed = @{
    updated = (Get-Date).ToString("s")
    critical_48h = @(@{ id="G04-1"; title="Підтвердити реліз C12 Docs"; owner="core"; due=(Get-Date).AddDays(2).ToString("yyyy-MM-dd"); link="" })
    urgent_7d    = @(@{ id="G04-2"; title="Наповнити галереї ETHNO";     owner="media"; due=(Get-Date).AddDays(5).ToString("yyyy-MM-dd"); link="" })
    planned_30d  = @(@{ id="G04-3"; title="Автоматизувати CHECKSUMS у C12"; owner="auto"; due=(Get-Date).AddDays(25).ToString("yyyy-MM-dd"); link="" })
  } | ConvertTo-Json -Depth 6
  [IO.File]::WriteAllText($tasksJson, $seed, [Text.Encoding]::UTF8)
}

$tasks = Get-Content $tasksJson -Raw | ConvertFrom-Json

$summary = @{
  ts = (Get-Date).ToString("s")
  counts = @{
    critical_48h = ($tasks.critical_48h | Measure-Object).Count
    urgent_7d    = ($tasks.urgent_7d    | Measure-Object).Count
    planned_30d  = ($tasks.planned_30d  | Measure-Object).Count
  }
  items = $tasks
}

# Ensure feeds dir
if(-not (Test-Path $cfg.Feeds.Dir)){ New-Item -ItemType Directory -Path $cfg.Feeds.Dir | Out-Null }
[IO.File]::WriteAllText($cfg.Feeds.G04Feed, ($summary | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
"OK: G04 feed -> $($cfg.Feeds.G04Feed)"