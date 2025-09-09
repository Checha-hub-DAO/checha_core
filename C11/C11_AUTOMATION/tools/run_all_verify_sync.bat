@echo off
chcp 65001 >nul
schtasks.exe /Run /TN "Checha-VerifySync-g45-1-aot"
schtasks.exe /Run /TN "Checha-VerifySync-g43-iteta"
