@echo off
REM ============================================================
REM  register_task.bat - Register daily Task Scheduler job
REM  Run as Administrator
REM ============================================================

SET APP_PATH=C:\SportsBettingApp\SportsBettingFetcher.exe
SET TASK_NAME=SportsBettingFetcher

echo Registering scheduled task: %TASK_NAME%

schtasks /delete /tn "%TASK_NAME%" /f 2>nul

schtasks /create ^
    /tn "%TASK_NAME%" ^
    /tr "%APP_PATH%" ^
    /sc DAILY ^
    /st 06:00 ^
    /ru SYSTEM ^
    /rl HIGHEST ^
    /f ^
    /description "Fetches top 10 daily betting sports events and writes to MSSQL"

IF ERRORLEVEL 1 (
    echo ERROR: Failed to register task
    exit /b 1
)

echo Task registered. Runs daily at 6:00 AM as SYSTEM.
echo.
echo To run immediately:   schtasks /run /tn "%TASK_NAME%"
echo To check status:      schtasks /query /tn "%TASK_NAME%" /fo LIST /v
