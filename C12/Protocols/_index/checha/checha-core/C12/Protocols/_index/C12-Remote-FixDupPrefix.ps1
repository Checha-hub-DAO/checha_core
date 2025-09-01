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
    Write-Host "Немає файлів під BadPrefix: $BadPrefix" -ForegroundColor Yellow
    exit 0
}

Write-Host "Знайдено $($items.Count) об'єктів під BadPrefix" -ForegroundColor Cyan

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
    Write-Host "`nDry-run режим: рух не виконується. Додайте -DryRun:$false -Confirm щоб перенести." -ForegroundColor Yellow
    exit 0
}

# Execute moves, по одному ключу
$errors = 0
foreach ($p in $plan) {
    $oldKey = $p.Old
    $newKey = $p.New
    if (TargetExists -Bucket $Bucket -Key $newKey) {
        Write-Host "SKIP (існує): $newKey" -ForegroundColor Yellow
        continue
    }
    & mc mv ("minio/{0}/{1}" -f $Bucket, $oldKey) ("minio/{0}/{1}" -f $Bucket, $newKey)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERR: не вдалося перемістити $oldKey → $newKey" -ForegroundColor Red
        $errors++
    } else {
        Write-Host "OK: $oldKey → $newKey"
    }
}
if ($errors -eq 0) { Write-Host "Готово без помилок." -ForegroundColor Green } else { Write-Host "Завершено з помилками: $errors" -ForegroundColor Red }
# С.Ч.
