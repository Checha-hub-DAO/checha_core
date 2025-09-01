param(
  [string]$Alias      = "checha",
  [string]$BucketPath = "checha-core/C12/Protocols",
  [string]$Root       = "C:\CHECHA_CORE\C12\Protocols",
  [switch]$CleanupWrongKeys  # прибрати ключі з "C:\..." у бакеті
)

$ErrorActionPreference = "Stop"
$prefix = "$Alias/$BucketPath/"

if ($CleanupWrongKeys) {
  $bad = mc --disable-pager find "$Alias/$BucketPath" --regex 'C:\\Users\\serge\\checha\\checha-core\\C12\\Protocols.*'
  if ($bad) { $bad | ForEach-Object { mc --disable-pager rm --force $_ } }
}

# дзеркало з видаленням зайвого (виключення як у твоєму backup-скрипті)
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\C12\Protocols\_index\Backup-To-MinIO.ps1" `
  -BucketPath $BucketPath -RemoveExtra

# локальні файли (без службових _index)
$localList = @(
  Get-ChildItem $Root -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\_index\\(protocols_index\.bak_.*\.json|.*\.tmp|Protocols(_Report)?\.md)$'
  } | ForEach-Object {
    $_.FullName.Substring($Root.Length+1).Replace('\','/')
  } | Sort-Object -Unique
)

# віддалені файли під тим самим префіксом (без «віконних» та службових)
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
  Write-Warning "Є різниця:"
  if ($onlyLocal)  { "`n-- ТІЛЬКИ ЛОКАЛЬНО --";  $onlyLocal  | Sort-Object | ForEach-Object { $_ } }
  if ($onlyRemote) { "`n-- ТІЛЬКИ У БАКЕТІ --"; $onlyRemote | Sort-Object | ForEach-Object { $_ } }
} else {
  Write-Host "🟢 Перевірка ок: $($localList.Count) = $($remoteList.Count)" -ForegroundColor Green
}