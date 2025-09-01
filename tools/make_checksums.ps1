param(
    [string]$ReleaseDir = "."
)

if (-not (Test-Path $ReleaseDir)) {
    Write-Error "Директорія $ReleaseDir не існує."
    exit 1
}

$chkPath = Join-Path $ReleaseDir "CHECKSUMS.txt"

# Взяти всі файли, окрім CHECKSUMS.txt
$files = Get-ChildItem $ReleaseDir -Recurse -File | Where-Object { $_.Name -ne "CHECKSUMS.txt" }

$lines = foreach ($f in $files) {
    try {
        $hash = Get-FileHash -Path $f.FullName -Algorithm SHA256
        "{0} *{1}" -f $hash.Hash, (Resolve-Path -Relative $f.FullName)
    } catch {
        Write-Error "Не вдалося обчислити хеш для: $($f.FullName)"
    }
}

$lines | Set-Content -Path $chkPath -Encoding UTF8 -NoNewline:$false
Write-Host "✅ CHECKSUMS.txt згенерований: $chkPath"