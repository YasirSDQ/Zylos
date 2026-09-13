@echo off
:: ============================================================
::  Zylos Extension - One-Click Uninstaller
::  Auto-elevates to Administrator and removes registry keys
::  from ALL Chrome profiles.
:: ============================================================
setlocal

:: Check if already running as admin
net session >nul 2>&1
if %errorlevel% == 0 goto :run_uninstall

:: Not admin — re-launch elevated
echo [Zylos] Requesting Administrator privileges...
powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:run_uninstall
echo.
echo  =============================================
echo   Zylos Extension Uninstaller
echo  =============================================
echo.

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install_extension.ps1"

:: Check if pre-generated uninstall.reg exists (fastest path)
if exist "%SCRIPT_DIR%uninstall_extension.reg" (
    echo  Running registry removal via uninstall_extension.reg...
    regedit.exe /S "%SCRIPT_DIR%uninstall_extension.reg"
    echo  [OK] Registry keys removed.
) else if exist "%PS_SCRIPT%" (
    echo  Running PowerShell uninstaller...
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%PS_SCRIPT%" -ExtensionDir "%SCRIPT_DIR%" -Uninstall
) else (
    echo  [ERROR] Neither uninstall_extension.reg nor install_extension.ps1 found.
    echo  Expected in: %SCRIPT_DIR%
    pause
    exit /b 1
)

:: Also remove the External Extensions descriptor file if it exists
set "EXT_ID=zylosmediadownloaderchromeextens"
set "EXT_JSON=%LOCALAPPDATA%\Google\Chrome\User Data\External Extensions\%EXT_ID%.json"
if exist "%EXT_JSON%" (
    del /f /q "%EXT_JSON%"
    echo  [OK] Removed External Extensions descriptor.
)

echo.
echo  =============================================
echo   Zylos extension removed from Chrome.
echo   Please fully restart Chrome to apply.
echo  =============================================
echo.
pause
