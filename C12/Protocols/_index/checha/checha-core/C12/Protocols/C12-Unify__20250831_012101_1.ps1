param(
  [string]$Root = "C:\CHECHA_CORE\C12",
  [switch]$Apply,
  [switch]$Confirm,
  [switch]$CreateReadme,
  [switch]$FixNested,
  [switch]$Categorize,
  [switch]$Report,
  [switch]$HashArchive
)

# кодування виводу (щоб не було кракозябр у логах)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$global:OutputEncoding   = [Console]::OutputEncoding

$ErrorActionPreference = 'Stop'
$now      = Get-Date
$stamp    = $now.ToString("yyyyMMdd_HHmmss")
$summary  = New-Object System.Collections.Generic.List[object]
$RootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
$LogPath  = Join-Path (Split-Path $RootFull -Parent) "C03\LOG\LOG.md"
$Archive  = Join-Path $RootFull "Archive"

function Write-Info($m){ Write-Host "[i] $m" }
function Write-Ok($m)  { Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err($m) { Write-Host "[x] $m" -ForegroundColor Red }

function Ensure-Dir($p){
  if (-not (Test-Path -LiteralPath $p)) {
    if ($Apply) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
    Write-Info "Створено папку: $p (Apply=$Apply)"
  }
}

function Append-Log($text){
  $line = "[{0}] C12: {1}" -f ($now.ToString("yyyy-MM-dd HH:mm")), $text
  $logDir = Split-Path $LogPath -Parent
  if (-not (Test-Path -LiteralPath $logDir)) { if ($Apply) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null } }
  if ($Apply) { Add-Content -Path $LogPath -Value $line }
  Write-Ok $line
}

function Get-UniquePath([string]$dstBase){
  $dir  = Split-Path $dstBase -Parent
  $name = [IO.Path]::GetFileNameWithoutExtension($dstBase)
  $ext  = [IO.Path]::GetExtension($dstBase)
  $ts   = Get-Date -Format "yyyyMMdd_HHmmss"
  $try  = 0
  do {
    $suffix = if ($try -eq 0) { "" } else { "__" + $ts + "_" + $try }
    $candidate = if ($suffix) { Join-Path $dir ($name + $suffix + $ext) } else { $dstBase }
    $try++
  } while (Test-Path -LiteralPath $candidate)
  return $candidate
}

function Move-ItemSafe([string]$src, [string]$dst){
  if ($src -eq $dst) { Write-Info "SKIP (src=dst): $src"; return }
  if (-not (Test-Path -LiteralPath $src)) { Write-Warn "SKIP (no source): $src"; return }

  $dst = Get-UniquePath $dst
  Ensure-Dir (Split-Path $dst -Parent)

  $maxRetry = 5
  for ($i=0; $i -le $maxRetry; $i++) {
    try {
      if ($Apply) { Move-Item -LiteralPath $src -Destination $dst -ErrorAction Stop }
      $summary.Add([pscustomobject]@{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Action    = 'MOVE'
        From      = $src
        To        = $dst
      })
      Write-Ok "MOVE: `"$src`" → `"$dst`" (Apply=$Apply)"
      return
    } catch {
      if ($_.Exception.Message -match 'already exists|уже существует|вже існує') {
        $dst = Get-UniquePath $dst
        Write-Warn "Колізія імені, пробую ще: $dst"
        Start-Sleep -Milliseconds 120
        continue
      } else {
        Write-Err "Move failed: $src → $dst — $($_.Exception.Message)"
        return
      }
    }
  }
  Write-Err "Move aborted після $maxRetry спроб: $src"
}

if (-not (Test-Path -LiteralPath $RootFull)) { throw "Root не існує: $RootFull" }
Write-Info "ROOT: $RootFull"
Write-Info ("MODE: {0}" -f ($(if($Apply){"APPLY"}else{"DRY-RUN"})))

# --- правила категоризації
$rules = [ordered]@{
  "Books"      = { param($f) $f.Extension -match '^\.(pdf|epub|mobi)$' -or $f.Name -match '(?i)(BOOK|LIB|Frankl|Stoicism)' }
  "Documents"  = { param($f) $f.Extension -eq '.md' -and $f.Name -match '(?i)(ETHNO|STRATEGY|Moral|Awareness|Case|Guide|Analysis|README)' }
  "Media"      = { param($f) $f.Extension -match '^\.(png|jpg|jpeg|svg|mp4|mov)$' -or $f.Name -match '(?i)(Visual|Banner|Symbol|Infographic)' }
  "Protocols"  = { param($f) $f.Extension -match '^\.(ps1|bat|cmd|sh)$' -or $f.Name -match '(?i)(backup|cleanup|restore|health|protocol)' }
  "Forms"      = { param($f) $f.Name -match '(?i)(DAO-?FORM|Google-Form|Response|feedback|application)' }
  "Journals"   = { param($f) $f.Name -match '(?i)(JOURNAL|SESSION-REPORT|REPORT|DIARY|LOGBOOK)' }
  "Navigation" = { param($f) $f.Name -match '(?i)(THEMATIC_NAV|OPERATIVKA|NAVIGATION|INDEX)' }
  "Archive"    = { param($f) $f.Extension -eq '.zip' -or $f.Name -match '(?i)(ARCHIVE|PUSH_\d{8}|INTEGRATION_BANK_ZNAN)' }
}

# --- 1) Виправлення «подвійних» підшляхів
if ($FixNested) {
  Write-Info "Сканую на дублювання підшляхів…"
  $all = Get-ChildItem -LiteralPath $RootFull -Recurse -Force -ErrorAction SilentlyContinue
  $paths = $all | ForEach-Object { [IO.Path]::GetFullPath($_.FullName) } | Sort-Object { $_.Length } -Descending

  foreach ($full in $paths) {
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $lower = $full.ToLower()
    $idx   = $lower.IndexOf("\c12\")
    if ($idx -lt 0) { continue }

    $tail     = $full.Substring($idx + 5)
    $tailNorm = $tail -replace '^(?i)(?:checha\\checha-core\\c12\\)+',''
    $dupIdx   = $tailNorm.ToLower().IndexOf("\c12\")
    if ($dupIdx -ge 0) { $tailNorm = $tailNorm.Substring($dupIdx + 5) }

    if ($tail -ne $tailNorm) {
      $dst = Join-Path $RootFull $tailNorm
      if ($full -eq $dst) { continue }
      if ($Confirm -and $Apply) {
        $q = Read-Host "Виправити дубль?`n FROM: $full `n   TO: $dst `n[y/N]"
        if ($q -notin @('y','Y','yes','YES')) { continue }
      }
      Move-ItemSafe -src $full -dst $dst
    }
  }
  Append-Log "C12 уніфікація: виправлено дублі підшляхів (FixNested=$FixNested, Apply=$Apply)."
}

# --- 2) Категоризація
if ($Categorize) {
  Write-Info "Категоризація файлів…"
  $targets = @("Books","Documents","Media","Protocols","Forms","Journals","Navigation","Archive")
  foreach ($t in $targets) { Ensure-Dir (Join-Path $RootFull $t) }

  $files = Get-ChildItem -LiteralPath $RootFull -Recurse -File -Force |
           Where-Object { $_.Directory.FullName -notmatch '\\(Books|Documents|Media|Protocols|Forms|Journals|Navigation|Archive)\\' }

  foreach ($f in $files) {
    $moved = $false
    foreach ($kv in $rules.GetEnumerator()) {
      $cat = $kv.Key; $pred = $kv.Value
      if (& $pred $f) {
        $dst = Join-Path (Join-Path $RootFull $cat) $f.Name
        if ($Confirm -and $Apply) {
          $q = Read-Host "Перемістити у $cat? `"$($f.FullName)`" → `"$dst`" [y/N]"
          if ($q -notin @('y','Y','yes','YES')) { break }
        }
        Move-ItemSafe -src $f.FullName -dst $dst
        $moved = $true
        break
      }
    }
    if (-not $moved) {
      Write-Warn "Не класифіковано (залишено місце): $($f.FullName)"
      $summary.Add([pscustomobject]@{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Action    = 'SKIP'
        From      = $f.FullName
        To        = '—'
      })
    }
  }
  Append-Log "C12 категоризація: файли розкладено по папках (Categorize=$Categorize, Apply=$Apply)."
}

# --- 3) README у ключових папках
if ($CreateReadme) {
  $keyDirs = @(
    $RootFull
    (Join-Path $RootFull "Books")
    (Join-Path $RootFull "Documents")
    (Join-Path $RootFull "Media")
    (Join-Path $RootFull "Protocols")
    (Join-Path $RootFull "Forms")
    (Join-Path $RootFull "Journals")
    (Join-Path $RootFull "Navigation")
    (Join-Path $RootFull "Archive")
  )
  $dstr = (Get-Date).ToString("yyyy-MM-dd")
  foreach ($d in $keyDirs) {
    Ensure-Dir $d
    $readme = Join-Path $d "README.md"
    if (-not (Test-Path -LiteralPath $readme)) {
      $md = @"
# $(Split-Path $d -Leaf)
Статус: активний  
Дата: $dstr  

Короткий опис папки (DAO-GOGS стандарт).
"@
      if ($Apply) { $md | Set-Content -Path $readme -Encoding UTF8 }
      Write-Ok "README.md створено: $readme (Apply=$Apply)"
      $summary.Add([pscustomobject]@{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Action    = 'CREATE'
        From      = '—'
        To        = $readme
      })
    }
  }
  Append-Log "C12 README: створено мінімальні описи (CreateReadme=$CreateReadme, Apply=$Apply)."
}

# --- 4) Звіт
if ($Report) {
  Ensure-Dir $Archive
  $csv = Join-Path $Archive ("C12_UNIFY_REPORT_" + $stamp + ".csv")
  $md  = Join-Path $Archive ("C12_UNIFY_REPORT_" + $stamp + ".md")

  if ($summary.Count -gt 0) {
    if ($Apply) { $summary | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8 }
    Write-Ok "CSV звіт: $csv (Apply=$Apply)"

    $mdLines = @("# C12 Unify Report (" + $stamp + ")", "", "| Time | Action | From | To |", "|---|---|---|---|")
    foreach ($row in $summary) {
      $mdLines += "| {0} | {1} | {2} | {3} |" -f $row.Timestamp, $row.Action, ($row.From -replace '\|','\|'), ($row.To -replace '\|','\|')
    }
    if ($Apply) { $mdLines -join "`n" | Set-Content -Path $md -Encoding UTF8 }
    Write-Ok "MD звіт: $md (Apply=$Apply)"
    Append-Log "C12 звіт: експортовано CSV+MD ($stamp)."
  } else {
    Write-Warn "Немає дій для звіту (summary пустий)."
  }
}

# --- 5) SHA-256 для ZIP архівів
if ($HashArchive) {
  Ensure-Dir $Archive
  $manifest = Join-Path $Archive ("C12_ARCHIVE_SHA256_" + $stamp + ".txt")
  $lines = New-Object System.Collections.Generic.List[string]
  $zips = Get-ChildItem -LiteralPath $Archive -Filter *.zip -File -ErrorAction SilentlyContinue
  if ($zips.Count -eq 0) {
    Write-Warn "У Archive немає ZIP-файлів."
  } else {
    foreach ($z in $zips) {
      try {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $z.FullName).Hash
        $lines.Add(($hash + "  *" + $z.Name))
        Write-Ok ("SHA256: " + $z.Name + " = " + $hash)
      } catch {
        Write-Err ("Хеш не обчислено: " + $z.FullName + " — " + $_.Exception.Message)
      }
    }
    if ($Apply -and $lines.Count -gt 0) {
      $header = @(
        "C12 ARCHIVE SHA-256 MANIFEST",
        "Generated: " + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'),
        "Root: " + $RootFull,
        ""
      )
      ($header + $lines) | Set-Content -Path $manifest -Encoding UTF8
      Write-Ok "Маніфест SHA-256: $manifest"
      Append-Log "C12 архів: згенеровано SHA-256 маніфест ($stamp)."
    }
  }
}

Write-Host ""
Write-Host "===== SUMMARY =====" -ForegroundColor Cyan
$summary | Format-Table -AutoSize
Write-Host "===================" -ForegroundColor Cyan
Write-Info "Готово."
