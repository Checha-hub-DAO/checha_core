# McHelpers.psm1
# Version: 0.3.2
# Author: С.Ч. (DAO-GOGS)
# Description: Утіліти *-Mc* для логування, архівації, перевірок

function Write-McLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$LogPath,
    [Parameter(Mandatory)][string]$Message,
    [ValidateSet('DEBUG','INFO','WARN','ERROR')][string]$Level = 'INFO'
  )
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  $lvl = $Level.ToString().PadRight(5)
  $line = "$ts [$lvl] $Message"
  $dir = Split-Path $LogPath -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Add-Content -Path $LogPath -Value $line -Encoding utf8BOM
  $line
}

function Compress-McZip {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$ZipPath,
    [switch]$Overwrite
  )
  if (Test-Path $ZipPath -and -not $Overwrite -and -not $PSBoundParameters.ContainsKey('WhatIf')) {
    Write-McLog -LogPath "$env:ProgramData\CHECHA\LOG\mc_zip.log" -Message "ZIP існує: $ZipPath (використай -Overwrite або -WhatIf/-Confirm)" -Level WARN
    return [pscustomobject]@{
      SourcePath = $SourcePath; ZipPath = $ZipPath; Exists = $true; Created = $false; Size = (Get-Item $ZipPath).Length
    }
  }
  if ($PSCmdlet.ShouldProcess($ZipPath, "Create ZIP")) {
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($SourcePath, $ZipPath)
    $size = (Get-Item $ZipPath).Length
    Write-McLog -LogPath "$env:ProgramData\CHECHA\LOG\mc_zip.log" -Message "ZIP створено: $ZipPath ($size байт)" -Level INFO
    return [pscustomobject]@{
      SourcePath = $SourcePath; ZipPath = $ZipPath; Exists = $true; Created = $true; Size = $size
    }
  }
}

function Test-McEncodingUtf8Bom {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path
  )
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    return $true
  }
  return $false
}

Export-ModuleMember -Function *-Mc*
