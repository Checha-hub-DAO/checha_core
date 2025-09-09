[CmdletBinding()]
param(
  [string]$Tag,                         # напр.: c12-docs-v2.1 (якщо не задано, буде згенеровано)
  [string]$Title,                       # напр.: "C12 Docs v2.1 — FAQ + Examples" (дефолт = "C12 Docs <Tag>")
  [string]$ZipPath,                     # явний шлях до ZIP (опц.)
  [string]$RepoPath = "C:\CHECHA_CORE\repos\ETHNO-releases",
  [string]$NotesPath,                   # явний шлях до нотаток (опц.)
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Assert-Exe($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Required tool not found: $name"
  }
}
Assert-Exe gh

if (-not (Test-Path $RepoPath)) {
  throw "RepoPath not found: $RepoPath"
}

# 1) ZIP: явний або найновіший у репо
if ($ZipPath) {
  if (-not (Test-Path $ZipPath)) { throw "ZIP not found: $ZipPath" }
  $Zip = Get-Item $ZipPath
} else {
  $Zip = Get-ChildItem -Path $RepoPath -Filter *.zip -File |
         Sort-Object LastWriteTimeUtc -Descending |
         Select-Object -First 1
}

# 2) Тег: якщо не заданий — виводимо з імені ZIP; якщо ZIP нема — генеруємо
if (-not $Tag) {
  if ($Zip) {
    $name = $Zip.Name
    if     ($name -match '(?i)c12.*?v([\w\.\-]+)')       { $Tag = "c12-docs-v$($Matches[1])" }
    elseif ($name -match '(?i)c12.*?(\d{8}[_-]?\d{6})')  { $Tag = "c12-docs-$($Matches[1])" }
    else                                                 { $Tag = "c12-docs-$(Get-Date -AsUTC -Format yyyyMMdd_HHmmss)" }
  } else {
    $Tag = "c12-docs-$(Get-Date -AsUTC -Format yyyyMMdd_HHmmss)"
  }
}

# 3) Якщо ZIP досі нема — ЗБИРАЄМО з checha_core/
if (-not $Zip) {
  $src = Join-Path $RepoPath "checha_core"
  if (-not (Test-Path $src)) { throw "checha_core not found at $src — нема що пакувати." }
  $zipName    = "GitBook_C12_Docs_$($Tag).zip" -replace '[^\w\.\-]','_'
  $zipPathNew = Join-Path $RepoPath $zipName
  Write-Host "🧱 Building ZIP from $src -> $zipPathNew ..."
  if (Test-Path $zipPathNew) { Remove-Item $zipPathNew -Force }
  Compress-Archive -Path (Join-Path $src '*') -DestinationPath $zipPathNew -Force
  $Zip = Get-Item $zipPathNew
}

# 4) Title: дефолт
if (-not $Title -or [string]::IsNullOrWhiteSpace($Title)) {
  $Title = "C12 Docs $Tag"
}

# 5) CHECKSUMS: шукаємо; якщо нема — генеруємо
$ChecksumsFile = Get-ChildItem $RepoPath -Filter "*$Tag*.txt" -File -ErrorAction SilentlyContinue |
                 Select-Object -First 1
if (-not $ChecksumsFile) {
  $ChecksumPath = Join-Path $RepoPath ("CHECKSUMS_{0}.txt" -f $Tag)
  $sha = (Get-FileHash $Zip.FullName -Algorithm SHA256).Hash
  "$sha  $($Zip.Name)" | Out-File -FilePath $ChecksumPath -Encoding ASCII
  $ChecksumsFile = Get-Item $ChecksumPath
}

# 6) Notes: явний шлях або RELEASE_NOTES_<tag>.md; якщо нема — автогенерація
if ($NotesPath) {
  if (-not (Test-Path $NotesPath)) { throw "Notes file not found: $NotesPath" }
} else {
  $NotesPath = Join-Path $RepoPath ("RELEASE_NOTES_{0}.md" -f $Tag)
  if (-not (Test-Path $NotesPath)) {
    @"
# $Title
Manual release of C12 docs.

## Contents
- $($Zip.Name)
- $($ChecksumsFile.Name)

Generated: $(Get-Date -AsUTC -Format 'yyyy-MM-dd HH:mm:ss \U\T\C')
"@ | Set-Content -Path $NotesPath -Encoding UTF8
  }
}

Write-Host "📦 Release parameters:" -ForegroundColor Cyan
Write-Host "  Tag:        $Tag"
Write-Host "  Title:      $Title"
Write-Host "  ZIP:        $($Zip.FullName)"
Write-Host "  CHECKSUMS:  $($ChecksumsFile.FullName)"
Write-Host "  NOTES:      $NotesPath"

if ($DryRun) {
  Write-Host "💡 DryRun mode: no changes made to GitHub." -ForegroundColor Yellow
  exit 0
}

# 7) Публікація/оновлення релізу на GitHub
Push-Location $RepoPath
try {
  if (gh release view $Tag 2>$null) {
    Write-Host "♻️ Updating existing release..."
    gh release upload $Tag $Zip.FullName $ChecksumsFile.FullName --clobber
    gh release edit $Tag --title "$Title" --notes-file $NotesPath
  } else {
    Write-Host "🚀 Creating new release..."
    gh release create $Tag `
      $Zip.FullName `
      $ChecksumsFile.FullName `
      $NotesPath `
      --title "$Title" `
      --notes-file $NotesPath
  }
}
finally {
  Pop-Location
}

# 8) Автооновлення README.md → "Останній реліз" + "Історія релізів (топ-5)"
try {
  $readme = Join-Path $RepoPath "README.md"
  if (Test-Path $readme) {
    $repoSlug = "Checha-hub-DAO/ETHNO-releases"

    # Побудувати блок "Останній реліз"
    $urlLatest = "https://github.com/$repoSlug/releases/tag/$Tag"
    $latestLine = "`n## 🆕 Останній реліз`n- [$Title]($urlLatest) — $((Get-Date).ToString('yyyy-MM-dd'))`n"

    # Отримати останні релізи та побудувати "Історія релізів (топ-5)"
    $json = gh api "repos/$repoSlug/releases?per_page=10"
    $rels = $json | ConvertFrom-Json
    $top = $rels | Sort-Object { [datetime]($_.published_at ?? $_.created_at) } -Descending | Select-Object -First 5

    $histItems = foreach ($r in $top) {
      $nm = if ([string]::IsNullOrWhiteSpace($r.name)) { $r.tag_name } else { $r.name }
      $dt = [datetime]($r.published_at ?? $r.created_at)
      "- [$nm]($($r.html_url)) — $($dt.ToString('yyyy-MM-dd'))"
    }
    $historyBlock = "`n## 📜 Історія релізів (останні 5)`n" + ($histItems -join "`n") + "`n"

    # Прочитати README і оновити/вставити обидві секції
    $content = Get-Content $readme -Raw

    if ($content -match '## 🆕 Останній реліз') {
      $content = [regex]::Replace($content, '## 🆕 Останній реліз[\s\S]*?(?=\n## |\z)', $latestLine)
    } else {
      $content += $latestLine
    }

    if ($content -match '## 📜 Історія релізів') {
      $content = [regex]::Replace($content, '## 📜 Історія релізів[\s\S]*?(?=\n## |\z)', $historyBlock)
    } else {
      $content += $historyBlock
    }

    $content | Set-Content $readme -Encoding UTF8

    # Коміт і пуш змін README (якщо є)
    if (Get-Command git -ErrorAction SilentlyContinue) {
      Push-Location $RepoPath
      try {
        git add README.md | Out-Null
        $staged = (git diff --cached --name-only).Trim()
        if ($staged) {
          git commit -m "docs(repo): оновлено 'Останній реліз' та 'Історія релізів' ($Tag)" | Out-Null
          git push origin (git rev-parse --abbrev-ref HEAD).Trim() | Out-Null
          Write-Host "📝 README.md оновлено (останній + історія) та запушено."
        } else {
          Write-Host "ℹ️ README.md без змін (нічого комітити)."
        }
      } finally {
        Pop-Location
      }
    } else {
      Write-Warning "git не знайдено — README оновлено локально без коміту."
    }
  } else {
    Write-Warning "README.md не знайдено у $RepoPath — пропускаю оновлення."
  }
} catch {
  Write-Warning "Не вдалося оновити README.md (останній/історія): $($_.Exception.Message)"
}

Write-Host "✅ Done."
