<#
.SYNOPSIS
  Fast commit & push helper for GitBook-synced repos.

.DESCRIPTION
  - Checks you are inside a git repository.
  - Stages files (paths or -All).
  - Creates a commit only if there are staged changes.
  - Pushes to remote/branch.
  - Optional creation of a draft PR.

.PARAMETER RepoPath
  Path to the git repository root. Default: current directory.

.PARAMETER Paths
  One or more file/folder paths to stage (relative to RepoPath). If omitted, use -All.

.PARAMETER All
  Stage all changes (equivalent to `git add .`).

.PARAMETER Message
  Commit message. Default: "docs: sync GitBook".

.PARAMETER Remote
  Git remote name. Default: origin.

.PARAMETER Branch
  Target branch. Default: current branch.

.PARAMETER CreatePR
  Create a draft Pull Request using GitHub CLI (gh).

.PARAMETER PRTitle
  Title for the PR (used with -CreatePR). Default: "docs: GitBook sync".

.EXAMPLE
  pwsh -File .\Sync-GitBook.ps1 -All -Message "docs(c12): update roadmap"

.EXAMPLE
  pwsh -File .\Sync-GitBook.ps1 -Paths "checha_core/c12_roadmap.md","SUMMARY.md" -Branch main -Message "docs(c12): add roadmap"
#>

[CmdletBinding()]
param(
  [string]$RepoPath = (Get-Location).Path,
  [string[]]$Paths,
  [switch]$All,
  [string]$Message = "docs: sync GitBook",
  [string]$Remote = "origin",
  [string]$Branch,
  [switch]$CreatePR,
  [string]$PRTitle = "docs: GitBook sync"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Exe($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Required tool not found: $name"
  }
}

function Assert-GitRepo {
  if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    throw "RepoPath is not a git repository: $RepoPath"
  }
}

# Preconditions
Assert-Exe git
if ($CreatePR) { Assert-Exe gh }

# Enter repo
Push-Location $RepoPath
try {
  Assert-GitRepo

  # Resolve target branch
  if ([string]::IsNullOrWhiteSpace($Branch)) {
    $Branch = (git rev-parse --abbrev-ref HEAD).Trim()
  }

  # Stage
  if ($All -or -not $PSBoundParameters.ContainsKey('Paths')) {
    git add .
  } else {
    foreach ($p in $Paths) {
      git add -- "$p"
    }
  }

  # Commit only if there are staged changes
  $status = git diff --cached --name-only
  if ($status) {
    git commit -m $Message
    Write-Host "✅ Commit created."
  } else {
    Write-Host "ℹ️ No staged changes. Nothing to commit."
  }

  # Push
  git push $Remote $Branch
  Write-Host "🚀 Pushed to $Remote/$Branch."

  # Optional PR
  if ($CreatePR) {
    try {
      gh pr create --title "$PRTitle" --body "$Message" --draft | Out-Host
      Write-Host "📝 Draft PR created."
    } catch {
      Write-Warning "Failed to create PR: $($_.Exception.Message)"
    }
  }
}
finally {
  Pop-Location
}
