Param([string]$Root="C:\CHECHA_CORE",[int]$K=5,[string]$Version="v2.1")
$ErrorActionPreference = "Stop"
$log  = Join-Path $Root "C03_LOG\initmap.log"
$main = Join-Path $Root "C03_LOG\LOG.md"
$enc  = [System.Text.UTF8Encoding]::new($false)
$dir  = Split-Path $log -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
if (-not (Test-Path $main)) { [System.IO.File]::WriteAllText($main, "# LOG`n", $enc) }
function W([string]$lev,[string]$msg){ $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; Add-Content -Encoding UTF8 -Path $log -Value "$ts [$lev] $msg" }
try {
  W 'INFO ' 'Run-CoordWeekly begin'
  $tools = Join-Path $Root 'C11\C11_AUTOMATION\tools\initmap'
  & pwsh -NoProfile -File (Join-Path $tools 'Validate-InitMap.ps1') -Root $Root
  W 'INFO ' 'Validate done'
  & pwsh -NoProfile -File (Join-Path $tools 'Anonymize-Cells.ps1') -Root $Root
  W 'INFO ' 'Anonymize done'
  & pwsh -NoProfile -File (Join-Path $tools 'Build-Heatmap.ps1') -Root $Root -K $K
  W 'INFO ' ("Heatmap done (k={0})" -f $K)
  & pwsh -NoProfile -File (Join-Path $tools 'Publish-InitMapSnapshot.ps1') -Root $Root -Version $Version
  W 'INFO ' ("Publish done (version={0})" -f $Version)
  Add-Content -Encoding UTF8 -Path $main -Value ("{0} [INFO ] Coord-Weekly OK {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Version)
  exit 0
} catch {
  W 'ERROR' ("Run-CoordWeekly failed: " + $_.Exception.Message)
  Add-Content -Encoding UTF8 -Path $main -Value ("{0} [ERROR] Coord-Weekly FAIL: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $_.Exception.Message)
  exit 1
}
