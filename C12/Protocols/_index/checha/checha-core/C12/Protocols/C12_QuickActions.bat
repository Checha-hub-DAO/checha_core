@echo off
:: C12 Quick Actions вЂ” РЎ.Р§.
setlocal ENABLEDELAYEDEXPANSION

:: === CONFIG ===
set "CORE=C:\CHECHA_CORE"
set "PROT=%CORE%\C12\Protocols"
set "NAV=%CORE%\C12\NAV\C12_NAV.md"
set "DAO_JOURNAL_URL=https://gogs-or-dao-systemtled-1.gitbook.io/dao-gogs-main/dao-gogs/stuktura/zhurnal-dao"
set "MINIO_CONSOLE_URL=http://127.0.0.1:9001"
set "G23_FORM_URL_LIVE=https://docs.google.com/forms/d/1BOy2GNpEiMJpm-h_2IW1WyicFqQw8KZu1G5R469eGis/viewform"
set "G23_SHEET_URL_LIVE=https://docs.google.com/spreadsheets/d/1oK8rIptL1Tj1R-Wd59eEJCIZSWWGvxuPFcHkazYPOIg/view?gid=1548703047"
set "G23_FORM_URL_EDIT=https://docs.google.com/forms/d/1BOy2GNpEiMJpm-h_2IW1WyicFqQw8KZu1G5R469eGis/edit"
set "G23_SHEET_URL_EDIT=https://docs.google.com/spreadsheets/d/1oK8rIptL1Tj1R-Wd59eEJCIZSWWGvxuPFcHkazYPOIg/edit?gid=1548703047#gid=1548703047"
set "GITBOOK_URL=https://gogs-or-dao-systemtled-1.gitbook.io/dao-gogs-main/checha_core/c12_knowledge_vault/tematichna-navigaciya-v1.0/golovne-operativka"
:: TODO: Р·Р°РґР°Р№ GITBOOK_URL РЅР° СЃС‚РѕСЂС–РЅРєСѓ "C12 вЂ” РўРµРјР°С‚РёС‡РЅР° РќР°РІС–РіР°С†С–СЏ"

:menu
cls
echo ============================================
echo   C12 Quick Actions
echo ============================================
echo [1] Reindex + Diff  (MinIO ^<^> Local)
echo [2] Weekly Snapshot (ZIP + SHA256)
echo [3] Open NAV (local)
echo [4] Open GitBook page (browser)
echo [Q] Quit
echo.
set /p "choice=Select: "

if /I "%choice%"=="1" goto act1
if /I "%choice%"=="2" goto act2
if /I "%choice%"=="3" goto act3
if /I "%choice%"=="4" goto act4
if /I "%choice%"=="7" goto act7
if /I "%choice%"=="Q" goto end
goto menu

:act1
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROT%\C12-Reindex-And-Diff.ps1" ^
  -Bucket "checha" ^
  -Prefix "checha/checha-core/C12/Protocols" ^
  -Local  "%CORE%\C12\Protocols"
pause
goto menu

:act2
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROT%\C12-Snapshot.ps1" ^
  -Source "%CORE%\C12" ^
  -ArchiveRoot "%CORE%\C05_ARCHIVE\C12_SNAPSHOTS"
pause
goto menu

:act3
if exist "%NAV%" start "" "%NAV%"
goto menu

:act4
if not "%GITBOOK_URL%"=="" start "" "%GITBOOK_URL%"
goto menu

:end
endlocal

:act7
if not "%DAO_JOURNAL_URL%"=="" ( start "" "%DAO_JOURNAL_URL%" ) else ( echo DAO_JOURNAL_URL is not set. Edit BAT to add your link. & pause )
goto menu

:act8
set "SNAP=%CORE%\C05_ARCHIVE\C12_SNAPSHOTS"
if exist "%SNAP%" ( start "" "%SNAP%" ) else ( echo Snapshots folder not found: %SNAP% & pause )
goto menu

:act9
if not "%MINIO_CONSOLE_URL%"=="" ( start "" "%MINIO_CONSOLE_URL%" ) else ( echo MINIO_CONSOLE_URL is not set. Edit BAT to add your link. & pause )
goto menu

:act10
if not "%G23_FORM_URL_LIVE%"=="" ( start "" "%G23_FORM_URL_LIVE%" ) else ( echo G23_FORM_URL_LIVE is not set. Edit BAT to add your link. & pause )
goto menu

:act11
if not "%G23_SHEET_URL_LIVE%"=="" ( start "" "%G23_SHEET_URL_LIVE%" ) else ( echo G23_SHEET_URL_LIVE is not set. Edit BAT to add your link. & pause )
goto menu

:act12
if not "%G23_FORM_URL_EDIT%"=="" ( start "" "%G23_FORM_URL_EDIT%" ) else ( echo G23_FORM_URL_EDIT is not set. Edit BAT to add your link. & pause )
goto menu

:act13
if not "%G23_SHEET_URL_EDIT%"=="" ( start "" "%G23_SHEET_URL_EDIT%" ) else ( echo G23_SHEET_URL_EDIT is not set. Edit BAT to add your link. & pause )
goto menu
