<#
  Run-VerifySync-WithConfig.ps1
  Universal verify (ZIP+CHECKSUMS) + GitBook publish + SYNC.md writer
  Version: 1.4 (ASCII-safe; balanced braces)
#>

param(
  [Parameter(Mandatory=$true)][string]$ChechaRoot,
  [Parameter(Mandatory=$true)][string]$ConfigPath,
  [switch]$UseGitHubAssets,
  [switch]$RunGitBook,
  [switch]$DoGitCommitPush
)

function Write-LogLine {
  param([string]$Message,[ValidateSet("INFO","WARN","ERROR")][string]$Level="INFO")
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "{0} [{1,-5}] {2}" -f $ts,$Level,$Message
  Write-Host $line
  return $line
}

function Add-ToMainLog {
  param([string]$ChechaRoot,[string]$MessageLine)
  $p = Join-Path $ChechaRoot "C03\LOG\LOG.md"
  try { Add-Content -Path $p -Value $MessageLine -Encoding utf8 } catch { }
}

function Get-ChecksumsFromFile {
  param([string]$ChecksumsPath)
  $map = @{}
  Get-Content -Path $ChecksumsPath | ForEach-Object {
    $line = $_.Trim()
    if (-not $line) { return }
    if ($line -match "^\s*([0-9A-Fa-f]{64})\s+(\*?)(.+?)\s*$") {
      $hash = $Matches[1].ToUpper()
      $name = $Matches[3].Trim('"')
      $map[(Split-Path -Leaf $name)] = $hash
      return
    }
    if ($line -match "^\s*SHA256\s*\((.+?)\)\s*=\s*([0-9A-Fa-f]{64})\s*$") {
      $name = $Matches[1].Trim('"')
      $hash = $Matches[2].ToUpper()
      $map[(Split-Path -Leaf $name)] = $hash
      return
    }
  }
  return $map
}

function Get-FileSha256Hex { param([string]$Path) (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToUpper() }
function Write-Utf8Bom { param([string]$Path,[string]$Text) [IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($true)) }

# Load config
if (-not (Test-Path $ConfigPath)) { throw "Config not found: $ConfigPath" }
$cfg = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json

$Repo               = $cfg.Repo
$Tag                = $cfg.Tag
$ZipName            = $cfg.ZipName
$GModuleDir         = $cfg.ModuleDir
$LocalReleasesDir   = if ($cfg.LocalReleasesDir) { $cfg.LocalReleasesDir } else { Join-Path $ChechaRoot "G\RELEASES\ARCHIVE" }
$GitBookRepoRoot    = if ($cfg.GitBookRepoRoot) { $cfg.GitBookRepoRoot } else { Join-Path $ChechaRoot "GitBook" }
$GitBookSubPath     = $cfg.GitBookSubPath
$GitBookExpectedSlug= $cfg.ExpectedSlug
$GitCommitMessage   = if ($cfg.GitCommitMessage) { $cfg.GitCommitMessage } else { "Verify+Publish: " + $cfg.Name }

# Mutex
$slug = $GitBookExpectedSlug
$lock = Join-Path $env:TEMP ("checha_lock_" + $slug + ".lock")
if (Test-Path $lock) { Write-Host "Already running: $lock"; exit 2 }
New-Item -ItemType File -Path $lock -Force | Out-Null

# Logging
$sessionId = Get-Date -Format "yyyyMMdd_HHmmss"
$runLogPath = Join-Path $ChechaRoot ("C03\LOG\verify_{0}_{1}.log" -f $slug,$sessionId)
"BEGIN verify {0} :: {1}" -f $slug,$sessionId | Out-File -FilePath $runLogPath -Encoding UTF8

# ensure BOM for run log (so Get-Content detects UTF-8)
try {
  \ = Get-Content -Raw -LiteralPath \
  [IO.File]::WriteAllText(\, \, [Text.UTF8Encoding]::new(\True))
} catch {}
try {
  (Write-LogLine ("Start verify " + $Tag + " in " + $Repo) "INFO") | Add-Content $runLogPath

  # 1) Fetch ZIP & CHECKSUMS
  $tempDir = Join-Path $env:TEMP ("checha_{0}_{1}" -f $slug,$sessionId)
  New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
  $zipPath       = Join-Path $tempDir $ZipName
  $checksumsPath = Join-Path $tempDir "CHECKSUMS.txt"

  if ($UseGitHubAssets) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "gh CLI not found" }
    gh release download $Tag --repo $Repo --pattern "CHECKSUMS.txt" --dir $tempDir | Out-Null
    if (-not (Test-Path $checksumsPath)) { throw "CHECKSUMS.txt not downloaded" }
    gh release download $Tag --repo $Repo --pattern $ZipName --dir $tempDir | Out-Null
    if (-not (Test-Path $zipPath)) { throw "ZIP not downloaded: " + $ZipName }
  } else {
    $localZip = Join-Path $LocalReleasesDir $ZipName
    $localChk = Join-Path $LocalReleasesDir "CHECKSUMS.txt"
    if (-not (Test-Path $localZip)) { throw "Local ZIP missing: " + $localZip }
    if (-not (Test-Path $localChk)) { throw "Local CHECKSUMS missing: " + $localChk }
    Copy-Item $localZip $zipPath -Force
    Copy-Item $localChk $checksumsPath -Force
  }

  if ((Get-Item $zipPath).Length -le 0) { throw "ZIP is empty: " + $zipPath }

  $map = Get-ChecksumsFromFile -ChecksumsPath $checksumsPath
  if ($map.Count -eq 0) { throw "CHECKSUMS.txt empty or invalid" }

  $zipLeaf = Split-Path -Leaf $ZipName
  $expected = $null
  if ($map.ContainsKey($zipLeaf)) {
    $expected = $map[$zipLeaf]
  } else {
    $cand = $map.Keys | Where-Object { (Split-Path -Leaf $_) -ieq $zipLeaf } | Select-Object -First 1
    if ($cand) {
      $expected = $map[$cand]
    } else {
      $tmpActual = Get-FileSha256Hex -Path $zipPath
      $byHash = $map.GetEnumerator() | Where-Object { $_.Value -eq $tmpActual } | Select-Object -First 1
      if ($byHash) { $expected = $byHash.Value } else { throw "No entry for " + $zipLeaf + " in CHECKSUMS.txt" }
    }
  }

  $actual = Get-FileSha256Hex -Path $zipPath
  if ($expected -ne $actual) { throw ("SHA-256 mismatch. Expected: " + $expected + "; Actual: " + $actual) }

  (Write-LogLine ("Checksum OK (" + $actual + ")") "INFO") | Add-Content $runLogPath
  Add-ToMainLog -ChechaRoot $ChechaRoot -MessageLine ( (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " [INFO ] " + $slug + ": checksum OK; tag=" + $Tag + "; zip=" + $ZipName + "; sha256=" + $actual )

  # 2) GitBook publish (optional)
  if ($RunGitBook) {
    $GitBookPublishScript = Join-Path $ChechaRoot "C11\C11_AUTOMATION\tools\GitBookStdPack\Publish-GitBook-Submodule.ps1"
    if (-not (Test-Path $GitBookPublishScript)) { throw "GitBook script not found: " + $GitBookPublishScript }
    if (-not (Test-Path $GitBookRepoRoot)) { throw "GitBookRepoRoot not found: " + $GitBookRepoRoot }
    $root = Join-Path $GitBookRepoRoot $GitBookSubPath

    & $GitBookPublishScript -Root $root -ExpectedSlug $GitBookExpectedSlug -RepoRoot $GitBookRepoRoot -CommitMsg $GitCommitMessage
    $rc = $LASTEXITCODE
    if ($rc -ne 0) {
      (Write-LogLine ("Publish code=" + $rc + ", rebase/push then retry") "WARN") | Add-Content $runLogPath
      Push-Location $GitBookRepoRoot
      git fetch origin
      git pull --rebase --autostash
      git push
      Pop-Location
      & $GitBookPublishScript -Root $root -ExpectedSlug $GitBookExpectedSlug -RepoRoot $GitBookRepoRoot -CommitMsg $GitCommitMessage
      $rc = $LASTEXITCODE
      if ($rc -ne 0) { throw ("GitBook publish failed code " + $rc) }
    }
    (Write-LogLine ("GitBook publish OK (" + $GitBookExpectedSlug + ")") "INFO") | Add-Content $runLogPath
  }

  # 3) SYNC.md
  if (-not (Test-Path $GModuleDir)) { throw "Module directory not found: " + $GModuleDir }
  $syncPath = Join-Path $GModuleDir "SYNC.md"
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $source = if ($UseGitHubAssets) { "GitHub Release (" + $Repo + ")" } else { "Local Releases (" + $LocalReleasesDir + ")" }
  $bt = [char]0x60

  $content = @"
# Sync Map — $($cfg.Name)

Updated: $ts

## Release artifacts
- Tag: $bt$Tag$bt
- ZIP: $bt$ZipName$bt
- SHA-256: $bt$actual$bt
- Source: $source

---
> Auto-updated by Run-VerifySync-WithConfig.ps1 for $bt$($cfg.Name)$bt.
"@

  Write-Utf8Bom -Path $syncPath -Text $content
  (Write-LogLine ("SYNC.md updated -> " + $syncPath) "INFO") | Add-Content $runLogPath

  # 4) Normalization (optional, safe)
  $conv = Join-Path $ChechaRoot "C11\C11_AUTOMATION\tools\Convert-ToUtf8.ps1"
  try {
    if (Test-Path $conv) {
      & $conv -Path (Join-Path $ChechaRoot "C03\LOG") -IncludeExt .md,.log -NormalizeEol -AssumeLegacy cp1251 | Out-Null
      & $conv -Path $GModuleDir -IncludeExt .md -NormalizeEol | Out-Null
      (Write-LogLine "Normalization OK" "INFO") | Add-Content $runLogPath
    } else {
      (Write-LogLine "Normalization skipped: converter not found" "WARN") | Add-Content $runLogPath
    }
  } catch {
    (Write-LogLine ("Normalization skipped: " + $_.Exception.Message) "WARN") | Add-Content $runLogPath
  }

  # 5) Git commit/push (optional)
  if ($DoGitCommitPush) {
    Push-Location $GitBookRepoRoot
    git add -A | Out-Null
    git commit -m $GitCommitMessage | Out-Null
    git push
    if ($LASTEXITCODE -ne 0) {
      git pull --rebase --autostash
      git push
    }
    Pop-Location
    (Write-LogLine ("Git commit/push OK in " + $GitBookRepoRoot) "INFO") | Add-Content $runLogPath
  }

  (Write-LogLine ("DONE OK: " + $cfg.Name) "INFO") | Add-Content $runLogPath

} catch {
  (Write-LogLine ("FAILED: " + $_.Exception.Message) "ERROR") | Add-Content $runLogPath
  throw
} finally {
  Get-ChildItem (Join-Path $ChechaRoot "C03\LOG") -Filter ("verify_{0}_*.log" -f $slug) -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Desc | Select-Object -Skip 30 | Remove-Item -Force -ErrorAction SilentlyContinue
  if (Test-Path $lock) { Remove-Item $lock -Force -ErrorAction SilentlyContinue }
}


