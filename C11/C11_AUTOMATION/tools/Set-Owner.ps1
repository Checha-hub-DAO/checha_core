<#
.SYNOPSIS
  Керування реєстром власників модулів (OWNERS.csv).

.DESCRIPTION
  Підтримує дії:
    - set    : додати/оновити Owner (і Contact) для коду GXX або GXX.YY
    - remove : видалити запис за Code
    - get    : показати запис за Code
    - list   : показати всі записи, відсортовані за Code
    - import : імпорт/злиття з CSV (колонки Code,Owner,Contact)

.PARAMETER Root
  Кореневий шлях CHECHA_CORE (за замовчуванням C:\CHECHA_CORE).

.PARAMETER Action
  set | remove | get | list | import   (default: list)

.PARAMETER Code
  Код модуля (G11, G44, G45.1 тощо) для дій set/remove/get.

.PARAMETER Owner
  Ім'я або назва групи-власника (для set).

.PARAMETER Contact
  Контакт (e-mail/посилання) — необов'язково (для set / import).

.PARAMETER BatchCsv
  Шлях до CSV-файлу для імпорту (для import).

.PARAMETER NoBackup
  Не створювати резервну копію OWNERS.csv перед збереженням.

.EXAMPLES
  # Показати всіх власників:
  pwsh -NoProfile -File Set-Owner.ps1

  # Призначити/оновити власника:
  pwsh -NoProfile -File Set-Owner.ps1 -Action set -Code G35 -Owner "Медіа-альянс" -Contact media@example.org

  # Видалити власника:
  pwsh -NoProfile -File Set-Owner.ps1 -Action remove -Code G35

  # Отримати одного:
  pwsh -NoProfile -File Set-Owner.ps1 -Action get -Code G44

  # Імпорт (злиття) з CSV:
  pwsh -NoProfile -File Set-Owner.ps1 -Action import -BatchCsv "C:\path\OWNERS_new.csv"
#>

[CmdletBinding()]
Param(
  [string]$Root = "C:\CHECHA_CORE",
  [ValidateSet('set','remove','get','list','import')]
  [string]$Action = 'list',
  [string]$Code,
  [string]$Owner,
  [string]$Contact,
  [string]$BatchCsv,
  [switch]$NoBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------- helpers ----------
function Get-OwnersPath([string]$root) {
  Join-Path $root "C12\KNOWLEDGE_VAULT\OWNERS.csv"
}
function Ensure-OwnersFile([string]$path) {
  $dir = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if (-not (Test-Path $path)) {
    "Code,Owner,Contact" | Set-Content -Path $path -Encoding UTF8
  }
}
function Load-Owners([string]$path) {
  if (-not (Test-Path $path)) { return @() }
  return Import-Csv -Path $path
}
function Save-Owners([array]$rows, [string]$path, [switch]$NoBackup) {
  if (-not $NoBackup) {
    $bak = "{0}.{1}.bak.csv" -f $path, (Get-Date -Format yyyyMMdd_HHmmss)
    Copy-Item -Path $path -Destination $bak -ErrorAction SilentlyContinue
  }
  $rows | Sort-Object Code | Export-Csv -Path $path -Encoding UTF8 -NoTypeInformation
}
function Validate-Code([string]$code) {
  if (-not $code -or ($code -notmatch '^G\d{2}(\.\d+)?$')) {
    throw "Невірний Code: '$code'. Очікується GNN або GNN.MM (наприклад, G11, G44, G45.1)."
  }
}

$ownersPath = Get-OwnersPath $Root
Ensure-OwnersFile $ownersPath
$rows = Load-Owners $ownersPath
$map = @{}
foreach ($r in $rows) { if ($r.Code) { $map[$r.Code] = $r } }

switch ($Action) {

  'list' {
    if ($rows.Count -eq 0) { Write-Host "OWNERS.csv порожній: $ownersPath"; break }
    $rows | Sort-Object Code | Format-Table Code, Owner, Contact -AutoSize
  }

  'get' {
    Validate-Code $Code
    if ($map.ContainsKey($Code)) {
      $map[$Code] | Format-List
    } else {
      Write-Warning "Запис для $Code не знайдено у OWNERS.csv"
    }
  }

  'set' {
    Validate-Code $Code
    if (-not $Owner -or [string]::IsNullOrWhiteSpace($Owner)) {
      throw "Для дії 'set' потрібний параметр -Owner."
    }
    if ($map.ContainsKey($Code)) {
      $map[$Code].Owner   = $Owner
      if ($PSBoundParameters.ContainsKey('Contact')) { $map[$Code].Contact = $Contact }
      Write-Host "Оновлено: $Code → Owner='$Owner'" -ForegroundColor Green
    } else {
      $new = [pscustomobject]@{ Code=$Code; Owner=$Owner; Contact=$Contact }
      $rows += ,$new
      $map[$Code] = $new
      Write-Host "Додано: $Code → Owner='$Owner'" -ForegroundColor Green
    }
    Save-Owners -rows $rows -path $ownersPath -NoBackup:$NoBackup
  }

  'remove' {
    Validate-Code $Code
    if (-not $map.ContainsKey($Code)) {
      Write-Warning "Немає запису для $Code."
      break
    }
    $rows = $rows | Where-Object { $_.Code -ne $Code }
    $map.Remove($Code) | Out-Null
    Save-Owners -rows $rows -path $ownersPath -NoBackup:$NoBackup
    Write-Host "Видалено: $Code" -ForegroundColor Yellow
  }

  'import' {
    if (-not $BatchCsv) { throw "Вкажи -BatchCsv для імпорту." }
    if (-not (Test-Path $BatchCsv)) { throw "Файл не знайдено: $BatchCsv" }
    $incoming = Import-Csv -Path $BatchCsv
    $updated = 0; $added = 0
    foreach ($i in $incoming) {
      if (-not $i.Code) { continue }
      Validate-Code $i.Code
      $c = $i.Code; $o = $i.Owner; $t = $i.Contact
      if ($map.ContainsKey($c)) {
        if ($o) { $map[$c].Owner = $o }
        if ($i.PSObject.Properties.Name -contains 'Contact') { $map[$c].Contact = $t }
        $updated++
      } else {
        $new = [pscustomobject]@{ Code=$c; Owner=$o; Contact=$t }
        $rows += ,$new
        $map[$c] = $new
        $added++
      }
    }
    Save-Owners -rows $rows -path $ownersPath -NoBackup:$NoBackup
    Write-Host "Імпорт завершено: додано $added, оновлено $updated. Файл: $ownersPath" -ForegroundColor Green
  }
}
