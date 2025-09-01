Param(
    [string]$Bucket = "checha",
    [string]$Prefix = "checha/checha-core/C12/Protocols",
    [string]$Local  = "C:\CHECHA_CORE\C12\Protocols",
    [switch]$NoReindex
)
function Get-RemoteKeys {
    param([string]$Bucket,[string]$Prefix)
    $pref = $Prefix.TrimEnd('/') + '/'
    $json = & mc ls --json --recursive "minio/$Bucket/$pref" 2>$null
    if (-not $json) { return @() }
    $items = $json | ConvertFrom-Json | Where-Object { $_.type -eq 'file' }
    $keys  = @()
    foreach ($i in $items) {
        $k = $i.key
        if ($k.StartsWith($pref)) { $k = $k.Substring($pref.Length) }
        $k = $k.TrimStart('/')
        if ($k -and -not $k.StartsWith('_index/')) { $keys += $k.Replace('\','/') }
    }
    return ($keys | Sort-Object -Unique)
}
function Get-LocalKeys {
    param([string]$Local)
    if (-not (Test-Path $Local)) { return @() }
    $files = Get-ChildItem -File -Recurse -Path $Local -ErrorAction SilentlyContinue
    $keys = @()
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($Local.Length).TrimStart('\','/')
        if ($rel -and -not $rel.StartsWith('_index')) { $keys += $rel.Replace('\','/') }
    }
    return ($keys | Sort-Object -Unique)
}
$remote = Get-RemoteKeys -Bucket $Bucket -Prefix $Prefix
$local  = Get-LocalKeys  -Local  $Local
Write-Host "Remote files (normalized): $($remote.Count)"
Write-Host "Local  files (normalized): $($local.Count)"
if (-not $NoReindex) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $tmp   = Join-Path $env:TEMP "REMOTE_INDEX_$stamp.txt"
    $remote | Out-File -FilePath $tmp -Encoding UTF8
    $indexKey = "$Prefix/_index/REMOTE_INDEX.txt"
    & mc cp "$tmp" "minio/$Bucket/$indexKey" | Out-Null
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}
$diff = Compare-Object $local $remote -PassThru
if (-not $diff) { Write-Host "🟢 OK: No differences detected (1:1)" -ForegroundColor Green }
else { Write-Host "🟡 DIFF detected (first 50):" -ForegroundColor Yellow; $diff | Select-Object -First 50 }
# С.Ч.
