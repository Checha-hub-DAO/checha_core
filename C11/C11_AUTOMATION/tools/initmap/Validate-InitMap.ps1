Param([string]$Root="C:\CHECHA_CORE")
$ErrorActionPreference='Stop'
$log = Join-Path $Root "C03_LOG\initmap.log"
function W($lvl,$msg){ "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$lvl,$msg | Add-Content -Path $log -Encoding UTF8 }

# Безпечний витяг поля: повертає $null якщо не знайдено
function Get-Field([string]$Text,[string]$Name){
  $rx = "(?m)^\s*-\s*$([regex]::Escape($Name)):\s*(.+?)\s*$"
  if($Text -match $rx){ return $Matches[1].Trim() } else { return $null }
}

$reg = Join-Path $Root "C08_COORD\REGISTRY"
$files = Get-ChildItem -Path $reg -Recurse -Filter 'CELL_PASSPORT.md' -ErrorAction SilentlyContinue
if(-not $files){
  W 'WARN ' "No CELL_PASSPORT.md found under $reg"
  exit 0
}

[int]$ok=0; [int]$warn=0; [int]$err=0
$patId = '^C[A-Z2-9]{6,8}$'
$pii  = '(?i)\b(phone|тел|email|e-mail|\+?380\d{8,})\b|@|https?://'

foreach($f in $files){
  $txt = Get-Content $f.FullName -Raw -Encoding UTF8
  if($txt -match $pii){ W 'ERROR' "PII-like pattern in $($f.FullName)"; $err++; continue }

  $id     = Get-Field $txt 'CELL-ID'
  $city   = Get-Field $txt 'City'
  $type   = Get-Field $txt 'Type'
  $status = Get-Field $txt 'Status'

  if(-not $id   -or -not ($id -match $patId)){ W 'WARN ' "Bad/Missing CELL-ID in $($f.FullName): '$id'"; $warn++ }
  if(-not $city){ W 'WARN ' "Missing City in $($f.FullName)"; $warn++ }
  if(-not $type){ W 'WARN ' "Missing Type in $($f.FullName)"; $warn++ }
  if(-not $status){ W 'WARN ' "Missing Status in $($f.FullName)"; $warn++ }

  if($id -and $id -match $patId -and $city -and $type -and $status){
    $ok++
  }
}
W 'INFO ' ("Validate summary: OK={0} WARN={1} ERROR={2}" -f $ok,$warn,$err)
