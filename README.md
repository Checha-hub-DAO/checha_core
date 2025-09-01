# CHECHA Release Repo Skeleton (v1.0)

Готовий каркас для надійних релізів (ETHNO, C12, ЩИТ-4 тощо). Вже містить:
- `tools/` — скрипти релізу (з шаблону v1.4)
- `.github/workflows/release.yml` — GitHub Actions
- `.githooks/pre-push` — локальна перевірка перед пушем
- `release.config.json` — типовий конфіг (ETHNO v1.2)
- `build/ETHNO/` — місце для вмісту, який пакуємо
- `assets/` — медіа для релізу
- `logs/` — логи запусків

## Швидкий старт
```powershell
# 1) Встановити хук (одноразово)
pwsh tools/install_hooks.ps1

# 2) Перевірити/змінити release.config.json (BlockName/Tag/SourceDir/OutZip)
# 3) Покласти контент для пакування у build/ETHNO/
# 4) Запустити реліз
pwsh tools/release_run.ps1 -Config release.config.json

# 5) (опц.) Створити та завантажити реліз у GitHub
pwsh tools/gh_release.ps1 -Tag (Get-Content release.config.json | ConvertFrom-Json).Tag -Clobber

# 6) Пост-перевірка
pwsh tools/verify_release_assets.ps1 -Tag (Get-Content release.config.json | ConvertFrom-Json).Tag -RequireAssets
```