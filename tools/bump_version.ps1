
param(
  [Parameter(Mandatory=$true)][ValidateSet("major","minor","patch")] [string]$Type,
  [string]$Config = "release.config.json"
)

$cfg = Get-Content $Config -Raw | ConvertFrom-Json
$tag = $cfg.Tag
if (-not $tag) { throw "No Tag in config." }

# Extract semver numbers
if ($tag -match "(\d+)\.(\d+)\.(\d+)") {
  $maj = [int]$Matches[1]
  $min = [int]$Matches[2]
  $pat = [int]$Matches[3]
} else {
  throw "Tag '$tag' is not semantic (x.y.z required)."
}

switch ($Type) {
  "major" { $maj++; $min = 0; $pat = 0 }
  "minor" { $min++; $pat = 0 }
  "patch" { $pat++ }
}
$newTag = ("v{0}.{1}.{2}" -f $maj,$min,$pat)
$cfg.Tag = $newTag
$cfg.OutZip = ("{0}_Block_{1}.zip" -f $cfg.BlockName,$newTag)
$cfg | ConvertTo-Json -Depth 5 | Set-Content $Config -Encoding UTF8
Write-Host "✅ New tag: $newTag; updated OutZip: $($cfg.OutZip)"
