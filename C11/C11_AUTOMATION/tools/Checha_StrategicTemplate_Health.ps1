$ErrorActionPreference="Stop"
$iso   = (Get-Date).ToString("yyyy-MM-dd")
$year  = (Get-Date).ToString("yyyy")
$ymd   = (Get-Date).ToString("yyyyMMdd")
$path  = "C:\CHECHA_CORE\C12\Vault\StrategicReports\{0}\Strategic_Template_{1}.md" -f $year,$iso
$log   = "C:\CHECHA_CORE\C03\LOG\strategic_template_health.log"
$mark  = "C:\CHECHA_CORE\C03\LOG\.hc_{0}.ok" -f $ymd
$ps    = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$tool  = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Create-StrategicTemplate.ps1"

New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null

# обережна ротація логів (>512 КБ)
try {
  if (Test-Path $log -and (Get-Item $log).Length -gt 524288) {
    $last = Get-Content $log -Tail 400
    [IO.File]::WriteAllLines($log, $last, [Text.UTF8Encoding]::new($false))
  }
} catch {}

function W([string]$m){ Add-Content -Path $log -Value ("{0} [HEALTH] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m) -Encoding UTF8 }

if (-not (Test-Path $path)) {
  W ("file={0} exists=False -> run tool" -f $path)
  & $ps -NoProfile -ExecutionPolicy Bypass -File $tool -OpenWith none
  $ok = Test-Path $path
  W ("remediation_result exists={0}" -f $ok)
  New-Item -ItemType File -Force -Path $mark | Out-Null
  exit 0
}

if (-not (Test-Path $mark)) {
  W ("file={0} exists=True (first check today)" -f $path)
  New-Item -ItemType File -Force -Path $mark | Out-Null
}