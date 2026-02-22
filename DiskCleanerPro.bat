@echo off
:: Create a temp VBS to launch PowerShell completely hidden (no console flash)
set "vbs=%temp%\DiskCleanerLaunch.vbs"
echo Set ws = CreateObject("WScript.Shell") > "%vbs%"
echo ws.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%~dp0DiskCleanerPro.ps1""", 0, False >> "%vbs%"
cscript //nologo "%vbs%"
del "%vbs%" 2>nul
exit
