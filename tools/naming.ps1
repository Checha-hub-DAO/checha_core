Set-StrictMode -Version Latest

function Get-CanonicalArtifactRegex {
@'REGEX'
^(?<module>[A-Za-z0-9-]+)-v(?<ver>\d+\.\d+(?:\.\d+)?)
_(?<ts>\d{8}_\d{4})
(?<suffix>(?:_[A-Za-z0-9-]+)*)\.
(?<ext>zip|7z|tar\.gz|mp4|pdf|md|txt)$
'REGEX'
}

function Normalize-ModuleName {
  param([Parameter(Mandatory)][string]$Module)
  $m = $Module.Trim() -replace '\s+','-' -replace '_','-'
  if ($m -notmatch '^[A-Za-z0-9-]+$') {
    throw "MODULE must contain only [A-Za-z0-9-]: '$m'"
  }
  return $m
}

function New-ArtifactName {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Module,
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+(\.\d+)?$')][string]$Version,
    [ValidateSet('zip','7z','tar.gz','mp4','pdf','md','txt')][string]$Ext = 'zip',
    [string]$Suffix
  )
  $mod = Normalize-ModuleName $Module
  $ts  = Get-Date -Format 'yyyyMMdd_HHmm'
  $name = '{0}-v{1}_{2}' -f $mod, $Version, $ts
  if ($Suffix) {
    $sfx = $Suffix.Trim() -replace '\s+','-'
    if ($sfx -notmatch '^[A-Za-z0-9-]+$') { throw "Invalid SUFFIX: '$Suffix'" }
    $name += "_$sfx"
  }
  if ($Ext -eq 'tar.gz') { return ($name + '.tar.gz') }
  return ($name + '.' + $Ext)
}

function Test-ArtifactName {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Name)
  $rx = Get-CanonicalArtifactRegex
  return [bool]([regex]::Match($Name, $rx).Success)
}

function Assert-ArtifactName {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Name)
  if (-not (Test-ArtifactName $Name)) {
    $rx = (Get-CanonicalArtifactRegex) -replace "`n",' '
    throw "Name '$Name' does not match canonical regex: $rx"
  }
}

function Parse-ArtifactName {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Name)
  $m = [regex]::Match($Name, (Get-CanonicalArtifactRegex))
  if (-not $m.Success) { throw "Cannot parse name: $Name" }
  $suffix = $m.Groups['suffix'].Value
  if ($suffix) { $suffix = $suffix.TrimStart('_').Split('_') } else { $suffix = @() }
  [pscustomobject]@{
    Module    = $m.Groups['module'].Value
    Version   = $m.Groups['ver'].Value
    Timestamp = $m.Groups['ts'].Value
    Suffixes  = $suffix
    Ext       = $m.Groups['ext'].Value
    GitTag    = ('{0}-v{1}' -f $m.Groups['module'].Value, $m.Groups['ver'].Value)
  }
}

function Resolve-GitTagFromArtifact {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Name)
  (Parse-ArtifactName $Name).GitTag
}
