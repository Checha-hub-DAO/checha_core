function Invoke-Mc {
  [CmdletBinding()]
  param(
    [string[]]$Args,
    [int]$TimeoutSec = 600,
    [switch]$UseDocker,
    [string]$DockerNetwork = 'checha_core_default',
    [string]$Repo = 'C:\CHECHA_CORE\C12\Protocols',
    [string]$McExe = 'C:\CHECHA_CORE\tools\mc.exe'
  )
  $ErrorActionPreference = 'Stop'
  if (-not (Test-Path $Repo))  { throw "Repo not found: $Repo" }
  if (-not (Test-Path $McExe)) { $McExe = 'mc' }

  if ($UseDocker) {
    # ГОЛОВНЕ ВИПРАВЛЕННЯ: ${Repo} замість $Repo
    $argList = @(
      'run','--rm',
      '--network', $DockerNetwork,
      '-v','C:\CHECHA_CORE\.mc:/root/.mc',
      '-v',"${Repo}:/repo",
      'minio/mc'
    ) + $Args
    $proc = Start-Process -FilePath 'docker' -ArgumentList $argList -NoNewWindow -PassThru
  } else {
    $proc = Start-Process -FilePath $McExe -ArgumentList $Args -NoNewWindow -PassThru
  }

  if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
    try { Stop-Process -Id $proc.Id -Force } catch {}
    throw "Timeout ($TimeoutSec s): mc $($Args -join ' ')"
  }
  if ($proc.ExitCode -ne 0) {
    throw "mc exited with code $($proc.ExitCode): $($Args -join ' ')"
  }
}
