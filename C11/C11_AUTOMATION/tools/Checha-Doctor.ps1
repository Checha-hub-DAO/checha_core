$root="C:\CHECHA_CORE"
$arc="$root\C05\ARCHIVE"; $log="$root\C03\LOG"
function S($ok){ if($ok){'🟢'} else {'🔴'} }
"== Paths =="; "core $(S (Test-Path $root))  | archive $(S (Test-Path $arc)) | log $(S (Test-Path $log))"
"== Last releases ==";
Get-ChildItem $arc -File -Filter "CHECHA_CORE_PUSH_*.zip" -EA SilentlyContinue |
 Sort LastWriteTime -Desc | Select -First 5 | ft LastWriteTime,Name,Length -Auto
"== Sched tasks ==";
schtasks /Query /FO LIST /V | findstr /I "\\CHECHA\\Release-" 
"== Logs tails ==";
gc "$log\release_daily.log"   -tail 2 2>$null
gc "$log\release_weekly.log"  -tail 2 2>$null
gc "$log\release_monthly.log" -tail 2 2>$null
