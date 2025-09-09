param(
    [string]$ReleaseDir = "."
)

if (-not (Test-Path $ReleaseDir)) {
    Write-Error "Р”РёСЂРµРєС‚РѕСЂС–СЏ $ReleaseDir РЅРµ С–СЃРЅСѓС”."
    exit 1
}

$chkPath = Join-Path $ReleaseDir "CHECKSUMS.txt"

# Р’Р·СЏС‚Рё РІСЃС– С„Р°Р№Р»Рё, РѕРєСЂС–Рј CHECKSUMS.txt
$files = Get-ChildItem $ReleaseDir -Recurse -File | Where-Object { $_.Name -ne "CHECKSUMS.txt" }

$lines = foreach ($f in $files) {
    try {
        $hash = Get-FileHash -Path $f.FullName -Algorithm SHA256
        "{0} *{1}" -f $hash.Hash, (Resolve-Path -Relative $f.FullName)
    } catch {
        Write-Error "РќРµ РІРґР°Р»РѕСЃСЏ РѕР±С‡РёСЃР»РёС‚Рё С…РµС€ РґР»СЏ: $($f.FullName)"
    }
}

$lines | Set-Content -Path $chkPath -Encoding UTF8 -NoNewline:$false
Write-Host "вњ… CHECKSUMS.txt Р·РіРµРЅРµСЂРѕРІР°РЅРёР№: $chkPath"