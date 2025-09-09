# CHECHA Release Repo Skeleton (v1.0)

Р“РѕС‚РѕРІРёР№ РєР°СЂРєР°СЃ РґР»СЏ РЅР°РґС–Р№РЅРёС… СЂРµР»С–Р·С–РІ (ETHNO, C12, Р©РРў-4 С‚РѕС‰Рѕ). Р’Р¶Рµ РјС–СЃС‚РёС‚СЊ:
- `tools/` вЂ” СЃРєСЂРёРїС‚Рё СЂРµР»С–Р·Сѓ (Р· С€Р°Р±Р»РѕРЅСѓ v1.4)
- `.github/workflows/release.yml` вЂ” GitHub Actions
- `.githooks/pre-push` вЂ” Р»РѕРєР°Р»СЊРЅР° РїРµСЂРµРІС–СЂРєР° РїРµСЂРµРґ РїСѓС€РµРј
- `release.config.json` вЂ” С‚РёРїРѕРІРёР№ РєРѕРЅС„С–Рі (ETHNO v1.2)
- `build/ETHNO/` вЂ” РјС–СЃС†Рµ РґР»СЏ РІРјС–СЃС‚Сѓ, СЏРєРёР№ РїР°РєСѓС”РјРѕ
- `assets/` вЂ” РјРµРґС–Р° РґР»СЏ СЂРµР»С–Р·Сѓ
- `logs/` вЂ” Р»РѕРіРё Р·Р°РїСѓСЃРєС–РІ

## РЁРІРёРґРєРёР№ СЃС‚Р°СЂС‚
```powershell
# 1) Р’СЃС‚Р°РЅРѕРІРёС‚Рё С…СѓРє (РѕРґРЅРѕСЂР°Р·РѕРІРѕ)
pwsh tools/install_hooks.ps1

# 2) РџРµСЂРµРІС–СЂРёС‚Рё/Р·РјС–РЅРёС‚Рё release.config.json (BlockName/Tag/SourceDir/OutZip)
# 3) РџРѕРєР»Р°СЃС‚Рё РєРѕРЅС‚РµРЅС‚ РґР»СЏ РїР°РєСѓРІР°РЅРЅСЏ Сѓ build/ETHNO/
# 4) Р—Р°РїСѓСЃС‚РёС‚Рё СЂРµР»С–Р·
pwsh tools/release_run.ps1 -Config release.config.json

# 5) (РѕРїС†.) РЎС‚РІРѕСЂРёС‚Рё С‚Р° Р·Р°РІР°РЅС‚Р°Р¶РёС‚Рё СЂРµР»С–Р· Сѓ GitHub
pwsh tools/gh_release.ps1 -Tag (Get-Content release.config.json | ConvertFrom-Json).Tag -Clobber

# 6) РџРѕСЃС‚-РїРµСЂРµРІС–СЂРєР°
pwsh tools/verify_release_assets.ps1 -Tag (Get-Content release.config.json | ConvertFrom-Json).Tag -RequireAssets
```