<#
.SYNOPSIS
  Створює/оновлює щоденний Strategic Template та індекс.

.PARAMETER OpenWith
  auto | notepad | code | none
  'auto' відкриє в notepad тільки в інтерактивній сесії.
#>

param(
  [ValidateSet('auto','notepad','code','none')]
  [string]$OpenWith = 'auto'
)

# -------------------- Налаштування --------------------
$ErrorActionPreference = 'Stop'

$CoreRoot   = 'C:\CHECHA_CORE'
$VaultRoot  = Join-Path $CoreRoot 'C12\Vault\StrategicReports'
$LogDir     = Join-Path $CoreRoot 'C03\LOG'

$now   = Get-Date
$iso   = $now.ToString('yyyy-MM-dd')
$ui    = $now.ToString('dd.MM.yyyy')
$year  = $now.ToString('yyyy')

$YearDir = Join-Path $VaultRoot $year
$FileName = "Strategic_Template_$iso.md"
$Target   = Join-Path $YearDir $FileName
$IndexMd  = Join-Path $VaultRoot '_index.md'

$LogPath  = Join-Path $LogDir ("strategic_template_{0}.log" -f $iso)

# -------------------- Утілiти --------------------
function Ensure-Dir([string]$Path) {
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function Write-Log([string]$Message, [string]$Level = 'INFO') {
  Ensure-Dir (Split-Path $LogPath -Parent)
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  $line = '{0} [{1,-5}] {2}' -f $ts, $Level.ToUpper(), $Message
  Add-Content -Path $LogPath -Value $line -Encoding UTF8
  if ($Level -eq 'ERROR') { Write-Host $line -ForegroundColor Red }
  elseif ($Level -eq 'WARN') { Write-Host $line -ForegroundColor Yellow }
  else { Write-Host $line }
}

function Repair-StrategicIndex {
  param([Parameter(Mandatory)] [string] $IndexPath)

  if (!(Test-Path $IndexPath)) { return }

  # 1) Прибрати переноси всередині Markdown-лінків і перед фінальним '|'
  $raw = Get-Content $IndexPath -Raw -Encoding UTF8
  $san = $raw
  $san = [regex]::Replace($san, '\]\s*\r?\n\s*\(', '](')      # між ']' та '('
  $san = [regex]::Replace($san, '\r?\n\]\s*\(', '](')         # перенос перед ']('
  $san = [regex]::Replace($san, '\)\s*\r?\n\s*\|', ') |')     # перенос перед '|'

  # 2) Склеїти «порвані» рядки таблиці до кінцевого '|'
  $lines = $san -split "\r?\n"
  $out   = New-Object System.Collections.Generic.List[string]
  $i=0
  while ($i -lt $lines.Count) {
    $buf = $lines[$i]
    if ($buf.TrimStart().StartsWith('|') -and -not ($buf.TrimEnd().EndsWith('|'))) {
      while ($i -lt ($lines.Count-1) -and -not ($buf.TrimEnd().EndsWith('|'))) {
        $i++
        $buf += ' ' + $lines[$i].Trim()
      }
    }
    $out.Add($buf); $i++
  }

  # 3) Де-дуп секції «Останні звіти»
  $L = $out
  $idxHdr = ($L | Select-String '##\s*Останні звіти').LineNumber
  if ($idxHdr) {
    $idxHdr = $idxHdr - 1
    $TH = if ($L.Count -gt ($idxHdr+1)) { $L[$idxHdr+1] } else { '| Дата | Файл |' }
    $TS = if ($L.Count -gt ($idxHdr+2)) { $L[$idxHdr+2] } else { '|---|---|' }
    $rest = if ($L.Count -gt ($idxHdr+3)) { $L[($idxHdr+3)..($L.Count-1)] } else { @() }

    $patRow = '^\|\s*\d{2}\.\d{2}\.\d{4}\s*\|\s*\[[^\]]+\]\([^)]+\)\s*\|$'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $rows = foreach($r in $rest){ if($r -match $patRow){ if($seen.Add($r)){$r} } else { $r } }

    $final = @()
    $final += $L[0..$idxHdr]; $final += $TH; $final += $TS; $final += $rows
    [IO.File]::WriteAllText($IndexPath, ($final -join "`r`n"), [Text.UTF8Encoding]::new($false))
  } else {
    [IO.File]::WriteAllText($IndexPath, ($L -join "`r`n"), [Text.UTF8Encoding]::new($false))
  }
}

function Update-Index {
  param(
    [Parameter(Mandatory)][string]$IndexPath,
    [Parameter(Mandatory)][string]$UiDate,
    [Parameter(Mandatory)][string]$Year,
    [Parameter(Mandatory)][string]$FileName
  )
  $link = "$Year/$FileName"
  $row  = "| $UiDate | [$FileName]($link) |"

  if (-not (Test-Path $IndexPath)) {
    $body = @(
      '# 📚 Strategic Reports — Vault'
      "Останнє оновлення: $UiDate"
      '---'
      '## Останні звіти'
      '| Дата | Файл |'
      '|---|---|'
      $row
    ) -join "`r`n"
    [IO.File]::WriteAllText($IndexPath, $body, [Text.UTF8Encoding]::new($false))
    Write-Log "_index.md created"
    return
  }

  # Оновити дату «Останнє оновлення:»
  $lines = Get-Content $IndexPath -Encoding UTF8
  $lines = $lines -replace '^Останнє оновлення:.*', "Останнє оновлення: $UiDate"

  # Вставити рядок у таблицю, якщо ще не існує
  if ($lines -notcontains $row) {
    $idx = ($lines | Select-String '##\s*Останні звіти').LineNumber
    if ($idx) {
      # вставляємо після заголовка таблиці та розділювача (тобто в позицію idx+2)
      $insertAt = [Math]::Min($lines.Count, $idx + 2)
      $head = $lines[0..$insertAt]
      $tail = if ($lines.Count -gt ($insertAt+1)) { $lines[($insertAt+1)..($lines.Count-1)] } else { @() }
      $lines = @() + $head + $row + $tail
    }
  }

  # Записати та прогнати санітарку/де-дуп
  [IO.File]::WriteAllText($IndexPath, ($lines -join "`r`n"), [Text.UTF8Encoding]::new($false))
  Write-Log "_index.md updated (insert/refresh)"

  Repair-StrategicIndex -IndexPath $IndexPath

  # Перевірка: рівно один запис за сьогодні
  $patternToday = "^\|\s*$UiDate\s*\|\s*\[Strategic_Template_.*\]\($Year/Strategic_Template_.*\)\s*\|$"
  $cnt = (Select-String -Path $IndexPath -Pattern $patternToday -AllMatches).Matches.Count
  if ($cnt -ne 1) {
    Write-Log ("Index post-check anomaly: today rows = {0}" -f $cnt) 'WARN'
  }
}

function Open-Editor([string]$PathToOpen) {
  switch ($OpenWith) {
    'none'     { Write-Log "OpenWith=none → skip opening editor"; return }
    'notepad'  { Start-Process notepad.exe -ArgumentList "`"$PathToOpen`"" | Out-Null; Write-Log "Opened in: notepad"; return }
    'code'     {
      $candidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "C:\Program Files\Microsoft VS Code\Code.exe",
        "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
      )
      $codeExe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
      if ($codeExe) { Start-Process $codeExe -ArgumentList "`"$PathToOpen`"" | Out-Null; Write-Log "Opened in: VSCode" }
      else { Write-Log "VSCode not found → fallback to notepad"; Start-Process notepad.exe -ArgumentList "`"$PathToOpen`"" | Out-Null; Write-Log "Opened in: notepad" }
      return
    }
    'auto'     {
      if ([Environment]::UserInteractive -and $env:USERNAME -and $env:USERNAME -ne 'SYSTEM') {
        Start-Process notepad.exe -ArgumentList "`"$PathToOpen`"" | Out-Null
        Write-Log "Opened in: notepad"
      } else {
        Write-Log "Non-interactive or SYSTEM → skip opening editor"
      }
      return
    }
  }
}

# -------------------- Основна логіка --------------------
try {
  Write-Log ("BEGIN Create-StrategicTemplate ({0})" -f $ui)

  Ensure-Dir $YearDir
  Ensure-Dir $LogDir

  if (-not (Test-Path $Target)) {
    # Базовий вміст на випадок першого створення
    $content = @"
# 🧭 Strategic Template — $ui

> Автостворено: $ui

## Mission Snapshot
- ...

## Key Tasks (Today)
- [ ] 

## Notes
- 

"@
    [IO.File]::WriteAllText($Target, $content, [Text.UTF8Encoding]::new($false))
    Write-Log ("Template created: {0}" -f $Target)
  } else {
    Write-Log ("Template exists: {0}" -f $Target)
  }

  Update-Index -IndexPath $IndexMd -UiDate $ui -Year $year -FileName $FileName
  Write-Log "_index.md sanitized+normalized+deduped"

  Open-Editor -PathToOpen $Target

  Write-Host "✅ Template ready & index OK"
  Write-Log "SUCCESS"
  Write-Log "END Create-StrategicTemplate"
  exit 0
}
catch {
  Write-Log ("ERROR: {0}" -f $_.Exception.Message) 'ERROR'
  Write-Log "END Create-StrategicTemplate"
  exit 1
}
