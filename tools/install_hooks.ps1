# Install pre-push hook that validates release set using release.config.json
param(
  [string]$Config = "release.config.json"
)
$hookDir = ".git/hooks"
if (-not (Test-Path $hookDir)) { Write-Error "Not a git repo (no .git/hooks)"; exit 1 }
$src = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\.githooks\pre-push"
$dst = Join-Path $hookDir "pre-push"
Copy-Item $src $dst -Force
# Make executable on Unix (best-effort)
try { bash -lc "chmod +x .git/hooks/pre-push" } catch {}
Write-Host "✅ Installed pre-push hook. It will run tools/check_release.ps1 before pushing."