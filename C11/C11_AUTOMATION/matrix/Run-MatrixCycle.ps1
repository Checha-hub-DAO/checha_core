[CmdletBinding()]
param(
  [string]$ConfigPath = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\checha_matrix_config.json",
  [switch]$MakeReport
)

Write-Host "=== 🚀 Run-MatrixCycle.ps1 start ===" -ForegroundColor Cyan

# -------------------------
# PREFLIGHT: самодіагностика
# -------------------------
$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$utf8BOM = New-Object System.Text.UTF8Encoding($true)

# каталоги
$needDirs = @(
  $cfg.Feeds.Dir,
  (Split-Path $cfg.G04.TasksJson),
  $cfg.C12.VaultRoot,
  $cfg.C12.StrategicReportsRoot,
  $cfg.C12.IndexDir
)
foreach($d in $needDirs){
  if(-not (Test-Path $d)){
    New-Item -ItemType Directory -Path $d | Out-Null
    Write-Host "📂 Створено папку: $d" -ForegroundColor Yellow
  }
}

# seed tasks.json
if(-not (Test-Path $cfg.G04.TasksJson)){
  $seed = @{
    updated = (Get-Date).ToString("s")
    critical_48h = @(@{ id="G04-1"; title="Підтвердити реліз C12 Docs"; owner="core";  due=(Get-Date).AddDays(2).ToString("yyyy-MM-dd"); link="" })
    urgent_7d    = @(@{ id="G04-2"; title="Наповнити галереї ETHNO";     owner="media"; due=(Get-Date).AddDays(5).ToString("yyyy-MM-dd"); link="" })
    planned_30d  = @(@{ id="G04-3"; title="Автоматизувати CHECKSUMS у C12"; owner="auto";  due=(Get-Date).AddDays(25).ToString("yyyy-MM-dd"); link="" })
  } | ConvertTo-Json -Depth 6
  [IO.File]::WriteAllText($cfg.G04.TasksJson, $seed, $utf8BOM)
  Write-Host "⚙️  Seed tasks.json створено" -ForegroundColor Yellow
}

# feed-и: автостворення якщо відсутні
$expG04 = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\Export-G04Feed.ps1"
$expC12 = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\Export-C12Feed.ps1"

if(-not (Test-Path $cfg.Feeds.G04Feed) -and (Test-Path $expG04)){
  Write-Host "🔄 Генерую G04 feed…" -ForegroundColor Yellow
  & $expG04 -ConfigPath $ConfigPath
}
if(-not (Test-Path $cfg.Feeds.C12Feed) -and (Test-Path $expC12)){
  Write-Host "🔄 Генерую C12 feed…" -ForegroundColor Yellow
  & $expC12 -ConfigPath $ConfigPath
}

# -------------------------
# ОСНОВНИЙ ЦИКЛ
# -------------------------
& $expG04 -ConfigPath $ConfigPath
& $expC12 -ConfigPath $ConfigPath

if($MakeReport){
  & "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\New-G44StrategicReport.ps1" -ConfigPath $ConfigPath
  & "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\New-StrategicChecksums.ps1" -ConfigPath $ConfigPath
  & "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\Publish-WeeklyRelease.ps1" -ConfigPath $ConfigPath
}

$upd = "C:\CHECHA_CORE\C11\C11_AUTOMATION\matrix\Update-MatrixDashboard.ps1"
if(Test-Path $upd){
  & $upd -ConfigPath $ConfigPath
}else{
  Write-Warning "Matrix dashboard script not found: $upd"
}

# -------------------------
# POSTFLIGHT: підсумкова перевірка
# -------------------------
$ok = (Test-Path $cfg.Feeds.G04Feed) -and (Test-Path $cfg.Feeds.C12Feed) -and (Test-Path (Join-Path $cfg.C12.VaultRoot "Matrix.md"))
if($ok){
  Write-Host "✅ MATRIX OK — feeds + dashboard готові" -ForegroundColor Green
}else{
  Write-Warning "⚠️ MATRIX WARN — перевір feeds/dashboard"
}

Write-Host "=== ✅ Run-MatrixCycle.ps1 complete ===" -ForegroundColor Cyan
