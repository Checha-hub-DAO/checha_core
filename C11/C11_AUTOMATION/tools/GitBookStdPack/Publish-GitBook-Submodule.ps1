[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)] [string]$Root,
  [Parameter(Mandatory=$true)] [string]$ExpectedSlug,
  [string[]]$ForbiddenTerms,
  [string]$RepoRoot = "C:\CHECHA_CORE\GitBook",
  [string]$CommitMsg = "GitBook: update content + bump page_version",
  [string[]]$BumpFiles = @("readme.md","manifest.md"),
  [string]$ValidatorPath = "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\GitBookStdPack\Validate-GitBook-Submodule.ps1"
)

$ErrorActionPreference = "Stop"

function Invoke-Validator {
  param([string]$root,[string]$slug,[string[]]$terms)
  $args = @('-NoProfile','-File', $ValidatorPath, '-Root', $root, '-ExpectedSlug', $slug)
  if ($PSBoundParameters.ContainsKey('terms') -and $terms -and $terms.Count -gt 0) {
    $args += @('-ForbiddenTerms') + $terms
  }
  pwsh @args
}

# 1) Validate before
Invoke-Validator -root $Root -slug $ExpectedSlug -terms $ForbiddenTerms

# 2) Bump versions
$ts = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") + "+03:00"
foreach($f in $BumpFiles){
  $p = Join-Path $Root $f
  $c = Get-Content $p -Raw
  if($c -match 'page_version:\s*"(\\d+)\\.(\\d+)\\.(\\d+)"'){
    $maj=$matches[1]; $min=$matches[2]; $pat=[int]$matches[3]+1
    $c = $c -replace 'page_version:\s*"\d+\.\d+\.\d+"', "page_version: `"$maj.$min.$pat`""
  }
  $c = $c -replace 'last_updated:\s*".+?"', "last_updated: `"$ts`""
  Set-Content $p $c -Encoding UTF8
}

# 3) Validate after
Invoke-Validator -root $Root -slug $ExpectedSlug -terms $ForbiddenTerms

# 4) Git publish if repo exists
if (Test-Path (Join-Path $RepoRoot ".git")) {
  Push-Location $RepoRoot
  if (-not (git remote -v)) {
    Write-Host "✖ No git remote configured. Run: git remote add origin <URL> && git push -u origin main"
    Pop-Location
    exit 2
  }
  Push-Location $RepoRoot
  git add --all
  git commit -m $CommitMsg
  git push
  Pop-Location
  Write-Host "✔ Опубліковано через git."
} else {
  Write-Host "⚠ Репозиторій git не знайдено у $RepoRoot — пропускаю пуш. Опублікуй вручну у веб-редакторі."
}

