param(
  [string]$Alias      = "checha",
  [string]$BucketPath = "checha-core/C12/Protocols",
  [string]$Root       = "C:\CHECHA_CORE\C12\Protocols",
  [switch]$CleanupWrongKeys  # РїСЂРёР±СЂР°С‚Рё РєР»СЋС‡С– Р· "C:\..." Сѓ Р±Р°РєРµС‚С–
)

$ErrorActionPreference = "Stop"
$prefix = "$Alias/$BucketPath/"

if ($CleanupWrongKeys) {
  $bad = mc --disable-pager find "$Alias/$BucketPath" --regex 'C:\\Users\\serge\\checha\\checha-core\\C12\\Protocols.*'
  if ($bad) { $bad | ForEach-Object { mc --disable-pager rm --force $_ } }
}

# РґР·РµСЂРєР°Р»Рѕ Р· РІРёРґР°Р»РµРЅРЅСЏРј Р·Р°Р№РІРѕРіРѕ (РІРёРєР»СЋС‡РµРЅРЅСЏ СЏРє Сѓ С‚РІРѕС”РјСѓ backup-СЃРєСЂРёРїС‚С–)
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\C12\Protocols\_index\Backup-To-MinIO.ps1" `
  -BucketPath $BucketPath -RemoveExtra

# Р»РѕРєР°Р»СЊРЅС– С„Р°Р№Р»Рё (Р±РµР· СЃР»СѓР¶Р±РѕРІРёС… _index)
$localList = @(
  Get-ChildItem $Root -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\_index\\(protocols_index\.bak_.*\.json|.*\.tmp|Protocols(_Report)?\.md)$'
  } | ForEach-Object {
    $_.FullName.Substring($Root.Length+1).Replace('\','/')
  } | Sort-Object -Unique
)

# РІС–РґРґР°Р»РµРЅС– С„Р°Р№Р»Рё РїС–Рґ С‚РёРј СЃР°РјРёРј РїСЂРµС„С–РєСЃРѕРј (Р±РµР· В«РІС–РєРѕРЅРЅРёС…В» С‚Р° СЃР»СѓР¶Р±РѕРІРёС…)
$remoteRaw  = @( mc --disable-pager find "$Alias/$BucketPath" )
$remoteList = @(
  $remoteRaw | ForEach-Object {
    $p = $_.Trim()
    if ($p.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { $p = $p.Substring($prefix.Length) }
    $p
  } | Where-Object {
    $_ -and
    ($_ -notmatch '^C:\\') -and
    ($_ -notmatch '^_index/(protocols_index\.bak_.*\.json|.*\.tmp|Protocols(_Report)?\.md)$')
  } | Sort-Object -Unique
)

"LOCAL count : $($localList.Count)"
"REMOTE count: $($remoteList.Count)"

$diff = Compare-Object -ReferenceObject $localList -DifferenceObject $remoteList -PassThru
$onlyLocal  = $diff | Where-Object SideIndicator -eq '<='
$onlyRemote = $diff | Where-Object SideIndicator -eq '=>'

if ($onlyLocal -or $onlyRemote) {
  Write-Warning "Р„ СЂС–Р·РЅРёС†СЏ:"
  if ($onlyLocal)  { "`n-- РўР†Р›Р¬РљР Р›РћРљРђР›Р¬РќРћ --";  $onlyLocal  | Sort-Object | ForEach-Object { $_ } }
  if ($onlyRemote) { "`n-- РўР†Р›Р¬РљР РЈ Р‘РђРљР•РўР† --"; $onlyRemote | Sort-Object | ForEach-Object { $_ } }
} else {
  Write-Host "рџџў РџРµСЂРµРІС–СЂРєР° РѕРє: $($localList.Count) = $($remoteList.Count)" -ForegroundColor Green
}