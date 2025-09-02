# Save SOP.md у реальний репозиторій і запушити
$ErrorActionPreference='Stop'
$repoPath = "C:\Users\serge\Projects\checha_core"   # ← твій реальний репо
if (!(Test-Path "$repoPath\.git")) { throw "Це не git-репозиторій: $repoPath" }

$sopPath = Join-Path $repoPath 'dao-gallery\SOP.md'
New-Item -ItemType Directory -Force -Path (Split-Path $sopPath) | Out-Null

# Спробує взяти SOP з буфера; якщо буфер порожній — відкриє Notepad, щоб вставив вручну
try { $clip = Get-Clipboard -Raw -EA SilentlyContinue } catch { $clip = $null }
if ([string]::IsNullOrWhiteSpace($clip) -or $clip.Length -lt 50) {
  if (!(Test-Path $sopPath)) { Set-Content -Path $sopPath -Value "# DAO-Gallery — SOP`r`n(Встав сюди текст із канвасу й збережи)" -Encoding UTF8 }
  Start-Process notepad $sopPath
  Read-Host 'Встав SOP у Notepad, натисни Ctrl+S, закрий Notepad і потім Enter тут'
} else {
  Set-Content -Path $sopPath -Value $clip -Encoding UTF8
}

Push-Location $repoPath
git status
git add "dao-gallery\SOP.md"
git commit -m "DAO-Gallery: add/update one-page SOP"
git push
Pop-Location

"`n✅ SOP.md зафіксовано й запушено: $sopPath"

--- 
## 10) Функція PowerShell Update-GalleryGitBook (packs + changelog + git)
(Встав тут код із мого повідомлення вище — від `powershell до кінця, з прикладами)
