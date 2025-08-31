param(
  [string]$Version = (Get-Date -Format "yyyy-MM-dd_HHmm"),
  [string]$ReleaseBase = "release",
  [switch]$Publish
)
$ErrorActionPreference = "Stop"
$C01Zip = "c01_pack\C01_symbol_extended_pack_v1.1.zip"
$C02Zip = "c02_pack\C02_symbol_pack_v1.0.zip"
function Ensure-Zip($path, $buildScript) {
  if (-not (Test-Path $path)) { Write-Host "ℹ️ Building $path"; python $buildScript; if (-not (Test-Path $path)) { throw "❌ $path not found after build" } }
  else { Write-Host "✅ Found $path" }
}
Ensure-Zip $C01Zip ".\c01_pack\build_c01_symbol_pack.py"
Ensure-Zip $C02Zip ".\c02_pack\build_c02_symbol_pack.py"
$RelDir = Join-Path $ReleaseBase ("release_" + $Version)
New-Item -ItemType Directory -Force -Path $RelDir | Out-Null
Copy-Item $C01Zip $RelDir -Force
Copy-Item $C02Zip $RelDir -Force
"# CHECHA_CORE symbol packs — $Version`n* C01: $(Split-Path $C01Zip -Leaf)`n* C02: $(Split-Path $C02Zip -Leaf)" |
  Out-File (Join-Path $RelDir "INDEX.md") -Encoding utf8
Write-Host "✅ Versioned release staged at $RelDir"
if ($Publish) {
  if (Get-Command gh -ErrorAction SilentlyContinue) {
    $tag = "symbols-$Version"
    gh release view $tag *> $null; $exists = ($LASTEXITCODE -eq 0)
    if ($exists) {
      Write-Host "ℹ️ Release exists — uploading (clobber)…"
      gh release upload $tag (Join-Path $RelDir (Split-Path $C01Zip -Leaf)) (Join-Path $RelDir (Split-Path $C02Zip -Leaf)) --clobber
    } else {
      Write-Host "ℹ️ Creating GitHub Release…"
      gh release create $tag (Join-Path $RelDir (Split-Path $C01Zip -Leaf)) (Join-Path $RelDir (Split-Path $C02Zip -Leaf)) --title "CHECHA_CORE Symbols $Version" --notes-file (Join-Path $RelDir "INDEX.md")
    }
    Write-Host "✅ GitHub Release OK: $tag"
  } else {
    Write-Warning "⚠️ gh CLI not found. Install: https://cli.github.com/"
  }
}
