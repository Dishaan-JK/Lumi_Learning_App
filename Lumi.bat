@echo off
setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo Lumi requires Node.js 22 or newer. Install Node.js, then run Lumi.bat again.
  exit /b 1
)

node "%~dp0scripts\launch-lumi.mjs" %*
exit /b %errorlevel%
