# C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Publish-GitBook-G45AOT.ps1
[CmdletBinding()]
param(
  [string]$Root   = "C:\CHECHA_CORE\GitBook\dao-g\dao-g-mods\g45-kod-zakhystu\g45-1-aot",
  [string]$Repo   = "C:\CHECHA_CORE\GitBook",   # корінь git-репозиторію GitBook
  [string]$Msg    = "G45.1 AOT: update content + bump page_version"
)

$ErrorActionPreference = "Stop"
$ts = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") + "+03:00"
$files = "readme.md","manifest.md" | ForEach-Object { Join-Path $Root $_ }

# 1) Валідатор перед публікацією
pwsh -NoProfile -File "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Validate-GitBook-G45.ps1" -Root $Root

# 2) Оновити last_updated і підняти page_version (патч)
foreach($p in $files){
  $c = Get-Content $p -Raw
  if($c -match 'page_version:\s*"(\\d+)\\.(\\d+)\\.(\\d+)"'){
    $maj=$matches[1]; $min=$matches[2]; $pat=[int]$matches[3]+1
    $c = $c -replace 'page_version:\s*"\d+\.\d+\.\d+"', "page_version: `"$maj.$min.$pat`""
  }
  $c = $c -replace 'last_updated:\s*".+?"', "last_updated: `"$ts`""
  Set-Content $p $c -Encoding UTF8
}

# 3) Валідатор після правок (щоб точно зелено)
pwsh -NoProfile -File "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Validate-GitBook-G45.ps1" -Root $Root

# 4) Публікація (git)
if (Test-Path (Join-Path $Repo ".git")) {
  Push-Location $Repo
  git add --all
  git commit -m $Msg
  git push
  Pop-Location
  "✔ Опубліковано через git."
} else {
  "⚠ Репозиторій git не знайдено у $Repo — пропусти крок git та опублікуй у веб-редакторі."
}
