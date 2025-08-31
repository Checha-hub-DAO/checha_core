param(
  [string]$Root = ".",
  [string[]]$IncludeExt = @(".md",".markdown"),
  [string[]]$IgnoreDirs = @(".git","node_modules","release","dist",".github","build"),
  [switch]$ChangedOnly
)

$stampRegex = '_Stamp:_ .+ v\d+\.\d+ · \d{4}-\d{2}-\d{2} · .+'

function Should-Ignore($path) {
  foreach ($d in $IgnoreDirs) {
    if ($path -like "*\${d}\*") { return $true }
  }
  return $false
}

$files = @()

if ($ChangedOnly) {
  $git = git diff --cached --name-only | Where-Object { $_ -match '\.md$|\.markdown$' }
  foreach ($f in $git) {
    $full = Join-Path (Resolve-Path ".") $f
    if (-not (Should-Ignore $full)) { $files += $full }
  }
} else {
  Get-ChildItem -Path $Root -Recurse -File | ForEach-Object {
    if ($IncludeExt -contains $_.Extension.ToLower() -and -not (Should-Ignore $_.FullName)) {
      $files += $_.FullName
    }
  }
}

if (-not $files) { Write-Host "ℹ️ Немає файлів для перевірки."; exit 0 }

$bad = @()
foreach ($f in $files) {
  $content = Get-Content -LiteralPath $f -TotalCount 200 -ErrorAction SilentlyContinue | Out-String
  if ($content -notmatch $stampRegex) { $bad += $f }
}

if ($bad.Count -gt 0) {
  Write-Host "❌ Відсутній або невалідний штамп у файлах:" -ForegroundColor Red
  $bad | ForEach-Object { Write-Host " - $_" }
  Write-Host "`nОчікуваний формат:"
  Write-Host "_Stamp:_ NAME vX.Y · YYYY-MM-DD · Автор" -ForegroundColor Yellow
  exit 1
}

Write-Host "✅ Усі штампи валідні."
exit 0
