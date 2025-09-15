param([string]$Root,[string]$Label)
$ErrorActionPreference = "Stop"

function Resolve-CoreRoot {
  param([string]$Start)
  $cands = @()
  if ($Start) {
    $p = Split-Path -Parent $Start
    for ($i=0; $i -lt 8; $i++) { if ($p) { $cands += $p }; $parent = Split-Path -Parent $p; if (-not $parent -or $parent -eq $p) { break }; $p = $parent }
  }
  $cands += @($env:CHECHA_CORE, "C:\CHECHA_CORE", "D:\CHECHA_CORE") | Where-Object { $_ }
  foreach ($c in $cands) { try { if (Test-Path (Join-Path $c "C06")) { return (Resolve-Path $c).Path } } catch {} }
  throw "Не знайдено корінь CHECHA_CORE. Передай -Root або встанови env:CHECHA_CORE (у корені має бути тека C06). Перевірені: $($cands -join '; ')"
}

$coreRoot = if ($Root) { (Resolve-Path $Root).Path } else { $here = ($PSCommandPath ?? $MyInvocation.MyCommand.Path); Resolve-CoreRoot -Start $here }
$archiveDir = Join-Path $coreRoot "C05\ARCHIVE"
$toolsDir   = Join-Path $coreRoot "C11\C11_AUTOMATION\tools"
$updScript  = Join-Path $toolsDir "Update-Dashboard.ps1"
$updRel     = Join-Path $toolsDir "Update-Dashboard-Releases.ps1"
$updHealth  = Join-Path $toolsDir "Update-Dashboard-Health.ps1"
$cleanup    = Join-Path $toolsDir "Cleanup-Releases.ps1"
$eventsLog  = Join-Path $coreRoot "C03\LOG\events.jsonl"
New-Item -ItemType Directory -Force -Path $archiveDir,(Split-Path $eventsLog -Parent) | Out-Null

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$rand = -join ((48..57 + 97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
$labelPart = if ([string]::IsNullOrWhiteSpace($Label)) { "" } else { "_$Label" }
$zipName = "CHECHA_CORE_PUSH_${ts}_${rand}${labelPart}.zip"
$zipPath = Join-Path $archiveDir $zipName

# staging
$tempRoot = Join-Path $env:TEMP ("CHECHA_RELEASE_" + [guid]::NewGuid().Guid)
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$excludeDirs = @("C05\ARCHIVE",".git",".github","CHECHA_BACKUPS") | ForEach-Object { Join-Path $coreRoot $_ } | Where-Object { Test-Path $_ }
$xdArgs = @(); foreach($d in $excludeDirs){ $xdArgs += @("/XD", $d) }
$robocmd = @("robocopy", $coreRoot, $tempRoot, "/MIR","/R:1","/W:1","/NFL","/NDL","/NJH","/NJS","/XF","*.zip","*.7z") + $xdArgs

& $robocmd[0] $robocmd[1..($robocmd.Count-1)] | Out-Null
$rc = $LASTEXITCODE
if ($rc -ge 8) {
  Start-Sleep 3
  & $robocmd[0] $robocmd[1..($robocmd.Count-1)] | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "ROBOCOPY code=$LASTEXITCODE after retry" }
}

if (Test-Path $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $tempRoot "*") -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item -LiteralPath $tempRoot -Recurse -Force

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
"$hash  $zipName" | Set-Content -LiteralPath ($zipPath + ".sha256") -Encoding ASCII
Add-Content -LiteralPath (Join-Path $archiveDir "CHECKSUMS.txt") -Value ("{0}  {1}" -f $hash,$zipName) -Encoding ASCII

if (Test-Path $updScript) { & $updScript }
if (Test-Path $updRel)    { & $updRel }
if (Test-Path $updHealth) { & $updHealth }
if (Test-Path $cleanup)   { & $cleanup }

# JSON подія
$event = [ordered]@{ ts=(Get-Date).ToString("s"); type="release"; label=$Label; zip=$zipName; size=(Get-Item $zipPath).Length }
"$($event | ConvertTo-Json -Compress)" | Add-Content -LiteralPath $eventsLog -Encoding UTF8

Write-Host "✅ Release ready:" $zipPath
