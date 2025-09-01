# --- C12-Unify weekly wrapper (CheCha) ---
$Root      = "C:\CHECHA_CORE\C12"
$Script    = Join-Path $Root "C12-Unify.ps1"
$LogDir    = Join-Path (Split-Path $Root -Parent) "C03\LOG"
$Stamp     = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile   = Join-Path $LogDir ("C12_Unify_Task_{0}.log" -f $Stamp)

# гарантуємо наявність лог-директорії
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }

Start-Transcript -Path $LogFile -Force | Out-Null
Write-Host ("[START] {0}" -f (Get-Date))

# основний виклик
& pwsh -NoProfile -ExecutionPolicy Bypass -File $Script `
  -Apply -FixNested -Categorize -CreateReadme -Report -HashArchive -Confirm:$false

$code = $LASTEXITCODE
Write-Host ("[END] ExitCode={0} {1}" -f $code, (Get-Date))
Stop-Transcript | Out-Null

exit $code
