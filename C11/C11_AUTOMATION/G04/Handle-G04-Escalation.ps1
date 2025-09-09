[CmdletBinding()]
param(
  [string]$Root = "C:\CHECHA_CORE",
  [string]$HealthScript = $null,            # Р±СѓРґРµ РІРёР·РЅР°С‡РµРЅРѕ Р°РІС‚РѕРјР°С‚РёС‡РЅРѕ (newв†’fallback), СЏРєС‰Рѕ РЅРµ Р·Р°РґР°РЅРѕ
  [int]$CooldownHours = 12,
  [string[]]$NotifyChannels = @(),          # РЅР°РїСЂ. @('Telegram') Р°Р±Рѕ @('Telegram','Email')
  [switch]$DryRun
)

# ---------------- Path resolver (newв†’fallback) ----------------
# РџС–РґС‚СЂРёРјРєР° РѕР±РѕС… СЂРѕР·РјС–С‰РµРЅСЊ: C11\C11_AUTOMATION\G04 (РЅРѕРІРµ) в†’ C11_AUTOMATION\G04 (fallback)
$AutoDirCandidates = @(
  [IO.Path]::Combine($Root,'C11','C11_AUTOMATION','G04'),
  [IO.Path]::Combine($Root,'C11_AUTOMATION','G04')
)
$AutomationDir = $AutoDirCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if(-not $AutomationDir){ $AutomationDir = $AutoDirCandidates[0] }

if(-not $HealthScript){
  $HealthScript = Join-Path $AutomationDir 'Invoke-G04-Health.ps1'
}

# Р¤Р°Р№Р» РЅРѕС‚РёС„С–РєР°С†С–Р№ (СЏРєС‰Рѕ РїРѕС‚СЂС–Р±РЅРѕ)
$NotifyScript = Join-Path $AutomationDir 'Notify-G04.ps1'

# ---------------- Helpers ----------------
function Ensure-Dir($p){ if(-not (Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Read-Json($p){
  if(Test-Path $p){
    try{ Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json } catch{ $null }
  } else { $null }
}

$DataDir   = Join-Path $Root 'C06_FOCUS\_data'
$TasksJson = Join-Path $DataDir 'g04_tasks.json'
$EscJson   = Join-Path $DataDir 'g04_escalations.json'
$Dash      = Join-Path $Root 'RHYTHM_DASHBOARD.md'
$Hist      = Join-Path $Root 'C03\LOG\G04_ESCALATION.log'

Ensure-Dir $DataDir
Ensure-Dir (Split-Path $Hist -Parent)

# ---------------- Load state ----------------
$tasks = Read-Json $TasksJson; if(-not $tasks){ $tasks = @{ critical_48h=@(); urgent_7d=@(); planned_30d=@() } }
$esc   = Read-Json $EscJson;   if(-not $esc){   $esc   = @{ items=@() } }

# ---------------- Run health-check ----------------
if(-not (Test-Path $HealthScript)){
  Write-Warning "Health script not found: $HealthScript"
  $healthOutput = @('[FAIL] Health script missing')
  $exit = 1
} else {
  $healthOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $HealthScript *>&1
  $exit = $LASTEXITCODE
}

$ts    = Get-Date
$tsStr = $ts.ToString('yyyy-MM-dd HH:mm:ss')

if($exit -eq 0){
  $line = "[$tsStr] G04 health OK"
  if(-not $DryRun){ Add-Content -Encoding UTF8 -Path $Dash -Value $line; Add-Content -Encoding UTF8 -Path $Hist -Value $line }
  Write-Host "OK"; exit 0
}

# ---------------- Parse FAIL reasons ----------------
$failLines = $healthOutput | Where-Object { $_ -match '^\[FAIL\]|HEALTH FAIL|JSON parse error|Missing' } | Select-Object -First 3
$reason = if($failLines){ ($failLines -join ' | ') } else { 'Unknown failure' }

# ---------------- Cooldown (Р°РЅС‚РёРґСѓР±Р»СЊ) ----------------
function WithinCooldown($item){
  try{ $t=[datetime]::Parse($item.ts) } catch { return $false }
  return (($ts - $t).TotalHours -lt $CooldownHours -and $item.reason -eq $reason)
}
$dupe = $esc.items | Where-Object { WithinCooldown $_ } | Select-Object -First 1
if($dupe){
  $line = "[$tsStr] G04 health FAIL; SKIP escalate (cooldown); Reason=$reason"
  if(-not $DryRun){ Add-Content -Path $Dash -Encoding UTF8 -Value $line; Add-Content -Path $Hist -Encoding UTF8 -Value $line }
  Write-Warning "Cooldown active"; exit 2
}

# ---------------- Build new critical task ID ----------------
$today  = $ts.ToString('yyyyMMdd')
$prefix = "G04-T-$today-C"
$existingToday = @(); foreach($t in $tasks.critical_48h){ if($t.id -match "^$prefix(?:-(\d+))?$"){ $existingToday += $t } }
$next = 1; $max=0
foreach($t in $existingToday){ if($t.id -match "^$prefix-(\d+)$"){ $n=[int]$Matches[1]; if($n -gt $max){ $max=$n } } }
if($max -gt 0){ $next = $max + 1 }
$id = if($next -eq 1 -and -not ($tasks.critical_48h | Where-Object { $_.id -eq $prefix })) { $prefix } else { "$prefix-$('{0:D2}' -f $next)" }

$eta = ($ts.AddHours(24)).ToString('s') + '+03:00'
$newTask = @{
  id=$id; title='Р•СЃРєР°Р»Р°С†С–СЏ: РІРёРїСЂР°РІРёС‚Рё РїРѕРјРёР»РєРё Р· health-check G04';
  owner='OnвЂ‘duty'; eta=$eta; status='Pending'; notes=$reason
}

# ---------------- Prepend task & persist ----------------
$tasks.critical_48h = @($newTask) + @($tasks.critical_48h) | Select-Object -First 10

if(-not $DryRun){
  $tasks | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $TasksJson
  $esc.items = @(@{ id=$id; ts=$ts.ToString('s'); reason=$reason; cooldown_h=$CooldownHours }) + @($esc.items) | Select-Object -First 50
  $esc | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $EscJson
  $line = "[$tsStr] G04 health FAIL; Task=$id; Reason=$reason"
  Add-Content -Encoding UTF8 -Path $Dash -Value $line
  Add-Content -Encoding UTF8 -Path $Hist -Value $line
}

# ---------------- Optional notifications ----------------
if($NotifyChannels -and (Test-Path $NotifyScript)){
  . $NotifyScript
  try{
    $ttl = "[G04] HEALTH FAIL вЂ” $id"
    $txt = "РџСЂРёС‡РёРЅР°: $reason`nETA: $eta`nOwner: On-duty"
    Send-G04Notification -title $ttl -text $txt -channels $NotifyChannels
  } catch { Write-Warning "Notify failed: $_" }
} elseif($NotifyChannels -and -not (Test-Path $NotifyScript)){
  Write-Warning "Notify script not found: $NotifyScript"
}

Write-Host "Escalated: $id"; exit 1
