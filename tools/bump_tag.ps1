param([string]$Prefix = "symbols")
$now = Get-Date -Format "yyyy-MM-dd_HHmm"
$tag = "$Prefix-$now"
git tag $tag
git push origin $tag
Write-Host "✅ Pushed tag: $tag"
