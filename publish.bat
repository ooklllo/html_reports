@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish.ps1"
set "EXIT_CODE=%errorlevel%"

if %EXIT_CODE% neq 0 (
    echo.
    echo ========================================================
    echo  [!] Error occurred during publication. (Code: %EXIT_CODE%)
    echo ========================================================
    echo.
    pause
    exit /b %EXIT_CODE%
)

timeout /t 5
exit /b 0
