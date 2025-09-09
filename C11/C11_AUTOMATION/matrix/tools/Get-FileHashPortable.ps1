param(
  [Parameter(Mandatory)][string]$Path,
  [ValidateSet('SHA256','SHA1','MD5')][string]$Algorithm = 'SHA256'
)
$stream = [System.IO.File]::OpenRead($Path)
try {
  switch ($Algorithm) {
    'SHA256' { $hasher = [System.Security.Cryptography.SHA256]::Create() }
    'SHA1'   { $hasher = [System.Security.Cryptography.SHA1]::Create() }
    'MD5'    { $hasher = [System.Security.Cryptography.MD5]::Create() }
  }
  $hashBytes = $hasher.ComputeHash($stream)
  ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
}
finally { $stream.Dispose() }
