[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)] [string]$Root,
  [Parameter(Mandatory=$true)] [string]$ExpectedSlug,
  [string[]]$ForbiddenTerms = @(),
  [string[]]$RequiredFiles  = @("manifest.md","readme.md","panel.md","agents.md","forms.md","protocols.md","partners.md","research.md","kpi.md","media.md")
)
$ErrorActionPreference = "Stop"
$exit = 0
function Fail([string]$m){ Write-Host "x $m"; $script:exit = 2 }
function Ok  ([string]$m){ Write-Host "+ $m" }
function Info([string]$m){ Write-Host "> $m" }

Write-Host ">> Validate $Root"

if(!(Test-Path $Root)){ Fail "Root does not exist: $Root"; exit $exit }

# 1) required files
$missing = @()
foreach($f in $RequiredFiles){ if(!(Test-Path (Join-Path $Root $f))){ $missing += $f } }
if($missing){ Fail ("Missing files: " + ($missing -join ", ")) } else { Ok "All required files are present." }

# 2) forbidden terms (optional)
if($ForbiddenTerms.Count -gt 0){
  $hits = Get-ChildItem $Root -File -Recurse | ForEach-Object {
    $t = Select-String -Path $_.FullName -Pattern $ForbiddenTerms -SimpleMatch -List
    if($t){[pscustomobject]@{File=$_.FullName; Match=$t.Line.Trim()}}
  }
  if($hits){ Fail "Forbidden terms found:"; $hits | ForEach-Object { "   - $($_.File): $($_.Match)" } }
  else { Ok "No forbidden terms found." }
} else { Info "Forbidden terms check skipped." }

# 3) front matter check
function Test-FrontMatter($path){
  $name = Split-Path $path -Leaf
  $txt = Get-Content $path -Raw
  if($txt -match '(?s)^---\s*(.+?)\s*---'){
    $fm = $matches[1]
    $need = @("title:","slug:","module:","submodule:","doc_class:","page_version:","last_updated:")
    $miss = $need | Where-Object { $fm -notmatch [regex]::Escape($_) }
    if($miss){ Fail "$($name): missing fields in front-matter -> $($miss -join ', ')" }
    if($fm -notmatch 'doc_class:\s*"?Public"?' ){ Fail "$($name): doc_class must be Public" }
    if($fm -notmatch ('slug:\s*"?'+[regex]::Escape($ExpectedSlug)+'"?' )){ Fail "$($name): slug must be "+$ExpectedSlug }
  } else {
    Fail "No YAML front-matter in $($name)"
  }
}
Test-FrontMatter (Join-Path $Root "readme.md")
Test-FrontMatter (Join-Path $Root "manifest.md")

# 4) required sections in readme.md
$readme = Get-Content (Join-Path $Root "readme.md") -Raw
$must = @("## Місія","## Швидкий старт","## Ритми","## Релізний цикл")
$miss = $must | Where-Object { $readme -notmatch [regex]::Escape($_) }
if($miss){ Fail ("readme.md: missing sections -> " + ($miss -join ", ")) } else { Ok "readme.md sections OK." }

if($exit -eq 0){ Ok "Validation passed." } else { Write-Host "VALIDATION FAILED."; exit $exit }
