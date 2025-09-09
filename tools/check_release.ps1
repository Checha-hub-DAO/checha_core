<#
.SYNOPSIS
  Обгортка для verify_release_assets.ps1 з логуванням і надійним пошуком verify-скрипта.
#>

[CmdletBinding()]
param(
  [string] $Repo = "Checha-hub-DAO/checha_core",
  [Parameter(Mandatory)] [string] $Tag,

  [string] $ZipName,
  [string] $LocalZip,
  [string] $ZipPattern,
  [switch] $AutoDownloadZip,
  [switch] $ZipNameNormalize,
  [switch] $StrictMatch,

  [string[]] $RequireAssets,
  [switch] $RequireMP4,
  [switch] $VerifyChecksums,

  [string] $VerifyPath
)

# 1) Лог
$logDirCandidates = @("C:\CHECHA_CORE\C03\LOG","$env:ProgramData\CHECHA\LOG","$pwd")
$logDir = $logDirCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $logDir) { $logDir = (Get-Location).Path }
$logFile = Join-Path $logDir ("release_check_{0}_{1}.log" -f ($Tag -replace '[^\w\.-]','_'), (Get-Date -Format "yyyyMMdd_HHmmss"))
Write-Host ("Лог: {0}" -f $logFile)

# 2) Must-have
$baseAssets = @()
if ($VerifyChecksums) { $baseAssets += "CHECKSUMS.txt" }
if ($RequireAssets)   { $baseAssets += $RequireAssets }

# 3) Локатор verify_release_assets.ps1
function Resolve-VerifyScript {
  param([string]$ExplicitPath)
  if ($ExplicitPath -and (Test-Path -LiteralPath $ExplicitPath)) {
    return (Resolve-Path -LiteralPath $ExplicitPath).Path
  }
  $here = $null
  if ($PSCommandPath) { $here = Split-Path -Parent $PSCommandPath }
  elseif ($MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
  else { $here = (Get-Location).Path }
  $parent = $null
  try { $parent = (Resolve-Path (Join-Path $here "..") -ErrorAction Stop).Path } catch { }
  $possibleDirs = @($here,$parent,$PSScriptRoot,$env:CHECHA_TOOLS,"C:\CHECHA_CORE\tools") |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
  foreach ($d in $possibleDirs) {
    $candidate = Join-Path $d "verify_release_assets.ps1"
    if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
  }
  return $null
}
$verifyPath = Resolve-VerifyScript -ExplicitPath $VerifyPath
if (-not $verifyPath) {
  Write-Host "ERROR: Не знайдено verify_release_assets.ps1. Передай -VerifyPath або поклади файл у C:\CHECHA_CORE\tools."
  exit 2
}

# 4) Аргументи
$invokeParams = @("-Repo",$Repo,"-Tag",$Tag,"-LogPath",$logFile)
foreach ($a in $baseAssets) { $invokeParams += @("-RequireAssets",$a) }
if ($RequireMP4)       { $invokeParams += "-RequireMP4" }
if ($VerifyChecksums)  { $invokeParams += "-VerifyChecksums" }
if ($LocalZip)         { $invokeParams += @("-LocalZip",$LocalZip) }
if ($ZipName)          { $invokeParams += @("-ZipName",$ZipName) }
if ($ZipPattern)       { $invokeParams += @("-ZipPattern",$ZipPattern) }
if ($AutoDownloadZip)  { $invokeParams += "-AutoDownloadZip" }
if ($ZipNameNormalize) { $invokeParams += "-ZipNameNormalize" }
if ($StrictMatch)      { $invokeParams += "-StrictMatch" }

# 5) Виконання
Write-Host "→ Перевіряю реліз через: $verifyPath"
& powershell -NoProfile -ExecutionPolicy Bypass -File $verifyPath @invokeParams
$code = $LASTEXITCODE
if ($code -eq 0) { Write-Host "✅ Реліз '$Tag' пройшов перевірку. Деталі: $logFile" }
else             { Write-Host "❌ Перевірка релізу '$Tag' завершилась з кодом $code. Дивись лог: $logFile" }
exit $code
