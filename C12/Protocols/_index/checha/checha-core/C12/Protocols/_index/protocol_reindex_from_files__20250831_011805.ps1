param(
  [string]$Root = "C:\CHECHA_CORE\C12\Protocols",
  [string]$IndexPath = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.json",
  [switch]$GenerateTable = $true
)
$ErrorActionPreference = "Stop"
function ParseFrontMatter($txt){
  $m = [regex]::Match($txt,'(?s)^\s*---\s*(.*?)\s*---')
  if(!$m.Success){ return $null }
  $block = $m.Groups[1].Value
  $map = @{}
  foreach($line in ($block -split "`r?`n")){
    if($line -match '^\s*(#|$)'){ continue }
    if($line -match '^\s*([A-Za-z0-9_]+)\s*:\s*(.*)\s*$'){
      $k=$matches[1]; $v=$matches[2].Trim()
      if($v -match '^\[(.*)\]$'){
        $list = $matches[1] -split ',' | % { $_.Trim().Trim("'`"") }
        $map[$k]=$list
      } else {
        $map[$k]=$v.Trim("'`"")
      }
    }
  }
  return $map
}
function GetFieldMd($txt,$name){
  $m = [regex]::Match($txt,"(?im)^\*\*\s*$([regex]::Escape($name))\s*:\*\*\s*(.+?)\s*$")
  if($m.Success){ $m.Groups[1].Value.Trim() } else { $null }
}
function Iso($s,$fallback){
  if([string]::IsNullOrWhiteSpace($s)){ return $fallback.ToString("o") }
  try{ ([datetime]::Parse($s,[Globalization.CultureInfo]::GetCultureInfo("uk-UA"))).ToString("o") }
  catch{ try{ ([datetime]::Parse($s,[Globalization.CultureInfo]::InvariantCulture)).ToString("o") } catch{ $fallback.ToString("o") } }
}
$files = Get-ChildItem $Root -Recurse -File -Filter *.md |
  Where-Object { $_.FullName -notmatch '\\_index\\|\\templates\\' }
$items = New-Object System.Collections.Generic.List[object]
$allowed=@("active","draft","archived","closed")
foreach($f in $files){
  $rel = $f.FullName.Substring($Root.Length+1).Replace('\','/')
  $txt = Get-Content $f.FullName -Raw
  $fm  = ParseFrontMatter $txt
  $id  = if($fm -and $fm.ContainsKey('id')){ $fm['id'] } else {
    $m = [regex]::Match($txt,"(?im)^\#\s*Протокол\s+([A-Za-z0-9\-]+)")
    if($m.Success){ $m.Groups[1].Value.Trim() } else { ([IO.Path]::GetFileNameWithoutExtension($f.Name) -split '[_\s]',2)[0] }
  }
  if([string]::IsNullOrWhiteSpace($id)){ Write-Warning "Skip (no ID): $rel"; continue }
  $topic = if($fm -and $fm.ContainsKey('topic')){ $fm['topic'] } else {
    $t = GetFieldMd $txt "Тема"
    if($t){ $t } else { $base=[IO.Path]::GetFileNameWithoutExtension($f.Name); if($base -match '^[^_]+_(.+)$'){ ($matches[1] -replace '-', ' ').Trim() } else { $base } }
  }
  $owner   = if($fm -and $fm.ContainsKey('owner')){ $fm['owner'] } else { (GetFieldMd $txt "Відповідальний"); if(!$? -or [string]::IsNullOrWhiteSpace($LASTEXITCODE)){}; if([string]::IsNullOrWhiteSpace($owner)){"С.Ч."} else {$owner} }
  if([string]::IsNullOrWhiteSpace($owner)){ $owner = "С.Ч." }
  $version = if($fm -and $fm.ContainsKey('version')){ $fm['version'] } else { (GetFieldMd $txt "Версія"); if([string]::IsNullOrWhiteSpace($version)){"v0.1"} else {$version} }
  $status  = if($fm -and $fm.ContainsKey('status')){ ($fm['status'] -replace "<!--.*?-->","").Trim().ToLower() } else {
    $s = (GetFieldMd $txt "Статус"); if($s){ ($s -replace "<!--.*?-->","").Trim().ToLower() } else { (Split-Path $f.DirectoryName -Leaf).ToLower() }
  }
  if($status -notin $allowed){ $status = (Split-Path $f.DirectoryName -Leaf).ToLower() }
  $created = if($fm -and $fm.ContainsKey('created_at')){ Iso $fm['created_at'] $f.CreationTime } else { Iso (GetFieldMd $txt "Дата створення") $f.CreationTime }
  $updated = if($fm -and $fm.ContainsKey('updated_at')){ Iso $fm['updated_at'] $f.LastWriteTime } else { Iso (GetFieldMd $txt "Останнє оновлення") $f.LastWriteTime }
  $tags    = @()
  if($fm -and $fm.ContainsKey('tags')){ $tags = @($fm['tags']) } else {
    $tr = GetFieldMd $txt "Теги"; if($tr){ $tags = ($tr -split ",") | % { $_.Trim() } }
  }
  $obj = [pscustomobject]@{
    id=$id; topic=$topic; status=$status; owner=$owner; version=$version
    created_at=$created; updated_at=$updated; tags=$tags; path=$rel; links=@{}
  }
  [void]$items.Add($obj)
}
if($items.Count -eq 0){ throw "Не знайдено жодного .md у $Root (active/draft/archived/closed)." }
$dedup = $items | Group-Object id | ForEach-Object { if($_.Count -le 1){ $_.Group[0] } else { $_.Group | Sort-Object { [datetime]$_.updated_at } -Descending | Select-Object -First 1 } }
$payload = [pscustomobject]@{ updated_at=(Get-Date).ToString("o"); protocols=@($dedup) }
# бекап
$bak = Join-Path (Split-Path $IndexPath) ("protocols_index.bak_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
if(Test-Path $IndexPath){ Copy-Item $IndexPath $bak -Force; Write-Host "🔒 Backup індексу: $bak" }
# атомарний запис з BOM
$tmp="$IndexPath.tmp"; $json=($payload|ConvertTo-Json -Depth 99)
$enc=New-Object System.Text.UTF8Encoding($true)
[IO.File]::WriteAllText($tmp,$json,$enc); Move-Item $tmp $IndexPath -Force
Write-Host ("✅ Перезібрано індекс: {0} (унікальних протоколів: {1})" -f $IndexPath, $dedup.Count) -ForegroundColor Green
if($GenerateTable){ & (Join-Path (Split-Path $IndexPath) "generate_protocols_table.ps1") -IndexPath $IndexPath -OutputPath (Join-Path (Split-Path $IndexPath) "Protocols.md") | Out-Null; Write-Host "✅ Таблицю згенеровано." -ForegroundColor Green }