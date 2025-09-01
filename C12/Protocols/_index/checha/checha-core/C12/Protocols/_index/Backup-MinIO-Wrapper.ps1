param(
  [string]$Alias  = 'checha',
  [string]$Bucket = 'checha-core',
  [string]$Prefix = 'C12/Protocols',
  [string[]]$Exclude = @(
    '_index/*','*/_index/*',
    '.git/*','*/.git/*',
    '.github/*','*/.github/*',
    '.vscode/*','*/.vscode/*',
    'checha/*','*/checha/*',
    'checha-core/*','*/checha-core/*',
    '**/logs/*','*.log','*.tmp','*.bak','desktop.ini','Thumbs.db'
  )
)
$ErrorActionPreference = 'Stop'

$Src = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Env:MC_CONFIG_DIR = 'C:\CHECHA_CORE\.mc'

function Invoke-Mc([string[]]$Args){
  $mc = Get-Command mc -ErrorAction SilentlyContinue
  if ($mc) {
    $p = Start-Process -FilePath $mc.Source -ArgumentList $Args -NoNewWindow -PassThru -Wait
    if ($p.ExitCode -ne 0){ throw "mc exited $($p.ExitCode): $($Args -join ' ')" }
    return
  }
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if ($docker){
    $args2 = @(
      'run','--rm','--network','checha_core_default',
      '-v', (Join-Path 'C:\CHECHA_CORE' '.mc') + ':/root/.mc',
      '-v', ('{0}:/repo' -f $Src),
      'minio/mc'
    ) + $Args
    $p = Start-Process -FilePath $docker.Source -ArgumentList $args2 -NoNewWindow -PassThru -Wait
    if ($p.ExitCode -ne 0){ throw "docker/mc exited $($p.ExitCode): $($args2 -join ' ')" }
    return
  }
  throw "Neither 'mc' nor 'docker' found to run MinIO client."
}

$TargetRoot = '{0}/{1}' -f $Alias,$Bucket
$Target     = '{0}/{1}' -f $TargetRoot,$Prefix

Invoke-Mc @('mb','--ignore-existing', $TargetRoot)

$mirror = @('mirror','--overwrite','--remove')
foreach($pat in $Exclude){ $mirror += @('--exclude', $pat) }
$mirror += @($Src, $Target)

Invoke-Mc $mirror
Write-Host "Mirror OK -> $Target"
