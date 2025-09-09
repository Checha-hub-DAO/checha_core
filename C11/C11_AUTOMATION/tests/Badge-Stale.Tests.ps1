#requires -Version 5.1
$ErrorActionPreference = 'Stop'

# ---- Шляхи (script scope) -----------------------------------------------
$script:root      = "C:\CHECHA_CORE"
$script:panel     = Join-Path $script:root "C06_FOCUS\CONTROL_PANEL.md"
$script:status    = Join-Path $script:root "C06_FOCUS\_runall_status.json"
$script:updScript = Join-Path $script:root "C11\C11_AUTOMATION\tools\Update-ControlPanel.ps1"

# ---- Санітарна перевірка шляхів -----------------------------------------
if (-not (Test-Path $script:updScript)) {
  Describe "STATUS_BADGE stale check" {
    It "SKIPPED: Update-ControlPanel.ps1 not found at $($script:updScript)" -Skip {
      $false | Should -BeTrue
    }
  }
  return
}

# Гарантуємо наявність теки/файлів (у discovery фазі, але пишемо $script:)
$script:panelDir = Split-Path $script:panel -Parent
if (-not (Test-Path $script:panelDir)) { New-Item -ItemType Directory -Path $script:panelDir -Force | Out-Null }
if (-not (Test-Path $script:panel)) {
@"
# 🛠 Панель Управління — v1.0
Останнє оновлення: {{DATE}}
Статус: {{STATUS_BADGE}}

## 1. 🔍 Статус Системи
- Останнє RunAll: {{AUTO:last_runall}}
"@ | Set-Content -Path $script:panel -Encoding utf8BOM
}

if (-not (Test-Path $script:status)) {
  $o = [ordered]@{
    ts           = (Get-Date).ToString("o")
    ok           = $true
    duration_sec = "0.1"
    only         = @()
    force        = $false
    user         = "$env:USERNAME"
  } | ConvertTo-Json -Depth 5
  [System.IO.File]::WriteAllText($script:status, $o, [System.Text.UTF8Encoding]::new($true))
}

Describe "STATUS_BADGE shows 🟡 when _runall_status.json is older than 24h" {

  BeforeAll {
    # старимо ts на 49 год
    $obj = Get-Content $script:status -Raw -Encoding UTF8 | ConvertFrom-Json
    $obj.ts = (Get-Date).AddHours(-49).ToString("o")
    [System.IO.File]::WriteAllText($script:status, ($obj | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($true))

    # оновлюємо панель
    & $script:updScript | Out-Null
  }

  It "Panel path is valid" {
    $script:panel | Should -Not -BeNullOrEmpty
    (Test-Path $script:panel) | Should -BeTrue
  }

  It "Status path is valid" {
    $script:status | Should -Not -BeNullOrEmpty
    (Test-Path $script:status) | Should -BeTrue
  }

  It "Panel contains yellow stale badge" {
    $txt = Get-Content $script:panel -Raw -Encoding UTF8
    $txt | Should -Match 'Статус:\s*🟡'
  }

  AfterAll {
    # відновлюємо свіжий ts
    $obj = Get-Content $script:status -Raw -Encoding UTF8 | ConvertFrom-Json
    $obj.ts = (Get-Date).ToString("o")
    [System.IO.File]::WriteAllText($script:status, ($obj | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($true))
    & $script:updScript | Out-Null
  }
}
