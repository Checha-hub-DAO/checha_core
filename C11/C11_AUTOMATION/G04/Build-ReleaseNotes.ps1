[CmdletBinding()]
param(
  [string]$Root='C:/CHECHA_CORE',
  [string]$RepoPath='C:/CHECHA_CORE',
  [string]$OutPath,                                     # Р·Р° Р·Р°РјРѕРІС‡СѓРІР°РЅРЅСЏРј: $Root/RELEASE_NOTES.md
  [string]$Version='v1.1',
  [string]$TagPrefix='g04-automation-',                 # С„РѕСЂРјСѓС” С‚РµРі: <TagPrefix><Version>
  [string]$PrevTag=$null,                               # СЏРєС‰Рѕ РЅРµ Р·Р°РґР°РЅРѕ вЂ” РІРёР·РЅР°С‡Р°С”С‚СЊСЃСЏ Р°РІС‚РѕРјР°С‚РёС‡РЅРѕ Р·Р° РїСЂРµС„С–РєСЃРѕРј
  [int]$SinceDays=30,                                   # СЏРєС‰Рѕ РЅРµРјР° РїРѕРїРµСЂРµРґРЅСЊРѕРіРѕ С‚РµРіСѓ
  [string]$ZipGlob=$null,                               # С€Р»СЏС… РґРѕ Р°СЂС‚РµС„Р°РєС‚Сѓ ZIP (РјРѕР¶РЅР° Р· *), РЅР°РїСЂ. C:/CHECHA_CORE/C05_ARCHIVE/G04_AUTOMATION_v1.1_*.zip
  [switch]$Publish                                      # СЏРєС‰Рѕ РІРєР°Р·Р°РЅРѕ вЂ” СЃС‚РІРѕСЂРёС‚Рё/РѕРЅРѕРІРёС‚Рё GitHub Release
)

if(-not $OutPath){ $OutPath = Join-Path $Root 'RELEASE_NOTES.md' }

function Git([string[]]$args){ pushd $RepoPath | Out-Null; try{ git @args } finally { popd | Out-Null } }

# 1) Р’РёР·РЅР°С‡РёС‚Рё РїРѕРїРµСЂРµРґРЅС–Р№ С‚РµРі (Р·Р° РїСЂРµС„С–РєСЃРѕРј)
if(-not $PrevTag){
  $lines = Git for-each-ref "--format=%(refname:short) %(creatordate:iso8601)" "--sort=-creatordate" "refs/tags/$TagPrefix*"
  if($lines -and $lines.Count -gt 0){ $PrevTag = ($lines[0] -split ' ')[0] } else { $PrevTag = $null }
}

# 2) Р—С–Р±СЂР°С‚Рё РєРѕРјС–С‚Рё
$logArgs = @('log','--no-merges','--date=iso','--pretty=format:%H|%ad|%an|%s')
if($PrevTag){ $logArgs += "$PrevTag..HEAD" } else { $logArgs = @('log',"--since=$SinceDays.days",'--no-merges','--date=iso','--pretty=format:%H|%ad|%an|%s') }
$rows = Git $logArgs

# 3) РљР°С‚РµРіРѕСЂРёР·Р°С†С–СЏ Р·Р° Conventional Commits
$groups = [ordered]@{
  'РќРѕРІС– С„С–С‡С–'=@(); 'Р’РёРїСЂР°РІР»РµРЅРЅСЏ'=@(); 'РџСЂРѕРґСѓРєС‚РёРІРЅС–СЃС‚СЊ'=@(); 'Р РµС„Р°РєС‚РѕСЂРёРЅРі'=@();
  'Р”РѕРєСѓРјРµРЅС‚Р°С†С–СЏ'=@(); 'CI/CD'=@(); 'РўРµСЃС‚Рё'=@(); 'РЎР»СѓР¶Р±РѕРІС–'=@(); 'Revert'=@(); 'Р†РЅС€Рµ'=@()
}

# РћС‚СЂРёРјР°С‚Рё repo slug Р· origin
$origin = (Git remote get-url origin) 2>$null
$repoSlug = $null
if($origin -match 'github.com[:/](?<owner>[^/]+)/(?<name>[^\.]+)'){ $repoSlug = "$($Matches.owner)/$($Matches.name)" }
$commitUrl = if($repoSlug){ "https://github.com/$repoSlug/commit/" } else { $null }

foreach($row in $rows){
  $p = $row -split '\|',4; if($p.Length -lt 4){ continue }
  $sha=$p[0]; $date=$p[1]; $author=$p[2]; $msg=$p[3]
  $m = [regex]::Match($msg,'^(?<type>feat|fix|perf|refactor|docs|build|ci|test|chore|style|revert)(?:\((?<scope>[^)]+)\))?(?<breaking>!)?:\s*(?<sub>.+)$')
  $type = if($m.Success){ $m.Groups['type'].Value } else { '' }
  $scope = if($m.Success){ $m.Groups['scope'].Value } else { '' }
  $subj = if($m.Success){ $m.Groups['sub'].Value } else { $msg }
  $line = if($scope){ "**$scope:** $subj" } else { $subj }
  $short = $sha.Substring(0,7)
  if($commitUrl){ $line += " ([${short}]($commitUrl$sha))" } else { $line += " [$short]" }
  switch($type){
    'feat'      { $groups['РќРѕРІС– С„С–С‡С–']       += $line; continue }
    'fix'       { $groups['Р’РёРїСЂР°РІР»РµРЅРЅСЏ']     += $line; continue }
    'perf'      { $groups['РџСЂРѕРґСѓРєС‚РёРІРЅС–СЃС‚СЊ']  += $line; continue }
    'refactor'  { $groups['Р РµС„Р°РєС‚РѕСЂРёРЅРі']     += $line; continue }
    'docs'      { $groups['Р”РѕРєСѓРјРµРЅС‚Р°С†С–СЏ']    += $line; continue }
    'ci'        { $groups['CI/CD']           += $line; continue }
    'test'      { $groups['РўРµСЃС‚Рё']           += $line; continue }
    'chore'     { $groups['РЎР»СѓР¶Р±РѕРІС–']        += $line; continue }
    'build'     { $groups['РЎР»СѓР¶Р±РѕРІС–']        += $line; continue }
    'style'     { $groups['РЎР»СѓР¶Р±РѕРІС–']        += $line; continue }
    'revert'    { $groups['Revert']          += $line; continue }
    default     { $groups['Р†РЅС€Рµ']            += $line; continue }
  }
}

# 4) РђРІС‚РѕСЂРё
$authors = (Git shortlog -sne $([string]::IsNullOrEmpty($PrevTag) ? "--since=$SinceDays.days" : "$PrevTag..HEAD")) | ForEach-Object { ($_ -replace '^\s*\d+\s+','').Trim() }

# 5) РџРѕР±СѓРґРѕРІР° Markdown
$today = (Get-Date).ToString('yyyy-MM-dd')
$tag   = "$TagPrefix$Version"
$header = "# G04 Automation $Version вЂ” $today"
if($PrevTag){ $header += "`nР—РјС–РЅРё Р· **$PrevTag**." } else { $header += "`nР—РјС–РЅРё Р·Р° РѕСЃС‚Р°РЅРЅС– **$SinceDays РґРЅС–РІ**." }

$md = @()
$md += $header
$md += ''
foreach($k in $groups.Keys){
  $items = $groups[$k]
  if($items.Count -gt 0){
    $md += "## $k"
    foreach($i in $items){ $md += "- $i" }
    $md += ''
  }
}
if($authors -and $authors.Count -gt 0){
  $md += '## РђРІС‚РѕСЂРё'
  foreach($a in $authors){ $md += "- $a" }
  $md += ''
}
$mdText = ($md -join "`n").TrimEnd() + "`n"
$mdText | Set-Content -Encoding UTF8 $OutPath
Write-Host "вњ… RELEASE_NOTES Р·С–Р±СЂР°РЅРѕ в†’ $OutPath"

# 6) РџСѓР±Р»С–РєР°С†С–СЏ (РѕРїС†С–Р№РЅРѕ)
if($Publish){
  $GH = Get-Command gh -ErrorAction SilentlyContinue
  if(-not $GH){ Write-Warning 'gh CLI РЅРµ Р·РЅР°Р№РґРµРЅРѕ вЂ” РїСЂРѕРїСѓСЃРєР°СЋ Publish'; return }
  if(-not $repoSlug){ Write-Warning 'РќРµ РІРёР·РЅР°С‡РёРІСЃСЏ origin github repo вЂ” РїСЂРѕРїСѓСЃРєР°СЋ Publish'; return }
  $notes = Get-Content $OutPath -Raw
  $zip = $null
  if($ZipGlob){ $zip = (Get-ChildItem -Path $ZipGlob | Sort-Object LastWriteTime -Desc | Select-Object -First 1).FullName }
  $title = "G04 Automation $Version"
  $exists = (& gh release view "$tag" -R "$repoSlug" 2>$null); $ec=$LASTEXITCODE
  if($ec -ne 0){
    if($zip){ & gh release create "$tag" "$zip" -R "$repoSlug" -t "$title" -n "$notes" }
    else     { & gh release create "$tag" -R "$repoSlug" -t "$title" -n "$notes" }
  } else {
    & gh release edit "$tag" -R "$repoSlug" -t "$title" -n "$notes"
    if($zip){ & gh release upload "$tag" "$zip" --clobber -R "$repoSlug" }
  }
  Write-Host "рџљЂ РћРїСѓР±Р»С–РєРѕРІР°РЅРѕ/РѕРЅРѕРІР»РµРЅРѕ СЂРµР»С–Р·: $tag РІ $repoSlug"
}
