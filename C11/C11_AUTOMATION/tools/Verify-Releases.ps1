param([string]$Root)

function Resolve-CoreRoot {
  param([string]$Guess)
  if ($Guess -and (Test-Path (Join-Path $Guess "C06"))) { return (Resolve-Path $Guess).Path }
  $cand = (Resolve-Path "$PSScriptRoot\..\..").Path
  if (Test-Path (Join-Path $cand "C06")) { return $cand }
  throw "Не знайдено корінь CHECHA_CORE."
}

$root = Resolve-CoreRoot -Guess $Root
$arc  = Join-Path $root "C05\ARCHIVE"
$repD = Join-Path $arc  "REPORTS"
New-Item -ItemType Directory -Force -Path $repD | Out-Null
$report = Join-Path $repD ("VERIFY_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HHmm'))

$zips = Get-ChildItem -Path $arc -Filter "*.zip" -Recurse -File | Sort-Object LastWriteTime -Descending
$maxCheck = 12
$ok=0; $bad=0
"VERIFY LAST $maxCheck RELEASES" | Set-Content -LiteralPath $report -Encoding UTF8

foreach($z in $zips | Select-Object -First $maxCheck){
  $sha = "$($z.FullName).sha256"
  if (-not (Test-Path $sha)) { "NO_SHA  $($z.Name)" | Add-Content $report; $bad++; continue }
  $expect = (Get-Content -LiteralPath $sha -Raw) -split '\s+' | Select-Object -First 1
  $real   = (Get-FileHash -LiteralPath $z.FullName -Algorithm SHA256).Hash
  if ($real -ieq $expect) { "OK      $($z.Name)" | Add-Content $report; $ok++ } else { "MISMATCH $($z.Name)" | Add-Content $report; $bad++ }
}

"Summary: OK=$ok BAD=$bad" | Add-Content $report
Write-Host "✅ Verify done. $report"
