param(
  [switch]$Native,
  [switch]$ForceFallback,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Args
)
$ErrorActionPreference = 'Stop'

# Керуємо fallback'ом через env, а реальному генератору нічого зайвого не передаємо
if ($ForceFallback) { $env:CHECHA_NO_NATIVE = '1' }
elseif ($Native)    { Remove-Item Env:\CHECHA_NO_NATIVE -ErrorAction SilentlyContinue }

# Приберемо всі опції (-*, --*) зі списку шляхів
$clean = @($Args | Where-Object { $_ -and ($_ -notmatch '^-{1,2}') })

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$candidates = @(
  Join-Path $here '_index\generate_protocols_table.ps1'
) + (Get-ChildItem -Path $here -Recurse -Filter 'generate_protocols_table.ps1' -ErrorAction SilentlyContinue |
     Where-Object { $_.FullName -like '*\_index\generate_protocols_table.ps1' } |
     Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName)

$real = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $real) { throw "Real generator not found." }

Write-Host "Shim(generate_table) -> $real"
# Debug на один раз, якщо треба побачити що пішло далі:
# Write-Host "Args(raw)= $($Args -join ' | ')"
# Write-Host "Args(clean)= $($clean -join ' | ')"

Unblock-File -LiteralPath $real
& $real @clean
