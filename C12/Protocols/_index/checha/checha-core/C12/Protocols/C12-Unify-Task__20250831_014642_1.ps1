# --- C12-Unify weekly wrapper (v2.7: timeout + non-interactive) ---
$Root    = "C:\CHECHA_CORE\C12"
$Script  = Join-Path $Root "C12-Unify.ps1"
$Pwsh7   = "C:\Program Files\PowerShell\7\pwsh.exe"
$WinPS51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$TimeoutSec = 600  # 10 С…РІРёР»РёРЅ; Р·РјС–РЅСЋР№ Р·Р° РїРѕС‚СЂРµР±Рё

# Р›РѕРіРё
$LogDir  = Join-Path (Split-Path $Root -Parent) "C03\LOG"
if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
$Stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir ("C12_Unify_Task_{0}.log" -f $Stamp)
$OutFile = Join-Path $LogDir ("C12_Unify_Task_{0}.out.log" -f $Stamp)
$ErrFile = Join-Path $LogDir ("C12_Unify_Task_{0}.err.log" -f $Stamp)

Start-Transcript -Path $LogFile -Force | Out-Null
Write-Host ("[START] {0}" -f (Get-Date))
Write-Host ("[i] Pwsh7 : {0}" -f $Pwsh7)
Write-Host ("[i] WinPS5: {0}" -f $WinPS51)
Write-Host ("[i] Script: {0}" -f $Script)

# Preflight
$exists = Test-Path -LiteralPath $Script
Write-Host ("[i] Test-Path Script = {0}" -f $exists)
if (-not $exists) {
  Write-Host "[!] Script not found. Listing ${Root}:"
  if (Test-Path -LiteralPath $Root) { Get-ChildItem -LiteralPath $Root | ForEach-Object { Write-Host (" - " + $_.FullName) } }
}

# РћРґРёРЅ СЂСЏРґРѕРє Р°СЂРіСѓРјРµРЅС‚С–РІ (-NonInteractive РґРѕРґР°РЅРѕ)
$argString = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $Script + '" -Apply -FixNested -Categorize -CreateReadme -Report -HashArchive'
Write-Host ("[i] Args: {0}" -f $argString)

function Invoke-Proc([string]$exe, [string]$args){
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName               = $exe
  $psi.Arguments              = $args
  $psi.WorkingDirectory       = $Root
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false
  $psi.CreateNoWindow         = $true

  $p = [System.Diagnostics.Process]::new()
  $p.StartInfo = $psi
  [void]$p.Start()

  # РѕС‡С–РєСѓС”РјРѕ Р· С‚Р°Р№РјР°СѓС‚РѕРј
  if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    Write-Host ("[!] TIMEOUT {0}s вЂ” killing process PID={1}" -f $TimeoutSec, $p.Id)
    try { $p.Kill($true) } catch {}
    $p.WaitForExit()
    $exit = 124  # СѓРјРѕРІРЅРёР№ РєРѕРґ "timeout"
  } else {
    $exit = $p.ExitCode
  }

  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  return $exit, $out, $err
}

# 1) РџСЂРѕР±СѓС”РјРѕ pwsh 7
$exit,$outTxt,$errTxt = Invoke-Proc -exe $Pwsh7 -args $argString

# 2) РЇРєС‰Рѕ РЅРµ РѕРє вЂ” WinPS 5.1
if ($exit -ne 0 -and $exit -ne 124 -and $errTxt -match "not recognized|РЅРµ СЂР°СЃРїРѕР·РЅР°РЅ|РЅРµ СЂРѕР·РїС–Р·РЅР°РЅРѕ|The argument .* is not recognized") {
  Write-Host "[!] pwsh7 complained; trying Windows PowerShell 5.1вЂ¦"
  $exit,$out2,$err2 = Invoke-Proc -exe $WinPS51 -args $argString
  $outTxt += $out2
  $errTxt += $err2
}

[IO.File]::WriteAllText($OutFile, $outTxt)
[IO.File]::WriteAllText($ErrFile, $errTxt)

Write-Host ("[END] ExitCode={0} {1}" -f $exit, (Get-Date))
Stop-Transcript | Out-Null
exit $exit
