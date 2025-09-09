@echo off
chcp 65001 >nul
set "CHECHA_ROOT=%~1"
set "CFG=%~2"
set "PWSH=pwsh"
where pwsh >nul 2>&1 || set "PWSH=powershell.exe"
"%PWSH%" -NoProfile -ExecutionPolicy Bypass ^
  -File "%CHECHA_ROOT%\C11\C11_AUTOMATION\tools\Run-VerifySync-WithConfig.ps1" ^
  -ChechaRoot "%CHECHA_ROOT%" ^
  -ConfigPath "%CFG%" ^
  -RunGitBook -DoGitCommitPush
exit /B %ERRORLEVEL%
