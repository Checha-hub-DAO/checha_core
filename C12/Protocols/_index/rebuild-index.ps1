<# 
  Р РµР±С–Р»Рґ Р»РѕРєР°Р»СЊРЅРёС… С–РЅРґРµРєСЃС–РІ С– РЅРѕСЂРјР°Р»С–Р·Р°С†С–СЏ РґСѓР±Р»С–РІ РїСЂРµС„С–РєСЃСѓ
  С‚РёРїСѓ 'checha/checha-core/.../checha/checha-core/...'.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$Target = "C12\Protocols\_index",
  [string]$ExpectedPrefix = "checha/checha-core/",
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$indexDir = Join-Path $Root $Target
if (!(Test-Path $indexDir)) { New-Item -ItemType Directory $indexDir | Out-Null }

function Normalize-Prefix([string]$s, [string]$prefix) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $s }
  # РЇРєС‰Рѕ РїРѕРґРІС–Р№РЅРёР№ РїСЂРµС„С–РєСЃ, СЃС‚РёСЃРєР°С”РјРѕ РґРѕ РѕРґРЅРѕРіРѕ
  $pat = '^(' + [regex]::Escape($prefix) + ')+'
  return ([regex]::Replace($s, $pat, $prefix))
}

# 1) Р—Р°РІР°РЅС‚Р°Р¶СѓС”РјРѕ С–СЃРЅСѓСЋС‡С– СЃРїРёСЃРєРё (СЏРєС‰Рѕ С”)
$filesJson = Join-Path $indexDir "FILES.json"
$paths = @()
if (Test-Path $filesJson) {
  try { $paths = (Get-Content $filesJson -Raw | ConvertFrom-Json) } catch { $paths = @() }
}

# 2) РЎРєР°РЅР°С”РјРѕ СЂРµР°Р»СЊРЅРёР№ РєРѕСЂС–РЅСЊ C12/Protocols
$scanRoot = Join-Path $Root "C12\Protocols"
if (Test-Path $scanRoot) {
  Get-ChildItem -Path $scanRoot -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($Root.Length).TrimStart('\').Replace('\','/')
    $paths += "$ExpectedPrefix$rel"
  }
}

# 3) РќРѕСЂРјР°Р»С–Р·Р°С†С–СЏ
$norm = $paths | ForEach-Object { Normalize-Prefix $_ $ExpectedPrefix } | Sort-Object -Unique

# 4) Р—Р°РїРёСЃ
if ($DryRun) {
  Write-Host "рџ”Ћ DryRun: would write $($norm.Count) items to $filesJson"
} else {
  $norm | ConvertTo-Json -Depth 2 | Set-Content -Path $filesJson -Encoding UTF8
  Write-Host "рџџў Rebuilt index: $filesJson ($($norm.Count) items)"
}
