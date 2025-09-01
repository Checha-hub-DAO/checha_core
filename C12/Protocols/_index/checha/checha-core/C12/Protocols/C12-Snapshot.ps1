Param(
    [string]$Source = "C:\CHECHA_CORE\C12",
    [string]$ArchiveRoot = "C:\CHECHA_CORE\C05_ARCHIVE\C12_SNAPSHOTS"
)
if (-not (Test-Path $ArchiveRoot)) { New-Item -ItemType Directory -Path $ArchiveRoot | Out-Null }
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$zip = Join-Path $ArchiveRoot ("CHECHA_CORE_PUSH_{0}.zip" -f $ts)
$sha = "$zip.sha256"

# Create archive
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $Source '*') -DestinationPath $zip -Force

# SHA-256
$hash = Get-FileHash -Path $zip -Algorithm SHA256
"{}  {}".format($hash.Hash, (Split-Path $zip -Leaf)) | Out-File -FilePath $sha -Encoding ASCII

Write-Host "Snapshot created:" -ForegroundColor Green
Write-Host "  $zip"
Write-Host "  $sha"
# С.Ч.

# SIG # Begin signature block
# MIIFsAYJKoZIhvcNAQcCoIIFoTCCBZ0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCbL4c6P8j1Jlf3
# RIgs7pJKyE0dMHqsYcy+Xy8XQA6Q3KCCAxwwggMYMIICAKADAgECAhAhdawdEC1f
# vku/EXEkG9WEMA0GCSqGSIb3DQEBCwUAMCQxIjAgBgNVBAMMGUNIRUNIQSBMb2Nh
# bCBDb2RlIFNpZ25pbmcwHhcNMjUwODMwMjAxODQ2WhcNMjYwODMwMjAzODQ2WjAk
# MSIwIAYDVQQDDBlDSEVDSEEgTG9jYWwgQ29kZSBTaWduaW5nMIIBIjANBgkqhkiG
# 9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0pGLIHhBZysYfPhwY8SqLrwcP7oVLMVjVMog
# dsO50OdnhxYvZgU9/jHdDUAzZUa0VllXdHjdrrtkl6r98cZbv3ryDzwEcObiSAq+
# ABaSixBhCKJ1JE/pJ0Q8RA9RZlt/BCxKQoywWK/AhzBruJwXXgKdgDHdyx3zoosV
# K6MO0tasdfGrDFT0c4McLKfHPNhZey4GwVY954dHTz2MsE3EtuXLORiUUW2CZx74
# 78GEFyYa3ixxzTP9+ykGhqxUeUE+8uciaJzKg5QpHfLxYFd8w06Ikb4+VdPx9QQd
# om+z8ibwkWM5Akb+5eiiw1TeKErWEuHDn5N4SfigfvvKT8B7ZQIDAQABo0YwRDAO
# BgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFGYo
# O6eq0W3Y/Ye6WqsxtBN1ETWeMA0GCSqGSIb3DQEBCwUAA4IBAQAaEEBK9CG8Gwbn
# z224pxzHGpw6FgOT0LKFWwk9n4aTIGfsdP1xK1ohLH38DCjTfCuI4gLD5xZ3s3ZI
# wILvd/k08k57yIIeRF4cTDcNyiCb8fdtFwZabbeBAAs05VkFLutoNU4pbezuUWW4
# ovh4/Im0YrhuXrCwgPSryZgDW5/6BHuhhE8BAucONULJt38u7NrXZPnjfTFtM32k
# IKSgJ6IHfpGUPkVt8sKvADkaxV1nlgtX6uPcI/cnHoS8qKcMfz+U2HCDvS4mLiiG
# XRfScyKu6XPAhd2seoCogA1v3z8Rx1ITXgVTWV2VC7vDqy6Oj9k3OPAFW3ztWcJ9
# 5G3s4I4JMYIB6jCCAeYCAQEwODAkMSIwIAYDVQQDDBlDSEVDSEEgTG9jYWwgQ29k
# ZSBTaWduaW5nAhAhdawdEC1fvku/EXEkG9WEMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# ILpfwhlt/L7GsE01GfPy8ovySotm08FQXCGeSJy6DuP3MA0GCSqGSIb3DQEBAQUA
# BIIBADdgFfVYtQ6AhPQHSB4j4GB8/DgzVWuM9hmeaVbxtGr9VMKq9biFtG45JeLr
# gEfmAx8pYKrCowKai9QfXwb/V6/pX8Ab9UQeP0eKNajvPgKlB1aq3dLYNoZ0jKfx
# df2FdLbaeCGRUcGTN6EJZM+SZmT9bD4xqV4RFr0P+azJ7IcdEByQtcU+dRF0UITf
# 5pe41tGTjQ3ZZKifGdBo3nmvnT9Lv07XZQoZbaLLkwgsyj24x/XFhvFB8szZZGQb
# Epde65Y9UimiIsP4i1fyy62oY+kRrWuNyfxXdvn+QFKSFRaA5sphzykPX76jbVmj
# xGa/XHSRqc0tWi8eQYTSljK9FSw=
# SIG # End signature block
