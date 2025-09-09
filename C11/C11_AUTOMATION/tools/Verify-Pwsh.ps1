<# 
  Verify-Pwsh.ps1 — знаходить pwsh.exe, перевіряє підпис/версію/хеш.
  Опція -Adopt оновлює ярлик CheCha-Start.lnk та контекстні меню CheCha на знайдений pwsh.exe.
  Виклик:
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\Verify-Pwsh.ps1
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\Verify-Pwsh.ps1 -Adopt
#>
[CmdletBinding()]
param(
  [string]$Path,       # якщо знаєш точний шлях — передай тут
  [switch]$Adopt       # оновити ярлики/меню CheCha на цей pwsh.exe
)

$ErrorActionPreference = 'Stop'

function Find-Pwsh {
  param([string]$Hint)
  if ($Hint -and (Test-Path $Hint)) { return (Resolve-Path $Hint).Path }

  $found = (Get-Command pwsh.exe -ErrorAction SilentlyContinue)?.Source
  if ($found) { return $found }

  $candidates = @(
    "C:\Program Files\PowerShell\7\pwsh.exe",
    "C:\Program Files\PowerShell\7-preview\pwsh.exe",
    "$env:LOCALAPPDATA\Programs\PowerShell\7\pwsh.exe",
    "$env:LOCALAPPDATA\Microsoft\powershell\pwsh.exe"
  ) + (($env:PATH -split ';' | Where-Object { $_ }) | ForEach-Object { Join-Path $_ 'pwsh.exe' })
  return ($candidates | Where-Object { Test-Path $_ } | Select-Object -Unique -First 1)
}

function Verify-Pwsh {
  param([string]$Exe)
  if (-not (Test-Path $Exe)) { throw "Не знайдено pwsh.exe: $Exe" }

  $sig = Get-AuthenticodeSignature -FilePath $Exe
  $vi  = (Get-Item $Exe).VersionInfo
  $sha = Get-FileHash $Exe -Algorithm SHA256

  [PSCustomObject]@{
    Path            = $Exe
    SignatureStatus = $sig.Status
    Signer          = $sig.SignerCertificate.Subject
    ProductVersion  = $vi.ProductVersion
    FileVersion     = $vi.FileVersion
    CompanyName     = $vi.CompanyName
    SHA256          = $sha.Hash
  }
}

function Adopt-Pwsh {
  param([string]$Exe)
  # 1) Ярлик на робочому столі
  $desktop = [Environment]::GetFolderPath('Desktop')
  $lnkPath = Join-Path $desktop 'CheCha-Start.lnk'
  $ws  = New-Object -ComObject WScript.Shell
  $lnk = $ws.CreateShortcut($lnkPath)
  $lnk.TargetPath       = $Exe
  $lnk.Arguments        = '-NoProfile -ExecutionPolicy Bypass -File "C:\CHECHA_CORE\C11\C11_AUTOMATION\Checha-RunAll.ps1" -UpdatePanel'
  $lnk.WorkingDirectory = 'C:\CHECHA_CORE'
  if (Test-Path 'C:\CHECHA_CORE\C06_FOCUS\icons\checha_start.ico') { $lnk.IconLocation = 'C:\CHECHA_CORE\C06_FOCUS\icons\checha_start.ico' }
  $lnk.WindowStyle      = 1
  $lnk.Description      = 'CheCha — Точка входу'
  $lnk.Save()

  # 2) Контекстні меню (оновлюємо, якщо існують)
  $pairs = @(
    @{ Key='HKCU:\Software\Classes\Directory\Background\shell\CheCha_UpdatePanel\command';
       Cmd="`"$Exe`" -NoProfile -ExecutionPolicy Bypass -File `"C:\CHECHA_CORE\C11\C11_AUTOMATION\Checha-RunAll.ps1`" -UpdatePanel" },
    @{ Key='HKCU:\Software\Classes\Directory\Background\shell\CheCha_RunAllFull\command';
       Cmd="`"$Exe`" -NoProfile -ExecutionPolicy Bypass -File `"C:\CHECHA_CORE\C11\C11_AUTOMATION\Checha-RunAll.ps1`"" }
  )
  foreach ($p in $pairs) {
    if (Test-Path $p.Key) {
      New-Item -Path $p.Key -Force | Out-Null
      New-ItemProperty -Path $p.Key -Name '(default)' -Value $p.Cmd -PropertyType String -Force | Out-Null
    }
  }
  "✅ Оновлено ярлик і контекстні меню на: $Exe"
}

# --- main ---
$exe = Find-Pwsh -Hint $Path
if (-not $exe) { throw "pwsh.exe не знайдено. Вкажи шлях через -Path." }

$info = Verify-Pwsh -Exe $exe
$info | Format-List

if ($info.SignatureStatus -ne 'Valid' -or $info.Signer -notlike '*Microsoft Corporation*') {
  Write-Warning "Підпис не валідний або не від Microsoft — НЕ рекомендовано приймати."
  return
}

# dry-run
& $exe -NoProfile -Command '$PSVersionTable.PSVersion; "OK"' | Out-Null

if ($Adopt) { Adopt-Pwsh -Exe $exe }
