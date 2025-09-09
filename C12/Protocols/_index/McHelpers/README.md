# McHelpers — Starter Pack (v0.3.3)
Стартовий модуль із базовими утилітами `*-Mc*` + автоінсталятор.

## Вміст
- `McHelpers.psm1` / `McHelpers.psd1` — модуль.
- `tests\McHelpers.tests.ps1` — smoke-тести.
- `.editorconfig`, `.gitattributes` — політики коду.
- `C11\C11_AUTOMATION\tools\Install-McHelpers.ps1` — **auto-install**.
- `tools\Normalize-ChechaEncodings.ps1` — масова нормалізація кодувань.

## Швидкий старт
```powershell
# 1) Запусти автоінсталятор (вкажи шлях до ZIP, якщо треба)
pwsh -NoProfile -File "C:\CHECHA_CORE\C11\C11_AUTOMATION\tools\Install-McHelpers.ps1"

# 2) Smoke-тест
Import-Module McHelpers -Force
Write-McLog -LogPath "C:\CHECHA_CORE\C03\LOG\demo.log" -Message "McHelpers OK" -Level INFO
```
