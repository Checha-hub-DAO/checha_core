<# ======================================================================
  Update-ControlPanel.ps1 — v1.2.2
  Оновлює плейсхолдери у C06_FOCUS\CONTROL_PANEL.md реальними даними.

  Ключові можливості:
  - {{STATUS_BADGE}}: 🟢 (свіже і ok), 🟡 (застаріле >24h), 🟠 (ok=false)
  - {{AUTO:last_runall}}: читає C06_FOCUS\_runall_status.json, форматує тривалість інваріантно (0.0s)
  - Запис у UTF-8 BOM (щоб уникнути «кракозябр»)
  - Unescape-Legacy: прибирає \[ \. \( \) та інші старі екранування
  - Replace-Token: не екранує значення (щоб не плодити слеші в маркдауні)
====================================================================== #>

[CmdletBinding()]
param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$PanelRel = "C06_FOCUS\CONTROL_PANEL.md",
  [switch]$VerboseLog
)

# ------------------------ Helpers ------------------------

function Get-LatestFileLine {
  param([Parameter(Mandatory)][string]$Dir,[string]$Filter="*",[int]$Tail=1)
  if (-not (Test-Path $Dir)) { return $null }
  $f = Get-ChildItem $Dir -Filter $Filter -File | Sort-Object LastWriteTime -Desc | Select-Object -First 1
  if (-not $f) { return $null }
  try { return (Get-Content $f.FullName -Tail $Tail -Encoding UTF8) -join "`n" } catch { return $null }
}

function Get-LatestFilePath {
  param([Parameter(Mandatory)][string]$Dir,[string]$Filter="*")
  if (-not (Test-Path $Dir)) { return $null }
  (Get-ChildItem $Dir -Filter $Filter -File | Sort-Object LastWriteTime -Desc | Select-Object -First 1)?.FullName
}

function Parse-DesktopHealth {
  param([string]$DashboardPath)
  if (-not (Test-Path $DashboardPath)) { return $null }
  $tail = Get-Content $DashboardPath -Tail 50 -Encoding UTF8 | Where-Object { $_ -match 'Desktop health' }
  if (-not $tail) { return $null }
  ($tail | Select-Object -Last 1).Trim()
}

function Extract-AlertsFromLog {
  param([string]$LogDir)
  if (-not (Test-Path $LogDir)) { return @() }
  $latest = Get-ChildItem $LogDir -Filter *.log -File | Sort-Object LastWriteTime -Desc | Select-Object -First 5
  $alerts = @()
  foreach ($lf in $latest) {
    try {
      $lines = Get-Content $lf.FullName -Tail 500 -Encoding UTF8
      $alerts += $lines | Where-Object { $_ -match '(?i)(error|err;|warning|warn;|critical|fatal|помилка|увага|крити|⚠️|❗)' }
    } catch {}
  }
  $alerts | Select-Object -First 5
}

function Get-GitStatus {
  param([string]$LogDir)
  $line = Get-LatestFileLine -Dir $LogDir -Filter "git_sync_*.log" -Tail 5
  if ($line) { (($line -split "`n") | Select-Object -Last 1).Trim() } else { $null }
}

function Get-VaultStatus {
  param([string]$VaultReadme)
  if (-not (Test-Path $VaultReadme)) { return $null }
  $head = Get-Content $VaultReadme -TotalCount 60 -Encoding UTF8
  $updated = ($head | Where-Object { $_ -match 'Останнє оновлення' } | Select-Object -First 1)
  $lastRow = ($head | Where-Object { $_ -match '^\|\s*20\d{2}-\d{2}-\d{2}\s*\|' } | Select-Object -First 1)
  if ($updated -or $lastRow) { @($updated, $lastRow) -join " | " } else { $null }
}

function Get-AgentsStatus {
  param([string]$AgentsRoot)
  if (-not (Test-Path $AgentsRoot)) { return $null }
  $dirs = Get-ChildItem $AgentsRoot -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
  if ($dirs) { "Агенти: " + (($dirs | Select-Object -First 8) -join ", ") } else { $null }
}

function Get-PipelineStatus {
  param([string]$AgentsRoot)
  $reportsDir = Join-Path $env:SystemDrive "CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\reports"
  if (Test-Path $reportsDir) {
    $f = Get-LatestFilePath -Dir $reportsDir -Filter "Strateg_Report_*.md"
    if ($f) { return "Останній стратегічний: $(Split-Path $f -Leaf)" }
  }
  $logDir = Join-Path $env:SystemDrive "CHECHA_CORE\C03\LOG"
  $line = Get-LatestFileLine -Dir $logDir -Filter "*pipeline*.log" -Tail 1
  if ($line) { return $line }
  $null
}

function Unescape-Legacy {
  param([string]$s)
  if (-not $s) { return $s }
  $s = $s -replace '\\\.', '.' `
           -replace '\\\:', ':' `
           -replace '\\\-', '-' `
           -replace '\\\)', ')' `
           -replace '\\\(', '(' `
           -replace '\\\]', ']' `
           -replace '\\\[', '[' `
           -replace '\\\\', '\'
  return $s
}

function Replace-Token {
  param(
    [Parameter(Mandatory)][string]$Text,
    [Parameter(Mandatory)][string]$Token,
    [Parameter(Mandatory)][string]$Value
  )
  # Екрануємо лише токен, значення підставляємо «як є» (окрім $ → $$)
  $pattern = [regex]::Escape($Token)
  $safe    = $Value -replace '\$','$$'
  return ($Text -replace $pattern, $safe)
}

function Fix-MdPathSlashes {
  param([string]$s)
  if (-not $s) { return $s }
  # Замінюємо \ на / тільки в частині ( ... ) після [...]:
  return ($s -replace '(\[[^\]]*\]\()([^)]+)\)', {
    $open  = $matches[1]
    $path  = $matches[2] -replace '\\','/'
    "$open$path)"
  })
}

# Форматує duration як "0.0s" з крапкою незалежно від локалі
function Format-Duration {
  param([double]$Seconds)
  return $Seconds.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture) + "s"
}

# Читає _runall_status.json і повертає:
# - рядок для {{AUTO:last_runall}}
# - бейдж для {{STATUS_BADGE}}: 🟢 / 🟡 / 🟠
function Get-RunAllInfo {
  param([string]$Root)
  $jsonPath = Join-Path $Root "C06_FOCUS\_runall_status.json"
  if (-not (Test-Path $jsonPath)) { return @{'line'='n/a'; 'badge'='🟡 застаріло'} }
  try {
    $obj = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $obj.ts) { return @{'line'='n/a'; 'badge'='🟡 застаріло'} }

    $ts    = Get-Date $obj.ts
    $stamp = $ts.ToString("yyyy-MM-dd HH:mm:ss")
    $isOk  = [bool]$obj.ok
    $ageH  = (New-TimeSpan -Start $ts -End (Get-Date)).TotalHours

    # duration може бути рядком або числом
    $durVal = $null
    if ($obj.PSObject.Properties.Name -contains 'duration_sec' -and $obj.duration_sec -ne $null) {
      try { $durVal = [double]$obj.duration_sec } catch { $durVal = $null }
    }
    $durStr = if ($durVal -ne $null) { Format-Duration -Seconds $durVal } else { "n/a" }

    $only  = if ($obj.only -and $obj.only.Count -gt 0) { "Only: " + ($obj.only -join ", ") } else { $null }
    $force = if ($obj.force) { "Force: on" } else { $null }
    $by    = if ($obj.user) { "User: $($obj.user)" } else { $null }

    $parts = @("$stamp — " + ($(if ($isOk) {"ALL GREEN ✅"} else {"issues ⚠️"})), "• $durStr", $only, $force, $by) `
             | Where-Object { $_ } | ForEach-Object { $_ }

    $line  = ($parts -join "  ")

    # Логіка бейджа:
    # - 🟠 якщо ok=false
    # - 🟡 якщо старше 24 год
    # - 🟢 інакше
    $badge = if (-not $isOk) { "🟠 є питання" } elseif ($ageH -gt 24) { "🟡 застаріло" } else { "🟢 стабільно" }

    return @{'line' = $line; 'badge' = $badge}
  } catch {
    return @{'line'='n/a'; 'badge'='🟡 застаріло'}
  }
}

# ------------------------ Main ------------------------

$panelPath = Join-Path $Root $PanelRel
if (-not (Test-Path $panelPath)) {
  Write-Error "CONTROL_PANEL.md не знайдено: $panelPath"
  exit 1
}

$now      = Get-Date
$isoDate  = $now.ToString('yyyy-MM-dd')
$weekNum  = [System.Globalization.ISOWeek]::GetWeekOfYear($now)
$weekStr  = "{0:D2}-{1}" -f $weekNum, $now.Year

$logDir      = Join-Path $Root "C03\LOG"
$dashMd      = Join-Path $Root "RHYTHM_DASHBOARD.md"
$vaultReadme = Join-Path $Root "C12\Vault\StrategicReports\README.md"
$agentsRoot  = Join-Path $Root "C11\C11_AUTOMATION\AGENTS"

$desktopHealth = Parse-DesktopHealth -DashboardPath $dashMd
$lastLogLine   = Get-LatestFileLine -Dir $logDir -Filter "*.log" -Tail 1
$alerts        = Extract-AlertsFromLog -LogDir $logDir
$gitStatus     = Get-GitStatus -LogDir $logDir
$vaultStatus   = Get-VaultStatus -VaultReadme $vaultReadme
$agentsStatus  = Get-AgentsStatus -AgentsRoot $agentsRoot
$pipelineStat  = Get-PipelineStatus -AgentsRoot $agentsRoot
$runAllInfo    = Get-RunAllInfo  -Root $Root

# Значення за замовчуванням
if (-not $desktopHealth) { $desktopHealth = "n/a" }
if (-not $lastLogLine)   { $lastLogLine   = "n/a" }
if (-not $gitStatus)     { $gitStatus     = "n/a" }
if (-not $vaultStatus)   { $vaultStatus   = "n/a" }
if (-not $agentsStatus)  { $agentsStatus  = "n/a" }
if (-not $pipelineStat)  { $pipelineStat  = "n/a" }

$alertsStr = if ($alerts -and $alerts.Count -gt 0) { ($alerts -join " ⎯ ") } else { "нема" }

# Прибираємо спадкові екранування
$desktopHealth = Unescape-Legacy $desktopHealth
$lastLogLine   = Unescape-Legacy $lastLogLine
$alertsStr     = Unescape-Legacy $alertsStr
$gitStatus     = Unescape-Legacy $gitStatus
$vaultStatus   = Unescape-Legacy $vaultStatus
$agentsStatus  = Unescape-Legacy $agentsStatus
$pipelineStat  = Unescape-Legacy $pipelineStat
$lastRunAll    = Unescape-Legacy $runAllInfo['line']
$statusBadge   = $runAllInfo['badge']

# Підстановка плейсхолдерів
$text = Get-Content $panelPath -Raw -Encoding UTF8
$text = Replace-Token -Text $text -Token "{{DATE}}"                 -Value $isoDate
$text = Replace-Token -Text $text -Token "{{WEEK}}"                 -Value $weekStr
$text = Replace-Token -Text $text -Token "{{AUTO:desktop_health}}"  -Value $desktopHealth
$text = Replace-Token -Text $text -Token "{{AUTO:last_log}}"        -Value $lastLogLine
$text = Replace-Token -Text $text -Token "{{AUTO:alerts}}"          -Value $alertsStr
$text = Replace-Token -Text $text -Token "{{AUTO:git_status}}"      -Value $gitStatus
$text = Replace-Token -Text $text -Token "{{AUTO:vault_status}}"    -Value $vaultStatus
$text = Replace-Token -Text $text -Token "{{AUTO:agents_status}}"   -Value $agentsStatus
$text = Replace-Token -Text $text -Token "{{AUTO:last_pipeline}}"   -Value $pipelineStat
$text = Replace-Token -Text $text -Token "{{AUTO:last_runall}}"     -Value $lastRunAll
$text = Replace-Token -Text $text -Token "{{STATUS_BADGE}}"         -Value $statusBadge

# Запис у UTF-8 BOM
[System.IO.File]::WriteAllText($panelPath, $text, [System.Text.UTF8Encoding]::new($true))

if ($VerboseLog) {
  Write-Host "DATE: $isoDate"
  Write-Host "WEEK: $weekStr"
  Write-Host "desktop_health: $desktopHealth"
  Write-Host "last_log: $lastLogLine"
  Write-Host "alerts: $alertsStr"
  Write-Host "git_status: $gitStatus"
  Write-Host "vault_status: $vaultStatus"
  Write-Host "agents_status: $agentsStatus"
  Write-Host "last_pipeline: $pipelineStat"
  Write-Host "last_runall: $lastRunAll"
  Write-Host "status_badge: $statusBadge"
}
Write-Host "✅ CONTROL_PANEL.md оновлено"
