# --- C12-Unify weekly wrapper (SYSTEM-safe v2.1) ---
$Root   = "C:\CHECHA_CORE\C12"
$Script = Join-Path $Root "C12-Unify.ps1"

# 1) pwsh РїС–Рґ SYSTEM: Р¶РѕСЂСЃС‚РєРёР№ С€Р»СЏС… + fallback
$Pwsh = $null
try { $Pwsh = (Get-Command "C:\Program Files\PowerShell\7\pwsh.exe" -ErrorAction Stop).Source } catch {}
if (-not $Pwsh) { try { $Pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source } catch {} }
if (-not $Pwsh) { $Pwsh = (Get-Command powershell.exe -ErrorAction Stop).Source }

# 2) Р›РѕРіРё
$LogDir  = Join-Path (Split-Path $Root -Parent) "C03\LOG"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
$Stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir ("C12_Unify_Task_{0}.log" -f $Stamp)
$OutFile = Join-Path $LogDir ("C12_Unify_Task_{0}.out.log" -f $Stamp)
$ErrFile = Join-Path $LogDir ("C12_Unify_Task_{0}.err.log" -f $Stamp)

Start-Transcript -Path $LogFile -Force | Out-Null
Write-Host ("[START] {0}" -f (Get-Date))
Write-Host ("[i] Using engine: {0}" -f $Pwsh)
Write-Host ("[i] Script: {0}" -f $Script)

# 3) РђСЂРіСѓРјРµРЅС‚Рё (РїРѕРєРё Р‘Р•Р— -CreateReadme, С‰РѕР± РІРёРєР»СЋС‡РёС‚Рё Р»СЋРґСЃСЊРєРёР№ С„Р°РєС‚РѕСЂ)
$args = @(
  "-NoProfile","-ExecutionPolicy","Bypass",
  "-File","`"$Script`"",
  "-Apply","-FixNested","-Categorize","-Report","-HashArchive"
)

# 4) Р—Р°РїСѓСЃРє Р· СЂРµРґРёСЂРµРєС‚РѕРј РІРёРІРѕРґСѓ
$proc = Start-Process -FilePath $Pwsh -ArgumentList $args -PassThru -Wait -WindowStyle Hidden `
         -RedirectStandardOutput $OutFile -RedirectStandardError $ErrFile
$code = if ($null -eq $proc) { -1 } else { $proc.ExitCode }
Write-Host ("[END] ExitCode={0} {1}" -f $code, (Get-Date))
Stop-Transcript | Out-Null
exit $code
