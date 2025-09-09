# McHelpers — Starter Pack (v0.3.2)
Стартовий модуль із базовими утилітами `*-Mc*`.

## Вміст
- `McHelpers.psm1` — функції `Write-McLog`, `Compress-McZip`, `Test-McEncodingUtf8Bom`.
- `McHelpers.psd1` — маніфест.
- `tests\McHelpers.tests.ps1` — прості smoke-тести.
- `.editorconfig`, `.gitattributes` — політики кодування/рядків.

## Встановлення
1. Скопіюй папку `C12\Protocols\_index\McHelpers` у свою структуру `CHECHA_CORE`.
2. Додай шлях модуля до `$env:PSModulePath` або імпортуй за абсолютним шляхом.
3. Використай:
```powershell
Import-Module McHelpers -Force
Write-McLog -LogPath "C:\CHECHA_CORE\C03\LOG\demo.log" -Message "McHelpers OK" -Level INFO
```

## Примітки
- Рекомендована кодування: UTF-8 з BOM для скриптів із кирилицею.
