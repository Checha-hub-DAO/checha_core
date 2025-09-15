param([string]$Root)
# Визначаємо корінь
function Resolve-CoreRoot {
  param([string]$Start)
  if ($Root) { return (Resolve-Path $Root).Path }
  $p = Split-Path -Parent ($PSCommandPath ?? $MyInvocation.MyCommand.Path)
  for($i=0;$i -lt 8;$i++){ if (Test-Path (Join-Path $p "C06")) { return (Resolve-Path $p).Path }; $parent = Split-Path -Parent $p; if (-not $parent -or $parent -eq $p) { break }; $p = $parent }
  if ($env:CHECHA_CORE -and (Test-Path (Join-Path $env:CHECHA_CORE "C06"))) { return (Resolve-Path $env:CHECHA_CORE).Path }
  return "C:\CHECHA_CORE"
}
$root = Resolve-CoreRoot -Start ($PSCommandPath ?? $MyInvocation.MyCommand.Path)

# (опційно) інвентар
try {
  $repD = Join-Path $root "C05\ARCHIVE\REPORTS"; New-Item -ItemType Directory -Force -Path $repD | Out-Null
  $today = Get-Date -Format "yyyy-MM-dd"; $inv = Join-Path $repD "WEEKLY_INVENTORY_$today.txt"
  "CHECHA WEEKLY INVENTORY $today" | Set-Content -LiteralPath $inv -Encoding UTF8
  "== Files by top-level ==" | Add-Content $inv
  Get-ChildItem -Path $root -Directory | ForEach-Object {
    $cnt = (Get-ChildItem -Recurse -File -Path $_.FullName -EA SilentlyContinue | Measure-Object).Count
    "{0,-20} {1,8} files" -f $_.Name, $cnt | Add-Content $inv
  }
} catch {}

# Сам реліз (label=weekly)
$release = Join-Path $root "C11\C11_AUTOMATION\tools\New-ChechaRelease.ps1"
& $release -Label "weekly" -Root $root
if ($LASTEXITCODE -le 7) { exit 0 } else { exit $LASTEXITCODE }

