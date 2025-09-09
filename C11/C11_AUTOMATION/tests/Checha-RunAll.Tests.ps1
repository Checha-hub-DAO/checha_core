#requires -Version 5.1
# Pester v5
$root   = "C:\CHECHA_CORE"
$tool   = Join-Path $root "C11\C11_AUTOMATION\Checha-RunAll.ps1"
$panel  = Join-Path $root "C06_FOCUS\CONTROL_PANEL.md"
$status = Join-Path $root "C06_FOCUS\_runall_status.json"

Describe "Checha-RunAll status JSON" {
  BeforeAll {
    . $tool  # завантажуємо функцію
    # пробний запуск швидкий і без сайд-ефектів на дашборд
    Checha-RunAll -Only "Test" -SkipDashboard -NoTranscript | Out-Null
    Assert-True (Test-Path $status) "status file should exist"
    $jsonRaw = Get-Content $status -Raw -Encoding UTF8
    $obj = $jsonRaw | ConvertFrom-Json
    Set-ItVariable -Name "obj" -Value $obj
  }

  It "has ISO8601 timestamp" {
    $script:obj.ts | Should -Match '^\d{4}-\d{2}-\d{2}T'
  }

  It "has boolean ok" {
    ($script:obj.ok -is [bool]) | Should -BeTrue
  }

  It "duration has dot separator" {
    $script:obj.duration_sec | Should -Match '^\d+\.\d$'
  }

  It "only is an array (may be empty)" {
    ($script:obj.only -is [System.Collections.IEnumerable]) | Should -BeTrue
  }

  It "user is non-empty" {
    [string]::IsNullOrWhiteSpace($script:obj.user) | Should -BeFalse
  }
}

Describe "Checha-RunAll panel update" {
  It "updates CONTROL_PANEL.md when -UpdatePanel" {
    . $tool
    Checha-RunAll -Only "Test" -SkipDashboard -NoTranscript -UpdatePanel | Out-Null
    (Test-Path $panel) | Should -BeTrue
    $head = Get-Content $panel -Encoding UTF8 -TotalCount 40
    ($head -join "`n") | Should -Match 'Останнє RunAll:'
  }
}
