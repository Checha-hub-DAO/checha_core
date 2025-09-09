<#
  Convert-ToUtf8.ps1 (v1.4, ASCII-only)
  - Re-encode text files to UTF-8 (with/without BOM)
  - Optional normalize EOL to LF
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
  [Parameter(Mandatory=$true)][string]$Path,
  [string[]]$IncludeExt=@('.md','.log','.txt','.ps1','.psm1','.json','.yml','.yaml','.xml','.cfg','.ini','.csv'),
  [switch]$Recurse,
  [switch]$NormalizeEol,
  [switch]$WithBom=$false,
  [ValidateSet('auto','cp1251','windows-1251','utf8','utf16le','utf16be')][string]$AssumeLegacy='auto',
  [switch]$Backup=$true
)

function _FlattenExts([string[]]$exts){ $out=@(); foreach($e in $exts){ if($null -ne $e){ $out += ($e -split '\s*,\s*' | Where-Object { $_ -ne '' }) } } return $out }
function _Patterns([string[]]$exts){
  $p=@(); foreach($e in $exts){ if(-not $e){continue}; $x=$e.Trim()
    if($x.StartsWith('*.')){ $p += $x }
    elseif($x.StartsWith('.')){ $p += ('*'+$x) }
    elseif($x.Contains('*')){ $p += $x }
    else{ $p += ('*.'+$x) }
  }
  if($p.Count -eq 0){ $p=@('*.md','*.log','*.txt') }
  return $p
}

function _DetectBom([byte[]]$b){
  if($b.Length -ge 3 -and $b[0]-eq 0xEF -and $b[1]-eq 0xBB -and $b[2]-eq 0xBF){ return 'utf8-bom' }
  if($b.Length -ge 2 -and $b[0]-eq 0xFF -and $b[1]-eq 0xFE){ return 'utf16le' }
  if($b.Length -ge 2 -and $b[0]-eq 0xFE -and $b[1]-eq 0xFF){ return 'utf16be' }
  return $null
}

function _ReadText([string]$file,[string]$assume){
  $bytes=[IO.File]::ReadAllBytes($file)
  $bom=_DetectBom $bytes
  switch -Regex ($assume) {
    '^(cp1251|windows-1251)$' { return [Text.Encoding]::GetEncoding(1251).GetString($bytes) }
    '^utf16le$'               { return [Text.Encoding]::Unicode.GetString($bytes) }
    '^utf16be$'               { return [Text.Encoding]::BigEndianUnicode.GetString($bytes) }
    '^utf8$'                  { return [Text.Encoding]::UTF8.GetString($bytes) }
    default {
      switch ($bom) {
        'utf8-bom' { return [Text.Encoding]::UTF8.GetString($bytes,3,$bytes.Length-3) }
        'utf16le'  { return [Text.Encoding]::Unicode.GetString($bytes,2,$bytes.Length-2) }
        'utf16be'  { return [Text.Encoding]::BigEndianUnicode.GetString($bytes,2,$bytes.Length-2) }
        default    { return [Text.Encoding]::UTF8.GetString($bytes) }
      }
    }
  }
}

function _WriteUtf8([string]$file,[string]$text,[bool]$bom){
  $enc=[Text.UTF8Encoding]::new([bool]$bom)
  [IO.File]::WriteAllText($file,$text,$enc)
}

$extList=_FlattenExts $IncludeExt
$patterns=_Patterns $extList
$pathStar=Join-Path $Path '*'

try {
  $files=Get-ChildItem -Path $pathStar -Include $patterns -File -Recurse:$Recurse -ErrorAction Stop
} catch {
  Write-Host ("ERROR: Cannot read path: {0} ? {1}" -f $Path,$_.Exception.Message)
  return
}

if(-not $files -or $files.Count -eq 0){
  Write-Host ("No files matching: {0} in {1}" -f ($patterns -join ', '), $Path)
  return
}

[int]$changed=0; [int]$skipped=0
foreach($f in $files){ if((Split-Path -Leaf $f.FullName) -ieq "SYNC.md"){ continue }
  try {
    $text=_ReadText -file $f.FullName -assume $AssumeLegacy
    if($NormalizeEol){ $text = $text -replace "`r`n","`n" -replace "`r(?!`n)","`n" }

    $desc = "Re-encode -> UTF-8"
    if($NormalizeEol){ $desc = $desc + " + LF" }

    if($PSCmdlet.ShouldProcess($f.FullName,$desc)){
      if($Backup){
        $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
        Copy-Item -LiteralPath $f.FullName -Destination ($f.FullName+".bak_$stamp") -ErrorAction SilentlyContinue
      }
      _WriteUtf8 -file $f.FullName -text $text -bom:$WithBom
      $changed = $changed + 1
    }
  } catch {
    $skipped = $skipped + 1
  }
}

Write-Host ("Done. Converted: {0}; Skipped: {1}; Total: {2}" -f $changed,$skipped,$files.Count)
