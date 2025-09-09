param(
    [Parameter(Mandatory=$true)][string]$SourceDir,
    [Parameter(Mandatory=$true)][string]$OutZip
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

if (Test-Path $OutZip) {
    Remove-Item $OutZip -Force
}

[System.IO.Compression.ZipFile]::CreateFromDirectory($SourceDir, $OutZip)
Write-Host "вњ… ZIP СЃС‚РІРѕСЂРµРЅРѕ: $OutZip"