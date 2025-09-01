Set-StrictMode -Version Latest

# Bootstrap naming.ps1 (must sit next to this file)
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$dep = Join-Path $scriptDir 'naming.ps1'
if (-not (Test-Path $dep)) { throw "naming.ps1 not found: $dep" }
. $dep

function Get-RepoSlug {
  [CmdletBinding()]
  param([string]$RepoSlug)
  if ($RepoSlug) { return $RepoSlug }
  try {
    $obj = gh repo view --json nameWithOwner | ConvertFrom-Json
    if ($obj.nameWithOwner) { return $obj.nameWithOwner }
  } catch { }
  throw "Cannot determine RepoSlug. Pass -RepoSlug 'owner/repo'."
}

function Ensure-Release {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Tag,
    [string]$RepoSlug,
    [string]$RepoRoot = (Get-Location).Path,
    [string]$Title,
    [string]$Notes = ""
  )
  $slug = Get-RepoSlug $RepoSlug
  gh release view -R $slug $Tag 1>$null 2>$null
  if ($LASTEXITCODE -eq 0) { return }

  Push-Location $RepoRoot
  try {
    if (-not (git tag -l $Tag)) { git tag $Tag | Out-Null }
    git push origin $Tag | Out-Null
  } finally { Pop-Location }

  if (-not $Title) { $Title = $Tag }
  gh release create -R $slug $Tag --title $Title --notes $Notes | Out-Null
}

function Find-LocalArtifact {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Module,
    [Parameter(Mandatory)][string]$Version,
    [string]$DistDir = (Join-Path (Get-Location) 'dist'),
    [ValidateSet('zip','7z','tar.gz','mp4','pdf','md','txt')]
    [string]$Ext = 'zip'
  )
  $Module = Normalize-ModuleName $Module
  if (-not (Test-Path $DistDir)) { return $null }

  $extPart = if ($Ext -eq 'tar.gz') { 'tar.gz' } else { $Ext }
  $rx = ('^{0}-v{1}_\d{{8}}_\d{{4}}(?:_[A-Za-z0-9-]+)?\.{2}$' -f `
          [regex]::Escape($Module),
          [regex]::Escape($Version),
          [regex]::Escape($extPart))

  $files = Get-ChildItem -Path $DistDir -File | Where-Object { $_.Name -match $rx }
  if (-not $files) { return $null }
  ($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function Ensure-Upload {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Tag,
    [Parameter(Mandatory)][string]$Module,
    [Parameter(Mandatory)][string]$Version,
    [string]$RepoSlug,
    [string]$DistDir = (Join-Path (Get-Location) 'dist'),
    [ValidateSet('zip','7z','tar.gz','mp4','pdf','md','txt')]
    [string]$Ext = 'zip'
  )
  $Module = Normalize-ModuleName $Module
  $slug = Get-RepoSlug $RepoSlug
  $path = Find-LocalArtifact -Module $Module -Version $Version -DistDir $DistDir -Ext $Ext
  if (-not $path) {
    Write-Warning "Local artifact not found in $DistDir for $Module v$Version ($Ext). Skipping upload."
    return
  }
  $name = Split-Path $path -Leaf
  $sumPath = Join-Path $DistDir 'CHECKSUMS.txt'

  $hash = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
  if (Test-Path $sumPath) {
    $content = Get-Content $sumPath -Raw
    $pattern = '^[0-9a-fA-F]{64}\s+' + [regex]::Escape($name) + '\s*$'
    if ($content -match $pattern) {
      $content = [regex]::Replace($content, $pattern, "$hash  $name", 'Multiline')
      $content | Set-Content $sumPath -Encoding UTF8
    } else {
      Add-Content $sumPath ("$hash  $name")
    }
  } else {
    "$hash  $name" | Set-Content $sumPath -Encoding UTF8
  }

  gh release upload -R $slug $Tag $path $sumPath --clobber | Out-Null
  Write-Host "Uploaded: $name + CHECKSUMS.txt -> $Tag"
}

function Test-ReleaseChecksum {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Tag,
    [Parameter(Mandatory)][string]$Module,
    [Parameter(Mandatory)][string]$Version,
    [ValidateSet('zip','7z','tar.gz','mp4','pdf','md','txt')]
    [string]$Ext = 'zip',
    [string]$Suffix,
    [string]$RepoSlug,
    [switch]$ThrowOnMismatch
  )
  $Module = Normalize-ModuleName $Module
  $slug = Get-RepoSlug $RepoSlug

  $json = gh release view -R $slug $Tag --json assets | ConvertFrom-Json
  if (-not $json -or -not $json.assets) { throw "No assets found for release $Tag" }

  $suffixPart = if ($Suffix) { '_' + [regex]::Escape($Suffix) } else { '(?:_[A-Za-z0-9-]+)?' }
  $extPart = if ($Ext -eq 'tar.gz') { 'tar\.gz' } else { [regex]::Escape($Ext) }
  $rx = ('^{0}-v{1}_\d{{8}}_\d{{4}}{2}\.{3}$' -f `
          [regex]::Escape($Module),
          [regex]::Escape($Version),
          $suffixPart,
          $extPart)

  $asset = $json.assets | Where-Object { $_.name -match $rx } | Select-Object -First 1
  if (-not $asset) { throw "No asset matches regex: $rx" }
  $name = $asset.name

  $dir = Join-Path $env:TEMP ('rel_' + [guid]::NewGuid())
  New-Item $dir -ItemType Directory | Out-Null
  try {
    gh release download -R $slug $Tag --pattern $name --dir $dir | Out-Null
    gh release download -R $slug $Tag --pattern CHECKSUMS.txt --dir $dir | Out-Null

    $zipPath = Join-Path $dir $name
    $sumPath = Join-Path $dir 'CHECKSUMS.txt'
    if (-not (Test-Path $zipPath)) { throw "ZIP not downloaded: $zipPath" }
    if (-not (Test-Path $sumPath)) { throw "CHECKSUMS.txt not downloaded: $sumPath" }

    $calc = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
    $line = Select-String -Path $sumPath -Pattern ([regex]::Escape($name)) | Select-Object -First 1
    if (-not $line) { throw "No checksum line for $name" }
    $expected = ($line.Line -split '\s+')[0].ToLower()

    if ($calc -eq $expected) {
      Write-Host "✅ checksum OK -> $name"
      return $true
    } else {
      Write-Host "❌ checksum mismatch -> $name"
      "expected: $expected"
      "actual  : $calc"
      if ($ThrowOnMismatch) { throw "Checksum mismatch" } else { return $false }
    }
  }
  finally {
    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
  }
}
