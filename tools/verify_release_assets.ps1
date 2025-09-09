[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $Repo,
  [Parameter(Mandatory)] [string] $Tag,

  [string[]] $RequireAssets,
  [switch]   $RequireMP4,
  [switch]   $VerifyChecksums,

  # ZIP-ціль
  [string] $LocalZip,
  [string] $ZipName,
  [string] $ZipPattern,        # напр.: "*ETHNO*1.2*.zip"
  [switch] $AutoDownloadZip,   # якщо LocalZip не задано — завантажити ассет з релізу
  [switch] $ZipNameNormalize,  # нормалізація імен для зіставлення (прибирає дати, уніфікує -/_)
  [switch] $StrictMatch,       # суворий режим: не підбирати “єдиний ZIP у CHECKSUMS” як fallback

  # Службове
  [string] $LogPath
)

function Write-Log($msg, [string]$level="INFO") {
  $line = "[{0}] {1}: {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $level.ToUpper(), $msg
  Write-Host $line
  if ($LogPath) {
    $dir = Split-Path -Parent $LogPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -LiteralPath $LogPath -Value $line
  }
}

function Normalize-Name([string]$name) {
  if (-not $name) { return $null }
  $base = [System.IO.Path]::GetFileName($name)
  # Прибрати часові суфікси перед .zip: _YYYYMMDD_HHMM або -YYYYMMDD-HHMM
  $base = $base -replace '([_-])\d{8}([_-])\d{4}(\.zip)$', '$3'
  # Уніфікувати роздільники
  $base = ($base -replace '[-_]+','_')
  $base.ToLowerInvariant()
}

# --- залежність: gh ---
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Log "Не знайдено 'gh' CLI у PATH. Встанови: winget install GitHub.cli" "ERROR"
  exit 2
}

# --- 1) реліз JSON ---
try { $rel = gh api "repos/$Repo/releases/tags/$Tag" | ConvertFrom-Json }
catch { Write-Log "Не вдалось отримати реліз $Repo / $Tag. $_" "ERROR"; exit 3 }
if (-not $rel) { Write-Log "Реліз не знайдено: $Repo / $Tag" "ERROR"; exit 3 }

$assets = @()
if ($rel.assets) {
  $assets = $rel.assets | ForEach-Object { [pscustomobject]@{ name=$_.name; size=$_.size; id=$_.id } }
}
Write-Log ("Знайдено ассетів: {0}" -f $assets.Count)

# --- 2) must-have ассети ---
$fail = $false
if ($RequireAssets) {
  foreach ($req in $RequireAssets) {
    if (-not ($assets.name -contains $req)) { Write-Log "Відсутній обов’язковий ассет: $req" "ERROR"; $fail = $true }
    else { Write-Log "OK ассет: $req" }
  }
}

# --- 3) MP4 ---
if ($RequireMP4) {
  $hasMp4 = $assets.name | Where-Object { $_ -match '\.mp4$' }
  if (-not $hasMp4) { Write-Log "У релізі немає *.mp4, але -RequireMP4 увімкнено." "ERROR"; $fail = $true }
  else { Write-Log ("Знайдено MP4: {0}" -f ($hasMp4 -join ', ')) }
}

# --- 4) CHECKSUMS: розбір GNU/BSD ---
$checksDict = @{}   # fileName -> sha256
$checksName  = "CHECKSUMS.txt"
$checksPath  = $null

if ($VerifyChecksums) {
  if (-not ($assets.name -contains $checksName)) {
    Write-Log "Відсутній CHECKSUMS.txt — звірка неможлива." "ERROR"; $fail = $true
  } else {
    try {
      $tmpDir = Join-Path $env:TEMP ("checks_{0}_{1}" -f ($Repo -replace '[\\/]', '_'), $Tag)
      if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null }
      gh release download $Tag -R $Repo --pattern $checksName --dir $tmpDir --clobber | Out-Null
      $checksPath = Join-Path $tmpDir $checksName
      Write-Log "CHECKSUMS.txt завантажено: $checksPath"
    } catch { Write-Log "Помилка завантаження CHECKSUMS.txt: $_" "ERROR"; $fail = $true }

    if ($checksPath -and (Test-Path $checksPath)) {
      $lines = Get-Content -LiteralPath $checksPath | Where-Object { $_ -match '\S' }
      foreach ($line in $lines) {
        # GNU: "<sha256>  filename" або "<sha256> *filename"
        if ($line -match '^([0-9a-fA-F]{64})\s+\*?(.+)$') {
          $hash = $Matches[1].ToLower(); $file = $Matches[2].Trim()
          if (-not $checksDict.ContainsKey($file)) { $checksDict[$file] = $hash }
          continue
        }
        # BSD: "SHA256 (filename) = <sha256>"
        if ($line -match '^SHA256\s*\((.+)\)\s*=\s*([0-9a-fA-F]{64})$') {
          $file = $Matches[1].Trim(); $hash = $Matches[2].ToLower()
          if (-not $checksDict.ContainsKey($file)) { $checksDict[$file] = $hash }
          continue
        }
      }
      if ($checksDict.Count -eq 0) { Write-Log "CHECKSUMS.txt не містить розпізнаваних рядків SHA256." "ERROR"; $fail = $true }
      else {
        $list = ($checksDict.Keys | Sort-Object) -join ', '
        Write-Log "Імена, знайдені у CHECKSUMS: $list"
      }
    }
  }
}

# --- 5) Визначення цільового ZIP ---
function Infer-ZipName {
  param([string[]]$assetNames, [string]$pattern)
  if ($pattern) {
    $cand = @($assetNames | Where-Object { $_ -like $pattern -and $_.ToLower().EndsWith(".zip") })
    if ($cand.Count -ge 1) { return $cand[0] }
  }
  $zips = @($assetNames | Where-Object { $_.ToLower().EndsWith(".zip") })
  if ($zips.Count -eq 1) { return $zips[0] }
  return $null
}

$targetZipName = $ZipName
if (-not $targetZipName) {
  $targetZipName = Infer-ZipName -assetNames $assets.name -pattern $ZipPattern
  if ($targetZipName) { Write-Log "Визначено ZIP: $targetZipName" }
  elseif ($LocalZip)  { $targetZipName = Split-Path $LocalZip -Leaf; Write-Log "Використовую ім’я з LocalZip: $targetZipName" }
}

# --- 6) Підготовка LocalZip (завантаження за потреби) ---
if ($targetZipName -and -not $LocalZip -and $AutoDownloadZip) {
  try {
    $dlDir = Join-Path $env:TEMP ("zip_{0}_{1}" -f ($Repo -replace '[\\/]', '_'), $Tag)
    if (-not (Test-Path $dlDir)) { New-Item -ItemType Directory -Path $dlDir -Force | Out-Null }
    gh release download $Tag -R $Repo --pattern $targetZipName --dir $dlDir --clobber | Out-Null
    $LocalZip = Join-Path $dlDir $targetZipName
    Write-Log "Завантажено ZIP: $LocalZip"
  } catch { Write-Log "Не вдалося завантажити ZIP '$targetZipName'. $_" "ERROR"; $fail = $true }
}
if ($LocalZip -and -not (Test-Path $LocalZip)) {
  Write-Log "Локальний ZIP не знайдено: $LocalZip" "ERROR"; $fail = $true
}

# --- 7) Гнучке зіставлення з CHECKSUMS ---
function Find-ChecksumFor([string]$fileName, [hashtable]$dict, [switch]$normalize, [switch]$strict) {
  if (-not $dict -or $dict.Count -eq 0) { return $null }

  # Exact
  if ($fileName -and $dict.ContainsKey($fileName)) {
    return [pscustomobject]@{ Name=$fileName; Hash=$dict[$fileName]; Mode="Exact" }
  }

  # Normalized
  if ($normalize -and $fileName) {
    $targetN = Normalize-Name $fileName
    foreach ($key in $dict.Keys) {
      if ((Normalize-Name $key) -eq $targetN) {
        return [pscustomobject]@{ Name=$key; Hash=$dict[$key]; Mode="Normalized" }
      }
    }
  }

  # Single ZIP in checks (fallback) — лише коли НЕ строгий режим
  if (-not $strict) {
    $zipEntries = @($dict.Keys | Where-Object { $_.ToLower().EndsWith(".zip") })
    if ($zipEntries.Count -eq 1) {
      $k = $zipEntries[0]
      return [pscustomobject]@{ Name=$k; Hash=$dict[$k]; Mode="SingleZipInChecks" }
    }
  }

  return $null
}

# --- 8) Звірка SHA256 (за наявності умов) ---
if ($VerifyChecksums) {
  if (-not $targetZipName -and $LocalZip) { $targetZipName = Split-Path $LocalZip -Leaf; Write-Log "Використовую ім’я з LocalZip: $targetZipName" }

  $match = Find-ChecksumFor -fileName $targetZipName -dict $checksDict -normalize:$ZipNameNormalize -strict:$StrictMatch
  if (-not $match) {
    if ($checksDict.Count -gt 0) {
      $avail = ($checksDict.Keys | Sort-Object) -join ', '
      Write-Log "Не знайдено рядок у CHECKSUMS для '$targetZipName'. Доступні: $avail" "ERROR"
    } else {
      Write-Log "CHECKSUMS порожній або нечитабельний." "ERROR"
    }
    $fail = $true
  } else {
    Write-Log "Checksum для '$($match.Name)' знайдено (mode: $($match.Mode))."
    if ($LocalZip) {
      try {
        $hash = (Get-FileHash -LiteralPath $LocalZip -Algorithm SHA256).Hash.ToLower()
        if ($hash -ne $match.Hash) { Write-Log "SHA256 НЕ збігається для '$($match.Name)'. Local=$hash vs Ref=$($match.Hash)" "ERROR"; $fail = $true }
        else { Write-Log "SHA256 збігається для '$($match.Name)'." }
      } catch { Write-Log "Помилка обчислення SHA256 для '$LocalZip'. $_" "ERROR"; $fail = $true }
    } else {
      Write-Log "Знайдено checksum, але -LocalZip не задано — звірку пропущено." "WARN"
    }
  }
}

# --- 9) Фінал ---
if ($fail) { Write-Log "Перевірка релізу НЕ пройдена." "ERROR"; exit 9 }
Write-Log "✅ Перевірка релізу успішна."; exit 0
