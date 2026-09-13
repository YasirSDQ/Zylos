@echo off
:: ============================================================
::  Zylos Extension - One-Click Installer
::  Auto-elevates to Administrator and runs the PowerShell
::  installer which writes registry keys for ALL Chrome profiles.
:: ============================================================
setlocal

:: Check if already running as admin
net session >nul 2>&1
if %errorlevel% == 0 goto :run_install

:: Not admin — re-launch elevated
echo [Zylos] Requesting Administrator privileges...
powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:run_install
echo.
echo  =============================================
echo   Zylos Extension Installer
echo  =============================================
echo.

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install_extension.ps1"

if not exist "%PS_SCRIPT%" (
    echo  [ERROR] install_extension.ps1 not found.
    echo  Expected: %PS_SCRIPT%
    pause
    exit /b 1
)

echo  Installing Zylos Chrome Extension...
echo  Extension folder: %SCRIPT_DIR%
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%PS_SCRIPT%" -ExtensionDir "%SCRIPT_DIR%"

echo.
pause
