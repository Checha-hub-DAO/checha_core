$arc="C:\CHECHA_CORE\C05\ARCHIVE"
function Prune($pattern,$keep){
  $files = Get-ChildItem $arc -Filter $pattern -File | Sort LastWriteTime -Desc
  $files | Select -Skip $keep | Remove-Item -Force -EA SilentlyContinue
  Get-ChildItem $arc -Filter ($pattern+'.sha256') -File | Select -Skip $keep | Remove-Item -Force -EA SilentlyContinue
}
Prune "CHECHA_CORE_PUSH_*_daily.zip"   14
Prune "CHECHA_CORE_PUSH_*_weekly.zip"   8
Prune "CHECHA_CORE_PUSH_*_monthly.zip" 12
Write-Host "✅ Cleanup done"
