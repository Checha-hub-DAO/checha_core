[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $Path,
  [Parameter(Mandatory)] [string] $Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
  $verFile = Join-Path $Path 'VERSION.txt'
  Set-Content -Path $verFile -Value $Version -Encoding ASCII

  # Опційно: оновити рядок version у manifest.md, якщо є
  $manifest = Join-Path $Path 'manifest.md'
  if (Test-Path $manifest) {
    $content = Get-Content $manifest -Raw
    if ($content -match '(?m)^version:\s*"?.*?"?\s*$') {
      $content = [regex]::Replace($content, '(?m)^version:\s*"?.*?"?\s*$', "version: ""$Version""")
    } else {
      $content = $content.TrimEnd() + "`nversion: ""$Version""`n"
    }
    Set-Content $manifest -Value $content -Encoding UTF8
  }

  Write-Host "✔ VERSION.txt оновлено: $Version" -ForegroundColor Green
  exit 0
}
catch {
  Write-Error $_
  exit 5
}
