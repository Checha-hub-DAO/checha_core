<#
Ingest-Agent-To-Vault.ps1 (v1.2)
Копіює/переміщує файли з AgentsDir у Vault, розкладаючи по \YYYY\.
- Працює з будь-якими іменами, де є дата формату YYYY-MM-DD (регекс налаштовується).
- DryRun / Move / Force, перевірка SHA-256, логи UTF-8 BOM у C03\LOG.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
  [string]$AgentsDir = "C:\CHECHA_CORE\C11\C11_AUTOMATION\AGENTS\G44_STRATEG\reports",
  [string]$VaultDir  = "C:\CHECHA_CORE\C12\Vault\StrategicReports",
  [string]$Pattern   = "*.md",
  [string]$YearRegex = '(\d{4})-\d{2}-\d{2}',   # Група 1 = рік
  [switch]$Move,
  [switch]$Force,
  [switch]$DryRun,
  [string]$LogDir   = "C:\CHECHA_CORE\C03\LOG"
)

$ErrorActionPreference = 'Stop'
$ts = Get-Date -Format "yyyy-MM-dd_HHmmss"

# Лог-файл (UTF-8 BOM)
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogPath = Join-Path $LogDir "ingest_agent_to_vault_$ts.log"
if (-not (Test-Path $LogPath)) {
  [System.IO.File]::WriteAllText($LogPath, "", (New-Object System.Text.UTF8Encoding($true)))
}
function Log([string]$m) {
  $line = "{0} {1}`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
  [System.IO.File]::AppendAllText($LogPath, $line, (New-Object System.Text.UTF8Encoding($true)))
  Write-Host $m
}
function Get-Sha256Safe([string]$Path) {
  if (-not (Test-Path $Path -PathType Leaf)) { return $null }
  try { return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash } catch { return $null }
}

# Валідації
if (-not (Test-Path $AgentsDir -PathType Container)) { throw "AgentsDir not found: $AgentsDir" }
if (-not (Test-Path $VaultDir  -PathType Container)) { throw "VaultDir not found: $VaultDir" }
$agentsFull = (Resolve-Path $AgentsDir).Path.TrimEnd('\')
$vaultFull  = (Resolve-Path $VaultDir).Path.TrimEnd('\')
if ($agentsFull -eq $vaultFull -or $agentsFull.StartsWith($vaultFull)) { throw "AgentsDir вказує на Vault або його підпапку." }

Log ("BEGIN Ingest; AgentsDir='{0}'; VaultDir='{1}'; Pattern='{2}'; Move={3}; Force={4}; DryRun={5}" -f $AgentsDir, $VaultDir, $Pattern, $Move.IsPresent, $Force.IsPresent, $DryRun.IsPresent)
Log ("Env: PS={0}; Host={1}; OS={2}" -f $PSVersionTable.PSVersion, $Host.Name, (Get-CimInstance Win32_OperatingSystem).Caption)

# Збір файлів
$srcFiles = Get-ChildItem -Path $AgentsDir -Filter $Pattern -File -Recurse -ErrorAction SilentlyContinue
if (-not $srcFiles) { Log "No files to ingest. END."; return }

# Лічильники
$copied=0; $moved=0; $overwritten=0; $skippedSame=0; $conflicts=0; $errors=0
$conflictLines = New-Object System.Collections.Generic.List[string]

foreach ($f in $srcFiles) {
  try {
    # == ВИЗНАЧЕННЯ РОКУ ==
    $year = "_unsorted"
    $m = [regex]::Match($f.BaseName, $YearRegex)
    if ($m.Success -and $m.Groups.Count -ge 2) {
      $year = $m.Groups[1].Value  # група з роком
    } else {
      # fallback: рік з LastWriteTime
      $year = $f.LastWriteTime.ToString('yyyy')
    }

    $dstDir = Join-Path $VaultDir $year
    $dst    = Join-Path $dstDir $f.Name
    if (-not $DryRun) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }

    if (Test-Path $dst -PathType Leaf) {
      $srcHash = Get-Sha256Safe $f.FullName
      $dstHash = Get-Sha256Safe $dst

      if ($srcHash -and $dstHash -and ($srcHash -eq $dstHash)) {
        $skippedSame++; Log ("SKIP SAME: {0} (hash={1}) -> {2}" -f $f.Name, $srcHash, $dst); continue
      }

      if ($Force) {
        $action = $Move.IsPresent ? "MOVE(OVERWRITE)" : "COPY(OVERWRITE)"
        if ($DryRun -or $PSCmdlet.ShouldProcess($dst, "$action from $($f.FullName)")) {
          if (-not $DryRun) {
            if ($Move) { Move-Item -LiteralPath $f.FullName -Destination $dst -Force }
            else       { Copy-Item -LiteralPath $f.FullName -Destination $dst -Force }
          }
          $overwritten++; Log ("{0}: {1} -> {2}" -f $action, $f.Name, $dst)
        }
      } else {
        $conflicts++; $msg = "CONFLICT: $($f.FullName) -> $dst (srcHash=$srcHash, dstHash=$dstHash)"
        $conflictLines.Add($msg) | Out-Null; Log $msg
      }
      continue
    }

    $action2 = $Move.IsPresent ? "MOVE" : "COPY"
    if ($DryRun -or $PSCmdlet.ShouldProcess($dst, "$action2 from $($f.FullName)")) {
      if (-not $DryRun) {
        if ($Move) { Move-Item -LiteralPath $f.FullName -Destination $dst -Force; $moved++ }
        else       { Copy-Item -LiteralPath $f.FullName -Destination $dst -Force; $copied++ }
      } else { if ($Move) { $moved++ } else { $copied++ } }
      Log ("{0}: {1} -> {2}" -f $action2, $f.Name, $dst)
    }
  }
  catch {
    $errors++; Log ("ERR: {0}" -f $_.Exception.Message)
  }
}

# Конфлікти у файл
if ($conflicts -gt 0) {
  $confFile = Join-Path $LogDir "ingest_conflicts_$ts.txt"
  $header = "Conflicts at {0} (AgentsDir='{1}', VaultDir='{2}')" -f (Get-Date -Format "yyyy-MM-dd HH:mm"), $AgentsDir, $VaultDir
  $all = New-Object System.Collections.Generic.List[string]
  $all.Add($header) | Out-Null; $all.Add("----") | Out-Null
  $conflictLines | ForEach-Object { $all.Add($_) | Out-Null }
  [System.IO.File]::WriteAllLines($confFile, $all, (New-Object System.Text.UTF8Encoding($true)))
  Log "CONFLICTS saved to: $confFile"
}

# Резюме
Log ("SUMMARY: copied={0}; moved={1}; overwritten={2}; skippedSame={3}; conflicts={4}; errors={5}" -f $copied,$moved,$overwritten,$skippedSame,$conflicts,$errors)
Log "END Ingest"