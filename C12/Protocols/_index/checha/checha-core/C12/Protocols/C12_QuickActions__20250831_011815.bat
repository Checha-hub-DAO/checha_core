@echo off
:: C12 Quick Actions — С.Ч.
setlocal ENABLEDELAYEDEXPANSION

:: === CONFIG ===
set "CORE=C:\CHECHA_CORE"
set "PROT=%CORE%\C12\Protocols"
set "NAV=%CORE%\C12\NAV\C12_NAV.md"
set "GITBOOK_URL="
:: TODO: задай GITBOOK_URL на сторінку "C12 — Тематична Навігація"

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
