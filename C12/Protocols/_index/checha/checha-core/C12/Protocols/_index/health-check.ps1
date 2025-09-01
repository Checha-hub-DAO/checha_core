param(
  [switch]$Json,
  [string]$Repo          = 'C:\CHECHA_CORE\C12\Protocols',
  [string]$BucketPrefix  = 'checha/checha-core/C12/Protocols'
)

$ErrorActionPreference = 'Stop'

# --- helpers ---
function Try-GetCommand($name, [string[]]$fallbacks) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in $fallbacks) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return $null
}
function Get-DirStats([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]@{ Exists=$false; Count=0; Bytes=0 } }
  $files = Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction SilentlyContinue
  $sz = ($files | Measure-Object Length -Sum).Sum
  return [pscustomobject]@{ Exists=$true; Count=($files.Count); Bytes=([int64]($sz ? $sz : 0)) }
}
function HumanSize([long]$n) {
  if ($n -lt 1024) { return "$n B" }
  $u=@('KiB','MiB','GiB','TiB'); $i=0; $v=[double]$n/1024
  while ($v -ge 1024 -and $i -lt $u.Count-1) { $v/=1024; $i++ }
  '{0:0.##} {1}' -f $v, $u[$i]
}
function Row($k,$v){ '{0,-28} {1}' -f $k, $v }

# --- paths ---
$IndexDir = Join-Path $Repo '_index'
$LogDir   = Join-Path $IndexDir 'logs'
$StageDir = Join-Path $IndexDir 'stage'
$OutDir   = Join-Path $IndexDir 'out'
$TableCsv = Join-Path $OutDir 'protocols_table.csv'

# --- collect ---
$issues = New-Object System.Collections.Generic.List[string]
$now = Get-Date

# 1) Scheduled Tasks
$tasksInfo = @()
try {
  $tasks = Get-ScheduledTask -TaskName 'CHECHA_PROTOCOLS_DAILY','CHECHA_PROTOCOLS_ONDEMAND' -ErrorAction Stop
  foreach($t in $tasks){
    $i = $t | Get-ScheduledTaskInfo
    $tasksInfo += [pscustomobject]@{
      TaskName = $t.TaskName
      LastRunTime = $i.LastRunTime
      NextRunTime = $i.NextRunTime
      LastTaskResult = $i.LastTaskResult
    }
    if ($i.LastTaskResult -ne 0) { $issues.Add("Task $($t.TaskName) last result: $($i.LastTaskResult)") }
  }
} catch {
  $issues.Add("Cannot read Scheduled Tasks: " + $_.Exception.Message)
}

# 2) Logs (latest)
function LatestLog($mask){
  $f = Get-ChildItem -LiteralPath $LogDir -Filter $mask -File -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($f) { return [pscustomobject]@{ Name=$f.Name; Path=$f.FullName; Time=$f.LastWriteTime; Size=$f.Length } }
  return $null
}
$logTask   = LatestLog 'Task-Runner_*.log'
$logDaily  = LatestLog 'Run-Daily_*.log'
$logStdOut = Join-Path $LogDir 'mc_stdout.txt'
$logStdErr = Join-Path $LogDir 'mc_stderr.txt'

$mcOutSz = 0
$mcErrSz = 0
if (Test-Path -LiteralPath $logStdOut) { $mcOutSz = (Get-Item -LiteralPath $logStdOut).Length }
if (Test-Path -LiteralPath $logStdErr) { $mcErrSz = (Get-Item -LiteralPath $logStdErr).Length }

# 3) Table freshness
$tableInfo = $null
if (Test-Path -LiteralPath $TableCsv) {
  $fi = Get-Item -LiteralPath $TableCsv
  $age = New-TimeSpan -Start $fi.LastWriteTime -End $now
  $tableInfo = [pscustomobject]@{ Path=$fi.FullName; LastWriteTime=$fi.LastWriteTime; Size=$fi.Length; AgeHours=[int][math]::Round($age.TotalHours) }
  if ($age.TotalHours -gt 48) { $issues.Add("protocols_table.csv is older than 48h") }
} else {
  $issues.Add("protocols_table.csv not found")
}

# 4) Staging
$stageStats = Get-DirStats $StageDir
if (-not $stageStats.Exists) { $issues.Add("Staging dir missing: $StageDir") }

# 5) MinIO & bucket
if (-not $env:MC_CONFIG_DIR) { $env:MC_CONFIG_DIR = 'C:\CHECHA_CORE\.mc' }  # unify
$mcExe = Try-GetCommand 'mc' @('C:\Program Files\MinIO\mc.exe','C:\Tools\minio\mc.exe')
$bucketSummary = $null
$bucketBadItems = @()
$tplRootExists = $false
if ($mcExe) {
  try {
    $summaryText = & $mcExe ls --recursive --summarize $BucketPrefix 2>$null
    $ts = ($summaryText | Where-Object { $_ -like 'Total Size:*' } | Select-Object -Last 1)
    $to = ($summaryText | Where-Object { $_ -like 'Total Objects:*' } | Select-Object -Last 1)
    $bucketSummary = [pscustomobject]@{
      TotalSizeLine    = $ts
      TotalObjectsLine = $to
    }
  } catch {
    $issues.Add("mc ls failed: " + $_.Exception.Message)
  }
  try {
    $all = & $mcExe find $BucketPrefix --print 2>$null
    if ($all) {
      # Normalize lines to alias-style paths even for filesystem aliases
      $prefixNorm = ($BucketPrefix.TrimEnd('/'))
      $norm = @()
      foreach($line in $all){
        $s = ($line.Trim() -replace '\\','/')
        if (-not $s) { continue }
        # Strip drive letter if present
        $s = $s -replace '^[A-Za-z]:(/|\\)?',''
        # If it's a local path that contains our alias subtree, cut everything before it
        $idx = $s.IndexOf('/checha/checha-core/C12/Protocols')
        if ($idx -ge 0) { $s = $s.Substring($idx + 1) } # +1 to drop leading '/'
        # Ensure it starts with the alias prefix when applicable
        if ($s.StartsWith('checha/checha-core/C12/Protocols')) {
          $s = $s
        } elseif ($s.StartsWith("/checha/checha-core/C12/Protocols")) {
          $s = $s.TrimStart('/')
        }
        $norm += $s
      }

      # Build relative keys under the prefix
      $relPaths = @()
      foreach($s in $norm){
        if ($s -eq $prefixNorm -or $s -eq "$prefixNorm/") { continue } # skip marker
        if ($s.StartsWith("$prefixNorm/")) {
          $rel = $s.Substring($prefixNorm.Length+1)
        } else {
          continue
        }
        if (-not [string]::IsNullOrWhiteSpace($rel)) { $relPaths += $rel }
      }

      $prefixNorm = ($BucketPrefix.TrimEnd('/'))
      $relPaths = @()
      foreach ($line in $all) {
        $s = ($line.Trim() -replace '\\','/')
        if (-not $s) { continue }
        if ($s -eq $prefixNorm -or $s -eq "$prefixNorm/") { continue } # skip prefix marker
        if ($s.StartsWith("$prefixNorm/")) { $rel = $s.Substring($prefixNorm.Length+1) } else { $rel = $s }
        if (-not [string]::IsNullOrWhiteSpace($rel)) { $relPaths += $rel }
      }
      $reService   = '/_index/|/\.(git|github|vscode)/'
      $reRecursion = '(^|/)(checha|checha-core)(/|$)'
      $bad = $relPaths | Where-Object { $_ -match $reService -or $_ -match $reRecursion }
      $bucketBadItems = $bad | Select-Object -First 10
      if ($bucketBadItems.Count -gt 0) { $issues.Add("Bucket contains service/recursive paths (first 10 shown)") }
      $tplRootExists = ($relPaths | Where-Object { $_ -match '^PROTOCOL_TEMPLATE\.md$' }).Count -gt 0
      if ($tplRootExists) { $issues.Add("Root PROTOCOL_TEMPLATE.md present in bucket") }
    }
  } catch {
    $issues.Add("mc find failed: " + $_.Exception.Message)
  }
} else {
  $issues.Add("mc not found; set PATH or install MinIO client")
}

# --- assemble report ---
$report = [pscustomobject]@{
  TimeUtc     = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  Repo        = $Repo
  Stage       = [pscustomobject]@{ Path=$StageDir; Exists=$stageStats.Exists; Files=$stageStats.Count; SizeBytes=$stageStats.Bytes; Size=HumanSize($stageStats.Bytes) }
  Table       = if ($tableInfo) { [pscustomobject]@{ Path=$tableInfo.Path; LastWriteTime=$tableInfo.LastWriteTime; AgeHours=$tableInfo.AgeHours; SizeBytes=$tableInfo.Size; Size=HumanSize($tableInfo.Size) } } else { $null }
  Tasks       = $tasksInfo
  Logs        = [pscustomobject]@{
                  LatestTaskRunner = $logTask
                  LatestRunDaily   = $logDaily
                  McStdoutBytes    = $mcOutSz
                  McStderrBytes    = $mcErrSz
                }
  MinIO       = [pscustomobject]@{
                  McPath        = $mcExe
                  MC_CONFIG_DIR = $env:MC_CONFIG_DIR
                  BucketPrefix  = $BucketPrefix
                  Summary       = $bucketSummary
                  BadItems      = $bucketBadItems
                  RootTpl       = $tplRootExists
                }
  Issues      = $issues
  Ok          = ($issues.Count -eq 0)
}

# --- output ---
if ($Json) {
  $report | ConvertTo-Json -Depth 6
} else {
  Write-Host "=== HEALTH CHECK: C12/Protocols ==="
  Write-Host (Row 'Time (UTC)' $report.TimeUtc)
  Write-Host (Row 'Repo' $report.Repo)
  Write-Host (Row 'Stage' $report.Stage.Path)
  Write-Host (Row 'Stage exists' $report.Stage.Exists)
  Write-Host (Row 'Stage files' $report.Stage.Files)
  Write-Host (Row 'Stage size'  $report.Stage.Size)
  if ($report.Table) {
    Write-Host (Row 'Table age (h)' $report.Table.AgeHours)
    Write-Host (Row 'Table size'    $report.Table.Size)
  } else {
    Write-Host (Row 'Table' 'NOT FOUND')
  }
  foreach($t in $report.Tasks){
    Write-Host (Row ("Task "+$t.TaskName) ("rc="+$t.LastTaskResult+" Next="+$t.NextRunTime))
  }
  Write-Host (Row 'MC_CONFIG_DIR' $report.MinIO.MC_CONFIG_DIR)
  $mcPathText = if ($report.MinIO.McPath) { $report.MinIO.McPath } else { 'NOT FOUND' }
  Write-Host (Row 'mc.exe' $mcPathText)
  if ($report.MinIO.Summary) {
    Write-Host (Row 'Bucket' $report.MinIO.BucketPrefix)
    Write-Host (Row 'Summary' ($report.MinIO.Summary.TotalSizeLine + ", " + $report.MinIO.Summary.TotalObjectsLine))
  }
  if ($report.MinIO.BadItems.Count -gt 0) {
    Write-Host "`nSuspicious items in bucket (first 10):"
    $report.MinIO.BadItems | ForEach-Object { Write-Host "  $_" }
  }
  if ($report.Issues.Count -gt 0) {
    Write-Host "`nISSUES:"
    $report.Issues | ForEach-Object { Write-Host " - $_" }
  } else {
    Write-Host "`nOK: no issues detected."
  }
}

# Exit code for CI/Task usage
if ($report.Ok) { exit 0 } else { exit 1 }
