
param(
  [string]$OutFile = "CHANGELOG.md",
  [int]$Limit = 200
)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Error "git not found"
  exit 1
}
$lines = git log -n $Limit --pretty=format:"%s" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$groups = @{
  "Features" = New-Object System.Collections.Generic.List[string]
  "Fixes"    = New-Object System.Collections.Generic.List[string]
  "Docs"     = New-Object System.Collections.Generic.List[string]
  "Chore"    = New-Object System.Collections.Generic.List[string]
  "Other"    = New-Object System.Collections.Generic.List[string]
}
foreach ($l in $lines) {
  if ($l -match "^feat(\(.+\))?:") { $groups["Features"].Add($l) }
  elseif ($l -match "^fix(\(.+\))?:") { $groups["Fixes"].Add($l) }
  elseif ($l -match "^docs(\(.+\))?:") { $groups["Docs"].Add($l) }
  elseif ($l -match "^chore(\(.+\))?:") { $groups["Chore"].Add($l) }
  else { $groups["Other"].Add($l) }
}
$sb = New-Object System.Text.StringBuilder
$null = $sb.AppendLine("# CHANGELOG")
foreach ($k in "Features","Fixes","Docs","Chore","Other") {
  if ($groups[$k].Count -gt 0) {
    $null = $sb.AppendLine("## $k")
    foreach ($i in $groups[$k]) { $null = $sb.AppendLine("- $i") }
    $null = $sb.AppendLine("")
  }
}
$sb.ToString() | Set-Content $OutFile -Encoding UTF8
Write-Host "✅ Generated $OutFile"
