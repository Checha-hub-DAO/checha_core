[CmdletBinding()]
Param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$OutDir = $null,
  [int]$Keep = 5,
  [switch]$GitPush,
  [switch]$Quiet,
  [switch]$RebuildChecks,
  [switch]$SanitizeLog,
  [string]$MirrorOutDir = $null,
  [string[]]$Exclude = @(),                                 # NEW: топ-рівневі маски (наприклад: 'repos','build','gallery','_tmp*')
  [ValidateSet('Optimal','Fastest','NoCompression')]
  [string]$CompressionLevel = 'Optimal'                     # NEW: швидкість/якість
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function W([string]$m){ if(-not $Quiet){ Write-Host $m } }
function Normalize([string]$p){ ([IO.Path]::GetFullPath($p)).TrimEnd('\').ToLowerInvariant() }

# ---- single-instance guard ---- (не дублюємо, якщо вже є)
if (-not (Get-Variable -Name __checha_mutex -Scope Global -ErrorAction SilentlyContinue)) {
  $global:__checha_mutex = New-Object System.Threading.Mutex($false, "Local\CHECHA_BACKUP_MUTEX")
}
if(-not $global:__checha_mutex.WaitOne(0)){
  Write-Host "[SKIP] Another backup instance is running. Exiting."
  exit 0
}
Register-EngineEvent PowerShell.Exiting -Action {
  try { if($global:__checha_mutex){ $global:__checha_mutex.ReleaseMutex(); $global:__checha_mutex.Dispose() } } catch {}
} | Out-Null

# 0) Paths
if(-not $OutDir){ $OutDir = Join-Path $env:USERPROFILE "CHECHA_BACKUPS" }
$LogPath = Join-Path $Root "C03_LOG\LOG.md"
$Checks  = Join-Path $OutDir "CHECKSUMS.txt"
if(-not (Test-Path $Root)){ throw "Root not found: $Root" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $LogPath -Parent) | Out-Null
if(-not (Test-Path $Checks)){ New-Item -ItemType File -Force -Path $Checks | Out-Null }
if(-not (Test-Path $LogPath)){ New-Item -ItemType File -Force -Path $LogPath | Out-Null }

# 1) Sanitize LOG (optional)
if($SanitizeLog){
  $lines = Get-Content -Path $LogPath -ErrorAction SilentlyContinue
  if($lines){
    $valid = $lines | Where-Object {
      $_ -match '^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+\|\s+BACKUP\s+\|\s+\S+\.zip\s+\|\s+SHA256:\s+[0-9A-Fa-f]{64}(\s+\|\s+FILES:\s+\d+\s+\|\s+SIZE_MB:\s+[\d\.]+)?\s*$' -or
      ($_ -notmatch '\|\s*BACKUP\s*\|')
    }
    if(($valid -join "`n") -ne ($lines -join "`n")){
      $valid | Set-Content -Path $LogPath -Encoding utf8
      W "[HEAL] LOG.md sanitized"
    }
  }
}

# 2) Build include list
#    - Виключаємо топ-рівневі елементи за масками з -Exclude
#    - Для C05_ARCHIVE беремо всі підтеки/файли КРІМ 'releases' (щоб не тягнути старі релізи)
$rootEntries = Get-ChildItem -LiteralPath $Root -Force
$include = New-Object System.Collections.Generic.List[string]
$excludedTop = [System.Collections.Generic.List[string]]::new()
foreach($e in $rootEntries){
  $skip = $false
  foreach($pat in $Exclude){
    if($e.Name -like $pat){ $skip=$true; break }
  }
  if($skip){ $excludedTop.Add($e.Name); continue }

  if($e.PSIsContainer -and $e.Name -ieq 'C05_ARCHIVE'){
    $children = Get-ChildItem -LiteralPath $e.FullName -Force
    foreach($ch in $children){
      if($ch.Name -ieq 'releases'){ continue }
      $include.Add($ch.FullName)
    }
  } else {
    $include.Add($e.FullName)
  }
}
if($include.Count -eq 0){ throw "Nothing to archive in $Root (all excluded?)" }
W ("[INFO] Items to archive (top-level excluded: {0}): {1}" -f ($excludedTop -join ','), $include.Count)

# 3) Zip in TEMP → move to OutDir (with retries)
$ts     = Get-Date -Format 'yyyyMMdd_HHmmss'
$guid8  = [Guid]::NewGuid().ToString('N').Substring(0,8)
$zip    = "CHECHA_CORE_PUSH_{0}_{1}.zip" -f $ts,$guid8
$tmpZip = Join-Path $env:TEMP $zip
$dstZip = Join-Path $OutDir $zip
if(Test-Path $tmpZip){ Remove-Item $tmpZip -Force }

W "[RUN] Compressing to TEMP…"
Compress-Archive -Path $include -DestinationPath $tmpZip -CompressionLevel $CompressionLevel
if(-not (Test-Path $tmpZip)){ throw "Temp zip not created: $tmpZip" }

$attempt=0;$max=10;$moved=$false
do{
  $attempt++
  try{
    Move-Item -LiteralPath $tmpZip -Destination $dstZip -Force
    $moved = Test-Path $dstZip
    if(-not $moved){
      Copy-Item -LiteralPath $tmpZip -Destination $dstZip -Force
      Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
      $moved = Test-Path $dstZip
    }
  } catch {
    Start-Sleep -Milliseconds (200 * [Math]::Min($attempt,6))
  }
} while(-not $moved -and $attempt -lt $max)
if(-not $moved){ throw ("Failed to move zip to {0}: {1}" -f $OutDir, $dstZip) }
W ("[OK] Zip created: {0}" -f $dstZip)

# 4) Checksums + LOG (+ manifest)
$sha = (Get-FileHash $dstZip -Algorithm SHA256).Hash
$filesCount = (& tar -tf $dstZip 2>$null | Measure-Object).Count  # швидка оцінка (якщо tar є), інакше пропустити
if(-not $filesCount){ $filesCount = 0 }
$sizeMB = [math]::Round((Get-Item $dstZip).Length/1MB, 1)

if($RebuildChecks){
  $zips = Get-ChildItem -LiteralPath $OutDir -Filter 'CHECHA_CORE_PUSH_*.zip' | Sort-Object LastWriteTime
  $tmp = New-TemporaryFile
  foreach($z in $zips){
    $h = if($z.FullName -eq $dstZip){ $sha } else { (Get-FileHash $z.FullName -Algorithm SHA256).Hash }
    "{0}  {1}" -f $z.Name, $h | Add-Content -Path $tmp -Encoding utf8
  }
  Get-Content $tmp | Set-Content -Path $Checks -Encoding utf8
  Remove-Item $tmp -Force
  W "[HEAL] CHECKSUMS rebuilt"
} else {
  $escapedZip = [regex]::Escape($zip)
  $pat = ("^{0}\s+[0-9A-Fa-f]{{64}}\s*$" -f $escapedZip)
  $has = Select-String -Path $Checks -Pattern $pat -Quiet -ErrorAction SilentlyContinue
  if(-not $has){ Add-Content -Path $Checks -Value "$zip  $sha" -Encoding utf8 }
}
$line = "{0} | BACKUP | {1} | SHA256: {2} | FILES: {3} | SIZE_MB: {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $zip, $sha, $filesCount, $sizeMB
Add-Content -Path $LogPath -Value $line

# 5) Rotation in OutDir
if($Keep -gt 0){
  $all = Get-ChildItem -LiteralPath $OutDir -Filter 'CHECHA_CORE_PUSH_*.zip' | Sort-Object LastWriteTime -Descending
  if($all.Count -gt $Keep){
    $all | Select-Object -Skip $Keep | Remove-Item -Force
    $now = Get-ChildItem -LiteralPath $OutDir -Filter 'CHECHA_CORE_PUSH_*.zip' | Sort-Object LastWriteTime
    $tmp2 = New-TemporaryFile
    foreach($z in $now){
      "{0}  {1}" -f $z.Name, (Get-FileHash $z.FullName -Algorithm SHA256).Hash | Add-Content -Path $tmp2 -Encoding utf8
    }
    Get-Content $tmp2 | Set-Content -Path $Checks -Encoding utf8
    Remove-Item $tmp2 -Force
  }
}

# 6) MIRROR (optional)
if($MirrorOutDir){
  New-Item -ItemType Directory -Force -Path $MirrorOutDir | Out-Null
  $MirrorChecks = Join-Path $MirrorOutDir 'CHECKSUMS.txt'
  if(-not (Test-Path $MirrorChecks)){ New-Item -ItemType File -Force -Path $MirrorChecks | Out-Null }

  $mirrorZip = Join-Path $MirrorOutDir (Split-Path $dstZip -Leaf)
  $attempt=0;$max=10;$ok=$false
  do{
    $attempt++
    try{
      Copy-Item -LiteralPath $dstZip -Destination $mirrorZip -Force
      $ok = Test-Path $mirrorZip
    } catch {
      Start-Sleep -Milliseconds (200 * [Math]::Min($attempt,6))
    }
  } while(-not $ok -and $attempt -lt $max)
  if(-not $ok){ throw ("Failed to mirror to {0}: {1}" -f $MirrorOutDir, $mirrorZip) }

  $zipLeaf = Split-Path $mirrorZip -Leaf
  $escapedLeaf = [regex]::Escape($zipLeaf)
  $patM = ("^{0}\s+[0-9A-Fa-f]{{64}}\s*$" -f $escapedLeaf)
  $hasM = Select-String -Path $MirrorChecks -Pattern $patM -Quiet -ErrorAction SilentlyContinue
  if(-not $hasM){
    Add-Content -Path $MirrorChecks -Value ("{0}  {1}" -f $zipLeaf, $sha) -Encoding utf8
  } else {
    (Get-Content $MirrorChecks) | ForEach-Object {
      if($_ -match $patM){ ("{0}  {1}" -f $zipLeaf, $sha) } else { $_ }
    } | Set-Content -Path $MirrorChecks -Encoding utf8
  }

  # rotation in mirror
  if($Keep -gt 0){
    $allM = Get-ChildItem -LiteralPath $MirrorOutDir -Filter 'CHECHA_CORE_PUSH_*.zip' | Sort-Object LastWriteTime -Descending
    if($allM.Count -gt $Keep){
      $allM | Select-Object -Skip $Keep | Remove-Item -Force
      $nowM = Get-ChildItem -LiteralPath $MirrorOutDir -Filter 'CHECHA_CORE_PUSH_*.zip' | Sort-Object LastWriteTime
      $tmpM = New-TemporaryFile
      foreach($z in $nowM){
        "{0}  {1}" -f $z.Name, (Get-FileHash $z.FullName -Algorithm SHA256).Hash | Add-Content -Path $tmpM -Encoding utf8
      }
      Get-Content $tmpM | Set-Content -Path $MirrorChecks -Encoding utf8
      Remove-Item $tmpM -Force
    }
  }

  W ("[MIRROR] Copied: {0}" -f $mirrorZip)
  W ("[MIRROR] Checksums: {0}" -f $MirrorChecks)
}

# 7) Git push (optional)
if($GitPush){
  $isGitRepo = Test-Path (Join-Path $Root ".git")
  if($isGitRepo){
    W "[GIT] add/commit/push…"
    Push-Location $Root
    try{
      & git add -A | Out-Null
      $msg = "chore(backup): $zip"
      & git commit -m $msg 2>$null | Out-Null
      & git push | Out-Null
      W "[GIT] Done."
    } catch {
      W ("[GIT] Warning: {0}" -f $_.Exception.Message)
    } finally { Pop-Location }
  }
}

W "[OK] Backup finished"
W ("📦 {0}" -f $dstZip)
W ("🔑 {0}" -f $sha)
exit 0
