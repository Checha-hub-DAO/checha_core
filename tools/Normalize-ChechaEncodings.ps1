[CmdletBinding()]
param(
  [string]$Root = 'C:\CHECHA_CORE',
  [switch]$Apply,
  [ValidateSet('1251','866','koi8u','utf8')] [string]$Assume = '1251'
)

function Get-EncObj($name) {
  switch ($name) {
    '1251'  { [System.Text.Encoding]::GetEncoding(1251) }
    '866'   { [System.Text.Encoding]::GetEncoding(866) }
    'koi8u' { [System.Text.Encoding]::GetEncoding('koi8-u') }
    'utf8'  { New-Object System.Text.UTF8Encoding($false) }
  }
}
$srcEnc = Get-EncObj $Assume
$dstEnc = New-Object System.Text.UTF8Encoding($true) # UTF-8 BOM

$targets = Get-ChildItem $Root -Recurse -Include *.ps1,*.psm1,*.psd1 -File
foreach ($f in $targets) {
  try {
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
      continue
    }
    $text = $srcEnc.GetString($bytes)
    if ($Apply) {
      [IO.File]::WriteAllText($f.FullName, $text, $dstEnc)
      Write-Host "FIXED -> utf8bom: $($f.FullName)"
    } else {
      Write-Host "[DRY] would fix: $($f.FullName)"
    }
  } catch {
    Write-Warning "ERR $($f.FullName): $($_.Exception.Message)"
  }
}
