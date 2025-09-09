<#
Run-ChechaPipelines.ps1
- Читає JSON-конфіг полиць і запускає Ingest -> Update для кожної полиці.
- Глобальний mutex-LOCK (щоб не було паралельних запусків OnLogon/Nightly).
- Лог у C03\LOG\checha_pipeline_*.log (UTF-8 BOM) + ротація.
#>

[CmdletBinding()]
param(
  [string]  $ConfigPath     = "C:\CHECHA_CORE\C11\C11_AUTOMATION\config\checha_shelves.json",
  [switch]  $DryRun,
  [switch]  $Force,
  [string[]]$Only,             # приклад: -Only StrategicReports,Releases або -Only "StrategicReports,Releases"
  [int]     $LockTimeoutSec = 180
)

$ErrorActionPreference = 'Stop'

# --- інструменти (pwsh + скрипти) ---
$Pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $Pwsh) {
  $Pwsh = "C:\Program Files\PowerShell\7\pwsh.exe"
  if (-not (Test-Path $Pwsh)) { $Pwsh = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" }
}

$Ingest = "C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\tools\Ingest-Agent-To-Vault.ps1"
$Update = "C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\tools\Update-VaultReadme.ps1"

if (-not (Test-Path $Ingest -PathType Leaf)) { throw "Tool not found: $Ingest" }
if (-not (Test-Path $Update -PathType Leaf)) { throw "Tool not found: $Update" }

# --- лог ---
$LogDir = "C:\CHECHA_CORE\C03\LOG"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$ts = Get-Date -Format "yyyy-MM-dd_HHmmss"
$LogPath = Join-Path $LogDir "checha_pipeline_$ts.log"
[System.IO.File]::WriteAllText($LogPath, "", (New-Object System.Text.UTF8Encoding($true)))

function Log([string]$m) {
  $line = "{0} {1}`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
  [System.IO.File]::AppendAllText($LogPath, $line, (New-Object System.Text.UTF8Encoding($true)))
  Write-Host $m
}

# --- LOCK (global named mutex) ---
$mtxName = "Global\CHECHA_VaultPipeline"
$mtx     = New-Object System.Threading.Mutex($false, $mtxName)
$hasLock = $false

try {
  Log ("BEGIN Run-ChechaPipelines; Config={0}; DryRun={1}; Force={2}; Pwsh={3}" -f $ConfigPath,$DryRun.IsPresent,$Force.IsPresent,$Pwsh)

  if (-not $mtx.WaitOne([TimeSpan]::FromSeconds($LockTimeoutSec))) {
    throw "Lock timeout ($LockTimeoutSec s): інша інстанція вже працює."
  }
  $hasLock = $true
  Log ("LOCK acquired: {0}" -f $mtxName)

  if (-not (Test-Path $ConfigPath -PathType Leaf)) { throw "Config not found: $ConfigPath" }
  $json = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $json) { throw "Empty/invalid JSON: $ConfigPath" }

  # Нормалізація -Only: приймаємо і масив, і "a,b,c"
  $onlyList = @()
  if ($PSBoundParameters.ContainsKey('Only') -and $Only) {
    foreach ($o in $Only) { $onlyList += ($o -split '\s*,\s*' | Where-Object { $_ }) }
  }

  $targets = if ($onlyList.Count -gt 0) {
    $json | Where-Object { $_.name -in $onlyList }
  } else {
    $json
  }

  if (-not $targets) {
    Log ("[i] No matching shelves (Only={0}). END." -f ($onlyList -join ','))
    return
  }

  Log ("Targets: {0}" -f ($targets.name -join ', '))

  foreach ($s in $targets) {
    $name   = [string]$s.name
    $title  = [string]$s.title
    $vault  = [string]$s.vault
    $agents = [string]$s.agents
    $pat    = [string]$s.pattern
    $take   = [int]   $s.take
    $drgx   = if ($s.PSObject.Properties['dateRegex']) { [string]$s.dateRegex } else { $null }

    if ([string]::IsNullOrWhiteSpace($vault) -or [string]::IsNullOrWhiteSpace($agents)) {
      throw "Invalid shelf '$name': vault/agents not set."
    }

    # гарантуємо теки
    New-Item -ItemType Directory -Path $vault  -Force | Out-Null
    New-Item -ItemType Directory -Path $agents -Force | Out-Null

    # --- INGEST ---
    Log ("INGEST [{0}]  {1} -> {2}  ({3})" -f $name,$agents,$vault,$pat)
    $ingestArgs = @(
      '-NoProfile','-ExecutionPolicy','Bypass','-File',$Ingest,
      '-AgentsDir',$agents,'-VaultDir',$vault,'-Pattern',$pat
    )
    if ($Force) { $ingestArgs += '-Force' }
    if ($DryRun){ $ingestArgs += '-DryRun' }

    & $Pwsh @ingestArgs
    if ($LASTEXITCODE -ne 0) { throw "Ingest failed ($name): exit $LASTEXITCODE" }
    Log ("INGEST done [{0}]" -f $name)

    # --- UPDATE ---
    Log ("UPDATE [{0}]  Title='{1}'" -f $name,$title)
    $updArgs = @(
      '-NoProfile','-ExecutionPolicy','Bypass','-File',$Update,
      '-Title',$title,'-VaultDir',$vault,'-AgentsDir',$agents,
      '-Pattern',$pat,'-Take',$take,'-WriteChecksums'
    )
    if ($drgx) { $updArgs += @('-DateRegex',$drgx) }

    & $Pwsh @updArgs
    if ($LASTEXITCODE -ne 0) { throw "Update failed ($name): exit $LASTEXITCODE" }
    Log ("UPDATE done [{0}]" -f $name)
# --- ALERT на DIFF у README
try {
  $readme = Join-Path $vault 'README.md'
  $diff = -1
  if (Test-Path $readme) {
    $rm = Get-Content $readme -Raw
    $m = [regex]::Match($rm, '(?m)^\*\*DIFF:\*\*\s*(\d+)\s*$')
    if ($m.Success) { $diff = [int]$m.Groups[1].Value }
  }
  $alertName = ("ALERT_{0}_DIFF.txt" -f $name.ToUpper())
  $alertPath = Join-Path "C:\CHECHA_CORE\C03\LOG" $alertName
  if ($diff -ge 0 -and $diff -gt 0) {
    $msg = "{0} {1}: DIFF={2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $name, $diff
    [System.IO.File]::WriteAllText($alertPath, $msg, (New-Object System.Text.UTF8Encoding($true)))
    Log ("ALERT written: {0}" -f $alertPath)
  } else {
    if (Test-Path $alertPath) { Remove-Item $alertPath -Force -ErrorAction SilentlyContinue }
    Log ("ALERT cleared (no DIFF): {0}" -f $name)
  }
} catch {
  Log ("[i] ALERT check error ({0}): {1}" -f $name, $_.Exception.Message)
}

  }

  Log "END OK"
}
catch {
  Log ("ERR: {0}" -f $_.Exception.Message)
  throw
}
finally {
  if ($hasLock) {
    try { $mtx.ReleaseMutex() | Out-Null } catch {}
    $mtx.Dispose()
    Log ("LOCK released: {0}" -f $mtxName)
  }
  # Ротація логів раннера (залишаємо останні 30)
  try {
    Get-ChildItem $LogDir -Filter "checha_pipeline_*.log" -File |
      Sort-Object LastWriteTime -Descending | Select-Object -Skip 30 |
      Remove-Item -Force -ErrorAction SilentlyContinue
  } catch { }
}