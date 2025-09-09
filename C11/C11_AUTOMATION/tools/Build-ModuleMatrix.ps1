Param(
  [string]C:\CHECHA_CORE    = 'C:\CHECHA_CORE',
  [string]  = 'C01_PARAMETERS\MODULE_MATRIX.md',
  [switch]
)

\Continue = 'Stop'

function Read-FirstHeading([string]\C:\){
  foreach(\ in 'README.md','readme.md'){
    \ = Join-Path \C:\ \
    if(Test-Path \){
      \ = Get-Content \ -Encoding UTF8 -TotalCount 1
      if(\ -match '^\s*#\s*(.+)$'){ return \[1].Trim() }
    }
  }
  return (Split-Path \C:\ -Leaf)
}
function Parse-Manifest([string]\C:\){
  \ = [ordered]@{ version=\; owner=\; status=\; priority=\; maturity=\; source='default' }
  foreach(\ in 'MANIFEST.yaml','manifest.yaml','manifest.yml'){
    \ = Join-Path \C:\ \
    if(Test-Path \){
      \ = Get-Content \ -Raw -Encoding UTF8
      foreach(\ in 'version','owner','status','priority','maturity'){
        if(\ -match ("(?m)^\s*{0}\s*:\s*(.+?)\s*$" -f [regex]::Escape(\))){
          \[\] = \[1].Trim('"" ').Trim()
        }
      }
      \['source'] = (Split-Path \ -Leaf)
      break
    }
  }
  return \
}
function Get-LastUpdate([string]\C:\){
  \ = Get-ChildItem -LiteralPath \C:\ -Recurse -File -ErrorAction SilentlyContinue
  if(\){ return (\ | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime }
  return (Get-Item -LiteralPath \C:\).LastWriteTime
}
function MaturityFrom([string]\,[string]\){
  if(\){ try { return [int]\ } catch {} }
  if(\ -and \ -match '(?i)v?(\d+)'){ \=[int]\[1]; if(\ -ge 3){return 3} elseif(\ -ge 2){return 2} elseif(\ -ge 1){return 1} }
  return 1
}
function Def(\,\){ if(\ -eq \ -or "\" -eq ''){ \ }
function EscMd([string]$s){
  if($null -eq $s){ return '' }
  $s = $s -replace '\|','\|'              # ескейпимо лише вертикальну риску
  $s = $s -replace '\\\\n',' '            # прибираємо літеральні \\n
  $s = $s -replace '\\\\r',' '            # прибираємо літеральні \\r
  $s = $s -replace '\\n',' '              # прибираємо літеральні \n
  $s = $s -replace '\\r',' '              # прибираємо літеральні \r
  $s -replace '\r?\n',' '                 # реальні переноси → пробіл
} else { \ } }

\ = @()

# ---- CORE: будь-які каталоги, що починаються на C/c + цифри (напр., C06_FOCUS, 'C06 FOCUS', C08_COORD, C10 DAO-DNA) ----
\ = Get-ChildItem -LiteralPath \C:\CHECHA_CORE -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { \.Name -match '^[Cc]\d+' }   # ПРОСТІШЕ, ніж \d{2}\b

if(\){ Write-Host "[DBG] CORE dirs: " }

foreach(\ in \){
  \C:\ = \.FullName
  \ = \.Name
  \   = Parse-Manifest \C:\
  \ += [pscustomobject]@{
    Code=\; Name=(Read-FirstHeading \C:\); Layer='CORE'
    Status=Def \.status 'active'; Version=Def \.version ''
    Parent='CHECHA_CORE'; Links=(Test-Path (Join-Path \C:\ 'README.md')) ? ("\/README.md") : \
    Owner=Def \.owner 'С.Ч.'; OwnerSource=\.source; Priority=Def \.priority 'M'
    'Maturity(0-3)'=(MaturityFrom \.maturity \.version)
    'Last Update'=(Get-Date (Get-LastUpdate \C:\) -Format 'yyyy-MM-dd HH:mm')
  }
}

# ---- DAO #1: GitBook/dao-g/dao-g-mods/* ----
\ = Join-Path \C:\CHECHA_CORE 'GitBook\dao-g\dao-g-mods'
\ = (Test-Path \) ? (Get-ChildItem -LiteralPath \ -Directory -Force -ErrorAction SilentlyContinue) : @()
if(\){ Write-Host ("[DBG] DAO1 dirs: {0}" -f (@(\ | Select-Object -Expand Name) -join ', ')) }
foreach(\ in \){
  \C:\=\.FullName; \=\.Name; \ = (\ -match '^g(\d+)[_-]') ? ('G'+\[1]) : \.ToUpper()
  \ = Parse-Manifest \C:\
  \ += [pscustomobject]@{
    Code=\; Name=(Read-FirstHeading \C:\); Layer='DAO'
    Status=Def \.status 'active'; Version=Def \.version ''
    Parent='GitBook'; Links="GitBook/dao-g/dao-g-mods/\/README.md"
    Owner=Def \.owner 'С.Ч.'; OwnerSource=\.source; Priority=Def \.priority 'M'
    'Maturity(0-3)'=(MaturityFrom \.maturity \.version)
    'Last Update'=(Get-Date (Get-LastUpdate \C:\) -Format 'yyyy-MM-dd HH:mm')
  }
}

# ---- DAO #2: кореневі G?? та G\G?? ----
\ = Get-ChildItem -LiteralPath \C:\CHECHA_CORE -Directory -Force -ErrorAction SilentlyContinue | Where-Object { \.Name -match '^[Gg]\d{2}\b' }
\ = Join-Path \C:\CHECHA_CORE 'G'
\ = (Test-Path \) ? (Get-ChildItem -LiteralPath \ -Directory -Force -ErrorAction SilentlyContinue | Where-Object { \.Name -match '^[Gg]\d{2}\b' }) : @()
\ = @(\ + \ | Select-Object -Unique)
if(\){ Write-Host ("[DBG] DAO2/3 dirs: {0}" -f (@(\ | Select-Object -Expand Name) -join ', ')) }
foreach(\ in \){
  \C:\=\.FullName; \=\.Name; \ = (\ -match '^[Gg](\d{2})') ? ('G'+\[1]) : \.ToUpper()
  \=Parse-Manifest \C:\
  \ += [pscustomobject]@{
    Code=\; Name=(Read-FirstHeading \C:\); Layer='DAO'
    Status=Def \.status 'active'; Version=Def \.version ''
    Parent='CHECHA_CORE'; Links="\/README.md"
    Owner=Def \.owner 'С.Ч.'; OwnerSource=\.source; Priority=Def \.priority 'M'
    'Maturity(0-3)'=(MaturityFrom \.maturity \.version)
    'Last Update'=(Get-Date (Get-LastUpdate \C:\) -Format 'yyyy-MM-dd HH:mm')
  }
}

# ---- Output (захист від OutRel=директорії) ----
\ = @'
| Code | Name | Layer | Status | Version | Parent | Links | Owner | OwnerSource | Priority | Maturity(0-3) | Last Update |
|---|---|---|---|---|---|---|---|---|---|---|---|
'@
\C:\CHECHA_CORE\MODULE_MATRIX.md = Join-Path \C:\CHECHA_CORE \
if (Test-Path \C:\CHECHA_CORE\MODULE_MATRIX.md -PathType Container) { \C:\CHECHA_CORE\MODULE_MATRIX.md = Join-Path \C:\CHECHA_CORE\MODULE_MATRIX.md 'MODULE_MATRIX.md' }

\C:\CHECHA_CORE = Split-Path \C:\CHECHA_CORE\MODULE_MATRIX.md -Parent
if(-not (Test-Path \C:\CHECHA_CORE)){ New-Item -ItemType Directory -Force -Path \C:\CHECHA_CORE | Out-Null }

\ = \ | Sort-Object Layer, Code, Name
\ = foreach(\ in \){
  '| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} |' -f 
    \.Code,\.Name,\.Layer,\.Status,\.Version,\.Parent,\.Links,\.Owner,\.OwnerSource,\.Priority,\.'Maturity(0-3)',\.'Last Update'
}

(\ + (\ -join [Environment]::NewLine)) | Set-Content -Encoding UTF8 -Path \C:\CHECHA_CORE\MODULE_MATRIX.md

Write-Host ("[DBG] CORE={0} DAO={1} TOTAL_ROWS={2}" -f @(\).Count, (@(\).Count + @(\).Count), @(\).Count)
Write-Host ("Matrix → {0}" -f \C:\CHECHA_CORE\MODULE_MATRIX.md)

