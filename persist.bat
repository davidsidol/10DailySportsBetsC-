@echo off
REM ============================================================
REM  persist.bat - Register everything for auto-start on boot
REM  Run ONCE as Administrator after initial deployment
REM ============================================================

echo === SportsBetting Persistence Setup ===
echo.

SET APPCMD=%SystemRoot%\System32\inetsrv\appcmd.exe

REM --- 1. Set SQL Server to auto-start ---
echo [1/5] Setting SQL Server IDOLMSSQL to auto-start...
sc config MSSQL$IDOLMSSQL start= auto
sc config SQLBrowser start= auto
net start SQLBrowser >nul 2>&1

REM --- 2. Set IIS to auto-start ---
echo [2/5] Setting IIS to auto-start...
sc config W3SVC start= auto
sc config WAS start= auto

REM --- 3. Set IIS app pool to auto-start ---
echo [3/5] Configuring app pool auto-start...
%APPCMD% set apppool "SportsBetting" /autoStart:true
%APPCMD% set apppool "SportsBetting" /startMode:AlwaysRunning
%APPCMD% set site "SportsBetting" /applicationDefaults.preloadEnabled:true

REM --- 4. Register startup check task at boot ---
echo [4/5] Registering boot startup task...
schtasks /delete /tn "SportsBettingStartup" /f >nul 2>&1
schtasks /create ^
    /tn "SportsBettingStartup" ^
    /tr "C:\SportsBettingApp\startup.bat" ^
    /sc ONSTART ^
    /delay 0001:00 ^
    /ru SYSTEM ^
    /rl HIGHEST ^
    /f

REM --- 5. Register daily fetcher task ---
echo [5/5] Registering daily fetcher task...
schtasks /delete /tn "SportsBettingFetcher" /f >nul 2>&1
schtasks /create ^
    /tn "SportsBettingFetcher" ^
    /tr "C:\SportsBettingApp\SportsBettingFetcher.exe" ^
    /sc DAILY ^
    /st 06:00 ^
    /ru SYSTEM ^
    /rl HIGHEST ^
    /f

echo.
echo === Persistence Setup Complete ===
echo.
echo Services configured for auto-start:
echo   - SQL Server IDOLMSSQL  (auto)
echo   - SQL Server Browser    (auto)
echo   - IIS W3SVC             (auto)
echo   - IIS WAS               (auto)
echo   - App Pool SportsBetting (AlwaysRunning)
echo.
echo Scheduled Tasks registered:
echo   - SportsBettingStartup  (on boot, 1min delay)
echo   - SportsBettingFetcher  (daily at 06:00 AM)
echo.
echo Dashboard will be available at http://localhost:8090 after reboot.
echo Run: schtasks /run /tn "SportsBettingFetcher" to fetch data immediately.
