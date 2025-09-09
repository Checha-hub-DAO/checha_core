[CmdletBinding()]
Param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$OutFile,
  [string]$CsvOut,
  [string]$MdMatrixOut,
  [string]$OwnersCsv,
  [switch]$FailOnMissingOwner,
  [ValidateSet('Modules','Submodules','All')]
  [string]$OwnersRequiredFor = 'All'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:__exitCode = 0
function Set-Exit([int]$code){ if($code -gt $script:__exitCode){ $script:__exitCode = $code } }

# -------- LOCK ----------
function Acquire-Lock([string]$Root,[string]$Name="matrix"){
  $runDir  = Join-Path $Root "C03\RUN"
  $lock    = Join-Path $runDir "$Name.lock"
  if (-not (Test-Path $runDir)) { New-Item -ItemType Directory -Force -Path $runDir | Out-Null }
  if (Test-Path $lock) {
    $age = (Get-Date) - (Get-Item $lock).LastWriteTime
    if ($age.TotalHours -lt 4) { Write-Host ("[SKIP] Lock exists: {0} (age {1:N1}h). ExitCode=2" -f $lock,$age.TotalHours); return $null }
    Remove-Item -Force $lock
  }
  "$PID|$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Set-Content -Path $lock -Encoding ascii
  return $lock
}
function Release-Lock([string]$LockPath){ try { if ($LockPath -and (Test-Path $LockPath)) { Remove-Item -Force $LockPath } } catch {} }

# -------- IO HELPERS (PS 5/7 SAFE) ----------
function Write-FileAtomic {
  param([string]$Content,[string]$Path,[string]$Encoding = "utf8BOM")
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $tmp = "$Path.tmp.$PID.$([DateTime]::UtcNow.Ticks)"
  if ($Encoding -ieq "utf8BOM") {
    [System.IO.File]::WriteAllText($tmp, $Content, (New-Object System.Text.UTF8Encoding($true)))
  } elseif ($Encoding -ieq "utf8") {
    [System.IO.File]::WriteAllText($tmp, $Content, (New-Object System.Text.UTF8Encoding($false)))
  } else {
    $Content | Set-Content -Path $tmp -Encoding $Encoding
  }
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}
function Export-CsvAtomic {
  param($InputObject,[string]$Path,[string]$Encoding="utf8BOM")
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $tmp = "$Path.tmp.$PID.$([DateTime]::UtcNow.Ticks)"
  $InputObject | Export-Csv -Path $tmp -Encoding UTF8 -NoTypeInformation
  if ($Encoding -ieq "utf8BOM") {
    $text = [System.IO.File]::ReadAllText($tmp, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($true)))
  }
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

# -------- OTHER HELPERS ----------
function Read-AllTextUtf8([string]$path){ if (-not (Test-Path $path)) { return $null }; Get-Content -Raw -Encoding UTF8 -Path $path }
function Parse-TableMarkdown{
  param([string]$md)
  $lines = $md -split "`r?`n"; $tables=@(); $curr=@()
  foreach($ln in $lines){ if ($ln.Trim().StartsWith('|')) { $curr+=,$ln } elseif ($curr.Count -gt 0) { $tables+=,@($curr); $curr=@() } }
  if ($curr.Count -gt 0) { $tables+=,@($curr) }
  $rows=@()
  foreach($tbl in $tables){
    if ($tbl.Count -lt 3) { continue }
    $hdr = ($tbl[0].Trim('|') -split '\|').ForEach({ $_.Trim() })
    for ($i=2; $i -lt $tbl.Count; $i++){
      $cols = ($tbl[$i].Trim('|') -split '\|').ForEach({ $_.Trim() })
      if ($cols.Count -ne $hdr.Count) { continue }
      $obj=@{}; for ($c=0; $c -lt $hdr.Count; $c++){ $obj[$hdr[$c]] = $cols[$c] }
      $rows += ,[pscustomobject]$obj
    }
  }; ,$rows
}
function Get-PropValueByRegex([psobject]$row, [string]$pattern){
  $p = $row.PSObject.Properties | Where-Object { $_.Name -match $pattern } | Select-Object -First 1
  if ($p) { return $p.Value } else { return $null }
}
function Parse-Manifest{
  param([string]$text,[string]$code)
  if (-not $text) { return $null }
  $get = { param($pattern,$text) $m=[regex]::Match($text,$pattern,'IgnoreCase, Multiline'); if ($m.Success) { return ($m.Groups[1].Value ?? $m.Groups[2].Value).Trim() } else { return $null } }
  [pscustomobject]@{
    Code       = $code
    Status     = (& $get "^\*\*Статус:\*\*\s*([^\r\n]+)" $text)
    Version    = (& $get "^\*\*Версія:\*\*\s*([^\r\n]+)" $text)
    LastUpdate = (& $get "^\*\*Останн(є|е)\s+оновлення:\*\*\s*([^\r\n]+)" $text)
    Links      = (& $get "^\*\*(Прив[\u2019']?язки|Зв[\u2019']?язки|Links):\*\*\s*([^\r\n]+)" $text)
    Submodules = (& $get "^\*\*Підмодулі:\*\*\s*([^\r\n]+)" $text)
  }
}
function Normalize-Status([string]$s){ switch -Regex ($s){ '^\s*core\s*$'{'Core';break}; '^\s*active\s*$'{'Active';break}; '^\s*draft\s*$'{'Draft';break}; '^\s*archived?\s*$'{'Archived';break}; default{$s} } }
function Status-ToMaturity([string]$s){ switch (Normalize-Status $s){ 'Core'{3}; 'Active'{2}; 'Draft'{1}; 'Archived'{0}; default{0} } }

# -------- LOCK ACQUIRE ----------
$__lock = Acquire-Lock -Root $Root -Name "matrix"
if (-not $__lock) { exit 2 }

try {
  # OWNERS
  if (-not $OwnersCsv) { $OwnersCsv = Join-Path $Root "C12\KNOWLEDGE_VAULT\OWNERS.csv" }
  $ownersMap=@{}; if (Test-Path $OwnersCsv) { foreach ($o in (Import-Csv -Path $OwnersCsv)) { if ($o.Code) { $ownersMap[$o.Code] = $o.Owner } } }
  function Get-OwnerFor([string]$code){
    if ($ownersMap.ContainsKey($code) -and -not [string]::IsNullOrWhiteSpace($ownersMap[$code])) { return [pscustomobject]@{ Owner=$ownersMap[$code]; Source='Exact' } }
    if ($code -match '^(G\d{2})\.\d+') { $parent = $Matches[1]; if ($ownersMap.ContainsKey($parent) -and -not [string]::IsNullOrWhiteSpace($ownersMap[$parent])) { return [pscustomobject]@{ Owner=$ownersMap[$parent]; Source='Inherited' } } }
    return [pscustomobject]@{ Owner=''; Source='' }
  }

  # LOAD MODULE_INDEX
  $moduleIndexPath = Join-Path $Root "C12\KNOWLEDGE_VAULT\MODULE_INDEX.md"
  $indexText = Read-AllTextUtf8 $moduleIndexPath
  if (-not $indexText) { throw "Не знайдено MODULE_INDEX.md: $moduleIndexPath" }
  $rows = Parse-TableMarkdown -md $indexText

  $modules = $rows | Where-Object { $_.PSObject.Properties.Name -contains 'Код' -and $_.PSObject.Properties.Name -contains 'Назва' -and $_.PSObject.Properties.Name -contains 'Статус' -and $_.Код -match '^G\d{2}$' }
  $submods = $rows | Where-Object { $_.PSObject.Properties.Name -contains 'Код' -and $_.PSObject.Properties.Name -contains 'Батьківський' -and $_.Код -match '^G\d{2}\.\d+' }

  # SCAN MANIFESTS
  $manifestData=@{}
  foreach ($m in $modules) {
    $code=$m.Код; $mfPath = Join-Path (Join-Path $Root ("G\"+$code)) "manifest.md"
    $txt = Read-AllTextUtf8 $mfPath; $manifestData[$code]=Parse-Manifest -text $txt -code $code
  }
  foreach ($s in $submods) {
    $code=$s.Код; $mod=($code -split '\.')[0]
    $expected = Join-Path (Join-Path $Root ("G\"+$mod)) (Join-Path $code "manifest.md")
    $txt = if (Test-Path $expected) { Read-AllTextUtf8 $expected } else {
      $parentDir=Join-Path $Root ("G\"+$mod)
      $cand=Get-ChildItem -Path $parentDir -Recurse -Depth 4 -Filter "manifest.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "(^|[\\/])$([regex]::Escape($code))([\\/]|$)" } |
        Select-Object -First 1
      if ($cand) { Read-AllTextUtf8 $cand.FullName } else { $null }
    }
    $manifestData[$code]=Parse-Manifest -text $txt -code $code
  }

  # DIFFS
  $diffs=@(); function Add-Diff($code,$field,$indexVal,$mfVal){ $diffs += [pscustomobject]@{ Code=$code; Field=$field; Index=$indexVal; Manifest=$mfVal } }
  foreach ($m in $modules) {
    $code=$m.Код; $idxStatus=Normalize-Status $m.Статус; $idxVer=$m.Версія; $mf=$manifestData[$code]
    if (-not $mf) { Add-Diff $code 'Manifest' '—' 'відсутній'; continue }
    if ($mf.Status)  { if ((Normalize-Status $mf.Status) -ne $idxStatus) { Add-Diff $code 'Статус' $idxStatus $mf.Status } } else { Add-Diff $code 'Статус' $idxStatus '—' }
    if ($mf.Version) { if ($mf.Version -ne $idxVer) { Add-Diff $code 'Версія' $idxVer $mf.Version } } else { Add-Diff $code 'Версія' $idxVer '—' }
    if (-not $mf.LastUpdate) { Add-Diff $code 'Останнє оновлення' '—' '—' }
  }
  foreach ($s in $submods) {
    $code=$s.Код; $idxStatus=Normalize-Status $s.Статус; $idxVer=$s.Версія; $mf=$manifestData[$code]
    if (-not $mf) { Add-Diff $code 'Manifest' '—' 'відсутній'; continue }
    if ($mf.Status)  { if ((Normalize-Status $mf.Status) -ne $idxStatus) { Add-Diff $code 'Статус' $idxStatus $mf.Status } } else { Add-Diff $code 'Статус' $idxStatus '—' }
    if ($mf.Version) { if ($mf.Version -ne $idxVer) { Add-Diff $code 'Версія' $idxVer $mf.Version } } else { Add-Diff $code 'Версія' $idxVer '—' }
    if (-not $mf.LastUpdate) { Add-Diff $code 'Останнє оновлення' '—' '—' }
  }

  # SCORE
  $score=@{ Core=0; Active=0; Draft=0; Archived=0; Missing=0 }
  foreach ($m in $modules) { $st=Normalize-Status $m.Статус; if ($st -match 'Core|Active|Draft|Archived'){$score[$st]++}else{$score.Missing++} }
  foreach ($s in $submods) { $st=Normalize-Status $s.Статус; if ($st -match 'Core|Active|Draft|Archived'){$score[$st]++}else{$score.Missing++} }

  # MATRIX
  $matrix=@()
  $modules | ForEach-Object {
    $code=$_.Код; $name=$_.Назва; $statusIdx=Normalize-Status $_.Статус; $versionIdx=$_.Версія
    $layer  = if ($_.PSObject.Properties.Name -contains 'Layer')    { $_.Layer } else { '' }
    $prio   = if ($_.PSObject.Properties.Name -contains 'Priority') { $_.Priority } else { '' }
    $linksIdx = Get-PropValueByRegex $_ "^Зв[\u2019']?язки$"; if (-not $linksIdx) { $linksIdx = '' }
    $mf=$manifestData[$code]
    $status = if ($mf.Status) { Normalize-Status $mf.Status } else { $statusIdx }
    $version= if ($mf.Version) { $mf.Version } else { $versionIdx }
    $last   = if ($mf.LastUpdate) { $mf.LastUpdate } else { '' }
    $links  = if ($mf.Links) { $mf.Links } elseif ($linksIdx) { $linksIdx } else { '' }
    $o = Get-OwnerFor $code
    $matrix += [pscustomobject]@{ Code=$code; Name=$name; Layer=$layer; Status=$status; Version=$version; Parent='—'; Links=$links; Owner=$o.Owner; OwnerSource=$o.Source; Priority=$prio; 'Maturity(0-3)'=(Status-ToMaturity $status); LastUpdate=$last }
  }
  $submods | ForEach-Object {
    $code=$_.Код; $name=$_.Назва; $parent=$_.Батьківський; $statusIdx=Normalize-Status $_.Статус; $versionIdx=$_.Версія
    $linksIdx = Get-PropValueByRegex $_ "^Зв[\u2019']?язки$"; if (-not $linksIdx) { $linksIdx = '' }
    $mf=$manifestData[$code]
    $status = if ($mf.Status) { Normalize-Status $mf.Status } else { $statusIdx }
    $version= if ($mf.Version) { $mf.Version } else { $versionIdx }
    $last   = if ($mf.LastUpdate) { $mf.LastUpdate } else { '' }
    $links  = if ($mf.Links) { $mf.Links } elseif ($linksIdx) { $linksIdx } else { '' }
    $o = Get-OwnerFor $code
    $matrix += [pscustomobject]@{ Code=$code; Name=$name; Layer=''; Status=$status; Version=$version; Parent=$parent; Links=$links; Owner=$o.Owner; OwnerSource=$o.Source; Priority=''; 'Maturity(0-3)'=(Status-ToMaturity $status); LastUpdate=$last }
  }

  # POLICY: missing owners
  function Matches-OwnersPolicy([string]$code){
    switch ($OwnersRequiredFor) { 'Modules' { return ($code -match '^G\d{2}$') }; 'Submodules' { return ($code -match '^G\d{2}\.\d+') }; default { return $true } }
  }
  $missingOwners = $matrix | Where-Object { (Matches-OwnersPolicy $_.Code) -and (-not $_.Owner -or [string]::IsNullOrWhiteSpace($_.Owner)) }
  $missingOwnersCount = @($missingOwners).Count

  # REPORT (MD)
  $today = (Get-Date).ToString('yyyy-MM-dd')
  $md=@("# 📑 Matrix Audit Report — $today","","> Автоматичний аудит архітектури DAO-GOGS на основі MODULE_INDEX.md + manifest.md.","","## 🧭 Підсумки станів","","| Статус | К-сть |","|---|---:|","| Core | {0} |" -f $score.Core,"| Active | {0} |" -f $score.Active,"| Draft | {0} |" -f $score.Draft,"| Archived | {0} |" -f $score.Archived)
  if ($score.Missing -gt 0){ $md += "| Невідомо | {0} |" -f $score.Missing }
  $md += "","## ⚠️ Розбіжності MODULE_INDEX ↔ manifest"
  if (@($diffs).Count -eq 0){ $md += "","Розбіжностей не виявлено." } else {
    $md += "","| Код | Поле | MODULE_INDEX | manifest.md |","|---|---|---|---|"
    foreach($d in $diffs){
      $idx = if ([string]::IsNullOrEmpty($d.Index)) { '—' } else { $d.Index }
      $mfv = if ([string]::IsNullOrEmpty($d.Manifest)) { '—' } else { $d.Manifest }
      $md += "| {0} | {1} | {2} | {3} |" -f $d.Code,$d.Field,$idx,$mfv
    }
  }
  $md += "","## ❗ Модулі без Owner"
  if ($missingOwnersCount -eq 0){ $md += "Немає." } else {
    $md += "","<span style='color:#b00020'><strong>Відсутній Owner у $missingOwnersCount модул(і/ях) (policy: $OwnersRequiredFor):</strong></span>","",
    "| Code | Name | Status | Priority | Last Update |","|---|---|---|---|---|"
    foreach($row in ($missingOwners | Sort-Object Code)){
      $md += ("| {0} | {1} | {2} | {3} | {4} |" -f $row.Code,$row.Name,$row.Status,($row.Priority ?? ''),($row.LastUpdate ?? ''))
    }
  }
  $recs=@(); if ($missingOwnersCount -gt 0){ $recs += "<span style='color:#b00020'>• Призначити <strong>власників</strong> для модулів без Owner (policy: $OwnersRequiredFor).</span>" }
  if ($diffs | Where-Object { $_.Field -eq 'Версія' }){ $recs += "• Вирівняти **Версії** (джерело істини — manifest.md)." }
  if ($diffs | Where-Object { $_.Field -eq 'Статус' }){ $recs += "• Синхронізувати **Статуси** Draft/Active/Core/Archived." }
  if ($diffs | Where-Object { $_.Field -eq 'Manifest' -or $_.Field -eq 'Останнє оновлення' }){ $recs += "• Створити відсутні manifest.md та додати **Останнє оновлення** у форматі YYYY-MM-DD." }
  if ($recs.Count -eq 0){ $recs += "• Узгоджено. Переходимо до глибокого наповнення (зв’язки, агенти, сценарії)." }
  $md += "","## 🎯 Рекомендації"; foreach($r in $recs){ $md += $r }
  $mdOut=($md -join "`r`n")
  if ($OutFile){ Write-FileAtomic -Content $mdOut -Path $OutFile -Encoding utf8BOM } else { $mdOut | Write-Output }

  # CSV (always create, even empty)
  if ($CsvOut) {
    if ($null -eq $matrix -or @($matrix).Count -eq 0) {
      $headers = 'Code,Name,Layer,Status,Version,Parent,Links,Owner,OwnerSource,Priority,Maturity(0-3),LastUpdate'
      Write-FileAtomic -Content $headers -Path $CsvOut -Encoding utf8BOM
    } else {
      Export-CsvAtomic -InputObject $matrix -Path $CsvOut -Encoding utf8BOM
    }
  }

  # MD MATRIX (always create header)
  if ($MdMatrixOut){
    $m=@("# 🧭 Матриця архітектури DAO-GOGS","")
    if ($null -eq $matrix -or @($matrix).Count -eq 0) {
      $cols = @('Code','Name','Layer','Status','Version','Parent','Links','Owner','OwnerSource','Priority','Maturity(0-3)','Last Update')
      $m += "| " + ($cols -join " | ") + " |"
      $m += "|" + ( ($cols | ForEach-Object { '---' }) -join "|" ) + "|"
    } else {
      $m += "| Code | Name | Layer | Status | Version | Parent | Links | Owner | OwnerSource | Priority | Maturity | Last Update |"
      $m += "|---|---|---|---|---|---|---|---|---|---:|---|---|"
      foreach($row in ($matrix | Sort-Object Code)){
        $layer = if ($null -ne $row.Layer) { $row.Layer } else { '' }
        $prio  = if ($null -ne $row.Priority) { $row.Priority } else { '' }
        $parent= if ($null -ne $row.Parent) { $row.Parent } else { '—' }
        $links = if ($null -ne $row.Links) { ($row.Links -replace '\|','/') } else { '' }
        $owner = if ($null -ne $row.Owner) { $row.Owner } else { '' }
        $osrc  = if ($null -ne $row.OwnerSource) { $row.OwnerSource } else { '' }
        $lu    = if ($null -ne $row.LastUpdate) { $row.LastUpdate } else { '' }
        $m += ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} |" -f `
          $row.Code,$row.Name,$layer,$row.Status,$row.Version,$parent,$links,$owner,$osrc,$prio,$row.'Maturity(0-3)',$lu)
      }
    }
    Write-FileAtomic -Content ($m -join "`r`n") -Path $MdMatrixOut -Encoding utf8BOM
  }

  # EXIT CODE
  $crit = $diffs | Where-Object { $_.Field -in @('Версія','Статус','Manifest') }
  if     (@($crit).Count -gt 0){ Set-Exit 1 }
  elseif ($FailOnMissingOwner -and $missingOwnersCount -gt 0){ Set-Exit 1 }
  else   { Set-Exit 0 }

}
finally {
  Release-Lock $__lock
  Write-Host ("[OK] MatrixAudit completed (OwnersPolicy={0}). ExitCode={1}" -f $OwnersRequiredFor,$script:__exitCode)
  exit $script:__exitCode
}