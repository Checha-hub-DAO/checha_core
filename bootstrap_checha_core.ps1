# bootstrap_checha_core.ps1
param(
  [string]$ZipPath = "$env:USERPROFILE\Downloads\CHECHA_Release_Repo_Skeleton_v1.0.zip",
  [string]$Target  = "C:\CHECHA_CORE",
  [switch]$SetRemote,
  [string]$RemoteUrl = ""
)

$ErrorActionPreference = "Stop"

function Info($m){ Write-Host "[i] $m" }
function Ok($m){ Write-Host "✅ $m" -ForegroundColor Green }
function Warn($m){ Write-Warning $m }
function Fail($m){ Write-Error $m; exit 1 }

# 0) Preconditions
if (-not (Test-Path $ZipPath)) { Fail "ZIP not found: $ZipPath" }

# 1) Prepare target
if (-not (Test-Path $Target)) {
  New-Item -ItemType Directory -Path $Target | Out-Null
  Info "Created $Target"
}

# 2) Unpack
$unpack = Join-Path $env:TEMP ("CHECHA_unpack_" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $unpack | Out-Null
Expand-Archive -Path $ZipPath -DestinationPath $unpack -Force
Ok "Unpacked skeleton to temp"

# 3) Detect inner root folder
$inner = Get-ChildItem $unpack | Where-Object { $_.PsIsContainer -and $_.Name -like "CHECHA_Release_Repo_Skeleton_v1.0*" } | Select-Object -First 1
if (-not $inner) { Fail "Inner folder not found in ZIP." }
$innerPath = $inner.FullName

# 4) Copy contents into target
Info "Copying files to $Target ..."
Copy-Item -Recurse -Force (Join-Path $innerPath "*") $Target
Ok "Files copied"

# 5) Git init & first commit
Set-Location $Target
function HasCmd($n){ $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

if (-not (HasCmd "git")) {
  Warn "git not found; skipping repo init."
} else {
  if (-not (Test-Path ".git")) {
    git init | Out-Null
    Ok "Git repo initialized"
  }
  git add . | Out-Null
  try {
    git commit -m "init: CHECHA Release Repo Skeleton v1.0" | Out-Null
    Ok "First commit created"
  } catch {
    Warn "Commit skipped (maybe nothing to commit)"
  }

  if ($SetRemote -and $RemoteUrl) {
    try {
      git remote add origin $RemoteUrl
      Ok "Remote set: $RemoteUrl"
    } catch {
      Warn "Remote add failed (maybe exists)"
      try { git remote set-url origin $RemoteUrl; Ok "Remote updated: $RemoteUrl" } catch {}
    }
  }
}

# 6) Install pre-push hook
if (Test-Path "tools/install_hooks.ps1") {
  try {
    pwsh -NoProfile -ExecutionPolicy Bypass -File "tools/install_hooks.ps1"
    Ok "Pre-push hook installed"
  } catch {
    Warn "Hook install failed: $($_.Exception.Message)"
  }
} else {
  Warn "tools/install_hooks.ps1 not found"
}

# 7) Show next steps
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1) Put your packable content into: $Target\build\ETHNO"
Write-Host "  2) Check release.config.json"
Write-Host "  3) Run: pwsh tools/release_run.ps1 -Config release.config.json"
Write-Host "  4) (opt) Publish: pwsh tools/gh_release.ps1 -Tag (Get-Content release.config.json | ConvertFrom-Json).Tag -Clobber"
Write-Host ""
Ok "Bootstrap complete at $Target"