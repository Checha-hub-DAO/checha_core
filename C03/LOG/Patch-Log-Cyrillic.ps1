[CmdletBinding()]param([string]$Path="C:\CHECHA_CORE\C03\LOG\LOG.md")
$bak="$Path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"; Copy-Item -LiteralPath $Path -Destination $bak -ErrorAction SilentlyContinue
$text=Get-Content -Raw -LiteralPath $Path
$replacements=@(
@{p='^\[2025-09-02 08:01:30\].*$';r='[2025-09-02 08:01:30] DAO-Forms Center v1.0 — додано Forms_Index.md, CHECKSUMS; ZIP у релізах; main синхронізовано.'},
@{p='^\[2025-09-02 08:13:05\].*$';r='[2025-09-02 08:13:05] DAO-Forms Center v1.0 — створено реліз (ETHNO-releases), контент синхронізовано з C12.'},
@{p='^\[2025-09-02 08:14:02\].*$';r='[2025-09-02 08:14:02] DAO-Forms Center v1.0 — реліз підтверджено (ETHNO-releases).'},
@{p='^2025-09-06 14:30:00 \[INFO \] G45\.1.*$';r='2025-09-06 14:30:00 [INFO ] G45.1 — АОТ v1.0 GitBook/Repo bundle archived; tag=g45-1-aot-v1.0; file=g45-1-aot_2025-09-06_build.zip'},
@{p='^2025-09-06 15:05:00 \[INFO \] G45\.1.*$';r='2025-09-06 15:05:00 [INFO ] G45.1 — АОТ v1.0 released; tag=g45-1-aot-v1.0; asset=g45-1-aot_2025-09-06_build.zip'},
@{p='^2025-09-06 16:05:00 \[INFO \] G45\.1.*$';r='2025-09-06 16:05:00 [INFO ] G45.1 — АОТ v1.1 released; tag=g45-1-aot-v1.1; asset=g45-1-aot_2025-09-06_build.zip'},
@{p='^2025-09-06 22:01:55 \[INFO \] G45\.1.*$';r='2025-09-06 22:01:55 [INFO ] G45.1 — AOT v1.1: LF нормалізовано; реліз детерміновано; перевірки OK.'}
)
foreach($r in $replacements){ $text=[regex]::Replace($text,$r.p,$r.r,'Multiline') }
Set-Content -LiteralPath $Path -Value $text -Encoding utf8
Write-Host "✅ LOG.md пропатчено. Бекап: $bak"
