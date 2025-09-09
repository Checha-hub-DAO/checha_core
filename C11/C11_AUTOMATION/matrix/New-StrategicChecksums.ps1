[CmdletBinding()]
param(
  [string]$ConfigPath = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\checha_matrix_config.json"
)

$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
if(-not $cfg.Checksums.Enable){ "Checksums disabled"; exit 0 }

$root = $cfg.Checksums.TargetDir
$file = Join-Path $root $cfg.Checksums.FileName
$algo = $cfg.Checksums.Algo
$include = $cfg.Checksums.IncludePatterns
$exclude = $cfg.Checksums.ExcludePatterns

$utf8BOM = New-Object System.Text.UTF8Encoding($true)
$lines = New-Object System.Collections.Generic.List[string]

$lines.Add("# CHECKSUMS ($algo)")
$lines.Add("# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")

Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object {
    $name = $_.Name
    ($include | ForEach-Object { $name -like $_ }) -contains $true -and
    -not (($exclude | ForEach-Object { $name -like $_ }) -contains $true)
  } |
  Sort-Object FullName |
  ForEach-Object {
    $rel = $_.FullName.Replace($root,"").TrimStart("\").Replace("\","/")
    $hash = & "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\tools\Get-FileHashPortable.ps1" -Path $_.FullName -Algorithm $algo
    $lines.Add("$hash  $rel")
  }

[IO.File]::WriteAllLines($file, $lines, $utf8BOM)
"OK: checksums -> $file"
