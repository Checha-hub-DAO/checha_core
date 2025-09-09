<#
.SYNOPSIS
  Місячний шедулер формує підсумкові звіти архітектури.
  Викликає New-MatrixAudit.ps1, збирає матрицю, рахує "застій" (-StaleDays),
  будує SUMMARY (MD) + опційний графік (ASCII/PNG), веде лог.

.PARAMETER Root
  Корінь репозиторію CHECHA_CORE (default: C:\CHECHA_CORE)

.PARAMETER Phase
  Start | End | Once  (default: Once)
  - Start/End можна вішати на планувальник; Once — одноразовий прогін.

.PARAMETER StaleDays
  Поріг "застою" у днях для колонки LastUpdate (default: 45)

.PARAMETER OwnersRequiredFor
  Modules | Submodules | All — політика наявності Owner (default: All).
  Передається у New-MatrixAudit.ps1.

.PARAMETER FailOnMissingOwner
  Якщо true — якщо знайдені модулі без Owner згідно політики, встановлюється загальний ExitCode=1.

.PARAMETER SummaryChart
  None | ASCII | PNG — тип графіка у SUMMARY (default: ASCII)

#>

[CmdletBinding()]
Param(
  [string]$Root = "C:\CHECHA_CORE",
  [ValidateSet('Start','End','Once')]
  [string]$Phase = 'Once',
  [int]$StaleDays = 45,
  [ValidateSet('Modules','Submodules','All')]
  [string]$OwnersRequiredFor = 'All',
  [switch]$FailOnMissingOwner,
  [ValidateSet('None','ASCII','PNG')]
  [string]$SummaryChart = 'ASCII'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ===================== COMMON HELPERS =====================

$script:__exit = 0
function Set-Exit([int]$code){ if ($code -gt $script:__exit){ $script:__exit = $code } }

function NowStamp(){ (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }

function Ensure-Dir([string]$path){
  if (-not [string]::IsNullOrWhiteSpace($path)){
    $dir = $path
    if (-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  }
}

function Write-FileAtomic([string]$Content,[string]$Path,[string]$Encoding="utf8BOM"){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $tmp = "$Path.tmp.$PID.$([DateTime]::UtcNow.Ticks)"
  if ($Encoding -ieq "utf8BOM") {
    [System.IO.File]::WriteAllText($tmp, $Content, (New-Object System.Text.UTF8Encoding($true)))
  } elseif ($Encoding -ieq "utf8") {
    [System.IO.File]::WriteAllText($tmp, $Content, (New-Object System.Text.UTF8Encoding($false)))
  } else {
    $Content | Set-Content -Path $tmp -Encoding $Encoding
  }
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}
  $tmp = "$Path.tmp.$PID.$([DateTime]::UtcNow.Ticks)"
  $Content | Set-Content -Path $tmp -Encoding $Encoding
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Write-Log([string]$root,[string]$level,[string]$msg){
  $runDir = Join-Path $root "C03\RUN"
  Ensure-Dir $runDir
  $log = Join-Path $runDir "LOG.md"

  if (-not (Test-Path $log)){
    $hdr = @(
      "# RUN LOG"
      ""
      "| Time | Level | Message |"
      "|---|---|---|"
    ) -join "`r`n"
    Write-FileAtomic -Content $hdr -Path $log
  }

  # >>> сумісний з PS 5.1 спосіб без дужок у -f
  $ts  = NowStamp
  $lvl = $level.ToUpper()
  $line = ("| {0} | {1} | {2} |" -f $ts, $lvl, $msg)

  Add-Content -Path $log -Value $line -Encoding utf8
}
function Acquire-Lock([string]$Root,[string]$Name="monthly",[int]$ttlHours=8){
  $runDir  = Join-Path $Root "C03\RUN"
  $lock    = Join-Path $runDir "$Name.lock"
  Ensure-Dir $runDir
  if (Test-Path $lock){
    $age = (Get-Date) - (Get-Item $lock).LastWriteTime
    if ($age.TotalHours -lt $ttlHours){
      Write-Log $Root "info" ("{0} lock present (age {1:N1}h) — SKIP" -f $Name,$age.TotalHours)
      return $null
    } else {
      Remove-Item -Force $lock
    }
  }
  "$PID|$(NowStamp)" | Set-Content -Path $lock -Encoding ascii
  return $lock
}
function Release-Lock([string]$LockPath){ try{ if ($LockPath -and (Test-Path $LockPath)){ Remove-Item -Force $LockPath } }catch{} }

function TryParse-Date([string]$s){
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  $dt=$null
  # Спершу суворо yyyy-MM-dd
  if ([DateTime]::TryParseExact($s,'yyyy-MM-dd',$null,[Globalization.DateTimeStyles]::AssumeLocal,[ref]$dt)){ return $dt }
  # Потім будь-який парс локаллю
  if ([DateTime]::TryParse($s,[ref]$dt)){ return $dt }
  return $null
}

# PNG збереження атомарно
function Save-PngAtomic([System.Drawing.Bitmap]$bmp,[string]$path){
  $dir = Split-Path $path -Parent
  if($dir){ Ensure-Dir $dir }
  $tmp = "$path.tmp.$PID.$([DateTime]::UtcNow.Ticks)"
  $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
  Move-Item -LiteralPath $tmp -Destination $path -Force
}

# ===================== PATHS =====================

$ReportsWeekly  = Join-Path $Root "C12\Vault\StrategicReports\weekly"
$ReportsMonthly = Join-Path $Root "C12\Vault\StrategicReports\monthly"
Ensure-Dir $ReportsWeekly
Ensure-Dir $ReportsMonthly

$today    = Get-Date
$dayTag   = $today.ToString('yyyy-MM-dd')
$fnameTag = $today.ToString('yyyyMMdd')

$AuditScript   = Join-Path $Root "C11\C11_AUTOMATION\tools\New-MatrixAudit.ps1"
$OutAuditMD    = Join-Path $ReportsWeekly  ("Matrix_Audit_{0}.md" -f $fnameTag)
$MatrixCsv     = Join-Path $ReportsMonthly "architecture_matrix.csv"         # "бойовий" CSV
$MatrixMd      = Join-Path $ReportsMonthly "ARCHITECTURE_MATRIX.md"         # "бойовий" MD
$SummaryMD     = Join-Path $ReportsMonthly ("SUMMARY_{0}.md" -f $fnameTag)
$ChartPng      = Join-Path $ReportsMonthly ("SUMMARY_{0}.png" -f $fnameTag)

# ===================== RUN AUDIT (with rc=2 => SKIP) =====================

function Run-MatrixAudit(){
  if (-not (Test-Path $AuditScript)){ throw "Audit script not found: $AuditScript" }

  & pwsh -NoProfile -File $AuditScript `
      -Root $Root `
      -OutFile $OutAuditMD `
      -CsvOut  $MatrixCsv `
      -MdMatrixOut $MatrixMd `
      -OwnersRequiredFor $OwnersRequiredFor `
      -FailOnMissingOwner:$FailOnMissingOwner | Out-Null

  $rc = $LASTEXITCODE
  if ($rc -eq 2){
    Write-Log $Root "info" "MatrixAudit SKIP (locked, rc=2)."
    return $false
  } elseif ($rc -ne 0){
    Write-Log $Root "error" ("MatrixAudit FAILED (rc={0})." -f $rc)
    Set-Exit 1
  } else {
    Write-Log $Root "info" "MatrixAudit OK."
  }
  return $true
}

# ===================== READ MATRIX =====================

function Read-MatrixCsv(){
  if (-not (Test-Path $MatrixCsv)){
    Write-Log $Root "warn" ("Matrix CSV not found: {0}" -f $MatrixCsv)
    return @()
  }
  try {
    return Import-Csv -Path $MatrixCsv
  } catch {
    Write-Log $Root "error" ("Cannot read CSV: {0}" -f $_.Exception.Message)
    Set-Exit 1
    return @()
  }
}

# ===================== SUMMARY BUILDERS =====================

function Build-AsciiChart([hashtable]$kv){
  # простий горизонтальний барчарт у моноширинному шрифті
  $lines=@()
  $maxLabel = ($kv.Keys | ForEach-Object { $_.ToString().Length } | Measure-Object -Maximum).Maximum
  $maxVal   = ($kv.Values | Measure-Object -Maximum).Maximum
  if ($null -eq $maxVal) { $maxVal = 1 }
  foreach($k in $kv.Keys){
    $v = [int]$kv[$k]
    $bars = if ($maxVal -gt 0) { ('#' * [int]([Math]::Round(40 * $v / $maxVal))) } else { '' }
    $lines += ("{0} | {1} ({2})" -f $k.PadRight($maxLabel), $bars, $v)
  }
  return ("```text`r`n" + ($lines -join "`r`n") + "`r`n```")
}

function Build-PngChart([hashtable]$kv,[string]$outPath){
  Add-Type -AssemblyName System.Drawing
  $width=720; $height=420
  $bmp = New-Object System.Drawing.Bitmap($width,$height)
  $g   = [System.Drawing.Graphics]::FromImage($bmp)
  try{
    $bg = [System.Drawing.Brushes]::White
    $g.FillRectangle($bg,0,0,$width,$height)
    $font = New-Object System.Drawing.Font("Segoe UI",12)
    $br   = [System.Drawing.Brushes]::Black
    $pen  = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,1)

    $padding=50
    $barW=40
    $gap=30
    $keys = @($kv.Keys)
    $vals = @($kv.Values | ForEach-Object {[int]$_})
    $max = ($vals | Measure-Object -Maximum).Maximum
    if ($null -eq $max -or $max -le 0){ $max = 1 }

    # axes
    $g.DrawLine($pen,$padding,$height-$padding,$width-$padding,$height-$padding)
    $g.DrawLine($pen,$padding,$padding,$padding,$height-$padding)

    $x = $padding + 20
    for($i=0;$i -lt $keys.Count;$i++){
      $v = $vals[$i]
      $h = [int]( ($height-2*$padding) * $v / $max )
      $y = $height - $padding - $h
      $rect = New-Object System.Drawing.Rectangle($x,$y,$barW,$h)
      $g.FillRectangle([System.Drawing.Brushes]::LightGray,$rect)
      $g.DrawRectangle($pen,$rect)
      # label
      $g.DrawString($keys[$i],$font,$br,$x,$height-$padding+5)
      $g.DrawString($v.ToString(),$font,$br,$x,$y-20)
      $x += $barW + $gap
    }

    Save-PngAtomic -bmp $bmp -path $outPath
  } finally {
    $g.Dispose(); $bmp.Dispose()
  }
}

function Build-Summary([array]$matrix){
  # Підрахунки
  $statusGroups = @{}
  foreach($st in @('Core','Active','Draft','Archived')){
    $statusGroups[$st] = 0
  }
  foreach($row in $matrix){
    $st = $row.Status
    if ($statusGroups.ContainsKey($st)){ $statusGroups[$st]++ } else { $statusGroups[$st]=1 }
  }

  # Stale
  $stale=@()
  $now = Get-Date
  foreach($row in $matrix){
    $dt = TryParse-Date $row.LastUpdate
    if ($dt -and ($now - $dt).TotalDays -gt $StaleDays){
      $stale += $row
    }
  }

  # Побудова SUMMARY.md
  $md=@()
  $md += "# 📊 Monthly Architecture Summary — $dayTag"
  $md += ""
  $md += "## Стани"
  $md += ""
  $md += "| Status | Count |"
  $md += "|---|---:|"
  foreach($k in $statusGroups.Keys){
    $md += "| {0} | {1} |" -f $k, $statusGroups[$k]
  }

  $md += ""
  $md += "## Застій > {0} днів (за LastUpdate)" -f $StaleDays
  if ($stale.Count -eq 0){
    $md += ""
    $md += "Немає."
  } else {
    $md += ""
    $md += "| Code | Name | Status | Last Update | Owner |"
    $md += "|---|---|---|---|---|"
    foreach($r in ($stale | Sort-Object Code)){
      $md += "| {0} | {1} | {2} | {3} | {4} |" -f $r.Code,$r.Name,$r.Status,($r.LastUpdate ?? ''),($r.Owner ?? '')
    }
  }

  # Графік
  if ($SummaryChart -eq 'ASCII'){
    $md += ""
    $md += "## Графік станів (ASCII)"
    $md += (Build-AsciiChart $statusGroups)
  } elseif ($SummaryChart -eq 'PNG'){
    try{
      Build-PngChart -kv $statusGroups -outPath $ChartPng
      $rel = Split-Path -Leaf $ChartPng
      $md += ""
      $md += "## Графік станів (PNG)"
      $md += "![Summary chart]($rel)"
    } catch {
      Write-Log $Root "warn" ("PNG chart failed: {0}. Fallback to ASCII." -f $_.Exception.Message)
      $md += ""
      $md += "## Графік станів (ASCII, fallback)"
      $md += (Build-AsciiChart $statusGroups)
    }
  }

  Write-FileAtomic -Content ($md -join "`r`n") -Path $SummaryMD -Encoding utf8BOM
  Write-Log $Root "info" ("SUMMARY ready: {0}" -f $SummaryMD)
}

# ===================== MAIN FLOW =====================

$lock = Acquire-Lock -Root $Root -Name "monthly" -ttlHours 8
if (-not $lock){ Write-Host "[SKIP] monthly lock active. ExitCode=0"; exit 0 }

try {
  Write-Log $Root "info" ("MonthlyScheduler start (Phase={0}, OwnersPolicy={1}, StaleDays={2}, Chart={3})" -f $Phase,$OwnersRequiredFor,$StaleDays,$SummaryChart)

  $auditRun = Run-MatrixAudit

  # читаємо матрицю (навіть якщо audit SKIP — беремо останню)
  $matrix = Read-MatrixCsv

  # діагностика (сумісно з PS5/7)
  Write-Host ("[DBG] Matrix rows: {0}" -f (@($matrix).Count))

  # формуємо SUMMARY тільки якщо є дані (або якщо audit відпрацював).
  if (@($matrix).Count -gt 0){
    Build-Summary -matrix $matrix
  } else {
    Write-Log $Root "warn" "Matrix is empty — SUMMARY not generated."
  }

  # Підсумковий exit-код
  if ($FailOnMissingOwner){
    # якщо у звіті New-MatrixAudit був ExitCode=1 через owner policy — ми вже підняли Set-Exit(1)
    # додатково можна перевірити у CSV порожні Owner згідно політики
    function Matches-OwnersPolicy([string]$code){
      switch ($OwnersRequiredFor){
        'Modules'    { return ($code -match '^G\d{2}$') }
        'Submodules' { return ($code -match '^G\d{2}\.\d+') }
        default      { return $true }
      }
    }
    $missing = @($matrix | Where-Object { (Matches-OwnersPolicy $_.Code) -and ([string]::IsNullOrWhiteSpace($_.Owner)) })
    if ($missing.Count -gt 0){
      Write-Log $Root "error" ("Owners missing (policy={0}): {1}" -f $OwnersRequiredFor, ($missing | ForEach-Object{$_.Code}) -join ', ')
      Set-Exit 1
    }
  }

} finally {
  Release-Lock $lock
  Write-Log $Root "info" ("MonthlyScheduler end (ExitCode={0})" -f $script:__exit)
  Write-Host ("[OK] MonthlyScheduler completed. ExitCode={0}" -f $script:__exit)
  exit $script:__exit
}

