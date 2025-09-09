Param([string]$Root="C:\CHECHA_CORE",[string]$Version="v2.1")
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$base = Join-Path $Root "C08_COORD\INIT_MAP\REPORTS"
$rel  = Join-Path $Root ("C05_ARCHIVE\RELEASES\INITMAP\" + $Version)
$null = New-Item -ItemType Directory -Force -Path $base, $rel
$zip  = Join-Path $rel ("INITMAP_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".zip")
[System.IO.Compression.ZipFile]::CreateFromDirectory($base,$zip)
$sha = (Get-FileHash -Path $zip -Algorithm SHA256).Hash
"sha256  $(Split-Path $zip -Leaf)  $sha" | Out-File -Encoding utf8 -FilePath (Join-Path $rel 'CHECKSUMS.txt')
$log = Join-Path $Root "C03_LOG\LOG.md"
Add-Content -Encoding utf8 -Path $log -Value ("{0} [INFO ] INITMAP release {1} → {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Version,(Resolve-Path $zip))
Add-Content -Encoding utf8 -Path (Join-Path $Root "C03_LOG\initmap.log") -Value ("{0} [INFO ] Publish-InitMapSnapshot: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $zip)
