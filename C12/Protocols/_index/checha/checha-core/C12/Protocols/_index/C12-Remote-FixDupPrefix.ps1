Param(
    [string]$Bucket = "checha",
    [string]$BadPrefix = "checha/checha-core/C12/Protocols/checha/checha-core/C12/Protocols/",
    [string]$GoodPrefix = "checha/checha-core/C12/Protocols/",
    [switch]$DryRun = $true,
    [switch]$Confirm  # require explicit -Confirm to execute
)
# Requirements: mc (MinIO client) in PATH

function Get-ItemsUnderPrefix {
    param([string]$Bucket,[string]$Prefix)
    $pref = $Prefix.TrimStart('/')
    $json = & mc ls --json --recursive ("minio/{0}/{1}" -f $Bucket, $pref) 2>$null
    if (-not $json) { return @() }
    $items = $json | ConvertFrom-Json | Where-Object { $_.type -eq 'file' }
    return $items
}

function TargetExists {
    param([string]$Bucket,[string]$Key)
    $out = & mc stat ("minio/{0}/{1}" -f $Bucket, $Key) 2>$null
    return ($LASTEXITCODE -eq 0)
}

$items = Get-ItemsUnderPrefix -Bucket $Bucket -Prefix $BadPrefix
if (-not $items -or $items.Count -eq 0) {
    Write-Host "РќРµРјР°С” С„Р°Р№Р»С–РІ РїС–Рґ BadPrefix: $BadPrefix" -ForegroundColor Yellow
    exit 0
}

Write-Host "Р—РЅР°Р№РґРµРЅРѕ $($items.Count) РѕР±'С”РєС‚С–РІ РїС–Рґ BadPrefix" -ForegroundColor Cyan

$plan = @()
foreach ($it in $items) {
    $oldKey = $it.key
    if (-not $oldKey.StartsWith($BadPrefix)) { continue }
    $tail   = $oldKey.Substring($BadPrefix.Length)
    $newKey = ($GoodPrefix.TrimEnd('/') + '/' + $tail).Replace('\','/')
    $plan += [PSCustomObject]@{ Old=$oldKey; New=$newKey }
}

# Show preview
$plan | Select-Object -First 50 | Format-Table -AutoSize
if ($DryRun -or -not $Confirm) {
    Write-Host "`nDry-run СЂРµР¶РёРј: СЂСѓС… РЅРµ РІРёРєРѕРЅСѓС”С‚СЊСЃСЏ. Р”РѕРґР°Р№С‚Рµ -DryRun:$false -Confirm С‰РѕР± РїРµСЂРµРЅРµСЃС‚Рё." -ForegroundColor Yellow
    exit 0
}

# Execute moves, РїРѕ РѕРґРЅРѕРјСѓ РєР»СЋС‡Сѓ
$errors = 0
foreach ($p in $plan) {
    $oldKey = $p.Old
    $newKey = $p.New
    if (TargetExists -Bucket $Bucket -Key $newKey) {
        Write-Host "SKIP (С–СЃРЅСѓС”): $newKey" -ForegroundColor Yellow
        continue
    }
    & mc mv ("minio/{0}/{1}" -f $Bucket, $oldKey) ("minio/{0}/{1}" -f $Bucket, $newKey)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERR: РЅРµ РІРґР°Р»РѕСЃСЏ РїРµСЂРµРјС–СЃС‚РёС‚Рё $oldKey в†’ $newKey" -ForegroundColor Red
        $errors++
    } else {
        Write-Host "OK: $oldKey в†’ $newKey"
    }
}
if ($errors -eq 0) { Write-Host "Р“РѕС‚РѕРІРѕ Р±РµР· РїРѕРјРёР»РѕРє." -ForegroundColor Green } else { Write-Host "Р—Р°РІРµСЂС€РµРЅРѕ Р· РїРѕРјРёР»РєР°РјРё: $errors" -ForegroundColor Red }
# РЎ.Р§.
