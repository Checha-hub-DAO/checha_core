$root = "C:\CHECHA_CORE"; $arc = "$root\C05\ARCHIVE"; $log = "$root\C03\LOG"
function S($ok,$warn=$false){ if($ok){'🟢'} elseif($warn){'🟡'} else {'🔴'} }
$hasArc = Test-Path $arc
$hasLogs = Test-Path $log
$w = Get-ChildItem $arc -Filter "*_weekly.zip"  -File -EA SilentlyContinue | Sort LastWriteTime -Desc | Select -First 1
$m = Get-ChildItem $arc -Filter "*_monthly.zip" -File -EA SilentlyContinue | Sort LastWriteTime -Desc | Select -First 1
$weeklyFresh  = $w -and ($w.LastWriteTime -gt (Get-Date).AddDays(-7))
$monthlyFresh = $m -and ($m.LastWriteTime -gt (Get-Date).AddDays(-35))
$newLine = "- Health: archive $(S $hasArc) | logs $(S $hasLogs) | weekly $(S $weeklyFresh) | monthly $(S $monthlyFresh)"

$dash = "$root\C06\FOCUS\Dashboard.md"
[string[]]$lines = @()
if (Test-Path $dash) { $lines = Get-Content -LiteralPath $dash -Encoding UTF8 }

# Прибрати старі "Health:" та додати свіжий зверху
$lines = $lines | Where-Object { $_ -notmatch '^\s*-\s*Health:' }
$lines = ,$newLine + $lines

Set-Content -LiteralPath $dash -Value $lines -Encoding UTF8
Write-Host "✅ Health оновлено"
