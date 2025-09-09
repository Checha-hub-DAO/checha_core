$script:Root = "C:\CHECHA_CORE"

function Write-TechLog {
  param([string]$File,[string]$Message,[ValidateSet('INFO','WARN','ERR')]$Level='INFO')
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  $line = "$ts [$Level] $Message"
  $path = Join-Path $script:Root "C03\LOG\$File"
  Add-Content -Path $path -Value $line -Encoding UTF8
}

function Ensure-Paths {
  param([string[]]$Paths)
  foreach ($p in $Paths) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Export-TaskXml {
  param([string[]]$TaskNames)
  $bk = Join-Path $script:Root "C11\Backups"
  foreach ($t in $TaskNames) {
    try { schtasks /Query /TN $t /XML > (Join-Path $bk "$t.xml") 2>$null } catch {}
  }
}

Export-ModuleMember -Function Write-TechLog,Ensure-Paths,Export-TaskXml
