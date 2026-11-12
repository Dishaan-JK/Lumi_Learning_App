@echo off
setlocal
cd /d "%~dp0"

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo Lumi needs Windows PowerShell to install its private runtimes.
  exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\bootstrap-lumi.ps1" %*
set "LUMI_EXIT=%errorlevel%"
if not "%LUMI_EXIT%"=="0" (
  echo.
  echo Lumi could not start. Check the message above.
  pause
)
exit /b %LUMI_EXIT%
