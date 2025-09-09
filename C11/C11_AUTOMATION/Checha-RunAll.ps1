function Checha-RunAll {
  [CmdletBinding()]
  param(
    [string[]]$Only,                 # напр.: -Only StrategicReports,Releases або -Only "StrategicReports,Releases"
    [switch]$Force,                  # прокидується у пайплайни
    [int]$StatusTake = 5,            # скільки позицій показати у статусі
    [switch]$SkipDashboard,          # пропустити Update-VaultDashboard.ps1
    [switch]$UpdatePanel,            # оновити C06_FOCUS\CONTROL_PANEL.md
    [string]$PanelScriptPath = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Update-ControlPanel.ps1",
    [string]$Root = "C:\CHECHA_CORE",
    [switch]$NoTranscript,           # не вести окремий лог-транскрипт
    [int]$ErrorExitCode = 1          # код виходу при помилках
  )

  # --- helpers ------------------------------------------------------------
  function Save-RunAllStatus {
    param(
      [string]$Root,
      [bool]$Ok,
      [double]$DurationSec,
      [string[]]$Only,
      [bool]$Force,
      [string]$User
    )
    try {
      $path = Join-Path $Root "C06_FOCUS\_runall_status.json"
      $obj = [ordered]@{
        ts           = (Get-Date).ToString("o")  # ISO 8601
        ok           = $Ok
        # інваріантне форматування з крапкою:
        duration_sec = $DurationSec.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture)
        only         = if ($Only) { @($Only) } else { @() }
        force        = [bool]$Force
        user         = $User
      }
      $json = ($obj | ConvertTo-Json -Depth 5)
      # Запис у UTF-8 з BOM
      [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($true))
    } catch {
      Write-Warning "Save-RunAllStatus ERR: $($_.Exception.Message)"
    }
  }

  # ------------------------------------------------------------------------
  $ErrorActionPreference = 'Stop'
  $cfg    = "C:\CHECHA_CORE\C11\C11_AUTOMATION\config\checha_shelves.json"
  $run    = "C:\CHECHA_CORE\C11\C11_AUTOMATION\Run-ChechaPipelines.ps1"
  $dash   = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Update-VaultDashboard.ps1"
  $logDir = Join-Path $Root "C03\LOG"

  # Приймаємо -Only "A,B"
  if ($Only -and $Only.Count -eq 1 -and $Only[0] -match ',') {
    $Only = $Only[0].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  }

  $hadErr = $false
  $global:LASTEXITCODE = 0

  # --- Transcript лог (опційно) ---
  $tsPath = Join-Path $logDir ("run_all_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
  if (-not $NoTranscript) {
    try {
      if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
      Start-Transcript -Path $tsPath -Append -ErrorAction Stop | Out-Null
    } catch {}
  }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  try {
    # --- Пайплайни ---
    if ($Only -and $Only.Count -gt 0) {
      & $run -ConfigPath $cfg -Only $Only -Force:$Force
    } else {
      & $run -ConfigPath $cfg          -Force:$Force
    }
    if ($LASTEXITCODE -ne 0) { throw "Pipeline exited $LASTEXITCODE" }
    Write-Host "PIPELINE OK"
  }
  catch {
    $hadErr = $true
    Write-Warning "PIPELINE ERR: $($_.Exception.Message)"
  }

  # --- Дашборд (якщо не пропущено) ---
  if (-not $SkipDashboard) {
    try { & $dash; Write-Host "DASHBOARD OK" }
    catch { $hadErr = $true; Write-Warning "DASHBOARD ERR: $($_.Exception.Message)" }
  }

  # --- Статус (якщо є команда) ---
  try {
    $statusCmd = Get-Command Show-ChechaStatus -ErrorAction SilentlyContinue
    if ($statusCmd) { Show-ChechaStatus -Take $StatusTake }
    else { Write-Verbose "Show-ChechaStatus is not available in this session." }
  } catch { $hadErr = $true; Write-Warning "STATUS ERR: $($_.Exception.Message)" }

  $sw.Stop()

  # --- Запис _runall_status.json (інваріант) ---
  $duration = $sw.Elapsed.TotalSeconds
  $okFlag   = -not $hadErr
  $user     = $env:USERNAME
  Save-RunAllStatus -Root $Root -Ok:$okFlag -DurationSec $duration -Only $Only -Force:$Force -User $user

  # --- Оновлення CONTROL_PANEL.md (опційно, вже після статусу) ---
  if ($UpdatePanel) {
    try {
      if (Test-Path $PanelScriptPath) {
        & $PanelScriptPath
        if ($LASTEXITCODE -ne 0) { throw "Update-ControlPanel exited $LASTEXITCODE" }
        Write-Host "CONTROL_PANEL OK"
      } else {
        throw "Panel script not found: $PanelScriptPath"
      }
    } catch { $hadErr = $true; Write-Warning "CONTROL_PANEL ERR: $($_.Exception.Message)" }
  }

  if (-not $NoTranscript) {
    try { Stop-Transcript | Out-Null } catch {}
  }

  # Інваріантний друк тривалості у консолі
  $durStr = $duration.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture)

  if ($hadErr) {
    Write-Host ("Checha-RunAll: completed with issues in {0}s." -f $durStr)
    exit $ErrorExitCode
  } else {
    Write-Host ("Checha-RunAll: ALL GREEN ✅ in {0}s." -f $durStr)
    exit 0
  }
}
