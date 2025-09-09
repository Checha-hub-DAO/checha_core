<# -----------------------------------------------------------------------
 Add-CheChaContext.ps1
 Створює/перевіряє/видаляє пункти контекстного меню у Провіднику (HKCU):
  - CheCha: Update Panel
  - CheCha: RunAll (Full)
  - (опц.) CheCha: Open CONTROL_PANEL.md

 Виклики:
   # Встановити 2 основні пункти
   pwsh -NoProfile -ExecutionPolicy Bypass -File .\Add-CheChaContext.ps1 -Install

   # Додатково поставити "Open CONTROL_PANEL.md"
   pwsh -NoProfile -ExecutionPolicy Bypass -File .\Add-CheChaContext.ps1 -Install -IncludeOpenPanel

   # Перевірити
   pwsh -NoProfile -ExecutionPolicy Bypass -File .\Add-CheChaContext.ps1 -Check

   # Видалити всі створені пункти
   pwsh -NoProfile -ExecutionPolicy Bypass -File .\Add-CheChaContext.ps1 -Remove

 Параметри для кастомізації шляхів:
   -PwshExe "C:\Program Files\PowerShell\7\pwsh.exe"
   -IconPath "C:\CHECHA_CORE\C06_FOCUS\icons\checha_start.ico"
   -ChechaRoot "C:\CHECHA_CORE"
------------------------------------------------------------------------ #>

[CmdletBinding(DefaultParameterSetName='Install')]
param(
  [Parameter(ParameterSetName='Install')][switch]$Install,
  [Parameter(ParameterSetName='Install')][switch]$IncludeOpenPanel,

  [Parameter(ParameterSetName='Check')][switch]$Check,
  [Parameter(ParameterSetName='Remove')][switch]$Remove,

  [string]$PwshExe   = "C:\Program Files\PowerShell\7\pwsh.exe",
  [string]$ChechaRoot= "C:\CHECHA_CORE",
  [string]$IconPath  = "C:\CHECHA_CORE\C06_FOCUS\icons\checha_start.ico"

  [string]$IconPath  = "C:\CHECHA_CORE\C06_FOCUS\icons\checha_start.ico",
  [string]$EditorPath  # ← ДОБАВЛЕНО: шлях до Code.exe або іншого редактора
)

$ErrorActionPreference = 'Stop'

# --- Helpers --------------------------------------------------------------
function Ensure-Path([string]$p){ if(-not(Test-Path $p)){ New-Item -Path $p -Force | Out-Null } }

function Ensure-ContextItem {
  param(
    [Parameter(Mandatory)][string]$KeyPath,      # HKCU:\Software\Classes\Directory\Background\shell\CheCha_X
    [Parameter(Mandatory)][string]$Text,         # Видимий заголовок
    [Parameter(Mandatory)][string]$CommandLine,  # Значення (default) у \command
    [string]$Icon = $null
  )
  Ensure-Path $KeyPath
  New-ItemProperty -Path $KeyPath -Name 'MUIVerb' -Value $Text -PropertyType String -Force | Out-Null
  if ($Icon -and (Test-Path $Icon)) {
    New-ItemProperty -Path $KeyPath -Name 'Icon' -Value $Icon -PropertyType String -Force | Out-Null
  }
  $cmdKey = Join-Path $KeyPath 'command'
  Ensure-Path $cmdKey
  New-ItemProperty -Path $cmdKey -Name '(default)' -Value $CommandLine -PropertyType String -Force | Out-Null
}

function Remove-ContextItem {
  param([Parameter(Mandatory)][string]$KeyPath)
  if (Test-Path $KeyPath) {
    Remove-Item -Path $KeyPath -Recurse -Force
    Write-Host "🧹 Removed: $KeyPath"
  } else {
    Write-Host "ℹ️ Not found: $KeyPath"
  }
}

function Get-ContextItem {
  param([Parameter(Mandatory)][string]$KeyPath)
  $cmdKey = Join-Path $KeyPath 'command'
  if (Test-Path $cmdKey) {
    [PSCustomObject]@{
      Key      = $KeyPath
      Command  = (Get-ItemProperty $cmdKey).'(default)'
      Text     = (Get-ItemProperty $KeyPath).MUIVerb
      Icon     = (Get-ItemProperty $KeyPath).Icon
      Exists   = $true
    }
  } else {
    [PSCustomObject]@{ Key=$KeyPath; Command=$null; Text=$null; Icon=$null; Exists=$false }
  }
}

# --- Targets & commands ---------------------------------------------------
$bgBase = 'HKCU:\Software\Classes\Directory\Background\shell'

$updateKey = Join-Path $bgBase 'CheCha_UpdatePanel'
$runAllKey = Join-Path $bgBase 'CheCha_RunAllFull'
$openKey   = Join-Path $bgBase 'CheCha_OpenPanel'

$updateCmd = "`"$PwshExe`" -NoProfile -ExecutionPolicy Bypass -File `"$ChechaRoot\C11\C11_AUTOMATION\Checha-RunAll.ps1`" -UpdatePanel"
$runAllCmd = "`"$PwshExe`" -NoProfile -ExecutionPolicy Bypass -File `"$ChechaRoot\C11\C11_AUTOMATION\Checha-RunAll.ps1`""
$openCmd   = {
  # шукаємо VS Code / fallback Notepad
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
    "C:\Program Files\Microsoft VS Code\Code.exe",
    "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
  )
  $code = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  $panel = Join-Path $ChechaRoot 'C06_FOCUS\CONTROL_PANEL.md'
  $exe = $code; if(-not $exe){ $exe = "$env:WINDIR\System32\notepad.exe" }
  return "`"$exe`" `"$panel`""
}.Invoke()

# --- Switchboard ----------------------------------------------------------
switch ($PSCmdlet.ParameterSetName) {
  'Install' {
    # Базові перевірки
    if (-not (Test-Path $PwshExe))   { throw "Не знайдено pwsh.exe: $PwshExe" }
    if (-not (Test-Path $ChechaRoot)){ throw "Не знайдено CheChaRoot: $ChechaRoot" }

    Ensure-ContextItem -KeyPath $updateKey -Text 'CheCha: Update Panel' -CommandLine $updateCmd -Icon $IconPath
    Ensure-ContextItem -KeyPath $runAllKey -Text 'CheCha: RunAll (Full)' -CommandLine $runAllCmd -Icon $IconPath

    if ($IncludeOpenPanel) {
      Ensure-ContextItem -KeyPath $openKey   -Text 'CheCha: Open CONTROL_PANEL.md' -CommandLine $openCmd -Icon $IconPath
    }

    Write-Host "✅ Installed context items:"
    Get-ContextItem -KeyPath $updateKey
    Get-ContextItem -KeyPath $runAllKey
    if ($IncludeOpenPanel) { Get-ContextItem -KeyPath $openKey }
  }

  'Check' {
    Get-ContextItem -KeyPath $updateKey
    Get-ContextItem -KeyPath $runAllKey
    Get-ContextItem -KeyPath $openKey
  }

  'Remove' {
    Remove-ContextItem -KeyPath $updateKey
    Remove-ContextItem -KeyPath $runAllKey
    Remove-ContextItem -KeyPath $openKey
    Write-Host "✅ All CheCha context items removed (if they existed)."
  }
}
