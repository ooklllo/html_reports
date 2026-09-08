@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish.ps1"
if %errorlevel% neq 0 (
    echo.
    echo ========================================================
    echo  [!] Error occurred. (Exit Code: %errorlevel%)
    echo ========================================================
    pause
    exit /b %errorlevel%
)
exit /b 0