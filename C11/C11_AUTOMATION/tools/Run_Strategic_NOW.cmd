@echo off
setlocal EnableExtensions EnableDelayedExpansion
title CheCha Strategic - RUN NOW

rem --- pick PowerShell engine (pwsh 7 -> fallback to Windows PowerShell) ---
set "PS7=C:\Program Files\PowerShell\7\pwsh.exe"
set "PSWIN=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%PS7%" (set "PS=%PS7%") else set "PS=%PSWIN%"

set "CORE=C:\CHECHA_CORE"
set "MAIN=%CORE%\C11\C11_AUTOMATION\tools\Create-StrategicTemplate.ps1"
set "HEALTH=%CORE%\C11\C11_AUTOMATION\tools\Checha_StrategicTemplate_Health.ps1"

set "TN_MAIN=\CHECHA\CreateStrategicTemplate-Daily"
set "TN_BK=\CHECHA\CreateStrategicTemplate-Daily-12h05"
set "TN_HC=\CHECHA\StrategicTemplate-HealthCheck"

echo [CheCha] Engine: %PS%
echo [CheCha] MAIN  : %MAIN%
echo [CheCha] HEALTH: %HEALTH%
echo.

rem --- try tasks first ---
set "HAD_TASKS="
for %%T in ("%TN_MAIN%" "%TN_BK%" "%TN_HC%") do (
  schtasks /Query /TN %%~T >nul 2>&1 && set "HAD_TASKS=1"
)

if defined HAD_TASKS (
  echo [CheCha] Tasks detected. Triggering what exists...
  schtasks /Query /TN "%TN_MAIN%" >nul 2>&1 && (echo  -> %TN_MAIN% & schtasks /Run /TN "%TN_MAIN%")
  schtasks /Query /TN "%TN_BK%"   >nul 2>&1 && (echo  -> %TN_BK%   & schtasks /Run /TN "%TN_BK%")
  schtasks /Query /TN "%TN_HC%"   >nul 2>&1 && (echo  -> %TN_HC%   & schtasks /Run /TN "%TN_HC%")
  timeout /t 3 >nul
) else (
  echo [CheCha] No CheCha tasks found. Using DIRECT fallback...
  if not exist "%MAIN%"   (echo  !! MAIN script missing: %MAIN% & goto TAIL)
  if not exist "%HEALTH%" (echo  !! HEALTH script missing: %HEALTH% & goto TAIL)

  "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%MAIN%"   -OpenWith none
  "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HEALTH%"
)

rem --- quick status (if tasks present) ---
if defined HAD_TASKS (
  for %%T in ("%TN_MAIN%" "%TN_BK%" "%TN_HC%") do (
    schtasks /Query /TN %%~T >nul 2>&1 && (
      echo ==== %%~T ====
      schtasks /Query /TN %%~T /V /FO LIST | findstr /R /C:"Last Run Time" /C:"Last Result" /C:"Next Run Time"
    )
  )
)

:TAIL
echo.
echo ---- Tail of strategic_template_*.log ----
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
 "try{ $p=Get-ChildItem 'C:\CHECHA_CORE\C03\LOG' -Filter 'strategic_template_*.log' | Sort-Object LastWriteTime -Desc | Select-Object -First 1 -ExpandProperty FullName }catch{}; if($p){ Get-Content -LiteralPath $p -Tail 20 } else { 'No strategic_template_*.log yet.' }"

echo.
pause
exit /b