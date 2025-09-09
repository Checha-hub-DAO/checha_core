@echo off
setlocal ENABLEDELAYEDEXPANSION
chcp 65001 >nul
REM Usage: run_from_config.bat "C:\CHECHA_CORE" "C:\CHECHA_CORE\C11\C11_AUTOMATION\configs\g45-1-aot.json"
set "CHECHA_ROOT=%~1"
set "CFG=%~2"
if "%CHECHA_ROOT%"=="" goto :usage
if "%CFG%"=="" goto :usage

set "PWSH="
where pwsh >nul 2>&1 && set "PWSH=pwsh"
if not defined PWSH if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PWSH set "PWSH=powershell.exe"

"%PWSH%" -NoProfile -ExecutionPolicy Bypass ^
  -File "%CHECHA_ROOT%\C11\C11_AUTOMATION\tools\Run-VerifySync-WithConfig.ps1" ^
  -ChechaRoot "%CHECHA_ROOT%" ^
  -ConfigPath "%CFG%" ^
  -UseGitHubAssets -RunGitBook -DoGitCommitPush

set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" echo [ERR] RC=%RC%
echo.
pause
exit /B %RC%

:usage
echo Usage: run_from_config.bat "C:\CHECHA_CORE" "path\to\config.json"
pause
exit /B 1
