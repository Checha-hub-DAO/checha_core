Param(
  [string]$Module,
  [string[]]$Modules,
  [string]$Root = "C:\CHECHA_CORE",
  [switch]$All,
  [switch]$Quiet
)

Set-StrictMode -Version Latest

function Write-RelLog {
  param(
    [string]$Root,
    [string]$Module,[string]$Version,[string]$Build,[string]$Status,
    [bool]$ShaMatch,[bool]$ChecksumEntry,[string]$Zip,[string]$Msg
  )
  $utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $line = "[timestamp=$utc] module=$Module version=$Version build=$Build status=$Status sha_match=$ShaMatch checksum_entry=$ChecksumEntry zip=$Zip msg=`"$Msg`""
  $logDir = Join-Path $Root "C03\LOG"
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  Add-Content -Path (Join-Path $logDir 'releases_validate.log') -Value $line -Encoding UTF8
}

function ColorSay([string]$Text,[string]$Level){
  if($Quiet){ return }
  switch($Level){
    "OK"   { Write-Host $Text -ForegroundColor Green }
    "WARN" { Write-Host $Text -ForegroundColor Yellow }
    "FAIL" { Write-Host $Text -ForegroundColor Red }
    default{ Write-Host $Text }
  }
}

function Parse-VersionFile([string]$Path){
  $map = @{}
  if(-not (Test-Path $Path)){ return $map }
  foreach($ln in (Get-Content -LiteralPath $Path)){
    if($ln -match '^([^:]+):\s*(.*)$'){
      $map[$matches[1].Trim()] = $matches[2].Trim()
    }
  }
  return $map
}

function Validate-One([string]$Root,[string]$Mod){
  $releaseDir = Join-Path $Root "G\$Mod\RELEASES"
  if(-not (Test-Path $releaseDir)){
    ColorSay "⚠️ $Mod: немає каталогу RELEASES/" "WARN"
    Write-RelLog -Root $Root -Module $Mod -Version "n/a" -Build "n/a" -Status "WARN" -ShaMatch:$false -ChecksumEntry:$false -Zip "" -Msg "missing RELEASES dir"
    return "WARN"
  }

  $versionFile = Join-Path $releaseDir "VERSION.txt"
  $checksumFile = Join-Path $releaseDir "CHECKSUMS.txt"

  if(-not (Test-Path $versionFile)){
    ColorSay "❌ $Mod: відсутній VERSION.txt" "FAIL"
    Write-RelLog -Root $Root -Module $Mod -Version "n/a" -Build "n/a" -Status "FAIL" -ShaMatch:$false -ChecksumEntry:$false -Zip "" -Msg "missing VERSION.txt"
    return "FAIL"
  }
  if(-not (Test-Path $checksumFile)){
    ColorSay "❌ $Mod: відсутній CHECKSUMS.txt" "FAIL"
    $vf = Parse-VersionFile $versionFile
    Write-RelLog -Root $Root -Module $Mod -Version ($vf["VERSION"] ?? "n/a") -Build ($vf["BUILD"] ?? "n/a") -Status "FAIL" -ShaMatch:$false -ChecksumEntry:$false -Zip "" -Msg "missing CHECKSUMS.txt"
    return "FAIL"
  }

  $vf = Parse-VersionFile $versionFile
  $version = $vf["VERSION"]; if([string]::IsNullOrWhiteSpace($version)){$version="n/a"}
  $build   = $vf["BUILD"];   if([string]::IsNullOrWhiteSpace($build)){$build="n/a"}
  $shaExp  = $vf["SHA256"];  if([string]::IsNullOrWhiteSpace($shaExp)){$shaExp=""}

  $zip = Get-ChildItem -LiteralPath $releaseDir -Filter *.zip -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if(-not $zip){
    ColorSay "❌ $Mod: немає ZIP-файлів у RELEASES/" "FAIL"
    Write-RelLog -Root $Root -Module $Mod -Version $version -Build $build -Status "FAIL" -ShaMatch:$false -ChecksumEntry:$false -Zip "" -Msg "missing zip"
    return "FAIL"
  }

  # Compute actual SHA256
  $shaAct = (Get-FileHash -LiteralPath $zip.FullName -Algorithm SHA256).Hash
  $shaMatch = ($shaExp -ne "") -and ($shaAct -eq $shaExp)

  # Check checksum entry for the zip
  $checksumLines = Get-Content -LiteralPath $checksumFile
  $zipLine = $checksumLines | Where-Object { $_ -match [regex]::Escape($zip.Name) }
  $checksumEntry = $false
  if($zipLine){
    # optional: verify hash in line equals actual
    if($zipLine -match '^([A-Fa-f0-9]{64})\s{2,}(.+)$'){
      $checksumEntry = ($matches[1].ToUpper() -eq $shaAct.ToUpper())
    } else {
      # if format unknown but entry exists, count as present
      $checksumEntry = $true
    }
  }

  # Decide status
  $status = "OK"
  $msg = "validated successfully"
  if(-not $shaMatch -and -not [string]::IsNullOrWhiteSpace($shaExp)){
    $status = "WARN"; $msg = "sha mismatch"
  }
  if(-not $checksumEntry){
    $status = if($status -eq "OK"){"WARN"} else {$status}
    if($msg -eq "validated successfully"){ $msg = "missing CHECKSUMS entry" } else { $msg += "; missing CHECKSUMS entry" }
  }
  if([string]::IsNullOrWhiteSpace($shaExp)){
    $status = if($status -eq "OK"){"WARN"} else {$status}
    $msg = "missing SHA256 in VERSION.txt" + ($(if($msg -ne "validated successfully"){"; " + $msg}else{""}))
  }

  ColorSay ("{0} {1}: {2} ({3}) — {4}" -f ($(if($status -eq "OK"){"✅"}elseif($status -eq "WARN"){"⚠️"}else{"❌"}), $Mod, $version, $zip.Name, $msg)) $status
  Write-RelLog -Root $Root -Module $Mod -Version $version -Build $build -Status $status -ShaMatch:$shaMatch -ChecksumEntry:$checksumEntry -Zip $zip.Name -Msg $msg

  return $status
}

# Resolve modules list
$modsToRun = @()
if($All){
  $json = Join-Path $Root "C06\FOCUS\data\modules.json"
  if(Test-Path $json){
    try {
      $data = Get-Content -LiteralPath $json -Raw | ConvertFrom-Json
      $modsToRun = $data.modules.code
    } catch {
      # fallback to filesystem
    }
  }
  if(-not $modsToRun -or $modsToRun.Count -eq 0){
    $modsToRun = Get-ChildItem -LiteralPath (Join-Path $Root "G") -Directory -Filter "G*" | Select-Object -ExpandProperty Name
  }
} elseif($Modules){
  $modsToRun = $Modules
} elseif($Module){
  $modsToRun = @($Module)
} else {
  Write-Host "Usage: .\Validate-Releases.ps1 -Module G28 | -Modules G28,G09 | -All [-Root C:\CHECHA_CORE] [-Quiet]" -ForegroundColor Yellow
  exit 3
}

$hasWarn = $false
$hasFail = $false

foreach($m in $modsToRun){
  $st = Validate-One -Root $Root -Mod $m
  if($st -eq "WARN"){$hasWarn=$true}
  elseif($st -eq "FAIL"){$hasFail=$true}
}

if($hasFail){ exit 2 }
elseif($hasWarn){ exit 1 }
else{ exit 0 }