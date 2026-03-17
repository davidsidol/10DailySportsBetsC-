@echo off
REM ============================================================
REM  startup.bat - Ensures all SportsBetting services are running
REM  Registered as a Windows Service via NSSM or Task Scheduler
REM  Called at system boot
REM ============================================================

echo [%DATE% %TIME%] SportsBetting startup check >> C:\SportsBettingApp\startup.log

REM --- 1. Ensure SQL Server instance is running ---
sc query MSSQL$IDOLMSSQL | findstr "RUNNING" >nul
IF ERRORLEVEL 1 (
    echo [%DATE% %TIME%] Starting SQL Server IDOLMSSQL... >> C:\SportsBettingApp\startup.log
    net start MSSQL$IDOLMSSQL
) ELSE (
    echo [%DATE% %TIME%] SQL Server IDOLMSSQL already running >> C:\SportsBettingApp\startup.log
)

REM --- 2. Ensure IIS is running ---
sc query W3SVC | findstr "RUNNING" >nul
IF ERRORLEVEL 1 (
    echo [%DATE% %TIME%] Starting IIS (W3SVC)... >> C:\SportsBettingApp\startup.log
    net start W3SVC
) ELSE (
    echo [%DATE% %TIME%] IIS already running >> C:\SportsBettingApp\startup.log
)

REM --- 3. Ensure SportsBetting IIS site is started ---
%SystemRoot%\System32\inetsrv\appcmd.exe start site "SportsBetting" >> C:\SportsBettingApp\startup.log 2>&1

REM --- 4. Ensure SportsBettingFetcher task is registered ---
schtasks /query /tn "SportsBettingFetcher" >nul 2>&1
IF ERRORLEVEL 1 (
    echo [%DATE% %TIME%] Re-registering scheduled task... >> C:\SportsBettingApp\startup.log
    schtasks /create /tn "SportsBettingFetcher" /tr "C:\SportsBettingApp\SportsBettingFetcher.exe" /sc DAILY /st 06:00 /ru SYSTEM /rl HIGHEST /f
)

echo [%DATE% %TIME%] Startup check complete >> C:\SportsBettingApp\startup.log
