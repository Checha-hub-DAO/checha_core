@echo off
chcp 65001 >nul
set "CHECHA_ROOT=%~1"
set "CFG=%~2"

set "PWSH="
where pwsh >nul 2>&1 && set "PWSH=pwsh"
if not defined PWSH if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PWSH set "PWSH=powershell.exe"

"%PWSH%" -NoProfile -ExecutionPolicy Bypass ^
  -File "%CHECHA_ROOT%\C11\C11_AUTOMATION\tools\Run-VerifySync-WithConfig.ps1" ^
  -ChechaRoot "%CHECHA_ROOT%" ^
  -ConfigPath "%CFG%" ^
  -UseGitHubAssets -RunGitBook -DoGitCommitPush

exit /B %ERRORLEVEL%
