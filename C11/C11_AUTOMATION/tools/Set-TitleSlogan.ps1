<# 
Set-TitleSlogan.ps1 — CheCha Branding Updater
Призначення:
  • Оновлює "title" і "description" (сліоган) у Markdown (з/без YAML) та JSON.
  • Режим -YamlOnly: змінює ТІЛЬКИ YAML (контент не чіпає). Для README.md застосовується автоматично.
  • Опційний git commit/push.

Приклад:
  pwsh -NoProfile -File .\Set-TitleSlogan.ps1 -Title "CheCha Vault" -Slogan "Швидко. Чітко. Щодня." `
    -Targets @("C:\CHECHA_CORE\C12\Vault\_index.md","C:\CHECHA_CORE\C12\Vault\README.md") `
    -YamlOnly -GitCommit -UpdateGitHub -GitCommitMessage "chore(vault): update title & slogan (yaml-only)"
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory)][string]$Title,
  [Parameter(Mandatory)][string]$Slogan,

  [string[]]$Targets = @(
    "C:\CHECHA_CORE\C12\Vault\_index.md",
    "C:\CHECHA_CORE\C12\Vault\README.md",
    "C:\CHECHA_CORE\GitBook\README.md"
  ),

  [string]$RepoPath = "C:\CHECHA_CORE",
  [switch]$GitCommit,
  [switch]$UpdateGitHub,
  [string]$GitCommitMessage = "chore: set title & slogan",
  [switch]$YamlOnly
)

$ErrorActionPreference = 'Stop'

function Write-Info($msg){ Write-Host ("{0} [INFO ] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -ForegroundColor Cyan }
function Write-Ok  ($msg){ Write-Host ("{0} [ OK  ] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -ForegroundColor Green }
function Write-Warn($msg){ Write-Host ("{0} [WARN ] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -ForegroundColor Yellow }
function Write-Err ($msg){ Write-Host ("{0} [ERR  ] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -ForegroundColor Red }

function Ensure-Utf8Bom([string]$Path,[string]$Content){
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Escape-Yaml([string]$s){
  if($null -eq $s){ return '' }
  return ($s -replace '"','\"')
}

# Якщо Targets помилково передано одним рядком із комами — розділити
if ($Targets.Count -eq 1 -and $Targets[0] -match ',') {
  $Targets = $Targets[0].Split(',') | ForEach-Object { $_.Trim() }
}

function Update-Md([string]$Path,[string]$Title,[string]$Slogan){
  if(-not (Test-Path $Path)){ Write-Warn "Skip (no file): $Path"; return $false }
  $orig = Get-Content -Raw -LiteralPath $Path
  $changed = $false

  $yamlPattern = '^(?<pre>\s*---\r?\n)(?<yaml>.*?)(\r?\n)---\s*\r?\n(?<rest>[\s\S]*)$'
  $hasYaml = [regex]::IsMatch($orig, $yamlPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

  if($hasYaml){
    $m    = [regex]::Match($orig, $yamlPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $yaml = $m.Groups['yaml'].Value
    $rest = $m.Groups['rest'].Value

    if($yaml -match '(?im)^\s*title\s*:\s*.*$'){
      $yaml = [regex]::Replace($yaml, '(?im)^\s*title\s*:\s*.*$', ('title: "{0}"' -f (Escape-Yaml $Title)))
    } else { $yaml = ('title: "{0}"' -f (Escape-Yaml $Title)) + "`n" + $yaml }

    if($yaml -match '(?im)^\s*(description|slogan)\s*:\s*.*$'){
      $yaml = [regex]::Replace($yaml, '(?im)^\s*(description|slogan)\s*:\s*.*$', ('description: "{0}"' -f (Escape-Yaml $Slogan)))
    } else { $yaml += ("`ndescription: ""{0}""" -f (Escape-Yaml $Slogan)) }

    $new = $m.Groups['pre'].Value + $yaml.TrimEnd() + "`n---`n" + $rest
    if($new -ne $orig){
      if($PSCmdlet.ShouldProcess($Path)){ Ensure-Utf8Bom -Path $Path -Content $new }
      $changed = $true
    }
  } else {
    $isReadme = ([IO.Path]::GetFileName($Path)) -ieq 'README.md'
    if($YamlOnly -or $isReadme){
      $fm = "---`n" + ('title: "{0}"' -f (Escape-Yaml $Title)) + "`n" +
            ('description: "{0}"' -f (Escape-Yaml $Slogan)) + "`n---`n`n"
      $new = $fm + $orig
      if($PSCmdlet.ShouldProcess($Path)){ Ensure-Utf8Bom -Path $Path -Content $new }
      return $true
    }

    # Старий режим: правимо H1 та блок-цитату після нього
    $lines = ($orig -split "\r?\n", -1)
    $idxH1 = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match '^\s*#\s' })
    if($idxH1 -ge 0){
      if($lines[$idxH1] -ne ('# ' + $Title)){ $lines[$idxH1] = '# ' + $Title; $changed = $true }
      $idxNext = $idxH1 + 1
      if($idxNext -lt $lines.Length -and $lines[$idxNext] -match '^\s*>'){
        $newS = '> ' + $Slogan
        if($lines[$idxNext] -ne $newS){ $lines[$idxNext] = $newS; $changed = $true }
      } else {
        $lines = $lines[0..$idxH1] + @('> ' + $Slogan) + $lines[($idxH1+1)..($lines.Length-1)]
        $changed = $true
      }
    } else {
      $fm = "---`n" + ('title: "{0}"' -f (Escape-Yaml $Title)) + "`n" +
            ('description: "{0}"' -f (Escape-Yaml $Slogan)) + "`n---`n"
      $new = $fm + $orig
      if($PSCmdlet.ShouldProcess($Path)){ Ensure-Utf8Bom -Path $Path -Content $new }
      return $true
    }

    if($changed){
      $new = ($lines -join "`r`n")
      if($PSCmdlet.ShouldProcess($Path)){ Ensure-Utf8Bom -Path $Path -Content $new }
    }
  }
  return $changed
}

function Update-Json([string]$Path,[string]$Title,[string]$Slogan){
  if(-not (Test-Path $Path)){ Write-Warn "Skip (no file): $Path"; return $false }
  try { $obj = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } 
  catch { Write-Warn "Invalid JSON → skip: $Path"; return $false }

  $before = ($obj | ConvertTo-Json -Depth 20)

  if($null -ne $obj.title){ $obj.title = $Title } else { $obj | Add-Member -NotePropertyName title -NotePropertyValue $Title }
  if($null -ne $obj.slogan){ $obj.slogan = $Slogan } elseif($null -ne $obj.description){ $obj.description = $Slogan } else { $obj | Add-Member -NotePropertyName description -NotePropertyValue $Slogan }

  $after = ($obj | ConvertTo-Json -Depth 20)
  if($after -ne $before){
    if($PSCmdlet.ShouldProcess($Path)){ Ensure-Utf8Bom -Path $Path -Content ($obj | ConvertTo-Json -Depth 20) }
    return $true
  }
  return $false
}

# ── Основний цикл ───────────────────────────────────────────────────────────
$changedFiles = @()
foreach($path in $Targets){
  try{
    $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
    $did = $false
    switch ($ext) {
      ".md"       { $did = Update-Md   -Path $path -Title $Title -Slogan $Slogan }
      ".markdown" { $did = Update-Md   -Path $path -Title $Title -Slogan $Slogan }
      ".json"     { $did = Update-Json -Path $path -Title $Title -Slogan $Slogan }
      default     { Write-Warn "Unknown extension, skip: $path" }
    }
    if($did){ $changedFiles += $path; Write-Ok "Updated: $path" } else { Write-Info "No change: $path" }
  } catch { Write-Err "$($path): $($_.Exception.Message)" }
}

if($changedFiles.Count -eq 0){ Write-Info "Nothing to commit."; return }

# ── Git коміт/пуш ───────────────────────────────────────────────────────────
if($GitCommit){
  try{
    Push-Location $RepoPath
    $inside = (git rev-parse --is-inside-work-tree 2>$null).Trim()
    if($inside -ne 'true'){
      Write-Warn "RepoPath не git-репозиторій: $RepoPath"
    } else {
      foreach($f in ($changedFiles | Where-Object { Test-Path $_ })){ git add -- "$f" }
      git commit -m $GitCommitMessage
      if($UpdateGitHub){ git push }
      Write-Ok "Committed: $GitCommitMessage"
    }
  } catch { Write-Err "Git ops failed: $($_.Exception.Message)" }
  finally { Pop-Location }
}