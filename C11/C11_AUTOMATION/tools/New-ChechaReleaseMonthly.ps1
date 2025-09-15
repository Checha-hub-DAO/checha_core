param([string]$Root)

# Визначаємо корінь
function Resolve-CoreRoot {
  param([string]$Start)
  if ($Root) { return (Resolve-Path $Root).Path }
  $p = Split-Path -Parent ($PSCommandPath ?? $MyInvocation.MyCommand.Path)
  for($i=0;$i -lt 8;$i++){ if (Test-Path (Join-Path $p 'C06')) { return (Resolve-Path $p).Path }; $parent = Split-Path -Parent $p; if (-not $parent -or $parent -eq $p) { break }; $p = $parent }
  if ($env:CHECHA_CORE -and (Test-Path (Join-Path $env:CHECHA_CORE 'C06'))) { return (Resolve-Path $env:CHECHA_CORE).Path }
  return 'C:\CHECHA_CORE'
}
$root = Resolve-CoreRoot -Start ($PSCommandPath ?? $MyInvocation.MyCommand.Path)

# Швидкий місячний звіт
try {
  $arc  = Join-Path $root 'C05\ARCHIVE'
  $repD = Join-Path $arc  'REPORTS'
  New-Item -ItemType Directory -Force -Path $repD | Out-Null

  $ts = Get-Date -Format 'yyyy-MM'
  $rep = Join-Path $repD "MONTHLY_REPORT_$ts.md"

  $filesCnt = (Get-ChildItem -Path $root -Recurse -File -EA SilentlyContinue | Measure-Object).Count
  $sizeGB   = "{0:N2}" -f ((Get-ChildItem -Path $root -Recurse -File -EA SilentlyContinue | Measure-Object -Sum Length).Sum / 1GB)

  @(
    "# CHECHA CORE — Місячний звіт ($ts)"
    ""
    "- Файлів у CORE: **$filesCnt**"
    "- Орієнтовний розмір CORE: **$sizeGB GB**"
    "- Дата: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    ""
    "## Примітки"
    "- [ ] Переглянути дашборд і фокуси на новий місяць"
    "- [ ] Оновити `status.json` (DAO списки, next3days)"
  ) | Set-Content -LiteralPath $rep -Encoding UTF8
} catch {}

# Виклик релізу (в цьому ж процесі) з явним -Root
$release = Join-Path (Join-Path $root 'C11\C11_AUTOMATION\tools') 'New-ChechaRelease.ps1'
& $release -Label 'monthly' -Root $root
if ($LASTEXITCODE -le 7) { exit 0 } else { exit $LASTEXITCODE }

