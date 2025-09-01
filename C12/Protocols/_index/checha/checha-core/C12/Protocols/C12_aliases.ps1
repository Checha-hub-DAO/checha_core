# C12 aliases — add to your PowerShell profile or dot-source manually
function c12nav { Invoke-Item 'C:\CHECHA_CORE\C12\NAV\C12_NAV.md' }
function c12diff {
  pwsh -NoProfile -ExecutionPolicy Bypass -File 'C:\CHECHA_CORE\C12\Protocols\C12-Reindex-And-Diff.ps1' `
    -Bucket 'checha' `
    -Prefix 'checha/checha-core/C12/Protocols' `
    -Local  'C:\CHECHA_CORE\C12\Protocols'
}
function c12snap {
  pwsh -NoProfile -ExecutionPolicy Bypass -File 'C:\CHECHA_CORE\C12\Protocols\C12-Snapshot.ps1' `
    -Source 'C:\CHECHA_CORE\C12' `
    -ArchiveRoot 'C:\CHECHA_CORE\C05_ARCHIVE\C12_SNAPSHOTS'
}
# Usage: c12nav; c12diff; c12snap
# С.Ч.
